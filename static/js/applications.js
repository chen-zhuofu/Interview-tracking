/**
 * Application CRUD + stage filter + quick stage switch — static/js/applications.js
 */
(function () {
  'use strict';

  var API_BASE = '/api/applications';
  var COMPANIES_API = '/api/companies';

  // Chinese stage labels
  var STAGE_LABELS = {
    applied: '投递',
    resume_screening: '简历筛选',
    first_interview: '一面',
    second_interview: '二面',
    third_interview: '三面',
    hr_interview: 'HR面',
    offer: 'Offer',
    accepted: '入职',
    rejected: '拒绝',
  };

  // Stage order for quick-switch buttons
  var STAGE_ORDER = [
    'applied',
    'resume_screening',
    'first_interview',
    'second_interview',
    'third_interview',
    'hr_interview',
    'offer',
    'accepted',
    'rejected',
  ];

  // ── DOM refs ──────────────────────────────────────────────
  var tbody            = document.getElementById('applications-tbody');
  var emptyRow         = document.getElementById('applications-empty');
  var btnAdd           = document.getElementById('btn-add-application');
  var modalOverlay     = document.getElementById('modal-overlay');
  var modalTitle       = document.getElementById('modal-title');
  var form             = document.getElementById('application-form');
  var idInput          = document.getElementById('application-id');
  var companySelect    = document.getElementById('app-company-id');
  var positionInput    = document.getElementById('app-position');
  var appliedDate      = document.getElementById('app-applied-date');
  var jobDescUrlInput  = document.getElementById('app-job-description-url');
  var notesInput       = document.getElementById('app-notes');
  var btnCancel        = document.getElementById('btn-cancel-application');
  var filterSelect     = document.getElementById('filter-stage');

  // ── Helpers ────────────────────────────────────────────────
  function escapeHtml(str) {
    if (!str) return '';
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  function showModal(isEdit) {
    modalTitle.textContent = isEdit ? '编辑投递' : '添加投递';
    modalOverlay.style.display = 'flex';
    if (companySelect.options.length <= 1) {
      loadCompanyOptions();
    }
  }

  function hideModal() {
    modalOverlay.style.display = 'none';
    form.reset();
    idInput.value = '';
    form.querySelectorAll('.form-error').forEach(function (el) { el.style.display = 'none'; });
  }

  function clearErrors() {
    form.querySelectorAll('.form-error').forEach(function (el) { el.style.display = 'none'; });
  }

  function formatDate(dateStr) {
    if (!dateStr) return '—';
    var d = new Date(dateStr);
    if (isNaN(d.getTime())) return escapeHtml(dateStr);
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, '0');
    var day = String(d.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + day;
  }

  // Look up company name from cache (populated by companies.js)
  function getCompanyName(companyId) {
    var cache = window.__companiesCache || [];
    for (var i = 0; i < cache.length; i++) {
      if (cache[i].id === companyId) return cache[i].name;
    }
    return null;
  }

  // ── Load company options ───────────────────────────────────
  function loadCompanyOptions() {
    while (companySelect.options.length > 1) {
      companySelect.remove(1);
    }

    fetch(COMPANIES_API)
      .then(function (res) {
        if (!res.ok) throw new Error('Failed to load companies');
        return res.json();
      })
      .then(function (companies) {
        window.__companiesCache = companies;
        companies.forEach(function (c) {
          var opt = document.createElement('option');
          opt.value = c.id;
          opt.textContent = c.name;
          companySelect.appendChild(opt);
        });
      })
      .catch(function (err) {
        console.error(err);
      });
  }

  // ── API calls ──────────────────────────────────────────────
  function fetchApplications(stage) {
    var url = API_BASE;
    if (stage) {
      url += '?stage=' + encodeURIComponent(stage);
    }
    return fetch(url)
      .then(function (res) {
        if (!res.ok) throw new Error('Failed to load applications');
        return res.json();
      })
      .then(function (data) {
        renderTable(data);
      })
      .catch(function (err) {
        console.error(err);
      });
  }

  function createApplication(payload) {
    return fetch(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to create application');
      return res.json();
    });
  }

  function updateApplication(id, payload) {
    return fetch(API_BASE + '/' + id, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to update application');
      return res.json();
    });
  }

  function deleteApplication(id) {
    return fetch(API_BASE + '/' + id, {
      method: 'DELETE',
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to delete application');
    });
  }

  function patchStage(id, newStage) {
    return fetch(API_BASE + '/' + id + '/stage', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStage }),
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to update stage');
      return res.json();
    });
  }

  // ── Render ─────────────────────────────────────────────────
  function renderTable(apps) {
    var rows = tbody.querySelectorAll('tr:not(#applications-empty)');
    rows.forEach(function (r) { r.remove(); });

    if (!apps || apps.length === 0) {
      emptyRow.style.display = '';
      return;
    }

    emptyRow.style.display = 'none';

    apps.forEach(function (a) {
      var stageKey = a.status || 'applied';
      var stageLabel = STAGE_LABELS[stageKey] || stageKey;
      var companyName = getCompanyName(a.company_id) || '—';

      var stageIdx = STAGE_ORDER.indexOf(stageKey);
      var canPrev = stageIdx > 0;
      var canNext = stageIdx >= 0 && stageIdx < STAGE_ORDER.length - 1;

      var tr = document.createElement('tr');
      tr.style.borderBottom = '1px solid var(--color-border)';
      tr.innerHTML =
        '<td style="padding: 12px 16px; font-weight: 500;">' + escapeHtml(a.position || '—') + '</td>' +
        '<td style="padding: 12px 16px;">' + escapeHtml(companyName) + '</td>' +
        '<td style="padding: 12px 16px;"><span class="badge badge-' + stageKey + '">' + stageLabel + '</span></td>' +
        '<td style="padding: 12px 16px;">' + formatDate(a.applied_date) + '</td>' +
        '<td style="padding: 12px 16px;">' +
          (canPrev
            ? '<button class="btn btn-sm btn-stage-prev" data-id="' + a.id + '" data-stage="' + STAGE_ORDER[stageIdx - 1] + '" title="' + (STAGE_LABELS[STAGE_ORDER[stageIdx - 1]] || STAGE_ORDER[stageIdx - 1]) + '">◀</button> '
            : '<span style="display:inline-block;width:30px;"></span>') +
          (canNext
            ? '<button class="btn btn-sm btn-stage-next" data-id="' + a.id + '" data-stage="' + STAGE_ORDER[stageIdx + 1] + '" title="' + (STAGE_LABELS[STAGE_ORDER[stageIdx + 1]] || STAGE_ORDER[stageIdx + 1]) + '">▶</button> '
            : '') +
          '<button class="btn btn-sm btn-edit-app" data-id="' + a.id + '" style="margin-left: 4px;">编辑</button> ' +
          '<button class="btn btn-danger btn-sm btn-delete-app" data-id="' + a.id + '">删除</button>' +
        '</td>';

      tbody.appendChild(tr);
    });

    // Bind stage prev buttons
    tbody.querySelectorAll('.btn-stage-prev').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = parseInt(this.getAttribute('data-id'), 10);
        var stage = this.getAttribute('data-stage');
        patchStage(id, stage).then(function () { refreshTable(); });
      });
    });

    // Bind stage next buttons
    tbody.querySelectorAll('.btn-stage-next').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = parseInt(this.getAttribute('data-id'), 10);
        var stage = this.getAttribute('data-stage');
        patchStage(id, stage).then(function () { refreshTable(); });
      });
    });

    // Bind edit buttons
    tbody.querySelectorAll('.btn-edit-app').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = parseInt(this.getAttribute('data-id'), 10);
        var app = apps.find(function (a) { return a.id === id; });
        if (app) openEditModal(app);
      });
    });

    // Bind delete buttons
    tbody.querySelectorAll('.btn-delete-app').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = parseInt(this.getAttribute('data-id'), 10);
        if (confirm('确定要删除该投递记录吗？')) {
          deleteApplication(id).then(function () { refreshTable(); });
        }
      });
    });
  }

  function refreshTable() {
    var stage = filterSelect.value;
    fetchApplications(stage || null);
  }

  function openEditModal(app) {
    function fillAndOpen() {
      idInput.value = app.id;
      companySelect.value = app.company_id || '';
      positionInput.value = app.position || '';
      appliedDate.value = app.applied_date ? app.applied_date.toString().substring(0, 10) : '';
      jobDescUrlInput.value = app.job_description_url || '';
      notesInput.value = app.notes || '';
      clearErrors();
      showModal(true);
    }

    if (companySelect.options.length <= 1) {
      loadCompanyOptions();
      // Wait for options to load, then fill values
      var start = Date.now();
      var timer = setInterval(function () {
        if (companySelect.options.length > 1) {
          clearInterval(timer);
          fillAndOpen();
        } else if (Date.now() - start > 5000) {
          clearInterval(timer);
          fillAndOpen();
        }
      }, 100);
    } else {
      fillAndOpen();
    }
  }

  // ── Form submit ────────────────────────────────────────────
  form.addEventListener('submit', function (e) {
    e.preventDefault();
    clearErrors();

    var hasError = false;

    var companyId = companySelect.value;
    if (!companyId) {
      var errEl = companySelect.closest('.form-group');
      if (errEl) {
        var span = errEl.querySelector('.form-error');
        if (span) span.style.display = '';
      }
      hasError = true;
    }

    var position = positionInput.value.trim();
    if (!position) {
      var errEl = positionInput.closest('.form-group');
      if (errEl) {
        var span = errEl.querySelector('.form-error');
        if (span) span.style.display = '';
      }
      hasError = true;
    }

    if (hasError) return;

    var payload = {
      company_id: parseInt(companyId, 10),
      position: position,
      job_description_url: jobDescUrlInput.value.trim() || null,
      applied_date: appliedDate.value || null,
      notes: notesInput.value.trim() || null,
    };
    Object.keys(payload).forEach(function (k) {
      if (payload[k] === null) delete payload[k];
    });

    var id = idInput.value;
    var promise = id
      ? updateApplication(parseInt(id, 10), payload)
      : createApplication(payload);

    promise
      .then(function () {
        hideModal();
        refreshTable();
      })
      .catch(function (err) {
        console.error(err);
        alert('操作失败: ' + err.message);
      });
  });

  // ── Stage filter ───────────────────────────────────────────
  filterSelect.addEventListener('change', function () {
    refreshTable();
  });

  // ── Event listeners ────────────────────────────────────────
  btnAdd.addEventListener('click', function () {
    form.reset();
    idInput.value = '';
    clearErrors();
    companySelect.value = '';
    showModal(false);
  });

  btnCancel.addEventListener('click', hideModal);

  modalOverlay.addEventListener('click', function (e) {
    if (e.target === modalOverlay) hideModal();
  });

  // ── Init ────────────────────────────────────────────────────
  refreshTable();
})();
