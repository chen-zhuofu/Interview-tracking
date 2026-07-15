(function () {
  'use strict';

  const stageMap = {
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

  const stageOrder = [
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

  const interviewingStages = [
    'resume_screening',
    'first_interview',
    'second_interview',
    'third_interview',
    'hr_interview',
  ];

  function fmtTime(iso) {
    const d = new Date(iso);
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    const hh = String(d.getHours()).padStart(2, '0');
    const mi = String(d.getMinutes()).padStart(2, '0');
    return mm + '-' + dd + ' ' + hh + ':' + mi;
  }

  function fmtDate(iso) {
    const d = new Date(iso);
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return mm + '-' + dd;
  }

  function empty() {
    var div = document.createElement('div');
    div.className = 'empty-state';
    div.textContent = '暂无数据';
    return div;
  }

  function renderStats(data) {
    document.getElementById('stat-total').textContent = data.total_applications || 0;

    var interviewing = 0;
    if (data.stage_counts) {
      interviewingStages.forEach(function (s) {
        interviewing += data.stage_counts[s] || 0;
      });
    }
    document.getElementById('stat-interviewing').textContent = interviewing;
    document.getElementById('stat-offer').textContent =
      (data.stage_counts && data.stage_counts.offer) || 0;
    document.getElementById('stat-this-week').textContent =
      (data.this_week_interviews && data.this_week_interviews.length) || 0;
  }

  function renderStageDistribution(data) {
    var container = document.getElementById('stage-distribution');
    container.innerHTML = '';

    var counts = data.stage_counts;
    if (!counts) {
      container.appendChild(empty());
      return;
    }

    var max = 0;
    stageOrder.forEach(function (s) {
      if (counts[s] > max) max = counts[s];
    });

    if (max === 0) {
      container.appendChild(empty());
      return;
    }

    var list = document.createElement('div');
    list.className = 'stage-list';

    stageOrder.forEach(function (s) {
      var cnt = counts[s] || 0;
      var pct = (cnt / max) * 100;

      var row = document.createElement('div');
      row.className = 'stage-row';

      var label = document.createElement('span');
      label.className = 'stage-label';
      label.textContent = stageMap[s] || s;

      var track = document.createElement('div');
      track.className = 'stage-track';

      var bar = document.createElement('div');
      bar.className = 'stage-bar';
      bar.style.width = pct + '%';

      var countEl = document.createElement('span');
      countEl.className = 'stage-count';
      countEl.textContent = cnt;

      track.appendChild(bar);
      row.appendChild(label);
      row.appendChild(track);
      row.appendChild(countEl);
      list.appendChild(row);
    });

    container.appendChild(list);
  }

  function renderThisWeekInterviews(data) {
    var container = document.getElementById('this-week-interviews');
    container.innerHTML = '';

    var interviews = data.this_week_interviews;
    if (!interviews || interviews.length === 0) {
      container.appendChild(empty());
      return;
    }

    var list = document.createElement('div');
    list.className = 'interview-list';

    interviews.forEach(function (iv) {
      var item = document.createElement('div');
      item.className = 'interview-item';

      var info = document.createElement('div');
      info.className = 'interview-info';

      var company = document.createElement('span');
      company.className = 'interview-company';
      company.textContent = iv.company_name || '';

      var pos = document.createElement('span');
      pos.className = 'interview-position';
      pos.textContent = iv.position_title || '';

      var stage = iv.interview_type || '';
      var badge = document.createElement('span');
      badge.className = 'badge badge-' + stage;
      badge.textContent = stageMap[stage] || stage;

      info.appendChild(company);
      info.appendChild(pos);
      info.appendChild(badge);

      var timeEl = document.createElement('span');
      timeEl.className = 'interview-time';
      timeEl.textContent = iv.interview_date ? fmtTime(iv.interview_date) : '';

      item.appendChild(info);
      item.appendChild(timeEl);
      list.appendChild(item);
    });

    container.appendChild(list);
  }

  function renderRecentActivities(data) {
    var container = document.getElementById('recent-activities');
    container.innerHTML = '';

    var activities = data.recent_activities;
    if (!activities || activities.length === 0) {
      container.appendChild(empty());
      return;
    }

    var list = document.createElement('div');
    list.className = 'activity-list';

    activities.forEach(function (a) {
      var item = document.createElement('div');
      item.className = 'activity-item';

      var desc = document.createElement('span');
      desc.className = 'activity-desc';
      var stageLabel = stageMap[a.current_stage] || a.current_stage || '';
      desc.innerHTML =
        '<strong>' +
        escapeHtml(a.position_title || '') +
        '</strong> @ ' +
        escapeHtml(a.company_name || '') +
        ' — ' +
        escapeHtml(stageLabel);

      var timeEl = document.createElement('span');
      timeEl.className = 'activity-time';
      timeEl.textContent = a.updated_at ? fmtDate(a.updated_at) : '';

      item.appendChild(desc);
      item.appendChild(timeEl);
      list.appendChild(item);
    });

    container.appendChild(list);
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  function load() {
    fetch('/api/dashboard/stats')
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (data) {
        renderStats(data);
        renderStageDistribution(data);
        renderThisWeekInterviews(data);
        renderRecentActivities(data);
      })
      .catch(function (err) {
        console.error('Dashboard load failed:', err);
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', load);
  } else {
    load();
  }
})();
