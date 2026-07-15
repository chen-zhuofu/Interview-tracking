const STAGE_ORDER = [
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

const STAGE_LABELS = {
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

let applications = [];

function companyName(app) {
  return app.company_name || (app.company && app.company.name) || '未知公司';
}

function formatDate(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function groupByStage(apps) {
  const groups = {};
  for (const stage of STAGE_ORDER) {
    groups[stage] = [];
  }
  for (const app of apps) {
    const stage = app.status || 'applied';
    if (groups[stage]) {
      groups[stage].push(app);
    }
  }
  return groups;
}

function renderCard(app) {
  const div = document.createElement('div');
  div.className = 'kanban-card';
  div.dataset.id = app.id;
  div.addEventListener('click', () => showDetail(app));

  const company = document.createElement('div');
  company.className = 'kanban-card-company';
  company.textContent = companyName(app);

  const position = document.createElement('div');
  position.className = 'kanban-card-position';
  position.textContent = app.position;

  const footer = document.createElement('div');
  footer.className = 'kanban-card-footer';

  const date = document.createElement('span');
  date.className = 'kanban-card-date';
  date.textContent = formatDate(app.applied_date);

  const badge = document.createElement('span');
  badge.className = 'badge badge-' + (app.status || 'applied');
  const interviewCount = app.interview_count || (app.interviews && app.interviews.length) || 0;
  badge.textContent = interviewCount + ' 面试';

  footer.appendChild(date);
  footer.appendChild(badge);

  div.appendChild(company);
  div.appendChild(position);
  div.appendChild(footer);

  return div;
}

function renderColumn(stage, apps) {
  const column = document.querySelector(`.kanban-column[data-stage="${stage}"]`);
  if (!column) return;

  const cardsContainer = column.querySelector('.kanban-cards');
  const countBadge = column.querySelector('.kanban-column-count');

  cardsContainer.innerHTML = '';
  for (const app of apps) {
    cardsContainer.appendChild(renderCard(app));
  }
  countBadge.textContent = apps.length;
}

function renderBoard() {
  const groups = groupByStage(applications);
  for (const stage of STAGE_ORDER) {
    renderColumn(stage, groups[stage]);
  }
}

function initSortable() {
  const columns = document.querySelectorAll('.kanban-cards');
  for (const col of columns) {
    Sortable.create(col, {
      group: 'stages',
      animation: 150,
      ghostClass: 'sortable-ghost',
      dragClass: 'sortable-drag',
      onEnd: function (evt) {
        const cardEl = evt.item;
        const appId = parseInt(cardEl.dataset.id, 10);
        const newStage = evt.to.dataset.stage;
        const oldStage = evt.from.dataset.stage;

        if (newStage === oldStage) return;

        // Optimistic: update card appearance immediately
        const interviewBadge = cardEl.querySelector('.badge');
        if (interviewBadge) {
          // remove old stage class, add new one
          for (const cls of interviewBadge.classList) {
            if (cls.startsWith('badge-')) {
              interviewBadge.classList.remove(cls);
            }
          }
          interviewBadge.classList.add('badge-' + newStage);
        }

        // Update column counts
        updateColumnCount(evt.from.dataset.stage);
        updateColumnCount(newStage);

        // API call
        updateStage(appId, newStage, function (err) {
          if (err) {
            // Rollback: move card back
            evt.from.appendChild(cardEl);
            updateColumnCount(evt.from.dataset.stage);
            updateColumnCount(newStage);

            // Restore badge
            if (interviewBadge) {
              for (const cls of interviewBadge.classList) {
                if (cls.startsWith('badge-')) {
                  interviewBadge.classList.remove(cls);
                }
              }
              interviewBadge.classList.add('badge-' + oldStage);
            }

            showToast('移动失败，已回滚', 'error');
          }
        });
      },
    });
  }
}

function updateColumnCount(stage) {
  const column = document.querySelector(`.kanban-column[data-stage="${stage}"]`);
  if (!column) return;
  const cardsContainer = column.querySelector('.kanban-cards');
  const countBadge = column.querySelector('.kanban-column-count');
  countBadge.textContent = cardsContainer.children.length;
}

function updateStage(appId, newStage, callback) {
  fetch('/api/applications/' + appId + '/stage', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ current_stage: newStage }),
  })
    .then(function (res) {
      if (!res.ok) {
        throw new Error('HTTP ' + res.status);
      }
      return res.json();
    })
    .then(function () {
      // Update local state
      const app = applications.find(function (a) { return a.id === appId; });
      if (app) {
        app.status = newStage;
      }
      callback(null);
    })
    .catch(function (err) {
      callback(err);
    });
}

