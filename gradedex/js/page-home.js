/* GradeDex — página inicial. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui;
  GD.pages = GD.pages || {};

  const GRADER_INFO = {
    PSA: 'Escala de 1 a 10, sem 9.5. O PSA 10 Gem Mint é a principal referência de preço do hobby.',
    BGS: 'Quatro subnotas: centralização, cantos, bordas e superfície. Com as quatro em 10, o slab vira Black Label.',
    CGC: 'Meio ponto até o 9.5. O Pristine 10 exige centralização praticamente perfeita e ganha etiqueta dourada.',
    TAG: 'Graduação por imagem em alta resolução, com relatório digital de cada defeito encontrado.',
  };
  const TOP_LISTING = { PSA: { grader: 'PSA', grade: 10 }, BGS: { grader: 'BGS', grade: 10, special: 'bl' }, CGC: { grader: 'CGC', grade: 10, special: 'pristine' }, TAG: { grader: 'TAG', grade: 10 } };

  function uniqueByCard(listings, n) {
    const seen = {}, out = [];
    for (const l of listings) {
      if (seen[l.card]) continue;
      seen[l.card] = true;
      out.push(l);
      if (out.length === n) break;
    }
    return out;
  }

  function section(title, sub, link, inner) {
    return '<section class="sec">' +
      '<div class="sec__head"><h2>' + title + '</h2>' + (link ? '<a href="' + link.href + '">' + link.text + '</a>' : '') + (sub ? '<p>' + sub + '</p>' : '') + '</div>' +
      inner + '</section>';
  }

  function hero() {
    const card = D.CARD['umbreon-vmax-alt'];
    const listing = U.showcase(D.listingsOf(card.id).filter(l => l.grader === 'PSA' && l.lang === 'EN'));
    const h = D.history(card, 'PSA', 10, null);
    const verifiedCount = D.SELLERS.filter(s => s.verified).length;
    return '<section class="hero">' +
      '<div class="hero__copy">' +
        '<p class="eyebrow">Marketplace de cartas Pokémon graduadas</p>' +
        '<h1>Slabs com nota, certificado e preço que dá para conferir.</h1>' +
        '<p class="hero__lede">Compare anúncios PSA, BGS, CGC e TAG lado a lado, veja quanto cada nota valeu nas últimas 52 semanas e confira o certificado antes de pagar.</p>' +
        '<div class="hero__cta"><a class="btn btn--volt btn--lg" href="#/busca">Explorar ' + D.LISTINGS.length + ' slabs</a><a class="btn btn--ghost btn--lg" href="#/colecoes">Ver coleções</a></div>' +
        '<dl class="hero__stats">' +
          '<div><dt>Slabs à venda</dt><dd class="num">' + D.LISTINGS.length + '</dd></div>' +
          '<div><dt>Lojas verificadas</dt><dd class="num">' + verifiedCount + '</dd></div>' +
          '<div><dt>Cartas no catálogo</dt><dd class="num">' + D.CARDS.length + '</dd></div>' +
        '</dl>' +
      '</div>' +
      '<div class="hero__stage">' +
        '<a class="hero__slab" href="#/carta/' + card.id + '?l=' + listing.id + '" aria-label="Ver ' + U.esc(card.name) + ' ' + D.gradeKey(listing) + '">' + U.slab(listing, { live: true }) + '</a>' +
        '<a class="hero__quote" href="#/carta/' + card.id + '">' +
          '<span class="eyebrow">Referência PSA 10</span>' +
          '<span class="hero__qname">' + U.esc(card.name) + ' · ' + card.num + '</span>' +
          '<span class="hero__qprice"><span class="num">' + U.brl(card.market) + '</span> <span class="' + (card.trend30 >= 0 ? 'up' : 'down') + '">' + U.pct(card.trend30) + ' <small>30d</small></span></span>' +
          U.spark(h, 180, 44) +
          '<span class="muted hero__qfoot">' + U.dateShort(h[0].t) + ' — ' + U.dateShort(h[h.length - 1].t) + '</span>' +
        '</a>' +
      '</div>' +
    '</section>';
  }

  function ticker() {
    const items = D.recentSales().map(s => {
      const c = D.CARD[s.card];
      return '<a class="tick" href="#/carta/' + c.id + '">' + U.swatch(c) + '<span class="tick__name">' + U.esc(c.name) + '</span>' + U.gchip(s) + '<span class="num">' + U.brl(s.price) + '</span><span class="muted">' + U.agoMin(s.mins) + '</span></a>';
    }).join('');
    return '<section class="ticker" aria-label="Vendas recentes (exemplos)">' +
      '<span class="ticker__label"><i aria-hidden="true"></i>Vendas recentes</span>' +
      '<div class="ticker__track"><div class="ticker__row">' + items + '</div><div class="ticker__row" aria-hidden="true">' + items + '</div></div>' +
    '</section>';
  }

  function graders() {
    const cells = D.GRADERS.map(g => {
      const n = D.LISTINGS.filter(l => l.grader === g).length;
      return '<a class="grader" href="#/busca?grader=' + g + '">' +
        '<span class="grader__chips">' + U.gchip(TOP_LISTING[g]) + '</span>' +
        '<h3>' + g + '</h3>' +
        '<p>' + GRADER_INFO[g] + '</p>' +
        '<span class="grader__count">' + U.plural(n, 'slab à venda', 'slabs à venda') + ' ' + U.icons.arrow + '</span>' +
      '</a>';
    }).join('');
    return section('Quatro graduadoras, uma régua', 'Cada empresa usa sua própria escala. Aqui você vê o que cada nota significa e quanto ela vale, lado a lado.', null, '<div class="graders">' + cells + '</div>');
  }

  function setTile(set) {
    const cards = D.CARDS.filter(c => c.set === set.id);
    const listings = D.LISTINGS.filter(l => D.CARD[l.card].set === set.id);
    const min = Math.min.apply(null, listings.map(l => l.price));
    const fan = cards.slice(0, 3).map(c => U.swatch(c)).join('');
    return '<a class="set-tile" href="#/busca?set=' + set.id + '">' +
      '<span class="set-tile__fan">' + fan + '</span>' +
      '<span class="set-tile__name">' + U.esc(U.setLabel(set)) + '</span>' +
      '<span class="set-tile__meta">' + set.year + ' · ' + D.ERAS[set.era] + '</span>' +
      '<span class="set-tile__meta">' + U.plural(listings.length, 'slab', 'slabs') + ' · a partir de <span class="num">' + U.brl(min) + '</span></span>' +
    '</a>';
  }
  GD.setTile = setTile;

  function features() {
    const f = [
      ['seal', 'Certificado conferido', 'Todo anúncio mostra o número do certificado da graduadora. Você confere antes de pagar.'],
      ['chart', 'Histórico por nota', 'Gráfico de 52 semanas para cada graduadora e nota, com o preço de referência do mercado.'],
      ['lock', 'Pagamento protegido', 'O valor fica retido até você confirmar que o slab chegou como anunciado.'],
      ['truck', 'Envio com seguro', 'Frete calculado por loja, com seguro opcional sobre o valor declarado do slab.'],
    ];
    return '<section class="sec features" aria-label="Como a GradeDex funciona">' + f.map(x =>
      '<div class="feature">' + U.icons[x[0]] + '<h3>' + x[1] + '</h3><p>' + x[2] + '</p></div>').join('') + '</section>';
  }

  GD.pages.home = function (main) {
    const hot = D.CARDS.slice().sort((a, b) => b.trend30 - a.trend30).slice(0, 6);
    const deals = uniqueByCard(D.LISTINGS.slice().sort((a, b) => a.price / a.ref - b.price / b.ref), 6);
    const fresh = uniqueByCard(D.LISTINGS.slice().sort((a, b) => a.days - b.days || b.price - a.price), 6);
    const vintage = D.CARDS.filter(c => c.era === 'WotC').sort((a, b) => b.market - a.market).slice(0, 6);
    const recent = GD.store.state.recent.slice(0, 6).map(id => D.CARD[id]);
    const featuredSets = ['evs', 'pre', 'bs', 'mew', 'neo1', 'fst'].map(id => D.SET[id]);

    main.innerHTML = hero() + ticker() +
      section('Em alta nos últimos 30 dias', 'Maior valorização da referência PSA 10.', { href: '#/busca?sort=trend', text: 'Ver ranking' },
        '<div class="tiles">' + hot.map(c => U.cardTile(c)).join('') + '</div>') +
      (recent.length >= 3 ? section('Vistos recentemente', null, null, '<div class="tiles">' + recent.map(c => U.cardTile(c)).join('') + '</div>') : '') +
      section('Abaixo da referência', 'Slabs anunciados por menos que o preço de referência da mesma nota.', { href: '#/busca?view=slabs&sort=deal', text: 'Ver todas as ofertas' },
        '<div class="tiles">' + deals.map(U.listingTile).join('') + '</div>') +
      graders() +
      section('Chegaram esta semana', null, { href: '#/busca?view=slabs&sort=new', text: 'Ver novos anúncios' },
        '<div class="tiles">' + fresh.map(U.listingTile).join('') + '</div>') +
      section('Vintage WotC', 'Base Set, Jungle, Fossil e Neo: as cartas de 1999 a 2002.', { href: '#/busca?era=WotC', text: 'Ver todo o vintage' },
        '<div class="tiles">' + vintage.map(c => U.cardTile(c)).join('') + '</div>') +
      section('Coleções em destaque', null, { href: '#/colecoes', text: 'Todas as coleções' },
        '<div class="sets">' + featuredSets.map(setTile).join('') + '</div>') +
      features();
  };
})(window.GD = window.GD || {});
