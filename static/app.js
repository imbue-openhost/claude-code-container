(function () {
  const tabsEl = document.getElementById('tabs');
  const newTabEl = document.getElementById('new-tab');
  const panesEl = document.getElementById('panes');
  const tabs = [];
  let nextId = 1;

  function wsUrl(sessionId) {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    const base = `${proto}://${location.host}/terminal/ws`;
    return sessionId ? `${base}?session=${encodeURIComponent(sessionId)}` : base;
  }

  function createTab(opts) {
    opts = opts || {};
    const id = nextId++;
    const label = opts.label || `term ${id}`;

    const tabEl = document.createElement('div');
    tabEl.className = 'tab';
    tabEl.innerHTML = `<span class="label"></span><span class="close" title="Close">×</span>`;
    tabEl.querySelector('.label').textContent = label;
    tabsEl.insertBefore(tabEl, newTabEl);

    const paneEl = document.createElement('div');
    paneEl.className = 'pane';
    const termEl = document.createElement('div');
    termEl.className = 'term';
    paneEl.appendChild(termEl);
    panesEl.appendChild(paneEl);

    const term = new Terminal({ cursorBlink: true, fontSize: 14,
      theme: { background: '#1e1e1e' } });
    const fit = new FitAddon.FitAddon();
    term.loadAddon(fit);
    term.open(termEl);

    const ws = new WebSocket(wsUrl(opts.sessionId));
    ws.binaryType = 'arraybuffer';

    function sendResize() {
      const d = fit.proposeDimensions();
      if (d && ws.readyState === WebSocket.OPEN) {
        const json = new TextEncoder().encode(JSON.stringify({ type: 'resize', cols: d.cols, rows: d.rows }));
        const buf = new Uint8Array(1 + json.length);
        buf[0] = 0x01; buf.set(json, 1);
        ws.send(buf.buffer);
      }
    }

    ws.onopen = () => { fit.fit(); sendResize(); };
    ws.onmessage = (ev) => {
      if (ev.data instanceof ArrayBuffer) term.write(new Uint8Array(ev.data));
      else term.write(ev.data);
    };
    ws.onclose = () => term.write('\r\n\x1b[90m[disconnected]\x1b[0m\r\n');

    term.onData((data) => {
      if (ws.readyState !== WebSocket.OPEN) return;
      const enc = new TextEncoder().encode(data);
      const buf = new Uint8Array(1 + enc.length);
      buf[0] = 0x00; buf.set(enc, 1);
      ws.send(buf.buffer);
    });

    const entry = { id, tabEl, paneEl, term, fit, ws };
    tabs.push(entry);

    tabEl.addEventListener('click', (e) => {
      if (e.target.classList.contains('close')) return;
      activate(entry);
    });
    tabEl.querySelector('.close').addEventListener('click', () => closeTab(entry));

    activate(entry);
    return entry;
  }

  function activate(entry) {
    for (const t of tabs) {
      t.tabEl.classList.toggle('active', t === entry);
      t.paneEl.classList.toggle('active', t === entry);
    }
    setTimeout(() => { entry.fit.fit(); }, 0);
  }

  function closeTab(entry) {
    try { entry.ws.close(); } catch (_) {}
    try { entry.term.dispose(); } catch (_) {}
    entry.tabEl.remove();
    entry.paneEl.remove();
    const idx = tabs.indexOf(entry);
    if (idx >= 0) tabs.splice(idx, 1);
    if (tabs.length === 0) createTab();
    else activate(tabs[Math.min(idx, tabs.length - 1)]);
  }

  newTabEl.addEventListener('click', () => createTab());
  window.addEventListener('resize', () => {
    for (const t of tabs) t.fit.fit();
  });

  // If launched with ?session=<id>, attach to that prefilled session in the first tab,
  // then strip the query string so reloads don't try to reuse a consumed id.
  const params = new URLSearchParams(location.search);
  const sessionId = params.get('session');
  if (sessionId) {
    history.replaceState({}, '', location.pathname);
    createTab({ sessionId, label: 'claude' });
  } else {
    createTab();
  }
})();