function showDetail(app) {
  const overlay = document.getElementById('detail-modal');
  const content = document.getElementById('detail-content');
  const errorEl = document.getElementById('modal-error');
  errorEl.style.display = 'none';

  const interviews = app.interviews || [];
  const interviewCount = app.interview_count || interviews.length;

  let interviewsHtml = '';
  if (interviews.length > 0) {
    interviewsHtml = '<div class="detail-section"><h4>面试历史</h4>';
    for (const inv of interviews) {
      interviewsHtml += '<div class="interview-item">';
      interviewsHtml += '<div><strong>' + escapeHtml(inv.interview_type) + '</strong></div>';
      if (inv.interview_date) {
        interviewsHtml += '<div class="detail-row"><span class="detail-label">日期</span><span class="detail-value">' + escapeHtml(formatDate(inv.interview_date)) + '</span></div>';
      }
      if (inv.interviewer) {
        interviewsHtml += '<div class="detail-row"><span class="detail-label">面试官</span><span class="detail-value">' + escapeHtml(inv.interviewer) + '</span></div>';
      }
      if (inv.result) {
        interviewsHtml += '<div class="detail-row"><span class="detail-label">结果</span><span class="detail-value">' + escapeHtml(inv.result) + '</span></div>';
      }
      if (inv.notes) {
        interviewsHtml += '<div class="detail-row"><span class="detail-label">备注</span><span class="detail-value">' + escapeHtml(inv.notes) + '</span></div>';
      }
      interviewsHtml += '</div>';
    }
    interviewsHtml += '</div>';
  }

  content.innerHTML =
    '<div class="detail-section"><h4>投递信息</h4>' +
    '<div class="detail-row"><span class="detail-label">公司</span><span class="detail-value">' + escapeHtml(companyName(app)) + '</span></div>' +
    '<div class="detail-row"><span class="detail-label">职位</span><span class="detail-value">' + escapeHtml(app.position) + '</span></div>' +
    '<div class="detail-row"><span class="detail-label">阶段</span><span class="detail-value"><span class="badge badge-' + (app.status || 'applied') + '">' + escapeHtml(STAGE_LABELS[app.status] || app.status) + '</span></span></div>' +
    (app.applied_date ? '<div class="detail-row"><span class="detail-label">投递日期</span><span class="detail-value">' + escapeHtml(formatDate(app.applied_date)) + '</span></div>' : '') +
    (app.job_description_url ? '<div class="detail-row"><span class="detail-label">JD链接</span><span class="detail-value"><a href="' + escapeHtml(app.job_description_url) + '" target="_blank">查看</a></span></div>' : '') +
    '<div class="detail-row"><span class="detail-label">面试次数</span><span class="detail-value">' + interviewCount + '</span></div>' +
    (app.notes ? '<div class="detail-row"><span class="detail-label">备注</span><span class="detail-value">' + escapeHtml(app.notes) + '</span></div>' : '') +
    '</div>' +
    interviewsHtml;

  overlay.style.display = 'flex';
}

function closeDetail() {
  document.getElementById('detail-modal').style.display = 'none';
}

function escapeHtml(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function showToast(msg, type) {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = 'toast ' + (type || '');
  toast.classList.add('show');
  clearTimeout(toast._timeout);
  toast._timeout = setTimeout(function () {
    toast.classList.remove('show');
  }, 2000);
}

function fetchApplications() {
  return fetch('/api/applications')
    .then(function (res) {
      if (!res.ok) {
        throw new Error('HTTP ' + res.status);
      }
      return res.json();
    })
    .then(function (data) {
      applications = data;
      renderBoard();
      initSortable();
    })
    .catch(function (err) {
      console.error('Failed to load applications:', err);
      showToast('加载投递数据失败', 'error');
    });
}

// Close modal on overlay click
document.addEventListener('click', function (e) {
  const overlay = document.getElementById('detail-modal');
  if (e.target === overlay) {
    closeDetail();
  }
});

// Init
fetchApplications();
