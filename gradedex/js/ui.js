/* GradeDex — formatação, ícones e componentes (slab, carta, tiles, gráficos). */
(function (GD) {
  'use strict';
  const D = GD.data;

  // ---------- Formatação ----------
  const fmt0 = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });
  const fmt2 = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const brl = (n, cents) => (cents ? fmt2 : fmt0).format(n);
  const int = n => Math.round(n).toLocaleString('pt-BR');
  const dec = (n, d = 1) => n.toLocaleString('pt-BR', { minimumFractionDigits: d, maximumFractionDigits: d });
  const pct = n => (n > 0.05 ? '+' : n < -0.05 ? '−' : '') + dec(Math.abs(n)) + '%';
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const MONTHS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  const dateShort = d => d.getDate() + ' ' + MONTHS[d.getMonth()];
  const dateLong = d => dateShort(d) + ' ' + d.getFullYear();
  const ago = days => days === 0 ? 'hoje' : days === 1 ? 'ontem' : 'há ' + days + ' dias';
  const agoMin = m => m < 60 ? 'há ' + m + ' min' : 'há ' + Math.floor(m / 60) + ' h';
  const plural = (n, one, many) => int(n) + ' ' + (n === 1 ? one : many);
  const setLabel = set => set.pt || set.name;
  const setFull = set => set.pt ? set.pt + ' (' + set.name + ')' : set.name;

  // ---------- Ícones ----------
  const I = d => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + d + '</svg>';
  const icons = {
    search: I('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
    heart: I('<path d="M12 20s-7-4.4-9.2-9A5 5 0 0 1 12 6a5 5 0 0 1 9.2 5c-2.2 4.6-9.2 9-9.2 9z"/>'),
    heartFill: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linejoin="round" d="M12 20s-7-4.4-9.2-9A5 5 0 0 1 12 6a5 5 0 0 1 9.2 5c-2.2 4.6-9.2 9-9.2 9z"/></svg>',
    cart: I('<path d="M3 4h2l2.4 11.2a1 1 0 0 0 1 .8h8.9a1 1 0 0 0 1-.8L20 8H6"/><circle cx="9" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/>'),
    compare: I('<rect x="3" y="4" width="7" height="16" rx="1.5"/><rect x="14" y="4" width="7" height="16" rx="1.5"/>'),
    sun: I('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'),
    moon: I('<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>'),
    check: I('<path d="m5 12 4.5 4.5L19 7"/>'),
    shield: I('<path d="M12 3 4 6v6c0 4.5 3.4 8 8 9 4.6-1 8-4.5 8-9V6z"/><path d="m9 12 2 2 4-4"/>'),
    truck: I('<path d="M3 6h11v10H3zM14 10h4l3 3v3h-7"/><circle cx="7" cy="18" r="1.6"/><circle cx="17" cy="18" r="1.6"/>'),
    chart: I('<path d="M4 19V5M4 19h16M8 15l4-4 3 3 5-6"/>'),
    seal: I('<path d="M12 2.5 14.4 4.6 17.6 4.3 18.3 7.4 21 9.2 19.8 12.2 21 15.2 18.3 17 17.6 20.1 14.4 19.8 12 21.9 9.6 19.8 6.4 20.1 5.7 17 3 15.2 4.2 12.2 3 9.2 5.7 7.4 6.4 4.3 9.6 4.6z"/><path d="m8.6 12.2 2.4 2.4 4.4-4.6"/>'),
    bell: I('<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 21h4"/>'),
    x: I('<path d="M6 6l12 12M18 6 6 18"/>'),
    filter: I('<path d="M4 5h16l-6 7.5V19l-4 1v-7.5z"/>'),
    grid: I('<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/>'),
    slabs: I('<rect x="5" y="2.5" width="14" height="19" rx="2"/><path d="M5 7.5h14"/>'),
    lock: I('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
    arrow: I('<path d="M5 12h14M13 6l6 6-6 6"/>'),
    pin: I('<path d="M12 21s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>'),
    star: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="m12 2.8 2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17.2l-5.6 3 1.1-6.3L2.9 9.5l6.3-.9z"/></svg>',
  };

  const GLYPHS = {
    fire: 'M12 2c1 4 5.5 6 5.5 11.5a5.5 5.5 0 0 1-11 0c0-2.4 1.2-4 2.4-5.2 0 2.2 1 3.4 2.2 3.4 0-3.2-1.2-6.3.9-9.7z',
    water: 'M12 2.5c4.2 5.2 7 8.8 7 12.2a7 7 0 0 1-14 0c0-3.4 2.8-7 7-12.2z',
    grass: 'M4.5 19.5C4.5 9.8 10.3 4 20 4c0 9.7-5.8 15.5-15.5 15.5z',
    lightning: 'M13.5 2 4.5 13.5h6L9.5 22l10-12.5h-6.2z',
    psychic: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zm10 3.6a3.6 3.6 0 1 0 0-7.2 3.6 3.6 0 0 0 0 7.2z',
    darkness: 'M15.5 2.5a9.5 9.5 0 1 0 6 16.6A8.3 8.3 0 0 1 15.5 2.5z',
    colorless: 'M12 2l2.7 7.3L22 12l-7.3 2.7L12 22l-2.7-7.3L2 12l7.3-2.7z',
    dragon: 'M12 2l5 7-5 13-5-13zm0 4.5L9.6 9.8 12 16l2.4-6.2z',
    metal: 'M12 2l8.7 5v10L12 22l-8.7-5V7zm0 5.5L7.5 10v4l4.5 2.5 4.5-2.5v-4z',
  };
  const glyph = type => '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill-rule="evenodd" d="' + GLYPHS[type] + '"/></svg>';

  // ---------- Carta (arte gerada) ----------
  function cardFace(card, opts) {
    opts = opts || {};
    const pal = card.look.palette || D.TYPES[card.type];
    const r = D.rng('art:' + card.id);
    const x = Math.round(20 + r() * 60), y = Math.round(15 + r() * 40);
    const cls = ['tcg',
      card.look.full ? 'tcg--full' : '',
      card.look.foil ? 'tcg--foil' : '',
      card.look.rim === 'silver' ? 'tcg--silver' : card.look.rim === 'gold' ? 'tcg--gold' : '',
      opts.live ? 'tcg--live' : ''].filter(Boolean).join(' ');
    return '<div class="' + cls + '" style="--a:' + pal.a + ';--b:' + pal.b + ';--x:' + x + '%;--y:' + y + '%" aria-hidden="true">' +
      '<div class="tcg__rim"><div class="tcg__in">' +
        '<div class="tcg__top"><span class="tcg__name">' + esc(card.name) + '</span><span class="tcg__hp"><small>HP</small>' + card.hp + '</span></div>' +
        '<div class="tcg__art">' + glyph(card.type) + '</div>' +
        '<div class="tcg__lines"><i></i><i></i><i></i></div>' +
        '<div class="tcg__num">' + esc(card.num) + '</div>' +
      '</div></div></div>';
  }

  // ---------- Slab ----------
  const PSA_SHORT = { 10: 'Gem Mt', 9: 'Mint', 8: 'NM-MT', 7: 'NM', 6: 'EX-MT' };
  const LABEL_RARITY = { 'Holo Rara': 'Holo', 'Comum': '', 'Shining': 'Holo', 'Gold Star': 'Gold Star Holo', 'Shiny': 'Shiny Holo', 'Secreta': 'Secret', 'Alt Art': 'Alternate Art', 'SIR': 'Special Illustration Rare', 'Promo': 'Promo' };
  const LABEL_LANG = { JP: 'Japanese', PT: 'Portuguese' };
  const labelTone = l => ({
    gold: (l.grader === 'BGS' && l.grade >= 9.5 && l.special !== 'bl') || ((l.grader === 'CGC' || l.grader === 'TAG') && l.special === 'pristine'),
    black: l.special === 'bl',
  });

  function slab(l, opts) {
    opts = opts || {};
    const card = D.CARD[l.card];
    const set = D.SET[card.set];
    const tone = labelTone(l);
    const labCls = 'lab lab--' + l.grader.toLowerCase() + (tone.gold ? ' is-gold' : '') + (tone.black ? ' is-black' : '');
    const variant = card.variant ? card.variant.replace('1ª Edição', '1st Edition') : '';
    const third = l.subs
      ? '<span class="lab__subs"><span>CEN ' + l.subs[0] + '</span><span>COR ' + l.subs[1] + '</span><span>EDG ' + l.subs[2] + '</span><span>SUR ' + l.subs[3] + '</span></span>'
      : '<span>' + esc([variant || LABEL_RARITY[card.rarity], LABEL_LANG[l.lang]].filter(Boolean).join(' · ')) + '</span>';
    const gtext = l.grader === 'PSA' && !l.special ? PSA_SHORT[l.grade] : D.gradeName(l);
    return '<div class="slab' + (opts.cls ? ' ' + opts.cls : '') + '" role="img" aria-label="' + esc(card.name + ', ' + set.name + ' ' + card.num + ', ' + D.gradeKey(l) + (l.cert ? ', certificado ' + l.cert : '')) + '"><div class="slab__case">' +
      '<div class="' + labCls + '">' +
        '<div class="lab__meta"><span>' + card.year + ' Pokémon ' + esc(set.name) + '</span><span><b>' + esc(card.name) + '</b> #' + esc(card.num.split('/')[0]) + '</span>' + third + '</div>' +
        '<div class="lab__grade"><span class="lab__gtext">' + esc(gtext) + '</span><span class="lab__gnum">' + D.fmtGrade(l.grade) + '</span></div>' +
        '<div class="lab__cert"><b>' + l.grader + '</b>' + esc(l.cert || '') + '</div>' +
      '</div>' +
      '<div class="slab__well">' + cardFace(card, opts) + '</div>' +
    '</div></div>';
  }

  function gchip(l) {
    const tone = labelTone(l);
    const extra = l.special === 'bl' ? ' BL' : l.special === 'pristine' && l.grader !== 'BGS' ? ' Pristine' : '';
    return '<span class="gchip gchip--' + l.grader.toLowerCase() + (tone.gold ? ' is-gold' : '') + (tone.black ? ' is-black' : '') + '">' + l.grader + ' <b>' + D.fmtGrade(l.grade) + '</b>' + extra + '</span>';
  }

  const swatch = card => {
    const pal = card.look.palette || D.TYPES[card.type];
    const rim = card.look.rim === 'silver' ? '#B9C0CA' : card.look.rim === 'gold' ? '#D7B55A' : '#F0CC4A';
    return '<span class="swatch" style="--a:' + pal.a + ';--b:' + pal.b + ';--rim-solid:' + rim + '" aria-hidden="true"></span>';
  };

  const rating = s => '<span class="rating">' + icons.star + '<span class="num">' + s.rating.toFixed(2).replace('.', ',') + '</span></span>';
  const verified = s => s.verified ? '<span class="tag tag--ok" title="Loja com identidade e endereço verificados">' + icons.seal + 'Verificada</span>' : '';

  // ---------- Tiles ----------
  // Melhor slab para a vitrine: maior nota; entre iguais, o mais barato.
  function showcase(list) {
    return list.slice().sort((a, b) => D.gradeScore(b) - D.gradeScore(a) || a.price - b.price)[0];
  }

  function favBtn(card) {
    const on = GD.store.isFav(card.id);
    return '<button class="fav-btn" type="button" data-fav="' + card.id + '" aria-pressed="' + on + '" aria-label="' + (on ? 'Remover dos favoritos: ' : 'Favoritar: ') + esc(card.name) + '">' + (on ? icons.heartFill : icons.heart) + '</button>';
  }

  const shortKey = l => l.grader + ' ' + D.fmtGrade(l.grade) + (l.special === 'bl' ? ' BL' : l.special === 'pristine' && l.grader !== 'BGS' ? ' Pristine' : '');

  // pick: 'top' (maior nota, padrão), 'cheapest' ou 'deal' (mais abaixo da referência).
  function cardTile(card, list, pick) {
    list = list && list.length ? list : D.listingsOf(card.id);
    const set = D.SET[card.set];
    const shown = pick === 'cheapest' ? list.slice().sort((a, b) => a.price - b.price)[0]
      : pick === 'deal' ? list.slice().sort((a, b) => a.price / a.ref - b.price / b.ref)[0]
      : showcase(list);
    const t = card.trend30;
    return '<article class="tile">' +
      '<a class="tile__link" href="#/carta/' + card.id + '">' +
        '<div class="tile__stage">' + slab(shown) + '</div>' +
        '<div class="tile__body">' +
          '<h3 class="tile__name">' + esc(card.name) + (card.variant ? ' <span class="muted">' + esc(card.variant) + '</span>' : '') + '</h3>' +
          '<p class="tile__set">' + esc(setLabel(set)) + ' · ' + esc(card.num) + '</p>' +
          '<div class="tile__row">' +
            '<span class="tile__pricebox"><span class="tile__from">' + shortKey(shown) + ' · ' + plural(list.length, 'anúncio', 'anúncios') + '</span><span class="tile__price">' + brl(shown.price) + '</span></span>' +
            '<span class="trend ' + (t >= 0 ? 'up' : 'down') + '" title="Variação da referência PSA ' + card.top + ' em 30 dias">' + pct(t) + '</span>' +
          '</div>' +
        '</div>' +
      '</a>' + favBtn(card) +
    '</article>';
  }

  function listingTile(l) {
    const card = D.CARD[l.card], set = D.SET[card.set], seller = D.SELLER[l.seller];
    const deal = l.price <= l.ref * 0.95;
    return '<article class="tile">' +
      '<a class="tile__link" href="#/carta/' + card.id + '?l=' + l.id + '">' +
        '<div class="tile__stage">' + slab(l) + '</div>' +
        '<div class="tile__body">' +
          '<h3 class="tile__name">' + esc(card.name) + (card.variant ? ' <span class="muted">' + esc(card.variant) + '</span>' : '') + '</h3>' +
          '<p class="tile__set">' + esc(setLabel(set)) + ' · ' + esc(card.num) + '</p>' +
          '<div class="tile__tags">' + gchip(l) + (l.lang !== 'EN' ? '<span class="tag">' + l.lang + '</span>' : '') + (deal ? '<span class="tag tag--ok">Abaixo da ref.</span>' : '') + '</div>' +
          '<div class="tile__row"><span class="tile__price">' + brl(l.price) + '</span><span class="tile__seller">' + esc(seller.name) + '</span></div>' +
        '</div>' +
      '</a>' + favBtn(card) +
    '</article>';
  }

  // ---------- Gráficos ----------
  function niceStep(range, ticks) {
    const raw = range / ticks;
    const mag = Math.pow(10, Math.floor(Math.log10(raw)));
    const f = raw / mag;
    return (f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10) * mag;
  }
  const compact = n => n >= 1e6 ? 'R$ ' + dec(n / 1e6, 1) + ' mi' : n >= 1e4 ? 'R$ ' + (n % 1000 ? dec(n / 1000, 1) : int(n / 1000)) + ' mil' : brl(n);

  // Linha com área; retorna o SVG e a geometria para o tooltip.
  function lineChart(pts, o) {
    o = Object.assign({ w: 640, h: 250, l: 70, r: 18, t: 16, b: 30 }, o);
    const ps = pts.map(p => p.p);
    let lo = Math.min.apply(null, ps), hi = Math.max.apply(null, ps);
    const pad = (hi - lo || hi * 0.1) * 0.12;
    lo = Math.max(0, lo - pad); hi = hi + pad;
    const step = niceStep(hi - lo, 4);
    lo = Math.floor(lo / step) * step; hi = Math.ceil(hi / step) * step;
    const X = i => o.l + (i / (pts.length - 1)) * (o.w - o.l - o.r);
    const Y = v => o.t + (1 - (v - lo) / (hi - lo)) * (o.h - o.t - o.b);
    let grid = '';
    for (let v = lo; v <= hi + step / 2; v += step) {
      grid += '<line x1="' + o.l + '" x2="' + (o.w - o.r) + '" y1="' + Y(v).toFixed(1) + '" y2="' + Y(v).toFixed(1) + '" class="ch-grid"/>' +
        '<text x="' + (o.l - 10) + '" y="' + (Y(v) + 4).toFixed(1) + '" text-anchor="end" class="ch-label">' + compact(v) + '</text>';
    }
    let xl = '', lastM = -1, lastX = -99;
    pts.forEach((p, i) => {
      const m = p.t.getMonth();
      if (m !== lastM && X(i) - lastX > 52 && X(i) < o.w - o.r - 20) {
        xl += '<text x="' + X(i).toFixed(1) + '" y="' + (o.h - 8) + '" text-anchor="middle" class="ch-label">' + MONTHS[m] + '</text>';
        lastX = X(i);
      }
      lastM = m;
    });
    const line = pts.map((p, i) => (i ? 'L' : 'M') + X(i).toFixed(1) + ' ' + Y(p.p).toFixed(1)).join('');
    const area = line + 'L' + X(pts.length - 1).toFixed(1) + ' ' + Y(lo) + 'L' + X(0).toFixed(1) + ' ' + Y(lo) + 'Z';
    const end = pts[pts.length - 1];
    const svg = '<svg class="chart" viewBox="0 0 ' + o.w + ' ' + o.h + '" role="img" aria-label="Histórico de preço: de ' + brl(pts[0].p) + ' em ' + dateLong(pts[0].t) + ' para ' + brl(end.p) + ' em ' + dateLong(end.t) + '">' +
      '<defs><linearGradient id="chfill" x1="0" x2="0" y1="0" y2="1"><stop offset="0" class="ch-stop-a"/><stop offset="1" class="ch-stop-b"/></linearGradient></defs>' +
      grid + xl +
      '<path d="' + area + '" fill="url(#chfill)"/>' +
      '<path d="' + line + '" class="ch-line"/>' +
      '<circle cx="' + X(pts.length - 1).toFixed(1) + '" cy="' + Y(end.p).toFixed(1) + '" r="5" class="ch-end"/>' +
      '<g class="ch-hover" visibility="hidden"><line class="ch-cross" y1="' + o.t + '" y2="' + (o.h - o.b) + '"/><circle r="4.5" class="ch-dot"/></g>' +
      '<rect class="ch-hit" x="' + o.l + '" y="' + o.t + '" width="' + (o.w - o.l - o.r) + '" height="' + (o.h - o.t - o.b) + '" fill="transparent"/>' +
    '</svg>';
    return { svg, X, Y, o };
  }

  function spark(pts, w, h) {
    w = w || 120; h = h || 36;
    const ps = pts.map(p => p.p);
    const lo = Math.min.apply(null, ps), hi = Math.max.apply(null, ps);
    const d = ps.map((p, i) => (i ? 'L' : 'M') + (i / (ps.length - 1) * (w - 4) + 2).toFixed(1) + ' ' + (h - 3 - (p - lo) / (hi - lo || 1) * (h - 6)).toFixed(1)).join('');
    const up = ps[ps.length - 1] >= ps[0];
    return '<svg class="spark ' + (up ? 'up' : 'down') + '" viewBox="0 0 ' + w + ' ' + h + '" width="' + w + '" height="' + h + '" aria-hidden="true"><path d="' + d + '" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/></svg>';
  }

  // ---------- Toast ----------
  let toastTimer = null;
  function toast(msg, link) {
    const el = document.getElementById('toast');
    if (!el) return;
    el.innerHTML = '<span>' + esc(msg) + '</span>' + (link ? '<a href="' + link.href + '">' + esc(link.text) + '</a>' : '');
    el.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { el.hidden = true; }, 3600);
  }

  GD.ui = {
    brl, int, dec, pct, esc, dateShort, dateLong, ago, agoMin, plural, setLabel, setFull, compact,
    icons, glyph, cardFace, slab, gchip, swatch, rating, verified, showcase, favBtn, cardTile, listingTile,
    lineChart, spark, toast, MONTHS,
  };
})(window.GD = window.GD || {});
