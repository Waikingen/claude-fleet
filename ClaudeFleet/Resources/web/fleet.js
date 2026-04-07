/* ── Fleet JS ── */

const audio = {
  ctx: null,
  init() {
    try { this.ctx = new AudioContext(); } catch(e) {}
  },
  play(freq, duration, type = 'sine') {
    if (!this.ctx) return;
    try {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = type;
      osc.frequency.value = freq;
      gain.gain.value = 0.05;
      gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration / 1000);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start();
      osc.stop(this.ctx.currentTime + duration / 1000);
    } catch(e) {}
  },
  attention() { this.play(400, 100); setTimeout(() => this.play(600, 100), 100); },
  approve() { this.play(800, 40); },
  deny() { this.play(200, 60, 'triangle'); },
  risk() { this.play(500, 80); setTimeout(() => this.play(700, 80), 100); setTimeout(() => this.play(500, 80), 200); },
};

const fleet = {
  // ── State ──
  state: null,
  previousState: null,
  selectedId: null,
  currentView: 'queue',
  daemonConnected: false,
  sparklineHistory: {},  // sessionId -> [statusValues]
  paletteSelectedIdx: 0,
  paletteItems: [],
  _mockMode: false,

  // ── Normalize snake_case → camelCase ──
  _normalizeSession(s) {
    return {
      sessionId: s.session_id || s.sessionId,
      title: s.title,
      project: s.project,
      branch: s.branch,
      path: s.path,
      lastLines: s.last_lines || s.lastLines,
      role: s.role,
      goal: s.goal,
      status: s.status,
      stateSummary: s.state_summary || s.stateSummary,
      progress: s.progress,
      suggestedAction: s.suggested_action || s.suggestedAction,
      suggestedPrompt: s.suggested_prompt || s.suggestedPrompt,
      confidence: s.confidence,
      risk: s.risk,
      riskReason: s.risk_reason || s.riskReason,
      urgency: s.urgency,
      autoSent: s.auto_sent || s.autoSent,
    };
  },

  _normalizeState(raw) {
    return {
      phase: raw.phase,
      mode: raw.mode,
      globalRole: raw.global_role || raw.globalRole,
      sessions: (raw.sessions || []).map(s => this._normalizeSession(s)),
      totalSessions: raw.total_sessions ?? raw.totalSessions ?? 0,
      needsAttention: raw.needs_attention ?? raw.needsAttention ?? 0,
      idleCount: raw.idle_count ?? raw.idleCount ?? 0,
      workingCount: raw.working_count ?? raw.workingCount ?? 0,
      updated: raw.updated,
    };
  },

  // ── Bridge: Swift → JS ──
  _onState(raw) {
    this.previousState = this.state;
    this.state = this._normalizeState(raw);
    this._updateSparklines();
    this._detectNewAttention();
    this.render();
  },

  _onDaemonStatus(connected) {
    this.daemonConnected = connected;
    const dot = document.querySelector('.daemon-dot');
    const label = document.getElementById('daemon-label');
    if (dot) {
      dot.className = 'daemon-dot ' + (connected ? 'online' : 'offline');
    }
    if (label) {
      label.textContent = connected ? 'Connected' : 'Disconnected';
    }
  },

  _onAttentionCount(count) {
    // Sync check — could update badge externally
  },

  // ── Bridge: JS → Swift ──
  _send(cmd) {
    if (this._mockMode) {
      console.log('[fleet] bridge:', JSON.stringify(cmd));
      return;
    }
    window.webkit?.messageHandlers?.fleet?.postMessage(cmd);
  },

  // ── Actions ──
  approve(sessionId, response) {
    this._send({ action: 'approve', sessionId, response: response || 'y' });
    audio.approve();
    this._animateQueueItem(sessionId, 'approving');
    this.showToast('Approved');
  },

  deny(sessionId, response) {
    this._send({ action: 'deny', sessionId, response: response || 'n' });
    audio.deny();
    this._animateQueueItem(sessionId, 'denying');
    this.showToast('Denied');
  },

  continue(sessionId, prompt) {
    this._send({ action: 'continue', sessionId, response: prompt });
  },

  scan() {
    this._send({ action: 'scan' });
    this.showToast('Scanning...');
  },

  setMode(mode) {
    this._send({ action: 'setMode', mode });
    this.showToast('Mode: ' + mode);
  },

  setRole(sessionId, role) {
    this._send({ action: 'setRole', sessionId, role });
    this.showToast('Role set: ' + role);
  },

  setRoleGlobal(role) {
    this._send({ action: 'setRoleGlobal', role });
    this.showToast('Global role: ' + role);
  },

  setGoal(sessionId, goal) {
    this._send({ action: 'setGoal', sessionId, goal });
  },

  approveAllSafe() {
    this._send({ action: 'approveAllSafe' });
    audio.approve();
    this.showToast('Approved all safe');
  },

  // ── Sparklines ──
  _statusToValue(status) {
    switch (status) {
      case 'working': return 3;
      case 'paused': return 1;
      case 'idle': return 2;
      case 'done': return 0;
      default: return 1;
    }
  },

  _updateSparklines() {
    if (!this.state?.sessions) return;
    for (const s of this.state.sessions) {
      if (!this.sparklineHistory[s.sessionId]) {
        this.sparklineHistory[s.sessionId] = [];
      }
      const h = this.sparklineHistory[s.sessionId];
      h.push(this._statusToValue(s.status));
      if (h.length > 20) h.shift();
    }
  },

  _createSparkline(sessionId) {
    const history = this.sparklineHistory[sessionId];
    if (!history || history.length < 2) return '';
    const w = 80, h = 24;
    const points = history.map((v, i) => {
      const x = (i / (history.length - 1)) * w;
      const y = h - (v / 3) * h;
      return `${x},${y}`;
    }).join(' ');
    return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
      <polyline points="${points}" fill="none" stroke="var(--accent)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity="0.6"/>
    </svg>`;
  },

  // ── Attention detection ──
  _needsAttention(s) {
    return (s.status === 'idle' || s.status === 'paused') && !s.autoSent;
  },

  _detectNewAttention() {
    if (!this.previousState?.sessions || !this.state?.sessions) return;
    const prevIds = new Set(
      this.previousState.sessions.filter(s => this._needsAttention(s)).map(s => s.sessionId)
    );
    for (const s of this.state.sessions) {
      if (this._needsAttention(s) && !prevIds.has(s.sessionId)) {
        audio.attention();
        if (s.risk) audio.risk();
        this.showToast(`${s.project || s.title} needs attention`);
        break; // one sound per update
      }
    }
  },

  // ── Animation helpers ──
  _animateQueueItem(sessionId, className) {
    const el = document.querySelector(`.session-card[data-id="${sessionId}"]`);
    if (el) {
      el.classList.add(className);
      setTimeout(() => el.remove(), 350);
    }
  },

  // ── Render ──
  render() {
    this.renderTopbar();
    this.renderStatusbar();
    switch (this.currentView) {
      case 'queue': this.renderQueue(); break;
      case 'grid': this.renderGrid(); break;
      case 'mini': this.renderMinimap(); break;
    }
  },

  renderTopbar() {
    const sessions = this.state?.sessions || [];
    const attention = sessions.filter(s => this._needsAttention(s)).length;
    const working = sessions.filter(s => s.status === 'working').length;
    const total = sessions.length;

    const sa = document.getElementById('stat-attention');
    const sw = document.getElementById('stat-working');
    const st = document.getElementById('stat-total');
    if (sa) sa.textContent = attention;
    if (sw) sw.textContent = working;
    if (st) st.textContent = total;

    // Sync mode tabs
    if (this.state?.mode) {
      document.querySelectorAll('.mode-tab').forEach(t => {
        t.classList.toggle('active', t.dataset.mode === this.state.mode);
      });
      const badge = document.getElementById('mode-badge');
      if (badge) badge.textContent = this.state.mode === 'autopilot' ? 'AUTOPILOT' : this.state.mode.toUpperCase();
    }
  },

  renderStatusbar() {
    // Footer stats are updated via renderTopbar
  },

  renderQueue() {
    const container = document.getElementById('queue-view');
    const sessions = this.state?.sessions || [];
    const attention = sessions.filter(s => this._needsAttention(s));
    const working = sessions.filter(s => s.status === 'working');
    const rest = sessions.filter(s => !this._needsAttention(s) && s.status !== 'working');

    // Sort attention: risky first, then by urgency
    const urgencyOrder = { high: 0, medium: 1, low: 2 };
    attention.sort((a, b) => {
      if (a.risk && !b.risk) return -1;
      if (!a.risk && b.risk) return 1;
      return (urgencyOrder[a.urgency] ?? 2) - (urgencyOrder[b.urgency] ?? 2);
    });

    if (!this.selectedId && attention.length > 0) {
      this.selectedId = attention[0].sessionId;
    }

    let html = '';

    for (const s of attention) {
      html += this._renderSessionCard(s);
    }

    if (working.length > 0) {
      html += '<div class="section-label">Running</div>';
      for (const s of working) {
        html += this._renderSessionCard(s);
      }
    }

    if (rest.length > 0) {
      html += '<div class="section-label">Other</div>';
      for (const s of rest) {
        html += this._renderCompactRow(s);
      }
    }

    if (sessions.length === 0) {
      html = '<div class="empty-state"><div class="empty-state-icon">◇</div><div class="empty-state-text">No sessions detected</div></div>';
    }

    container.innerHTML = html;
  },

  _renderSessionCard(s) {
    const isRisky = s.risk;
    const needsAtt = this._needsAttention(s);
    const selected = s.sessionId === this.selectedId ? ' selected' : '';
    const statusClass = isRisky ? ' risk' : needsAtt ? ' paused' : s.status === 'working' ? ' running' : s.status === 'done' ? ' done' : '';
    const dotClass = isRisky ? 'risk-paused' : needsAtt ? 'paused' : s.status || 'idle';
    const confPct = s.confidence != null ? Math.round(s.confidence * 100) : 0;

    // Terminal line
    const termLine = s.suggestedAction
      ? `<span class="cmd">▸</span> ${this._esc(s.suggestedAction)}`
      : `<span class="cmd">▸</span> ${this._esc(s.stateSummary || s.status || '')}`;

    // Waiting/summary line
    let waitingHtml = '';
    if (needsAtt && s.stateSummary) {
      if (isRisky) {
        waitingHtml = `<div class="card-waiting">${this._highlightRisk(s.stateSummary)}</div>`;
      } else {
        waitingHtml = `<div class="card-waiting">${this._highlight(s.stateSummary)}</div>`;
      }
    }

    // Action buttons
    let actionsHtml = '';
    if (needsAtt) {
      const prompt = s.suggestedPrompt || 'y';
      if (isRisky) {
        actionsHtml = `<div class="card-actions">
          <button class="btn-primary risk" onclick="fleet.approve('${s.sessionId}','${this._esc(prompt)}')">Review</button>
          <button class="btn-secondary risk" onclick="fleet.deny('${s.sessionId}')">n — Block</button>
          <div class="confidence">
            <span class="conf-label risk">RISKY</span>
            <div class="conf-bar"><div class="conf-fill risk" style="width:0%"></div></div>
          </div>
        </div>`;
      } else {
        actionsHtml = `<div class="card-actions">
          <button class="btn-primary" onclick="fleet.approve('${s.sessionId}','${this._esc(prompt)}')">${this._esc(prompt)} — Allow</button>
          <button class="btn-secondary" onclick="fleet.deny('${s.sessionId}')">n</button>
          <div class="confidence">
            <span class="conf-label">CONF</span>
            <div class="conf-bar"><div class="conf-fill" style="width:${confPct}%"></div></div>
          </div>
        </div>`;
      }
    }

    // Branch badge
    const branchHtml = s.branch
      ? `<div class="card-branch${isRisky ? ' risky' : ''}">${isRisky ? '⚠ ' : ''}${this._esc(s.branch)}</div>`
      : '';

    return `<div class="session-card${statusClass}${selected}" data-id="${s.sessionId}">
      <div class="card-border-glow"></div>
      <div class="card-row1">
        <div class="card-project">
          <div class="sdot ${dotClass}"></div>
          ${this._esc(s.project || s.title || s.sessionId)}
        </div>
        <div class="card-meta">
          ${branchHtml}
          ${s.role ? `<span class="card-role">${this._esc(s.role)}</span>` : ''}
        </div>
      </div>
      <div class="card-terminal">${termLine}${s.status === 'working' ? ' <span class="cursor"></span>' : ''}</div>
      ${waitingHtml}
      ${actionsHtml}
    </div>`;
  },

  _highlight(text) {
    // Highlight y/n, numbers in parens, and quoted text
    return this._esc(text)
      .replace(/\(y\/n\)/gi, '<span class="hl">(y/n)</span>')
      .replace(/\((\d+)\)/g, '<span class="hl">($1)</span>')
      .replace(/\[(\d+)\]/g, '<span class="hl">[$1]</span>');
  },

  _highlightRisk(text) {
    return this._esc(text)
      .replace(/\(y\/n\)/gi, '<span class="hl-risk">(y/n)</span>')
      .replace(/\((\d+)\)/g, '<span class="hl-risk">($1)</span>');
  },

  _renderCompactRow(s) {
    const dotClass = s.status || 'done';
    const sparkline = this._createSparkline(s.sessionId);
    return `<div class="compact-row" data-id="${s.sessionId}">
      <span class="sdot ${dotClass}"></span>
      <span class="compact-project">${this._esc(s.project || s.title || s.sessionId)}</span>
      <span class="compact-summary">${this._esc(s.stateSummary || '')}</span>
      <span class="compact-sparkline sparkline">${sparkline}</span>
    </div>`;
  },

  renderGrid() {
    const container = document.getElementById('grid-view');
    const sessions = this.state?.sessions || [];

    if (sessions.length === 0) {
      container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">◇</div><div class="empty-state-text">No sessions</div></div>';
      return;
    }

    // Group by project
    const groups = {};
    for (const s of sessions) {
      const proj = s.project || 'Unknown';
      if (!groups[proj]) groups[proj] = [];
      groups[proj].push(s);
    }

    let html = '';
    for (const [proj, items] of Object.entries(groups)) {
      const role = items[0]?.role || '';
      html += `<div class="grid-project-group">
        <div class="grid-project-header">
          <span class="grid-project-name">${this._esc(proj)} <span class="grid-project-count">(${items.length})</span></span>
          ${role ? `<span class="grid-project-role">Role: ${this._esc(role)}</span>` : ''}
        </div>
        <div class="grid-cards">`;
      for (const s of items) {
        const selected = s.sessionId === this.selectedId ? ' selected' : '';
        const dotClass = this._needsAttention(s) ? 'attention' : (s.status || 'idle');
        const riskClass = s.risk ? (s.urgency === 'high' ? 'high' : 'medium') : '';
        const sparkline = this._createSparkline(s.sessionId);
        html += `<div class="card${selected}" data-id="${s.sessionId}" onclick="fleet.selectedId='${s.sessionId}';fleet.render()">
          <div class="card-header">
            <span class="status-dot ${dotClass}"></span>
            <span class="card-title">${this._esc(s.title || s.sessionId)}</span>
          </div>
          ${s.branch ? `<div class="card-branch">${this._esc(s.branch)}</div>` : ''}
          <div class="card-summary">${this._esc(s.stateSummary || '')}</div>
          <div class="card-footer">
            <span class="sparkline">${sparkline}</span>
            ${riskClass ? `<span class="card-risk-indicator ${riskClass}"></span>` : ''}
          </div>
        </div>`;
      }
      html += '</div></div>';
    }

    container.innerHTML = html;
  },

  renderMinimap() {
    const container = document.getElementById('mini-view');
    const sessions = this.state?.sessions || [];

    if (sessions.length === 0) {
      container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">◇</div><div class="empty-state-text">No sessions</div></div>';
      return;
    }

    let html = '<div class="minimap-grid">';
    for (const s of sessions) {
      let cls = '';
      if (this._needsAttention(s)) {
        cls = s.risk ? 'attention-risk' : 'attention';
      } else {
        switch (s.status) {
          case 'working': cls = 'working'; break;
          case 'done': cls = 'done'; break;
          default: cls = 'idle'; break;
        }
      }
      html += `<div class="mini-square ${cls}" data-id="${s.sessionId}"
        onmouseenter="fleet._showMiniTooltip(event,'${s.sessionId}')"
        onmouseleave="fleet._hideMiniTooltip()"></div>`;
    }
    html += '</div>';
    container.innerHTML = html;
  },

  _showMiniTooltip(e, sessionId) {
    const s = this.state?.sessions?.find(x => x.sessionId === sessionId);
    if (!s) return;
    let tip = document.querySelector('.mini-tooltip');
    if (!tip) {
      tip = document.createElement('div');
      tip.className = 'mini-tooltip';
      document.body.appendChild(tip);
    }
    tip.innerHTML = `<div class="tt-project">${this._esc(s.project || s.title || s.sessionId)}</div>
      <div class="tt-summary">${this._esc(s.stateSummary || s.status || '')}</div>`;
    tip.style.left = (e.clientX + 12) + 'px';
    tip.style.top = (e.clientY - 10) + 'px';
    tip.style.display = 'block';
  },

  _hideMiniTooltip() {
    const tip = document.querySelector('.mini-tooltip');
    if (tip) tip.style.display = 'none';
  },

  // ── Toast ──
  showToast(text, isError = false) {
    const el = document.createElement('div');
    el.className = `toast ${isError ? 'error' : 'success'}`;
    el.textContent = text;
    document.getElementById('toast-container').appendChild(el);
    requestAnimationFrame(() => el.classList.add('visible'));
    setTimeout(() => {
      el.classList.remove('visible');
      setTimeout(() => el.remove(), 300);
    }, 2500);
  },

  // ── Command Palette ──
  showPalette() {
    const palette = document.getElementById('palette');
    palette.classList.remove('hidden');
    const input = document.getElementById('palette-input');
    input.value = '';
    input.focus();
    this.paletteSelectedIdx = 0;
    this._buildPaletteItems('');
    this._renderPalette();
  },

  hidePalette() {
    document.getElementById('palette').classList.add('hidden');
  },

  _buildPaletteItems(query) {
    const items = [];
    const q = query.toLowerCase();

    // Static commands
    const commands = [
      { icon: '✓', label: 'Approve all safe', hint: '⌘↵', action: () => this.approveAllSafe() },
      { icon: '⟳', label: 'Scan now', hint: 'r', action: () => this.scan() },
      { icon: '◇', label: 'Set mode: scout', action: () => this.setMode('scout') },
      { icon: '◈', label: 'Set mode: semi', action: () => this.setMode('semi') },
      { icon: '◆', label: 'Set mode: autopilot', action: () => this.setMode('autopilot') },
      { icon: '●', label: 'Set global role: builder', action: () => this.setRoleGlobal('builder') },
      { icon: '●', label: 'Set global role: yeoman', action: () => this.setRoleGlobal('yeoman') },
      { icon: '●', label: 'Set global role: cautious', action: () => this.setRoleGlobal('cautious') },
      { icon: '●', label: 'Set global role: reviewer', action: () => this.setRoleGlobal('reviewer') },
      { icon: '●', label: 'Set global role: shipper', action: () => this.setRoleGlobal('shipper') },
      { icon: '●', label: 'Set global role: scout', action: () => this.setRoleGlobal('scout') },
    ];

    // Session items
    const sessions = this.state?.sessions || [];
    for (const s of sessions) {
      commands.push({
        icon: '▸',
        label: s.project || s.title || s.sessionId,
        hint: s.status,
        action: () => { this.selectedId = s.sessionId; this.hidePalette(); this.switchView('queue'); this.render(); },
      });
    }

    for (const cmd of commands) {
      if (!q || cmd.label.toLowerCase().includes(q)) {
        items.push(cmd);
      }
    }

    this.paletteItems = items;
    this.paletteSelectedIdx = Math.min(this.paletteSelectedIdx, Math.max(0, items.length - 1));
  },

  _renderPalette() {
    const container = document.getElementById('palette-results');
    let html = '';
    for (let i = 0; i < this.paletteItems.length; i++) {
      const item = this.paletteItems[i];
      const sel = i === this.paletteSelectedIdx ? ' selected' : '';
      html += `<div class="palette-item${sel}" data-idx="${i}" onclick="fleet._executePaletteItem(${i})">
        <span class="palette-item-icon">${item.icon}</span>
        <span class="palette-item-label">${this._esc(item.label)}</span>
        ${item.hint ? `<span class="palette-item-hint">${this._esc(item.hint)}</span>` : ''}
      </div>`;
    }
    container.innerHTML = html;
  },

  _executePaletteItem(idx) {
    const item = this.paletteItems[idx];
    if (item?.action) {
      item.action();
      this.hidePalette();
    }
  },

  // ── View switching ──
  switchView(view) {
    this.currentView = view;
    document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
    document.getElementById(view + '-view')?.classList.add('active');
    document.querySelectorAll('.tab').forEach(t => {
      t.classList.toggle('active', t.dataset.view === view);
    });
    this.render();
  },

  // ── Keyboard ──
  handleKey(e) {
    // Palette open
    if (!document.getElementById('palette').classList.contains('hidden')) {
      switch (e.key) {
        case 'Escape':
          e.preventDefault();
          this.hidePalette();
          return;
        case 'ArrowUp':
          e.preventDefault();
          this.paletteSelectedIdx = Math.max(0, this.paletteSelectedIdx - 1);
          this._renderPalette();
          return;
        case 'ArrowDown':
          e.preventDefault();
          this.paletteSelectedIdx = Math.min(this.paletteItems.length - 1, this.paletteSelectedIdx + 1);
          this._renderPalette();
          return;
        case 'Enter':
          e.preventDefault();
          this._executePaletteItem(this.paletteSelectedIdx);
          return;
      }
      return;
    }

    // Cmd+K → palette
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      this.showPalette();
      return;
    }

    // Cmd+Enter → approve all
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      this.approveAllSafe();
      return;
    }

    // View switching
    if (e.key === '1') { this.switchView('queue'); return; }
    if (e.key === '2') { this.switchView('grid'); return; }
    if (e.key === '3') { this.switchView('mini'); return; }

    // Rescan
    if (e.key === 'r' && !e.metaKey && !e.ctrlKey) {
      this.scan();
      return;
    }

    // Escape
    if (e.key === 'Escape') {
      this.selectedId = null;
      this.render();
      return;
    }

    // Queue navigation
    if (this.currentView !== 'queue') return;
    const sessions = this.state?.sessions || [];
    const attention = sessions.filter(s => this._needsAttention(s));
    if (attention.length === 0) return;

    const currentIdx = attention.findIndex(s => s.sessionId === this.selectedId);

    switch (e.key) {
      case 'ArrowUp':
      case 'k':
        e.preventDefault();
        if (currentIdx > 0) {
          this.selectedId = attention[currentIdx - 1].sessionId;
        } else {
          this.selectedId = attention[attention.length - 1].sessionId;
        }
        this.render();
        break;
      case 'ArrowDown':
      case 'j':
        e.preventDefault();
        if (currentIdx < attention.length - 1) {
          this.selectedId = attention[currentIdx + 1].sessionId;
        } else {
          this.selectedId = attention[0].sessionId;
        }
        this.render();
        break;
      case 'ArrowRight':
      case 'l':
      case 'Enter':
        e.preventDefault();
        if (this.selectedId) this.approve(this.selectedId);
        break;
      case 'ArrowLeft':
      case 'h':
      case 'Backspace':
        e.preventDefault();
        if (this.selectedId) this.deny(this.selectedId);
        break;
    }
  },

  // ── Utility ──
  _esc(str) {
    if (!str) return '';
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
  },

  // ── Mock data for browser testing ──
  _loadMockState() {
    const projects = ['claude-fleet', 'allshares', 'xray-app'];
    const roles = ['builder', 'yeoman', 'cautious', 'reviewer', 'shipper', 'scout'];
    const statuses = ['working', 'paused', 'idle', 'done'];
    const urgencies = ['high', 'medium', 'low'];

    const mockSessions = [
      {
        sessionId: 's1', title: 'feature/web-ui', project: 'claude-fleet', branch: 'feature/web-ui',
        status: 'paused', stateSummary: 'Wants to run: git push --force origin main',
        suggestedAction: 'Deny — force push to main', suggestedPrompt: 'n',
        confidence: 0.92, risk: true, riskReason: 'Force push to main branch',
        urgency: 'high', role: 'builder', goal: 'Build web UI', autoSent: null, progress: 65,
      },
      {
        sessionId: 's2', title: 'fix/auth-bug', project: 'allshares', branch: 'fix/auth-bug',
        status: 'paused', stateSummary: 'Waiting for approval to modify auth middleware',
        suggestedAction: 'Approve — safe change', suggestedPrompt: 'y',
        confidence: 0.85, risk: false, urgency: 'medium', role: 'cautious',
        goal: 'Fix auth flow', autoSent: null, progress: 40,
      },
      {
        sessionId: 's3', title: 'refactor/api', project: 'allshares', branch: 'refactor/api',
        status: 'working', stateSummary: 'Refactoring API endpoints, 12 files changed',
        suggestedAction: null, confidence: null, risk: false,
        urgency: 'low', role: 'builder', goal: 'Refactor API layer', autoSent: null, progress: 78,
      },
      {
        sessionId: 's4', title: 'deploy/prod', project: 'xray-app', branch: 'main',
        status: 'idle', stateSummary: 'Ready to deploy to production',
        suggestedAction: 'Approve deployment', suggestedPrompt: 'y',
        confidence: 0.70, risk: true, riskReason: 'Production deployment',
        urgency: 'high', role: 'shipper', goal: 'Ship v2.1', autoSent: null, progress: 95,
      },
      {
        sessionId: 's5', title: 'test/e2e', project: 'xray-app', branch: 'test/e2e-suite',
        status: 'working', stateSummary: 'Running E2E test suite (14/38 passing)',
        suggestedAction: null, confidence: null, risk: false,
        urgency: 'low', role: 'reviewer', goal: 'E2E coverage', autoSent: null, progress: 37,
      },
      {
        sessionId: 's6', title: 'docs/readme', project: 'claude-fleet', branch: 'docs/readme',
        status: 'idle', stateSummary: 'Wants to create README.md',
        suggestedAction: 'Approve — documentation only', suggestedPrompt: 'y',
        confidence: 0.95, risk: false, urgency: 'low', role: 'yeoman',
        goal: 'Update docs', autoSent: null, progress: 20,
      },
      {
        sessionId: 's7', title: 'feature/dashboard', project: 'allshares', branch: 'feature/dashboard',
        status: 'done', stateSummary: 'Dashboard feature complete',
        suggestedAction: null, confidence: null, risk: false,
        urgency: 'low', role: 'builder', goal: 'Build dashboard', autoSent: 'y', progress: 100,
      },
      {
        sessionId: 's8', title: 'hotfix/css', project: 'claude-fleet', branch: 'hotfix/css',
        status: 'paused', stateSummary: 'Wants to delete src/styles/legacy.css',
        suggestedAction: 'Approve — cleanup', suggestedPrompt: 'y',
        confidence: 0.88, risk: false, urgency: 'low', role: 'builder',
        goal: 'CSS cleanup', autoSent: null, progress: 50,
      },
    ];

    // Seed sparkline history
    for (const s of mockSessions) {
      const h = [];
      for (let i = 0; i < 15; i++) {
        h.push(this._statusToValue(statuses[Math.floor(Math.random() * statuses.length)]));
      }
      h.push(this._statusToValue(s.status));
      this.sparklineHistory[s.sessionId] = h;
    }

    this._onState({
      mode: 'semi',
      globalRole: 'builder',
      sessions: mockSessions,
    });

    this._onDaemonStatus(true);
  },

  // ── Init ──
  init() {
    // Audio init on first interaction
    document.addEventListener('click', () => { if (!audio.ctx) audio.init(); }, { once: true });
    document.addEventListener('keydown', () => { if (!audio.ctx) audio.init(); }, { once: true });

    // Keyboard
    document.addEventListener('keydown', e => this.handleKey(e));

    // Tab clicks
    document.querySelectorAll('.tab').forEach(tab => {
      tab.addEventListener('click', () => this.switchView(tab.dataset.view));
    });

    // Session card clicks (delegation)
    document.getElementById('content').addEventListener('click', e => {
      const card = e.target.closest('.session-card');
      if (card && !e.target.closest('button')) {
        this.selectedId = card.dataset.id;
        this.render();
      }
    });

    // Mode tabs
    document.querySelectorAll('.mode-tab').forEach(tab => {
      tab.addEventListener('click', () => this.setMode(tab.dataset.mode));
    });

    // Scan button
    document.getElementById('scan-btn').addEventListener('click', () => this.scan());

    // Palette input
    document.getElementById('palette-input').addEventListener('input', e => {
      this._buildPaletteItems(e.target.value);
      this.paletteSelectedIdx = 0;
      this._renderPalette();
    });

    // Palette backdrop click
    document.querySelector('.palette-backdrop')?.addEventListener('click', () => this.hidePalette());

    // Expose to window for Swift bridge
    window.fleet = this;

    // Mock mode if no bridge
    if (!window.webkit?.messageHandlers?.fleet) {
      console.log('[fleet] running in browser mode — bridge commands will be logged');
      this._mockMode = true;
      this._loadMockState();
    }
  },
};

// Boot
document.addEventListener('DOMContentLoaded', () => fleet.init());
