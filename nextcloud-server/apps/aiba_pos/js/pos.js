(function () {
    'use strict';

    const t = (s) => (window.t ? t('aiba_pos', s) : s);

    function url(path) {
        return OC.generateUrl('/apps/aiba_pos' + path);
    }

    async function api(path, method, body) {
        const opts = {
            method: method || 'GET',
            headers: {
                'Accept': 'application/json',
                'requesttoken': OC.requestToken,
            },
        };
        if (body) {
            opts.headers['Content-Type'] = 'application/json';
            opts.body = JSON.stringify(body);
        }
        const res = await fetch(url(path), opts);
        let data = null;
        try { data = await res.json(); } catch (e) { /* ignore */ }
        return { ok: res.ok, status: res.status, data: data };
    }

    const el = (id) => document.getElementById(id);
    const fmt = (n) => {
        const v = Number(n || 0);
        return v.toLocaleString('ru-RU') + ' so\'m';
    };

    let restaurants = [];

    function currentRid() {
        const sel = el('pos-restaurant');
        return sel && sel.value ? sel.value : null;
    }

    async function loadRestaurants() {
        const r = await api('/api/restaurants');
        restaurants = Array.isArray(r.data) ? r.data : [];
        const sel = el('pos-restaurant');
        sel.innerHTML = '';
        restaurants.forEach((x) => {
            const o = document.createElement('option');
            o.value = x.id;
            o.textContent = x.name + ' (' + x.code + ')';
            sel.appendChild(o);
        });
        const has = restaurants.length > 0;
        el('pos-empty').style.display = has ? 'none' : 'block';
        el('pos-body').style.display = has ? 'block' : 'none';
        if (has) { await refresh(); }
    }

    function statusChip(status) {
        const span = document.createElement('span');
        span.className = 'pos-chip pos-chip--' + status;
        span.textContent = status;
        return span;
    }

    function fiscalChip(fiscal) {
        const span = document.createElement('span');
        if (!fiscal) { span.textContent = '—'; return span; }
        span.className = 'pos-chip pos-chip--' + fiscal.status;
        span.textContent = fiscal.status === 'sent' ? ('✓ ' + (fiscal.fiscal_sign || 'sent')) : fiscal.status;
        if (fiscal.qr_url) { span.title = fiscal.qr_url; }
        return span;
    }

    async function refresh() {
        const rid = currentRid();
        if (!rid) { return; }

        const sum = await api('/api/sales-summary?restaurant_id=' + encodeURIComponent(rid));
        if (sum.ok && sum.data) {
            el('pos-total').textContent = fmt(sum.data.total_sales);
            el('pos-orders').textContent = sum.data.orders_count;
            el('pos-cash').textContent = fmt(sum.data.total_cash);
            el('pos-card').textContent = fmt(sum.data.total_card);
        }

        const prods = await api('/api/products?restaurant_id=' + encodeURIComponent(rid));
        const tbody = el('pos-products');
        tbody.innerHTML = '';
        const list = Array.isArray(prods.data) ? prods.data : [];
        el('pos-prodcount').textContent = '(' + list.length + ')';
        list.forEach((p) => {
            const tr = document.createElement('tr');
            const c1 = document.createElement('td'); c1.textContent = p.name;
            const c2 = document.createElement('td'); c2.textContent = fmt(p.price);
            const c3 = document.createElement('td'); c3.textContent = p.mxik_code || '—'; c3.className = 'pos-muted';
            tr.append(c1, c2, c3);
            tbody.appendChild(tr);
        });

        const orders = await api('/api/orders?restaurant_id=' + encodeURIComponent(rid));
        const ob = el('pos-orderlist');
        ob.innerHTML = '';
        (Array.isArray(orders.data) ? orders.data : []).forEach((o) => {
            const tr = document.createElement('tr');
            const c1 = document.createElement('td'); c1.textContent = o.number || o.id.slice(0, 8);
            const c2 = document.createElement('td'); c2.appendChild(statusChip(o.status));
            const c3 = document.createElement('td'); c3.textContent = fmt(o.total);
            const c4 = document.createElement('td'); c4.appendChild(fiscalChip(o.fiscal));
            tr.append(c1, c2, c3, c4);
            ob.appendChild(tr);
        });
    }

    async function seed() {
        const btn = el('pos-seed');
        btn.disabled = true;
        const r = await api('/api/seed-demo', 'POST', {});
        btn.disabled = false;
        if (r.ok) {
            OC.Notification.showTemporary(t('Demo ma\'lumot yaratildi'));
            await loadRestaurants();
        } else {
            OC.Notification.showTemporary(t('Xato') + ': ' + (r.data && (r.data.error || r.data.detail) || r.status));
        }
    }

    document.addEventListener('DOMContentLoaded', function () {
        if (!document.getElementById('aiba-pos')) { return; }
        el('pos-refresh').addEventListener('click', refresh);
        el('pos-seed').addEventListener('click', seed);
        el('pos-restaurant').addEventListener('change', refresh);
        loadRestaurants();
    });
})();
