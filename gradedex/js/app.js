/* GradeDex — roteador, cabeçalho e ações globais (favoritar, carrinho, comparar). */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui, S = GD.store;
  const $ = sel => document.querySelector(sel);

  const ROUTES = [
    [/^\/$/, 'home'],
    [/^\/busca$/, 'busca'],
    [/^\/carta\/([\w-]+)$/, 'carta', ['id']],
    [/^\/loja\/([\w-]+)$/, 'loja', ['id']],
    [/^\/colecoes$/, 'colecoes'],
    [/^\/favoritos$/, 'favoritos'],
    [/^\/comparar$/, 'comparar'],
    [/^\/carrinho$/, 'carrinho'],
    [/^\/checkout$/, 'checkout'],
    [/^\/pedido$/, 'pedido'],
  ];
  let current = '/';

  function parse(path) {
    const i = path.indexOf('?');
    const p = i >= 0 ? path.slice(0, i) : path;
    const params = {};
    new URLSearchParams(i >= 0 ? path.slice(i + 1) : '').forEach((v, k) => { params[k] = v; });
    return { p: p || '/', params };
  }
  const fromHash = () => (location.hash.indexOf('#/') === 0 ? location.hash.slice(1) : null);

  function render(path) {
    current = path;
    const { p, params } = parse(path);
    let page = 'notfound';
    for (const [re, name, keys] of ROUTES) {
      const m = p.match(re);
      if (m) { page = name; (keys || []).forEach((k, i) => { params[k] = m[i + 1]; }); break; }
    }
    GD.onStore = null;
    closeSuggest();
    // Cada página recebe um <main> novo, sem ouvintes da página anterior.
    const old = document.getElementById('main');
    const main = old.cloneNode(false);
    old.replaceWith(main);
    GD.pages[page](main, params);
    $('#q').value = page === 'busca' ? (params.q || '') : '';
    document.querySelectorAll('.cats a').forEach(a => {
      if (a.getAttribute('href') === '#' + path) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
    window.scrollTo(0, 0);
  }

  GD.go = function (path, replace) {
    try { history[replace ? 'replaceState' : 'pushState']({ path }, '', '#' + path); } catch (e) { /* sem histórico */ }
    render(path);
  };
  GD.replace = function (path) {
    if (path === current) return;
    current = path;
    try { history.replaceState({ path }, '', '#' + path); } catch (e) { /* sem histórico */ }
  };
  window.addEventListener('popstate', e => render((e.state && e.state.path) || fromHash() || '/'));
  window.addEventListener('hashchange', () => { const h = fromHash(); if (h && h !== current) render(h); });

  // ---------- Contadores do cabeçalho ----------
  function counts() {
    const st = S.state;
    [['cart-count', st.cart.length], ['fav-count', st.favs.length], ['cmp-count', st.compare.length]].forEach(([id, n]) => {
      const el = document.getElementById(id);
      if (el) el.textContent = n ? String(n) : '';
    });
    $('#cart-link').setAttribute('aria-label', 'Carrinho' + (st.cart.length ? ', ' + U.plural(st.cart.length, 'slab', 'slabs') : ''));
  }
  S.on(() => { counts(); if (GD.onStore) GD.onStore(); });

  // ---------- Tema ----------
  const themeBtn = $('#theme-btn');
  function isDark() {
    const t = document.documentElement.getAttribute('data-theme');
    return t ? t === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function paintThemeBtn() {
    const dark = isDark();
    themeBtn.innerHTML = dark ? U.icons.sun : U.icons.moon;
    themeBtn.setAttribute('aria-label', dark ? 'Usar tema claro' : 'Usar tema escuro');
  }
  if (S.state.theme) document.documentElement.setAttribute('data-theme', S.state.theme);
  themeBtn.addEventListener('click', () => {
    const next = isDark() ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    S.setTheme(next);
    paintThemeBtn();
  });
  try {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', paintThemeBtn);
    new MutationObserver(paintThemeBtn).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  } catch (e) { /* navegadores antigos */ }

  // ---------- Busca com sugestões ----------
  const q = $('#q'), sug = $('#suggest');
  let active = -1;
  function closeSuggest() { sug.hidden = true; sug.innerHTML = ''; active = -1; q.setAttribute('aria-expanded', 'false'); }
  const certQuery = v => v.replace(/\s+/g, '').replace(/^(PSA|BGS|CGC|TAG)/i, '');
  q.addEventListener('input', () => {
    const v = q.value.trim();
    if (v.length < 2) { closeSuggest(); return; }
    const cert = D.findCert(certQuery(v));
    const cards = D.matchCards(v).slice(0, 6);
    let html = '';
    if (cert) {
      const c = D.CARD[cert.card];
      html += '<a href="#/carta/' + c.id + '?l=' + cert.id + '" role="option">' + U.swatch(c) + '<span><span class="suggest__name">Certificado ' + cert.grader + ' ' + cert.cert + '</span><span class="suggest__set">' + U.esc(c.name) + ' · ' + D.gradeKey(cert) + '</span></span><span class="suggest__price">' + U.brl(cert.price) + '</span></a>';
    }
    html += cards.map(c => {
      const min = D.listingsOf(c.id)[0].price;
      return '<a href="#/carta/' + c.id + '" role="option">' + U.swatch(c) + '<span><span class="suggest__name">' + U.esc(c.name) + (c.variant ? ' · ' + U.esc(c.variant) : '') + '</span><span class="suggest__set">' + U.esc(U.setLabel(D.SET[c.set])) + ' · ' + U.esc(c.num) + '</span></span><span class="suggest__price">' + U.brl(min) + '</span></a>';
    }).join('');
    html += cards.length || cert
      ? '<a class="suggest__all" href="#/busca?q=' + encodeURIComponent(v) + '">Ver todos os resultados para “' + U.esc(v) + '”</a>'
      : '<div class="suggest__empty">Nenhuma carta encontrada para “' + U.esc(v) + '”. Tente o nome do Pokémon, a coleção ou o número da carta.</div>';
    sug.innerHTML = html;
    sug.hidden = false;
    active = -1;
    q.setAttribute('aria-expanded', 'true');
  });
  q.addEventListener('keydown', e => {
    const items = Array.from(sug.querySelectorAll('a'));
    if (e.key === 'Escape') { closeSuggest(); return; }
    if (!items.length || (e.key !== 'ArrowDown' && e.key !== 'ArrowUp')) return;
    e.preventDefault();
    active = (active + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
    items.forEach((a, i) => a.classList.toggle('is-active', i === active));
  });
  q.addEventListener('blur', () => setTimeout(closeSuggest, 120));
  sug.addEventListener('mousedown', e => e.preventDefault());
  $('#search-form').addEventListener('submit', e => {
    e.preventDefault();
    const items = sug.querySelectorAll('a');
    if (active >= 0 && items[active]) { GD.go(items[active].getAttribute('href').slice(1)); return; }
    const v = q.value.trim();
    q.blur();
    GD.go(v ? '/busca?q=' + encodeURIComponent(v) : '/busca');
  });

  // ---------- Cliques globais ----------
  document.addEventListener('click', e => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const a = e.target.closest('a[href^="#/"]');
    if (a) { e.preventDefault(); GD.go(a.getAttribute('href').slice(1)); return; }

    const fav = e.target.closest('[data-fav]');
    if (fav) {
      const id = fav.dataset.fav, card = D.CARD[id];
      const on = S.toggleFav(id);
      document.querySelectorAll('[data-fav="' + id + '"]').forEach(b => {
        b.setAttribute('aria-pressed', String(on));
        b.setAttribute('aria-label', (on ? 'Remover dos favoritos: ' : 'Favoritar: ') + card.name);
        b.innerHTML = on ? U.icons.heartFill : U.icons.heart;
      });
      U.toast(on ? card.name + ' está nos favoritos.' : card.name + ' saiu dos favoritos.', on ? { href: '#/favoritos', text: 'Ver favoritos' } : null);
      return;
    }
    const cart = e.target.closest('[data-cart]');
    if (cart) {
      const added = S.toggleCart(cart.dataset.cart);
      U.toast(added ? 'Slab adicionado ao carrinho.' : 'Slab removido do carrinho.', added ? { href: '#/carrinho', text: 'Ver carrinho' } : null);
      return;
    }
    const cmp = e.target.closest('[data-compare]');
    if (cmp) {
      const r = S.toggleCompare(cmp.dataset.compare);
      if (r === null) U.toast('Você já está comparando 3 slabs.', { href: '#/comparar', text: 'Abrir comparação' });
      else U.toast(r ? 'Slab adicionado à comparação.' : 'Slab removido da comparação.', r ? { href: '#/comparar', text: 'Comparar agora' } : null);
    }
  });

  // ---------- Início ----------
  counts();
  paintThemeBtn();
  const start = fromHash() || '/';
  try { history.replaceState({ path: start }, '', '#' + start); } catch (e) { /* sem histórico */ }
  render(start);
})(window.GD = window.GD || {});
