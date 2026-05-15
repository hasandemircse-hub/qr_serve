/**
 * No-app QR menü: URL /r/{restaurantId}/t/{tableId}/{token}
 * Durum: REST GET …/orders/open + WebSocket ORDER_CONFIRMED / LINE_KITCHEN_STATUS
 */
(function () {
  const match = /^\/r\/([^/]+)\/t\/([^/]+)\/([^/]+)\/?$/.exec(window.location.pathname || '');
  if (!match) {
    document.body.innerHTML = '<p style="padding:24px">Geçersiz bağlantı. QR kodunu tekrar okutun.</p>';
    return;
  }
  const restaurantId = match[1];
  const tableId = match[2];
  const token = decodeURIComponent(match[3]);

  const { protocol, hostname, port } = window.location;
  const httpBase = `${protocol}//${hostname}${port ? ':' + port : ''}`;
  const wsProto = protocol === 'https:' ? 'wss:' : 'ws:';
  const wsBase = `${wsProto}//${hostname}${port ? ':' + port : ''}`;

  const api = (suffix) =>
    `${httpBase}/api/v1/guest/r/${restaurantId}/t/${tableId}/${encodeURIComponent(token)}${suffix}`;

  /** @type {{productId:string, quantity:number, selectedOptions: object, label:string}[]} */
  let cart = [];
  let ws;

  /** @type {Record<string, { orderNumber: string, orderStatus: string, orderedAt: any, lines: { lineId: string, productName: string, quantity: number, kitchenLineStatus: string }[] }>} */
  const orderBook = {};

  const $ = (id) => document.getElementById(id);

  function logWs(msg) {
    const el = $('wsLog');
    const line = typeof msg === 'string' ? msg : JSON.stringify(msg, null, 2);
    el.textContent = `[${new Date().toLocaleTimeString('tr-TR')}] ${line}\n` + el.textContent;
  }

  function fmtOrderedAt(v) {
    if (!v) return '';
    if (typeof v === 'string') return v;
    if (Array.isArray(v) && v.length >= 3) {
      const y = v[0];
      const m = String(v[1]).padStart(2, '0');
      const d = String(v[2]).padStart(2, '0');
      if (v.length >= 5) {
        const h = String(v[3]).padStart(2, '0');
        const mi = String(v[4]).padStart(2, '0');
        return `${y}-${m}-${d} ${h}:${mi}`;
      }
      return `${y}-${m}-${d}`;
    }
    return String(v);
  }

  function kitchenLabel(st) {
    switch (st) {
      case 'RECEIVED':
        return 'Hazırlanıyor';
      case 'READY':
        return 'Hazır';
      case 'PENDING':
      default:
        return 'Bekliyor';
    }
  }

  function pillClass(st) {
    if (st === 'READY') return 'status-pill p-ready';
    if (st === 'RECEIVED') return 'status-pill p-received';
    return 'status-pill p-pending';
  }

  function renderStatusOrders() {
    const root = $('statusOrders');
    const ids = Object.keys(orderBook);
    if (ids.length === 0) {
      root.innerHTML = '<div class="empty-status">Henüz açık sipariş yok. Menüden sipariş verin.</div>';
      return;
    }
    root.innerHTML = '';
    ids.sort();
    for (const oid of ids) {
      const o = orderBook[oid];
      const card = document.createElement('div');
      card.className = 'status-card';
      const when = fmtOrderedAt(o.orderedAt);
      card.innerHTML = `<h2>${escapeHtml(o.orderNumber || oid)}</h2>
        <div class="status-meta">${when ? escapeHtml(when) + ' · ' : ''}${escapeHtml(o.orderStatus || '')}</div>
        <div class="status-lines"></div>`;
      const linesEl = card.querySelector('.status-lines');
      for (const ln of o.lines || []) {
        const row = document.createElement('div');
        row.className = 'status-line';
        const st = ln.kitchenLineStatus || 'PENDING';
        row.innerHTML = `<span>${escapeHtml(ln.productName)} × ${ln.quantity}</span><span class="${pillClass(st)}">${kitchenLabel(st)}</span>`;
        linesEl.appendChild(row);
      }
      root.appendChild(card);
    }
  }

  function hydrateFromSnapshot(resp) {
    for (const k of Object.keys(orderBook)) delete orderBook[k];
    for (const o of resp.orders || []) {
      orderBook[o.orderId] = {
        orderNumber: o.orderNumber || '',
        orderStatus: o.status || '',
        orderedAt: o.orderedAt,
        lines: (o.lines || []).map((l) => ({
          lineId: l.lineItemId,
          productName: l.productName,
          quantity: l.quantity,
          kitchenLineStatus: l.kitchenLineStatus,
        })),
      };
    }
    renderStatusOrders();
  }

  async function loadOrderSnapshot() {
    const res = await fetch(api('/orders/open'));
    if (!res.ok) {
      logWs({ warn: 'orders-open-failed', status: res.status });
      return;
    }
    const data = await res.json();
    hydrateFromSnapshot(data);
  }

  function mergeOrderConfirmed(msg) {
    const lines = (msg.lines || []).map((l) => ({
      lineId: l.lineId,
      productName: l.productName,
      quantity: l.quantity,
      kitchenLineStatus: l.kitchenLineStatus || 'PENDING',
    }));
    orderBook[msg.orderId] = {
      orderNumber: msg.orderNumber || '',
      orderStatus: 'OPEN',
      orderedAt: null,
      lines,
    };
    renderStatusOrders();
  }

  function mergeLineStatus(msg) {
    const o = orderBook[msg.orderId];
    if (!o || !o.lines) return;
    for (const line of o.lines) {
      if (String(line.lineId) === String(msg.lineId)) {
        line.kitchenLineStatus = msg.kitchenLineStatus;
        break;
      }
    }
    renderStatusOrders();
  }

  function handleWsPayload(obj) {
    const t = obj.type;
    if (t === 'CONNECTED') return;
    if (t === 'ORDER_CONFIRMED') {
      mergeOrderConfirmed(obj);
      return;
    }
    if (t === 'LINE_KITCHEN_STATUS') {
      mergeLineStatus(obj);
      return;
    }
  }

  function setCartBadge() {
    $('cartBadge').textContent = String(cart.length);
    $('btnConfirm').disabled = cart.length === 0;
  }

  function switchTab(name) {
    document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
    document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === 'panel-' + name));
    if (name === 'status') {
      loadOrderSnapshot().catch((e) => logWs({ err: String(e) }));
    }
  }

  document.querySelectorAll('.tab').forEach((b) => {
    b.addEventListener('click', () => switchTab(b.dataset.tab));
  });

  $('btnRefreshStatus').addEventListener('click', () => {
    loadOrderSnapshot().catch((e) => logWs({ err: String(e) }));
  });

  async function init() {
    const s = await fetch(api('/session')).then((r) => {
      if (!r.ok) throw new Error('Oturum doğrulanamadı');
      return r.json();
    });
    $('subtitle').textContent = `${s.restaurantName} · Masa ${s.tableLabel}`;
    await loadMenus();
    await loadOrderSnapshot();
    renderStatusOrders();
    connectWs();
  }

  async function loadMenus() {
    const data = await fetch(api('/menu')).then((r) => r.json());
    const root = $('menuList');
    root.innerHTML = '';
    for (const menu of data.menus || []) {
      const m = document.createElement('div');
      m.innerHTML = `<h2 style="margin:8px 0 4px;font-size:1rem">${escapeHtml(menu.name)}</h2>`;
      root.appendChild(m);
      for (const p of menu.products || []) {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<h3>${escapeHtml(p.name)}</h3><p class="muted" style="margin:0;font-size:0.85rem">${escapeHtml(p.description || '')}</p><div class="price">${Number(p.price).toFixed(2)} ₺</div>`;
        card.addEventListener('click', () => openProductWizard(p));
        root.appendChild(card);
      }
    }
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  let modalState = { product: null, wizard: null, selections: {} };

  async function openProductWizard(product) {
    const wiz = await fetch(`${httpBase}/api/v1/qr/products/${product.id}/wizard`).then((r) => r.json());
    modalState = { product, wizard: wiz, selections: {} };
    $('modalTitle').textContent = product.name;
    const body = $('modalBody');
    body.innerHTML = '';
    for (const g of wiz.groups || []) {
      const wrap = document.createElement('div');
      wrap.className = 'option-group';
      wrap.innerHTML = `<h4>${escapeHtml(g.name)}</h4>`;
      const inputType = g.selectionType === 'MULTI' ? 'checkbox' : 'radio';
      const name = `g_${g.id}`;
      for (const o of g.options || []) {
        const lab = document.createElement('label');
        lab.className = 'opt';
        lab.innerHTML = `<input type="${inputType}" name="${name}" value="${o.id}" data-group="${g.id}" data-type="${g.selectionType}" /> ${escapeHtml(o.label)}${Number(o.priceAdjustment) ? ' (+' + Number(o.priceAdjustment).toFixed(2) + ' ₺)' : ''}`;
        wrap.appendChild(lab);
      }
      body.appendChild(wrap);
    }
    body.querySelectorAll('input').forEach((inp) => {
      inp.addEventListener('change', validateModal);
    });
    $('modal').classList.remove('hidden');
    validateModal();
  }

  function validateModal() {
    const g = modalState.wizard;
    if (!g || !g.groups) {
      $('modalAdd').disabled = true;
      return;
    }
    let ok = true;
    for (const gr of g.groups) {
      const picked = Array.from(
        document.querySelectorAll(`input[name="g_${gr.id}"]:checked`),
      ).map((x) => x.value);
      if (gr.selectionType === 'SINGLE' && picked.length !== 1) ok = false;
      if (gr.selectionType === 'MULTI' && picked.length < 1) ok = false;
    }
    $('modalAdd').disabled = !ok;
  }

  $('modalCancel').addEventListener('click', () => $('modal').classList.add('hidden'));
  $('modalAdd').addEventListener('click', () => {
    const g = modalState.wizard;
    const steps = [];
    for (const gr of g.groups || []) {
      const picked = Array.from(document.querySelectorAll(`input[name="g_${gr.id}"]:checked`)).map((x) => x.value);
      steps.push({
        groupId: gr.id,
        selectionType: gr.selectionType,
        selectedOptionIds: picked,
      });
    }
    const selectedOptions = { schemaVersion: 1, steps };
    cart.push({
      productId: modalState.product.id,
      quantity: 1,
      selectedOptions,
      label: modalState.product.name,
    });
    $('modal').classList.add('hidden');
    renderCart();
    setCartBadge();
  });

  function renderCart() {
    const root = $('cartList');
    root.innerHTML = '';
    cart.forEach((line, idx) => {
      const row = document.createElement('div');
      row.className = 'card';
      row.style.cursor = 'default';
      row.innerHTML = `<div style="display:flex;justify-content:space-between;gap:8px"><span>${escapeHtml(line.label)}</span><button type="button" data-i="${idx}" class="ghost rm">Kaldır</button></div>`;
      row.querySelector('.rm').addEventListener('click', () => {
        cart.splice(idx, 1);
        renderCart();
        setCartBadge();
      });
      root.appendChild(row);
    });
  }

  $('btnConfirm').addEventListener('click', async () => {
    if (!cart.length) return;
    const lines = cart.map((c) => ({
      productId: c.productId,
      quantity: c.quantity,
      selectedOptions: c.selectedOptions,
    }));
    const res = await fetch(api('/orders'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ lines }),
    });
    if (!res.ok) {
      alert('Sipariş gönderilemedi: ' + (await res.text()));
      return;
    }
    const data = await res.json();
    cart = [];
    renderCart();
    setCartBadge();
    alert('Sipariş alındı: ' + data.orderNumber);
    await loadOrderSnapshot();
    switchTab('status');
  });

  async function postService(type) {
    const res = await fetch(api('/service-requests'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type }),
    });
    if (!res.ok) {
      alert('İstek gönderilemedi');
      return;
    }
    logWs({ info: 'service-request-sent', type });
  }

  $('btnWaiter').addEventListener('click', () => postService('CALL_WAITER'));
  $('btnBill').addEventListener('click', () => postService('REQUEST_BILL'));

  function connectWs() {
    const q = `restaurantId=${encodeURIComponent(restaurantId)}&tableId=${encodeURIComponent(tableId)}&token=${encodeURIComponent(token)}`;
    ws = new WebSocket(`${wsBase}/ws/v1/guest?${q}`);
    ws.onmessage = (ev) => {
      try {
        const obj = JSON.parse(ev.data);
        logWs(obj);
        handleWsPayload(obj);
      } catch {
        logWs(ev.data);
      }
    };
    ws.onerror = () => logWs({ error: 'websocket-error' });
  }

  init().catch((e) => {
    document.body.innerHTML = '<p style="padding:24px">Başlatılamadı: ' + escapeHtml(e.message) + '</p>';
  });
})();
