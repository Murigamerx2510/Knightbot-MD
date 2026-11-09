/* GradeDex — busca e listagem com filtros facetados. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui;
  GD.pages = GD.pages || {};

  const PAGE = 24;
  const RARITIES = ['Holo Rara', 'Shining', 'Gold Star', 'Alt Art', 'SIR', 'Secreta', 'Shiny', 'Promo', 'Comum'];
  const SORTS = [
    ['rel', 'Relevância'], ['price', 'Menor preço'], ['price-desc', 'Maior preço'], ['grade', 'Maior nota'],
    ['new', 'Mais recentes'], ['trend', 'Maior valorização 30d'], ['deal', 'Mais abaixo da referência'],
  ];
  const list = v => (v ? String(v).split(',').filter(Boolean) : []);

  function parse(p) {
    return {
      q: p.q || '', grader: list(p.grader), min: parseFloat(p.min) || 0, special: p.special === '1',
      lang: list(p.lang), era: list(p.era), set: p.set || '', rarity: list(p.rarity),
      pmin: parseFloat(p.pmin) || 0, pmax: parseFloat(p.pmax) || 0, verified: p.verified === '1',
      sort: p.sort || 'rel', view: p.view === 'slabs' ? 'slabs' : 'cards',
    };
  }
  function toQuery(f) {
    const o = {};
    if (f.q) o.q = f.q;
    ['grader', 'lang', 'era', 'rarity'].forEach(k => { if (f[k].length) o[k] = f[k].join(','); });
    if (f.min) o.min = f.min;
    if (f.special) o.special = '1';
    if (f.set) o.set = f.set;
    if (f.pmin) o.pmin = f.pmin;
    if (f.pmax) o.pmax = f.pmax;
    if (f.verified) o.verified = '1';
    if (f.sort !== 'rel') o.sort = f.sort;
    if (f.view !== 'cards') o.view = f.view;
    const s = new URLSearchParams(o).toString();
    return '/busca' + (s ? '?' + s : '');
  }

  function filterListings(f, skip) {
    const ok = f.q ? new Set(D.matchCards(f.q).map(c => c.id)) : null;
    return D.LISTINGS.filter(l => {
      const c = D.CARD[l.card];
      if (ok && !ok.has(c.id)) return false;
      if (skip !== 'grader' && f.grader.length && !f.grader.includes(l.grader)) return false;
      if (f.min && l.grade < f.min) return false;
      if (f.special && !l.special) return false;
      if (skip !== 'lang' && f.lang.length && !f.lang.includes(l.lang)) return false;
      if (skip !== 'era' && f.era.length && !f.era.includes(c.era)) return false;
      if (skip !== 'set' && f.set && c.set !== f.set) return false;
      if (skip !== 'rarity' && f.rarity.length && !f.rarity.includes(c.rarity)) return false;
      if (f.pmin && l.price < f.pmin) return false;
      if (f.pmax && l.price > f.pmax) return false;
      if (f.verified && !D.SELLER[l.seller].verified) return false;
      return true;
    });
  }
  const facetCount = (f, key, value) => filterListings(f, key).filter(l => {
    const c = D.CARD[l.card];
    return key === 'grader' ? l.grader === value : key === 'lang' ? l.lang === value : key === 'era' ? c.era === value : key === 'rarity' ? c.rarity === value : true;
  }).length;

  function sortListings(arr, sort) {
    const by = {
      rel: (a, b) => D.gradeScore(b) - D.gradeScore(a) || a.price - b.price,
      price: (a, b) => a.price - b.price,
      'price-desc': (a, b) => b.price - a.price,
      grade: (a, b) => D.gradeScore(b) - D.gradeScore(a) || a.price - b.price,
      new: (a, b) => a.days - b.days,
      trend: (a, b) => D.CARD[b.card].trend30 - D.CARD[a.card].trend30,
      deal: (a, b) => a.price / a.ref - b.price / b.ref,
    };
    return arr.sort(by[sort] || by.rel);
  }
  function groupCards(listings, sort) {
    const map = {};
    listings.forEach(l => { (map[l.card] = map[l.card] || []).push(l); });
    const groups = Object.keys(map).map(id => {
      const ls = map[id].sort((a, b) => a.price - b.price);
      return { card: D.CARD[id], list: ls, min: ls[0].price, top: Math.max.apply(null, ls.map(D.gradeScore)), days: Math.min.apply(null, ls.map(l => l.days)), deal: Math.min.apply(null, ls.map(l => l.price / l.ref)) };
    });
    const by = {
      rel: (a, b) => b.list.length - a.list.length || b.card.market - a.card.market,
      price: (a, b) => a.min - b.min,
      'price-desc': (a, b) => b.min - a.min,
      grade: (a, b) => b.top - a.top || a.min - b.min,
      new: (a, b) => a.days - b.days,
      trend: (a, b) => b.card.trend30 - a.card.trend30,
      deal: (a, b) => a.deal - b.deal,
    };
    return groups.sort(by[sort] || by.rel);
  }

  function checks(name, options, f, key) {
    return options.map(([value, label]) => {
      const n = facetCount(f, key, value);
      const on = f[key].includes(value);
      return '<label class="check facet' + (n === 0 && !on ? ' is-empty' : '') + '"><input type="checkbox" name="' + name + '" value="' + U.esc(value) + '"' + (on ? ' checked' : '') + '><span>' + U.esc(label) + '</span><span class="facet__n num">' + n + '</span></label>';
    }).join('');
  }

  function filtersForm(f) {
    const grades = [[0, 'Qualquer'], [8, '8+'], [9, '9+'], [9.5, '9.5+'], [10, '10']];
    const sets = D.SETS.map(s => '<option value="' + s.id + '"' + (f.set === s.id ? ' selected' : '') + '>' + U.esc(U.setLabel(s)) + ' (' + s.year + ')</option>').join('');
    return '<form id="f-form" class="filters__form">' +
      '<fieldset><legend>Graduadora</legend>' + checks('grader', D.GRADERS.map(g => [g, g]), f, 'grader') + '</fieldset>' +
      '<fieldset><legend>Nota mínima</legend><div class="seg seg--wrap" role="radiogroup" aria-label="Nota mínima">' +
        grades.map(([v, t]) => '<label class="seg__opt"><input type="radio" name="min" value="' + v + '"' + (f.min === v ? ' checked' : '') + '><span>' + t + '</span></label>').join('') + '</div>' +
        '<label class="check"><input type="checkbox" name="special" value="1"' + (f.special ? ' checked' : '') + '><span>Só Black Label e Pristine</span></label></fieldset>' +
      '<fieldset><legend>Idioma</legend>' + checks('lang', Object.keys(D.LANGS).map(k => [k, D.LANGS[k]]), f, 'lang') + '</fieldset>' +
      '<fieldset><legend>Era</legend>' + checks('era', Object.keys(D.ERAS).map(k => [k, D.ERAS[k]]), f, 'era') + '</fieldset>' +
      '<fieldset><legend><label for="f-set">Coleção</label></legend><select id="f-set" name="set" class="input"><option value="">Todas as coleções</option>' + sets + '</select></fieldset>' +
      '<fieldset><legend>Raridade</legend>' + checks('rarity', RARITIES.map(r => [r, r]), f, 'rarity') + '</fieldset>' +
      '<fieldset><legend>Preço (R$)</legend><div class="range">' +
        '<label class="sr" for="f-pmin">Preço mínimo</label><input id="f-pmin" class="input" name="pmin" type="number" min="0" step="50" inputmode="numeric" placeholder="Mín." value="' + (f.pmin || '') + '">' +
        '<span aria-hidden="true">–</span>' +
        '<label class="sr" for="f-pmax">Preço máximo</label><input id="f-pmax" class="input" name="pmax" type="number" min="0" step="50" inputmode="numeric" placeholder="Máx." value="' + (f.pmax || '') + '">' +
      '</div></fieldset>' +
      '<fieldset><legend>Loja</legend><label class="check"><input type="checkbox" name="verified" value="1"' + (f.verified ? ' checked' : '') + '><span>Só lojas verificadas</span></label></fieldset>' +
    '</form>';
  }

  function readForm(form, f) {
    const fd = new FormData(form);
    return Object.assign({}, f, {
      grader: fd.getAll('grader'), lang: fd.getAll('lang'), era: fd.getAll('era'), rarity: fd.getAll('rarity'),
      min: parseFloat(fd.get('min')) || 0, special: fd.get('special') === '1', set: fd.get('set') || '',
      pmin: parseFloat(fd.get('pmin')) || 0, pmax: parseFloat(fd.get('pmax')) || 0, verified: fd.get('verified') === '1',
    });
  }

  function activeChips(f) {
    const chips = [];
    if (f.q) chips.push(['q', '', 'Busca: “' + f.q + '”']);
    f.grader.forEach(v => chips.push(['grader', v, v]));
    if (f.min) chips.push(['min', '', 'Nota ' + f.min + '+']);
    if (f.special) chips.push(['special', '', 'Black Label / Pristine']);
    f.lang.forEach(v => chips.push(['lang', v, D.LANGS[v]]));
    f.era.forEach(v => chips.push(['era', v, D.ERAS[v]]));
    if (f.set) chips.push(['set', '', U.setLabel(D.SET[f.set])]);
    f.rarity.forEach(v => chips.push(['rarity', v, v]));
    if (f.pmin) chips.push(['pmin', '', 'A partir de ' + U.brl(f.pmin)]);
    if (f.pmax) chips.push(['pmax', '', 'Até ' + U.brl(f.pmax)]);
    if (f.verified) chips.push(['verified', '', 'Lojas verificadas']);
    if (!chips.length) return '';
    return chips.map(([k, v, t]) => '<button type="button" class="chip is-on" data-unset="' + k + '" data-value="' + U.esc(v) + '">' + U.esc(t) + ' ' + U.icons.x + '<span class="sr">Remover filtro</span></button>').join('') +
      '<button type="button" class="chip" data-unset="all">Limpar tudo</button>';
  }

  function title(f) {
    if (f.q) return 'Resultados para “' + U.esc(f.q) + '”';
    if (f.set && !f.grader.length) return U.esc(U.setFull(D.SET[f.set]));
    if (f.grader.length === 1 && !f.set) return 'Slabs ' + f.grader[0];
    if (f.era.length === 1) return U.esc(D.ERAS[f.era[0]]);
    return 'Todos os slabs';
  }

  GD.pages.busca = function (main, params) {
    let f = parse(params);
    let shown = PAGE;
    const cert = f.q ? D.findCert(f.q) : null;
    if (cert) f.q = '';

    main.innerHTML =
      '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><span>Busca</span></nav>' +
      (cert ? '<div class="cert-hit panel">' + U.icons.seal + '<div><strong>Certificado ' + cert.grader + ' ' + cert.cert + ' encontrado.</strong> <span class="muted">Anunciado por ' + U.esc(D.SELLER[cert.seller].name) + '.</span></div><a class="btn btn--volt btn--sm" href="#/carta/' + cert.card + '?l=' + cert.id + '">Ver slab</a></div>' : '') +
      '<div class="search-layout">' +
        '<aside class="filters" id="filters" aria-label="Filtros"><div class="filters__head"><h2>Filtros</h2><button type="button" class="btn btn--ghost btn--sm" data-unset="all">Limpar</button><button type="button" class="btn btn--volt btn--sm filters-close" data-close-filters>Ver resultados</button></div><div id="f-body"></div></aside>' +
        '<section class="results" aria-live="polite">' +
          '<div class="results__head">' +
            '<div class="results__title"><h1 class="page-title" id="r-title"></h1><p class="muted" id="r-count"></p></div>' +
            '<div class="results__tools">' +
              '<button type="button" class="btn btn--ghost btn--sm filters-toggle" id="f-toggle" aria-expanded="false" aria-controls="filters">' + U.icons.filter + 'Filtros</button>' +
              '<div class="seg" role="group" aria-label="Exibir resultados como">' +
                '<button type="button" class="seg__btn" data-view="cards">' + U.icons.grid + 'Cartas</button>' +
                '<button type="button" class="seg__btn" data-view="slabs">' + U.icons.slabs + 'Slabs</button>' +
              '</div>' +
              '<label class="sr" for="r-sort">Ordenar por</label>' +
              '<select id="r-sort" class="input input--sm">' + SORTS.map(([v, t]) => '<option value="' + v + '">' + t + '</option>').join('') + '</select>' +
            '</div>' +
          '</div>' +
          '<div class="active" id="r-active"></div>' +
          '<div class="tiles" id="r-list"></div>' +
          '<div class="more" id="r-more"></div>' +
        '</section>' +
      '</div>';

    const $ = id => main.querySelector('#' + id);

    function render(keepForm) {
      if (!keepForm) $('f-body').innerHTML = filtersForm(f);
      else refreshCounts();
      $('r-title').innerHTML = title(f);
      $('r-sort').value = f.sort;
      main.querySelectorAll('[data-view]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.view === f.view)));
      $('r-active').innerHTML = activeChips(f);

      const ls = sortListings(filterListings(f), f.sort);
      let html = '', total;
      if (f.view === 'slabs') {
        total = ls.length;
        html = ls.slice(0, shown).map(U.listingTile).join('');
        $('r-count').textContent = U.plural(total, 'slab encontrado', 'slabs encontrados');
      } else {
        const groups = groupCards(ls, f.sort);
        total = groups.length;
        const pick = f.sort === 'price' || f.sort === 'price-desc' ? 'cheapest' : f.sort === 'deal' ? 'deal' : 'top';
        html = groups.slice(0, shown).map(g => U.cardTile(g.card, g.list, pick)).join('');
        $('r-count').textContent = U.plural(total, 'carta', 'cartas') + ' · ' + U.plural(ls.length, 'slab', 'slabs');
      }
      $('r-list').innerHTML = total ? html : '';
      $('r-list').hidden = !total;
      $('r-more').innerHTML = !total
        ? '<div class="empty"><h2>Nenhum slab com esses filtros</h2><p>Tente remover um filtro ou ampliar a faixa de preço. Você também pode buscar pelo número do certificado.</p><button type="button" class="btn btn--volt" data-unset="all">Limpar filtros</button></div>'
        : total > shown ? '<button type="button" class="btn btn--ghost" id="r-next">Mostrar mais ' + Math.min(PAGE, total - shown) + ' de ' + (total - shown) + ' restantes</button>' : '';
      GD.replace(toQuery(f));
    }

    function refreshCounts() {
      main.querySelectorAll('.facet').forEach(el => {
        const input = el.querySelector('input');
        const n = facetCount(f, input.name, input.value);
        el.querySelector('.facet__n').textContent = n;
        el.classList.toggle('is-empty', n === 0 && !input.checked);
      });
    }

    main.addEventListener('change', e => {
      const t = e.target;
      if (t.id === 'r-sort') { f.sort = t.value; shown = PAGE; render(true); return; }
      if (t.closest('#f-form')) { f = readForm($('f-form'), f); shown = PAGE; render(true); }
    });
    main.addEventListener('click', e => {
      const view = e.target.closest('[data-view]');
      if (view) { f.view = view.dataset.view; shown = PAGE; render(true); return; }
      const unset = e.target.closest('[data-unset]');
      if (unset) {
        const k = unset.dataset.unset, v = unset.dataset.value;
        if (k === 'all') f = parse({ sort: f.sort, view: f.view });
        else if (Array.isArray(f[k])) f[k] = f[k].filter(x => x !== v);
        else f[k] = typeof f[k] === 'boolean' ? false : typeof f[k] === 'number' ? 0 : '';
        if (k === 'q') { const q = document.getElementById('q'); if (q) q.value = ''; }
        shown = PAGE;
        render(false);
        return;
      }
      if (e.target.closest('#r-next')) { shown += PAGE; render(true); return; }
      const tog = e.target.closest('#f-toggle, [data-close-filters]');
      if (tog) {
        const open = $('filters').classList.toggle('is-open', tog.id === 'f-toggle' ? undefined : false);
        $('f-toggle').setAttribute('aria-expanded', String(open));
      }
    });

    render(false);
  };
})(window.GD = window.GD || {});
