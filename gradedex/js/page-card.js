/* GradeDex — página da carta: slab, anúncios, histórico, pop report, alerta e certificado. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui, S = GD.store;
  GD.pages = GD.pages || {};

  const RANGES = [[13, '3M'], [26, '6M'], [52, '1A']];
  const baseName = n => n.replace(/^Shining /, '').split(' ')[0];

  function keysOf(card, listings) {
    const map = {};
    listings.forEach(l => {
      const k = D.gradeKey(l);
      if (!map[k]) map[k] = { key: k, grader: l.grader, grade: l.grade, special: l.special, list: [] };
      map[k].list.push(l);
    });
    const top = 'PSA ' + card.top;
    if (!map[top]) map[top] = { key: top, grader: 'PSA', grade: card.top, special: null, list: [] };
    return Object.keys(map).map(k => map[k]).sort((a, b) => D.gradeScore(b) - D.gradeScore(a) || D.GRADERS.indexOf(a.grader) - D.GRADERS.indexOf(b.grader));
  }

  function buyPanel(card, l) {
    const seller = D.SELLER[l.seller];
    const diff = (l.price / l.ref - 1) * 100;
    const inCart = S.inCart(l.id), inCmp = S.inCompare(l.id);
    return '<div class="buy__row">' +
        '<div class="buy__what"><span class="lbl">Slab selecionado</span><span class="buy__chips">' + U.gchip(l) + (l.lang !== 'EN' ? '<span class="tag">' + D.LANGS[l.lang] + '</span>' : '') + (l.offer ? '<span class="tag">Aceita oferta</span>' : '') + '</span></div>' +
        '<div class="buy__price"><span class="num">' + U.brl(l.price) + '</span>' +
          '<span class="buy__ref">Referência ' + D.gradeKey(l) + ': <span class="num">' + U.brl(l.ref) + '</span> ' +
          '<span class="tag ' + (diff <= -5 ? 'tag--ok' : diff >= 5 ? 'tag--down' : '') + '">' + (Math.abs(diff) < 0.5 ? 'na referência' : U.pct(diff)) + '</span></span></div>' +
      '</div>' +
      '<div class="buy__actions">' +
        '<button type="button" class="btn btn--volt btn--lg' + (inCart ? ' is-on' : '') + '" data-cart="' + l.id + '">' + (inCart ? U.icons.check + 'No carrinho' : U.icons.cart + 'Adicionar ao carrinho') + '</button>' +
        '<button type="button" class="btn btn--ghost btn--lg' + (inCmp ? ' is-on' : '') + '" data-compare="' + l.id + '" aria-pressed="' + inCmp + '">' + U.icons.compare + (inCmp ? 'Comparando' : 'Comparar') + '</button>' +
      '</div>' +
      '<ul class="buy__assure">' +
        '<li>' + U.icons.shield + '<span><b>Pagamento protegido.</b> O valor só é liberado à loja quando você confirma o recebimento.</span></li>' +
        '<li>' + U.icons.truck + '<span>Vendido por <a href="#/loja/' + seller.id + '">' + U.esc(seller.name) + '</a> ' + U.rating(seller) + ' · envia de ' + U.esc(seller.city) + '/' + seller.uf + ' em até ' + U.plural(seller.ships, 'dia útil', 'dias úteis') + '.</span></li>' +
      '</ul>';
  }

  function offersTable(card, rows, selId) {
    if (!rows.length) return '<div class="empty"><p>Nenhum anúncio nesta nota agora. Crie um alerta abaixo para saber quando aparecer.</p></div>';
    return '<div class="table-wrap"><table class="offers">' +
      '<thead><tr><th scope="col">Slab</th><th scope="col">Idioma</th><th scope="col">Certificado</th><th scope="col">Loja</th><th scope="col">Envio</th><th scope="col" class="r">Preço</th><th scope="col"><span class="sr">Ações</span></th></tr></thead><tbody>' +
      rows.map(l => {
        const s = D.SELLER[l.seller];
        const diff = (l.price / l.ref - 1) * 100;
        const inCart = S.inCart(l.id);
        return '<tr class="' + (l.id === selId ? 'is-sel' : '') + '" data-row="' + l.id + '">' +
          '<td class="o-slab">' + U.gchip(l) + (l.subs ? '<span class="subs num" title="Centralização · Cantos · Bordas · Superfície">' + l.subs.join(' · ') + '</span>' : '') + '</td>' +
          '<td class="o-lang" data-label="Idioma">' + D.LANGS[l.lang] + '</td>' +
          '<td class="o-cert num" data-label="Certificado">' + l.cert + '</td>' +
          '<td class="o-seller"><a href="#/loja/' + s.id + '">' + U.esc(s.name) + '</a> ' + U.verified(s) + '<span class="muted o-sub">' + U.rating(s) + ' · ' + U.int(s.sales) + ' vendas · ' + U.esc(s.city) + '/' + s.uf + '</span></td>' +
          '<td class="o-ship" data-label="Envio">' + U.plural(s.ships, 'dia útil', 'dias úteis') + '<span class="muted o-sub">' + l.days + 'd anunciado</span></td>' +
          '<td class="o-price r"><span class="num o-amount">' + U.brl(l.price) + '</span>' + (diff <= -5 ? '<span class="tag tag--ok">' + U.pct(diff) + ' ref.</span>' : '') + '</td>' +
          '<td class="o-act"><button type="button" class="btn btn--ghost btn--sm" data-select="' + l.id + '">Ver slab</button><button type="button" class="btn btn--sm ' + (inCart ? 'is-on' : 'btn--volt') + '" data-cart="' + l.id + '" aria-label="' + (inCart ? 'Remover do carrinho' : 'Adicionar ao carrinho') + '">' + (inCart ? U.icons.check : U.icons.cart) + '</button></td>' +
        '</tr>';
      }).join('') + '</tbody></table></div>';
  }

  function popPanel(card, grader, l) {
    const pop = D.popReport(card)[grader];
    const max = Math.max.apply(null, pop.rows.map(r => r.count));
    const sameGrade = l && l.grader === grader ? pop.rows.find(r => r.grade === l.grade) : null;
    return '<div class="pop__stats">' +
        '<div><span class="lbl">População total</span><span class="num pop__big">' + U.int(pop.total) + '</span></div>' +
        '<div><span class="lbl">Taxa de 10</span><span class="num pop__big">' + U.dec(pop.gemRate * 100) + '%</span></div>' +
        (grader === 'BGS' ? '<div><span class="lbl">Black Label</span><span class="num pop__big">' + U.int(pop.blackLabel) + '</span></div>' : '') +
      '</div>' +
      '<ul class="pop__bars">' + pop.rows.map(r =>
        '<li class="' + (sameGrade && sameGrade.grade === r.grade ? 'is-sel' : '') + '"><span class="pop__g">' + r.grade + '</span><span class="pop__bar"><i style="width:' + (r.count / max * 100).toFixed(1) + '%"></i></span><span class="num pop__n">' + U.int(r.count) + '</span></li>').join('') + '</ul>' +
      (sameGrade ? '<p class="pop__note">O slab selecionado é 1 de ' + U.int(sameGrade.count) + ' com ' + grader + ' ' + sameGrade.grade + '.</p>' : '') +
      '<p class="muted pop__src">População aproximada para demonstração.</p>';
  }

  function chartStats(pts) {
    const ps = pts.map(p => p.p);
    const lo = Math.min.apply(null, ps), hi = Math.max.apply(null, ps);
    const ch = (ps[ps.length - 1] / ps[0] - 1) * 100;
    const sales = pts.reduce((s, p) => s + p.n, 0);
    return '<dl class="ch-stats">' +
      '<div><dt>Mínima</dt><dd class="num">' + U.brl(lo) + '</dd></div>' +
      '<div><dt>Máxima</dt><dd class="num">' + U.brl(hi) + '</dd></div>' +
      '<div><dt>No período</dt><dd class="num ' + (ch >= 0 ? 'up' : 'down') + '">' + U.pct(ch) + '</dd></div>' +
      '<div><dt>Vendas</dt><dd class="num">' + U.int(sales) + '</dd></div>' +
    '</dl>';
  }

  GD.pages.carta = function (main, params) {
    const card = D.CARD[params.id];
    if (!card) { GD.pages.notfound(main); return; }
    const set = D.SET[card.set];
    const all = D.listingsOf(card.id);
    const keys = keysOf(card, all);
    let sel = D.LISTING[params.l] && D.LISTING[params.l].card === card.id ? D.LISTING[params.l] : U.showcase(all.filter(l => l.lang === 'EN').length ? all.filter(l => l.lang === 'EN') : all);
    let filterKey = null;
    let chartKey = D.gradeKey(sel);
    let range = 52;
    let popGrader = sel.grader;
    S.pushRecent(card.id);

    const related = D.CARDS.filter(c => c.id !== card.id && (baseName(c.name) === baseName(card.name) || c.set === card.set))
      .sort((a, b) => (baseName(b.name) === baseName(card.name)) - (baseName(a.name) === baseName(card.name)) || b.market - a.market).slice(0, 6);
    D.CARDS.filter(c => c.id !== card.id && c.era === card.era && !related.includes(c)).sort((a, b) => b.market - a.market)
      .slice(0, 6 - related.length).forEach(c => related.push(c));
    const alertKeys = keys.map(k => '<option value="' + U.esc(k.key) + '">' + U.esc(k.key) + '</option>').join('');

    main.innerHTML =
      '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><a href="#/busca?set=' + set.id + '">' + U.esc(U.setLabel(set)) + '</a><span aria-hidden="true">/</span><span>' + U.esc(card.name) + '</span></nav>' +
      '<div class="pdp">' +
        '<div class="pdp__media">' +
          '<div class="pdp__slab" id="p-slab"></div>' +
          '<div class="pdp__cert" id="p-cert"></div>' +
        '</div>' +
        '<div class="pdp__info">' +
          '<p class="eyebrow">' + U.esc(U.setFull(set)) + ' · ' + set.year + '</p>' +
          '<div class="pdp__title"><h1>' + U.esc(card.name) + (card.variant ? ' <span>' + U.esc(card.variant) + '</span>' : '') + '</h1>' + U.favBtn(card) + '</div>' +
          '<p class="pdp__sub"><span class="tag">' + U.esc(card.num) + '</span><span class="tag">' + U.esc(card.rarity) + '</span><span class="tag">' + D.TYPES[card.type].pt + '</span><span class="tag">' + D.ERAS[card.era] + '</span></p>' +
          '<div class="buy panel" id="p-buy"></div>' +
          '<div class="pdp__grades"><h2 class="h-sm">Menor preço por nota</h2><div class="gcells" id="p-gcells"></div></div>' +
        '</div>' +
      '</div>' +
      '<section class="sec" id="anuncios"><div class="sec__head"><h2 id="p-offers-title"></h2><span class="muted" id="p-offers-filter"></span></div><div id="p-offers"></div></section>' +
      '<div class="pdp__split">' +
        '<section class="panel chart-panel" aria-labelledby="h-hist"><div class="panel__head"><h2 id="h-hist">Histórico de preço</h2><div class="seg" role="group" aria-label="Período" id="p-ranges">' +
          RANGES.map(([w, t]) => '<button type="button" class="seg__btn" data-range="' + w + '">' + t + '</button>').join('') + '</div></div>' +
          '<div class="chip-row" id="p-ckeys" role="group" aria-label="Nota do gráfico"></div>' +
          '<div class="chart-box" id="p-chart"></div><div id="p-cstats"></div></section>' +
        '<section class="panel pop-panel" aria-labelledby="h-pop"><div class="panel__head"><h2 id="h-pop">Pop report</h2><div class="seg" role="group" aria-label="Graduadora" id="p-pgraders">' +
          D.GRADERS.map(g => '<button type="button" class="seg__btn" data-pop="' + g + '">' + g + '</button>').join('') + '</div></div>' +
          '<div id="p-pop"></div></section>' +
      '</div>' +
      '<div class="pdp__split">' +
        '<section class="panel" aria-labelledby="h-alert"><h2 id="h-alert" class="panel__title">' + U.icons.bell + 'Avise-me quando baixar</h2>' +
          '<form id="p-alert" class="inline-form"><div class="field"><label for="a-key">Nota</label><select id="a-key" class="input">' + alertKeys + '</select></div>' +
          '<div class="field"><label for="a-price">Pagar até (R$)</label><input id="a-price" class="input" type="number" min="1" step="any" inputmode="numeric" required></div>' +
          '<button class="btn btn--ink" type="submit">Criar alerta</button></form><div id="p-alert-state" class="form-note"></div></section>' +
        '<section class="panel" aria-labelledby="h-cert"><h2 id="h-cert" class="panel__title">' + U.icons.seal + 'Conferir certificado</h2>' +
          '<form id="p-certform" class="inline-form"><div class="field field--grow"><label for="c-no">Número do certificado</label><input id="c-no" class="input num" type="text" autocomplete="off" placeholder="Ex.: ' + all[0].cert + '" required></div>' +
          '<button class="btn btn--ink" type="submit">Conferir</button></form><div id="p-certres" class="form-note" role="status"></div></section>' +
      '</div>' +
      (related.length ? '<section class="sec"><div class="sec__head"><h2>Relacionadas</h2></div><div class="tiles">' + related.map(c => U.cardTile(c)).join('') + '</div></section>' : '');

    const $ = id => main.querySelector('#' + id);

    function renderSel() {
      $('p-slab').innerHTML = U.slab(sel, { live: true });
      $('p-cert').innerHTML = '<span class="lbl">Certificado</span><span class="num" id="p-certno">' + sel.grader + ' ' + sel.cert + '</span><button type="button" class="btn btn--ghost btn--sm" data-copy="' + sel.cert + '">Copiar</button>';
      $('p-buy').innerHTML = buyPanel(card, sel);
      main.querySelectorAll('tr[data-row]').forEach(tr => tr.classList.toggle('is-sel', tr.dataset.row === sel.id));
    }
    function renderCells() {
      $('p-gcells').innerHTML = keys.map(k => {
        const min = k.list.length ? Math.min.apply(null, k.list.map(l => l.price)) : null;
        return '<button type="button" class="gcell' + (filterKey === k.key ? ' is-on' : '') + '" data-key="' + U.esc(k.key) + '" aria-pressed="' + (filterKey === k.key) + '">' +
          U.gchip(k) + '<span class="gcell__price num">' + (min ? U.brl(min) : '—') + '</span>' +
          '<span class="gcell__n">' + (k.list.length ? U.plural(k.list.length, 'anúncio', 'anúncios') : 'sem anúncio') + '</span></button>';
      }).join('');
    }
    function renderOffers() {
      const rows = filterKey ? all.filter(l => D.gradeKey(l) === filterKey) : all;
      $('p-offers-title').textContent = 'Anúncios (' + rows.length + ')';
      $('p-offers-filter').innerHTML = filterKey ? 'Mostrando só ' + U.esc(filterKey) + ' · <button type="button" class="link-btn" data-key="' + U.esc(filterKey) + '">ver todos</button>' : 'Ordenados do menor para o maior preço';
      $('p-offers').innerHTML = offersTable(card, rows, sel.id);
    }
    function renderChart() {
      const k = keys.find(x => x.key === chartKey) || keys[0];
      const pts = D.history(card, k.grader, k.grade, k.special).slice(-range);
      $('p-ckeys').innerHTML = keys.map(x => '<button type="button" class="chip' + (x.key === k.key ? ' is-on' : '') + '" data-ckey="' + U.esc(x.key) + '" aria-pressed="' + (x.key === k.key) + '">' + U.esc(x.key) + '</button>').join('');
      main.querySelectorAll('[data-range]').forEach(b => b.setAttribute('aria-pressed', String(+b.dataset.range === range)));
      const ch = U.lineChart(pts);
      $('p-chart').innerHTML = ch.svg + '<div class="ch-tip" hidden></div>';
      $('p-cstats').innerHTML = chartStats(pts);
      bindTip($('p-chart'), pts, ch);
    }
    function renderPop() {
      main.querySelectorAll('[data-pop]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.pop === popGrader)));
      $('p-pop').innerHTML = popPanel(card, popGrader, sel);
    }
    function renderAlert() {
      const a = S.alertOf(card.id);
      const k = keys.find(x => x.key === (a ? a.key : D.gradeKey(sel))) || keys[0];
      $('a-key').value = k.key;
      if (!$('a-price').value) {
        const min = k.list.length ? Math.min.apply(null, k.list.map(l => l.price)) : D.roundPrice(D.fairPrice(card, k.grader, k.grade, k.special, 'EN'));
        $('a-price').value = a ? a.price : D.roundPrice(min * 0.9);
      }
      if (!a) { $('p-alert-state').innerHTML = '<span class="muted">O alerta fica salvo neste navegador e aparece aqui quando houver anúncio no seu preço.</span>'; return; }
      const hit = all.filter(l => D.gradeKey(l) === a.key && l.price <= a.price).sort((x, y) => x.price - y.price)[0];
      $('p-alert-state').innerHTML = (hit
        ? '<span class="up"><b>Preço atingido:</b> ' + U.esc(a.key) + ' por ' + U.brl(hit.price) + ' na ' + U.esc(D.SELLER[hit.seller].name) + '.</span> <button type="button" class="link-btn" data-select="' + hit.id + '">Ver slab</button>'
        : '<span>Alerta ativo: <b>' + U.esc(a.key) + '</b> até <b class="num">' + U.brl(a.price) + '</b>. Nenhum anúncio nesse valor ainda.</span>') +
        ' <button type="button" class="link-btn" data-unalert>Remover alerta</button>';
    }

    function bindTip(box, pts, ch) {
      const svg = box.querySelector('svg'), tip = box.querySelector('.ch-tip'), hover = svg.querySelector('.ch-hover');
      const cross = hover.querySelector('line'), dot = hover.querySelector('circle');
      function show(clientX) {
        const r = svg.getBoundingClientRect();
        const x = (clientX - r.left) / r.width * ch.o.w;
        const i = Math.max(0, Math.min(pts.length - 1, Math.round((x - ch.o.l) / (ch.o.w - ch.o.l - ch.o.r) * (pts.length - 1))));
        const px = ch.X(i), py = ch.Y(pts[i].p);
        cross.setAttribute('x1', px); cross.setAttribute('x2', px);
        dot.setAttribute('cx', px); dot.setAttribute('cy', py);
        hover.setAttribute('visibility', 'visible');
        tip.innerHTML = '<span class="muted">Semana de ' + U.dateLong(pts[i].t) + '</span><b class="num">' + U.brl(pts[i].p) + '</b><span class="muted">' + U.plural(pts[i].n, 'venda', 'vendas') + '</span>';
        tip.hidden = false;
        const left = px / ch.o.w * r.width;
        tip.style.left = Math.min(Math.max(left, 70), r.width - 70) + 'px';
        tip.style.top = (py / ch.o.h * r.height) + 'px';
      }
      svg.addEventListener('pointermove', e => show(e.clientX));
      svg.addEventListener('pointerdown', e => show(e.clientX));
      svg.addEventListener('pointerleave', () => { hover.setAttribute('visibility', 'hidden'); tip.hidden = true; });
    }

    main.addEventListener('click', e => {
      const t = e.target;
      const selBtn = t.closest('[data-select]');
      if (selBtn) {
        sel = D.LISTING[selBtn.dataset.select];
        chartKey = D.gradeKey(sel); popGrader = sel.grader;
        renderSel(); renderChart(); renderPop();
        GD.replace('/carta/' + card.id + '?l=' + sel.id);
        $('p-slab').scrollIntoView({ behavior: 'smooth', block: 'center' });
        return;
      }
      const key = t.closest('[data-key]');
      if (key) {
        filterKey = filterKey === key.dataset.key ? null : key.dataset.key;
        if (filterKey) { chartKey = filterKey; renderChart(); }
        renderCells(); renderOffers();
        if (filterKey && key.classList.contains('gcell')) $('anuncios').scrollIntoView({ behavior: 'smooth', block: 'start' });
        return;
      }
      const ck = t.closest('[data-ckey]');
      if (ck) { chartKey = ck.dataset.ckey; renderChart(); return; }
      const rg = t.closest('[data-range]');
      if (rg) { range = +rg.dataset.range; renderChart(); return; }
      const pg = t.closest('[data-pop]');
      if (pg) { popGrader = pg.dataset.pop; renderPop(); return; }
      if (t.closest('[data-unalert]')) { S.removeAlert(card.id); $('a-price').value = ''; renderAlert(); U.toast('Alerta removido.'); return; }
      const cp = t.closest('[data-copy]');
      if (cp) {
        const text = cp.dataset.copy;
        const fallback = () => { const r = document.createRange(); r.selectNodeContents($('p-certno')); const s = window.getSelection(); s.removeAllRanges(); s.addRange(r); U.toast('Número selecionado. Use Ctrl+C para copiar.'); };
        try {
          navigator.clipboard.writeText(text).then(() => U.toast('Certificado ' + text + ' copiado.'), fallback);
        } catch (err) { fallback(); }
      }
    });
    main.addEventListener('submit', e => {
      e.preventDefault();
      if (e.target.id === 'p-alert') {
        const price = parseFloat($('a-price').value);
        if (!(price > 0)) { $('a-price').setAttribute('aria-invalid', 'true'); return; }
        $('a-price').removeAttribute('aria-invalid');
        S.setAlert(card.id, $('a-key').value, price);
        renderAlert();
        U.toast('Alerta criado para ' + $('a-key').value + ' até ' + U.brl(price) + '.');
      }
      if (e.target.id === 'p-certform') {
        const q = $('c-no').value.replace(/\s+/g, '').replace(/^(PSA|BGS|CGC|TAG)/i, '');
        const hit = D.findCert(q);
        const res = $('p-certres');
        if (!hit) {
          res.innerHTML = '<span class="down"><b>Não encontrado.</b></span> Nenhum anúncio da GradeDex usa esse certificado. Se a compra for fora da plataforma, confira o número no site da graduadora.';
        } else if (hit.card === card.id) {
          res.innerHTML = '<span class="up"><b>Confere.</b></span> ' + D.gradeKey(hit) + ' ' + D.gradeName(hit) + ', anunciado por ' + U.esc(D.SELLER[hit.seller].name) + ' por ' + U.brl(hit.price) + '. <button type="button" class="link-btn" data-select="' + hit.id + '">Ver slab</button>';
        } else {
          const c = D.CARD[hit.card];
          res.innerHTML = '<span class="down"><b>É de outra carta.</b></span> Esse certificado pertence a ' + U.esc(c.name) + ' (' + U.esc(U.setLabel(D.SET[c.set])) + ' ' + c.num + ') ' + D.gradeKey(hit) + '. <a href="#/carta/' + c.id + '?l=' + hit.id + '">Abrir anúncio</a>';
        }
      }
    });
    main.addEventListener('change', e => {
      if (e.target.id === 'a-key') {
        const k = keys.find(x => x.key === e.target.value);
        const min = k.list.length ? Math.min.apply(null, k.list.map(l => l.price)) : D.fairPrice(card, k.grader, k.grade, k.special, 'EN');
        $('a-price').value = D.roundPrice(min * 0.9);
      }
    });

    // Atualiza botões de carrinho/comparar quando o estado muda.
    GD.onStore = () => { renderSel(); renderOffers(); };

    renderSel(); renderCells(); renderOffers(); renderChart(); renderPop(); renderAlert();
  };
})(window.GD = window.GD || {});
