/**
 * Company CRUD — static/js/companies.js
 */
(function () {
  'use strict';

  const API_BASE = '/api/companies';

  // ── DOM refs ──────────────────────────────────────────────
  const tbody          = document.getElementById('companies-tbody');
  const emptyRow       = document.getElementById('companies-empty');
  const btnAdd         = document.getElementById('btn-add-company');
  const modalOverlay   = document.getElementById('modal-overlay');
  const modalTitle     = document.getElementById('modal-title');
  const form           = document.getElementById('company-form');
  const idInput        = document.getElementById('company-id');
  const nameInput      = document.getElementById('company-name');
  const cityInput      = document.getElementById('company-city');
  const industryInput  = document.getElementById('company-industry');
  const websiteInput   = document.getElementById('company-website');
  const notesInput     = document.getElementById('company-notes');
  const btnCancel      = document.getElementById('btn-cancel-company');

  // Store companies list for lookup by applications page
  window.__companiesCache = [];

  // ── Helpers ────────────────────────────────────────────────
  function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  function showModal(isEdit) {
    modalTitle.textContent = isEdit ? '编辑公司' : '添加公司';
    modalOverlay.style.display = 'flex';
  }

  function hideModal() {
    modalOverlay.style.display = 'none';
    form.reset();
    idInput.value = '';
    // Hide all error messages
    form.querySelectorAll('.form-error').forEach(function (el) { el.style.display = 'none'; });
  }

  function clearErrors() {
    form.querySelectorAll('.form-error').forEach(function (el) { el.style.display = 'none'; });
  }

  // ── API calls ──────────────────────────────────────────────
  function fetchCompanies() {
    return fetch(API_BASE)
      .then(function (res) {
        if (!res.ok) throw new Error('Failed to load companies');
        return res.json();
      })
      .then(function (data) {
        window.__companiesCache = data;
        renderTable(data);
      })
      .catch(function (err) {
        console.error(err);
      });
  }

  function createCompany(payload) {
    return fetch(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to create company');
      return res.json();
    });
  }

  function updateCompany(id, payload) {
    return fetch(API_BASE + '/' + id, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to update company');
      return res.json();
    });
  }

  function deleteCompany(id) {
    return fetch(API_BASE + '/' + id, {
      method: 'DELETE',
    }).then(function (res) {
      if (!res.ok) throw new Error('Failed to delete company');
    });
  }

  // ── Render ─────────────────────────────────────────────────
  function renderTable(companies) {
    // Remove all rows except the empty-state row
    var rows = tbody.querySelectorAll('tr:not(#companies-empty)');
    rows.forEach(function (r) { r.remove(); });

    if (!companies || companies.length === 0) {
      emptyRow.style.display = '';
      return;
    }

    emptyRow.style.display = 'none';

    companies.forEach(function (c) {
      var tr = document.createElement('tr');
      tr.style.borderBottom = '1px solid var(--color-border)';
      tr.innerHTML =
        '<td style="padding: 12px 16px;">' + escapeHtml(c.name) + '</td>' +
        '<td style="padding: 12px 16px;">' + escapeHtml(c.city || '—') + '</td>' +
        '<td style="padding: 12px 16px;">' + escapeHtml(c.industry || '—') + '</td>' +
        '<td style="padding: 12px 16px;">' +
          (c.website
            ? '<a href="' + escapeHtml(c.website) + '" target="_blank" rel="noopener">' + escapeHtml(c.website) + '</a>'
            : '—') +
        '</td>' +
        '<td style="padding: 12px 16px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">' + escapeHtml(c.notes || '—') + '</td>' +
        '<td style="padding: 12px 16px;">' +
          '<button class="btn btn-sm btn-edit" data-id="' + c.id + '" style="margin-right: 6px;">编辑</button>' +
          '<button class="btn btn-danger btn-sm btn-delete" data-id="' + c.id + '">删除</button>' +
        '</td>';

      tbody.appendChild(tr);
    });

    // Bind edit buttons
    tbody.querySelectorAll('.btn-edit').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = parseInt(this.getAttribute('data-id'), 10);
        var company = companies.find(function (c) { return c.id === id; });
        if (company) openEditModal(company);
      });
    });

    // Bind delete buttons
    tbody.querySelectorAll('.btn-delete').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = parseInt(this.getAttribute('data-id'), 10);
        if (confirm('确定要删除该公司吗？')) {
          deleteCompany(id).then(function () { return fetchCompanies(); });
        }
      });
    });
  }

  function openEditModal(company) {
    idInput.value = company.id;
    nameInput.value = company.name || '';
    cityInput.value = company.city || '';
    industryInput.value = company.industry || '';
    websiteInput.value = company.website || '';
    notesInput.value = company.notes || '';
    clearErrors();
    showModal(true);
  }

  // ── Form submit ────────────────────────────────────────────
  form.addEventListener('submit', function (e) {
    e.preventDefault();
    clearErrors();

    var name = nameInput.value.trim();
    if (!name) {
      nameInput.closest('.form-group').querySelector('.form-error').style.display = '';
      nameInput.focus();
      return;
    }

    var payload = {
      name: name,
      website: websiteInput.value.trim() || null,
      city: cityInput.value.trim() || null,
      industry: industryInput.value.trim() || null,
      notes: notesInput.value.trim() || null,
    };
    // Remove null fields
    Object.keys(payload).forEach(function (k) {
      if (payload[k] === null) delete payload[k];
    });

    var id = idInput.value;
    var promise = id
      ? updateCompany(parseInt(id, 10), payload)
      : createCompany(payload);

    promise
      .then(function () {
        hideModal();
        return fetchCompanies();
      })
      .catch(function (err) {
        console.error(err);
        alert('操作失败: ' + err.message);
      });
  });

  // ── Event listeners ────────────────────────────────────────
  btnAdd.addEventListener('click', function () {
    form.reset();
    idInput.value = '';
    clearErrors();
    showModal(false);
  });

  btnCancel.addEventListener('click', hideModal);

  modalOverlay.addEventListener('click', function (e) {
    if (e.target === modalOverlay) hideModal();
  });

  // ── Init ────────────────────────────────────────────────────
  fetchCompanies();
})();
