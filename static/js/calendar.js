/**
 * calendar.js — 面试日历页面
 * 功能：获取面试列表，按过去/未来分割，近期按日期分组，CRUD 操作
 */

(function () {
  'use strict';

  // ── Constants ──────────────────────────────────────────────────────────
  const TYPE_LABELS = { phone: '电话面', video: '视频面', onsite: '现场面' };
  const RESULT_LABELS = { pending: '待定', passed: '通过', failed: '未通过' };

  // ── State ──────────────────────────────────────────────────────────────
  let interviews = [];
  let applications = [];

  // ── DOM refs ───────────────────────────────────────────────────────────
  const $ = (sel) => document.querySelector(sel);
  const upcomingContainer = $('#upcoming-container');
  const pastContainer = $('#past-container');
  const addBtn = $('#add-interview-btn');
  const modal = $('#interview-modal');
  const modalTitle = $('#modal-title');
  const modalCloseBtn = $('#modal-close-btn');
  const modalCancelBtn = $('#modal-cancel-btn');
  const form = $('#interview-form');
  const interviewIdInput = $('#interview-id');
  const applicationSelect = $('#application-select');
  const interviewTypeSelect = $('#interview-type');
  const interviewDateInput = $('#interview-date');
  const interviewerInput = $('#interviewer');
  const resultSelect = $('#result');
  const notesInput = $('#notes');

  // ── Init ───────────────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    addBtn.addEventListener('click', openAddModal);
    modalCloseBtn.addEventListener('click', closeModal);
    modalCancelBtn.addEventListener('click', closeModal);
    modal.addEventListener('click', function (e) {
      if (e.target === modal) closeModal();
    });
    form.addEventListener('submit', handleSubmit);

    await Promise.all([fetchInterviews(), fetchApplications()]);
    render();
  }

  // ── API calls ──────────────────────────────────────────────────────────
  async function fetchInterviews() {
    try {
      const res = await fetch('/api/interviews');
      if (!res.ok) throw new Error('Failed to fetch interviews');
      interviews = await res.json();
    } catch (err) {
      console.error(err);
      interviews = [];
    }
  }

  async function fetchApplications() {
    try {
      const res = await fetch('/api/applications');
      if (!res.ok) throw new Error('Failed to fetch applications');
      applications = await res.json();
    } catch (err) {
      console.error(err);
      applications = [];
    }
    populateApplicationDropdown();
  }

  async function createInterview(data) {
    const res = await fetch('/api/interviews', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || '创建失败');
    }
    return res.json();
  }

  async function updateInterview(id, data) {
    const res = await fetch('/api/interviews/' + id, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || '更新失败');
    }
    return res.json();
  }

  async function deleteInterview(id) {
    const res = await fetch('/api/interviews/' + id, { method: 'DELETE' });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || '删除失败');
    }
  }

  // ── Date helpers ───────────────────────────────────────────────────────
  function startOfDay(d) {
    const nd = new Date(d);
    nd.setHours(0, 0, 0, 0);
    return nd;
  }

  function isToday(d) {
    const now = startOfDay(new Date());
    const target = startOfDay(d);
    return target.getTime() === now.getTime();
  }

  function isTomorrow(d) {
    const now = startOfDay(new Date());
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const target = startOfDay(d);
    return target.getTime() === tomorrow.getTime();
  }

  function isThisWeek(d) {
    const now = new Date();
    const target = new Date(d);
    const dayOfWeek = now.getDay(); // 0=Sun
    const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
    const monday = startOfDay(new Date(now));
    monday.setDate(monday.getDate() + mondayOffset);
    const nextMonday = new Date(monday);
    nextMonday.setDate(nextMonday.getDate() + 7);
    return target >= monday && target < nextMonday;
  }

  function formatDateTime(isoStr) {
    if (!isoStr) return '未定时间';
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return '未定时间';
    const y = d.getFullYear();
    const mo = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const h = String(d.getHours()).padStart(2, '0');
    const mi = String(d.getMinutes()).padStart(2, '0');
    return y + '-' + mo + '-' + day + ' ' + h + ':' + mi;
  }

  function toDatetimeLocalValue(isoStr) {
    if (!isoStr) return '';
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return '';
    const y = d.getFullYear();
    const mo = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const h = String(d.getHours()).padStart(2, '0');
    const mi = String(d.getMinutes()).padStart(2, '0');
    return y + '-' + mo + '-' + day + 'T' + h + ':' + mi;
  }

  // ── Grouping ───────────────────────────────────────────────────────────
  function splitPastFuture(list) {
    const now = startOfDay(new Date());
    const upcoming = [];
    const past = [];
    for (const iv of list) {
      if (!iv.interview_date) {
        // No date: treat as upcoming (can't determine)
        upcoming.push(iv);
        continue;
      }
      const d = startOfDay(new Date(iv.interview_date));
      if (d >= now) {
        upcoming.push(iv);
      } else {
        past.push(iv);
      }
    }
    // Sort upcoming ascending, past descending
    upcoming.sort((a, b) => new Date(a.interview_date || 0) - new Date(b.interview_date || 0));
    past.sort((a, b) => new Date(b.interview_date || 0) - new Date(a.interview_date || 0));
    return { upcoming, past };
  }

  function groupUpcoming(list) {
    const groups = { today: [], tomorrow: [], week: [], later: [] };
    for (const iv of list) {
      if (!iv.interview_date) {
        groups.later.push(iv);
        continue;
      }
      const d = new Date(iv.interview_date);
      if (isToday(d)) {
        groups.today.push(iv);
      } else if (isTomorrow(d)) {
        groups.tomorrow.push(iv);
      } else if (isThisWeek(d)) {
        groups.week.push(iv);
      } else {
        groups.later.push(iv);
      }
    }
    return groups;
  }

  // ── Rendering ──────────────────────────────────────────────────────────
  function render() {
    const { upcoming, past } = splitPastFuture(interviews);
    renderUpcoming(upcoming);
    renderPast(past);
  }

  function renderUpcoming(list) {
    if (list.length === 0) {
      upcomingContainer.innerHTML = '<div class="empty-state">暂无近期面试</div>';
      return;
    }

    const groups = groupUpcoming(list);
    const labels = { today: '今天', tomorrow: '明天', week: '本周', later: '之后' };
    let html = '';

    for (const [key, label] of Object.entries(labels)) {
      const items = groups[key];
      if (items.length === 0) continue;
      html += '<div class="date-group">';
      html += '<div class="date-group-label">' + label + '</div>';
      for (const iv of items) {
        html += renderCard(iv);
      }
      html += '</div>';
    }

    upcomingContainer.innerHTML = html;
  }

  function renderPast(list) {
    if (list.length === 0) {
      pastContainer.innerHTML = '<div class="empty-state">暂无历史面试</div>';
      return;
    }

    let html = '<div class="date-group"><div class="date-group-label">历史记录</div>';
    for (const iv of list) {
      html += renderCard(iv);
    }
    html += '</div>';
    pastContainer.innerHTML = html;
  }

  function renderCard(iv) {
    const app = findApplication(iv.application_id);
    const companyName = app ? (app.company_name || (app.company && app.company.name) || '未知公司') : '未知公司';
    const position = app ? app.position : '未知职位';
    const typeLabel = TYPE_LABELS[iv.interview_type] || iv.interview_type || '未知';
    const timeStr = formatDateTime(iv.interview_date);
    const interviewer = iv.interviewer || '—';
    const resultKey = iv.result || '';
    const resultLabel = RESULT_LABELS[resultKey] || '';
    const resultBadgeHtml = resultLabel
      ? '<span class="badge badge-' + resultKey + '">' + resultLabel + '</span>'
      : '';

    return (
      '<div class="interview-card" data-id="' + iv.id + '">' +
        '<div class="interview-card-main">' +
          '<div class="interview-card-company">' + escHtml(companyName) + '</div>' +
          '<div class="interview-card-position">' + escHtml(position) + '</div>' +
          '<div class="interview-card-meta">' +
            '<span class="badge badge-' + (iv.interview_type || 'phone') + '">' + escHtml(typeLabel) + '</span>' +
            '<span class="interview-card-time">' + escHtml(timeStr) + '</span>' +
            '<span class="interview-card-interviewer">面试官：' + escHtml(interviewer) + '</span>' +
            resultBadgeHtml +
          '</div>' +
        '</div>' +
        '<div class="interview-card-actions">' +
          '<button class="btn btn-sm edit-btn" data-id="' + iv.id + '">编辑</button>' +
          '<button class="btn btn-sm btn-danger delete-btn" data-id="' + iv.id + '">删除</button>' +
        '</div>' +
      '</div>'
    );
  }

  function escHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  function findApplication(id) {
    return applications.find(function (a) { return a.id === id; });
  }

  // ── Event delegation for edit/delete ───────────────────────────────────
  document.addEventListener('click', function (e) {
    const editBtn = e.target.closest('.edit-btn');
    const deleteBtn = e.target.closest('.delete-btn');

    if (editBtn) {
      const id = parseInt(editBtn.getAttribute('data-id'), 10);
      const iv = interviews.find(function (item) { return item.id === id; });
      if (iv) openEditModal(iv);
    }

    if (deleteBtn) {
      const id = parseInt(deleteBtn.getAttribute('data-id'), 10);
      handleDelete(id);
    }
  });

  // ── Modal ──────────────────────────────────────────────────────────────
  function openAddModal() {
    modalTitle.textContent = '添加面试';
    form.reset();
    interviewIdInput.value = '';
    resultSelect.value = '';
    modal.style.display = 'flex';
  }

  function openEditModal(iv) {
    modalTitle.textContent = '编辑面试';
    interviewIdInput.value = iv.id;
    applicationSelect.value = iv.application_id;
    interviewTypeSelect.value = iv.interview_type;
    interviewDateInput.value = toDatetimeLocalValue(iv.interview_date);
    interviewerInput.value = iv.interviewer || '';
    resultSelect.value = iv.result || '';
    notesInput.value = iv.notes || '';
    modal.style.display = 'flex';
  }

  function closeModal() {
    modal.style.display = 'none';
  }

  // ── Form submit ────────────────────────────────────────────────────────
  async function handleSubmit(e) {
    e.preventDefault();

    const id = interviewIdInput.value;
    const applicationId = parseInt(applicationSelect.value, 10);
    const interviewType = interviewTypeSelect.value;
    const dateLocal = interviewDateInput.value;

    if (!applicationId) { alert('请选择投递'); return; }
    if (!interviewType) { alert('请选择面试类型'); return; }
    if (!dateLocal) { alert('请选择面试时间'); return; }

    const interviewDate = new Date(dateLocal).toISOString();

    const payload = {
      application_id: applicationId,
      interview_type: interviewType,
      interview_date: interviewDate,
      interviewer: interviewerInput.value || null,
      result: resultSelect.value || null,
      notes: notesInput.value || null,
    };

    try {
      if (id) {
        await updateInterview(parseInt(id, 10), payload);
      } else {
        await createInterview(payload);
      }
      closeModal();
      await fetchInterviews();
      render();
    } catch (err) {
      alert('操作失败：' + err.message);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────
  async function handleDelete(id) {
    if (!confirm('确定要删除这条面试记录吗？')) return;
    try {
      await deleteInterview(id);
      await fetchInterviews();
      render();
    } catch (err) {
      alert('删除失败：' + err.message);
    }
  }

  // ── Populate application dropdown ───────────────────────────────────────
  function populateApplicationDropdown() {
    applicationSelect.innerHTML = '<option value="">请选择投递</option>';
    for (const app of applications) {
      const companyName = app.company_name || (app.company && app.company.name) || '未知公司';
      const label = companyName + ' — ' + app.position;
      const option = document.createElement('option');
      option.value = app.id;
      option.textContent = label;
      applicationSelect.appendChild(option);
    }
  }

})();
