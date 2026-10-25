/* GradeDex — loja, coleções, favoritos, comparação e página não encontrada. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui, S = GD.store;
  GD.pages = GD.pages || {};
  const crumbs = label => '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><span>' + label + '</span></nav>';

  GD.pages.loja = function (main, params) {
    const s = D.SELLER[params.id];
    if (!s) { GD.pages.notfound(main); return; }
    const ls = D.LISTINGS.filter(l => l.seller === s.id).sort((a, b) => b.price - a.price);
    const initials = s.name.split(/\s+/).filter(w => /^[A-Za-zÀ-ú]/.test(w)).slice(0, 2).map(w => w[0]).join('');
    const graders = D.GRADERS.map(g => [g, ls.filter(l => l.grader === g).length]).filter(x => x[1]);
    main.innerHTML = crumbs(U.esc(s.name)) +
      '<section class="seller panel">' +
        '<div class="seller__id"><span class="seller__avatar" aria-hidden="true">' + U.esc(initials) + '</span>' +
          '<div><h1 class="page-title">' + U.esc(s.name) + '</h1><p class="muted">' + U.icons.pin + U.esc(s.city) + '/' + s.uf + ' · na GradeDex desde ' + s.since + '</p></div>' + U.verified(s) + '</div>' +
        '<dl class="seller__stats">' +
          '<div><dt>Avaliação</dt><dd>' + U.rating(s) + ' <small class="muted">' + U.int(s.reviews) + ' avaliações</small></dd></div>' +
          '<div><dt>Vendas concluídas</dt><dd class="num">' + U.int(s.sales) + '</dd></div>' +
          '<div><dt>Prazo de postagem</dt><dd>até ' + U.plural(s.ships, 'dia útil', 'dias úteis') + '</dd></div>' +
          '<div><dt>Slabs à venda</dt><dd class="num">' + ls.length + '</dd></div>' +
        '</dl>' +
        '<p class="seller__policy">' + (s.focus === 'vintage' ? 'Especialista em vintage WotC e 1ª Edição. ' : '') + 'Envia cada slab em case rígido com plástico bolha e lacre numerado. ' + (s.verified ? 'Identidade, CNPJ e endereço conferidos pela GradeDex.' : 'Loja ainda em verificação: o pagamento protegido vale normalmente.') + '</p>' +
        '<p class="seller__mix">' + graders.map(([g, n]) => '<span class="tag">' + g + ' · ' + n + '</span>').join('') + '</p>' +
      '</section>' +
      '<section class="sec"><div class="sec__head"><h2>Slabs à venda</h2><p>Do maior para o menor preço.</p></div><div class="tiles">' + ls.map(U.listingTile).join('') + '</div></section>';
  };

  GD.pages.colecoes = function (main) {
    const eras = Object.keys(D.ERAS);
    main.innerHTML = crumbs('Coleções') +
      '<h1 class="page-title">Coleções</h1>' +
      '<p class="lede muted">' + D.SETS.length + ' coleções com slabs à venda, do Base Set de 1999 a Evoluções Prismáticas.</p>' +
      eras.map(era => {
        const sets = D.SETS.filter(s => s.era === era);
        if (!sets.length) return '';
        return '<section class="sec"><div class="sec__head"><h2>' + D.ERAS[era] + '</h2><a href="#/busca?era=' + era + '">Ver slabs desta era</a></div><div class="sets">' + sets.map(GD.setTile).join('') + '</div></section>';
      }).join('');
  };

  GD.pages.favoritos = function (main) {
    function render() {
      const favs = S.state.favs.map(id => D.CARD[id]);
      const alerts = Object.keys(S.state.alerts).map(id => ({ card: D.CARD[id], a: S.state.alerts[id] }));
      main.innerHTML = crumbs('Favoritos') + '<h1 class="page-title">Favoritos e alertas</h1>' +
        '<section class="sec"><div class="sec__head"><h2>Alertas de preço</h2><p>Salvos neste navegador.</p></div>' +
        (alerts.length ? '<ul class="alerts">' + alerts.map(({ card, a }) => {
          const hit = D.listingsOf(card.id).filter(l => D.gradeKey(l) === a.key && l.price <= a.price).sort((x, y) => x.price - y.price)[0];
          return '<li class="alert-row panel">' + U.swatch(card) +
            '<div><a href="#/carta/' + card.id + '"><b>' + U.esc(card.name) + '</b></a> <span class="muted">' + U.esc(U.setLabel(D.SET[card.set])) + ' · ' + card.num + '</span><br>' + U.esc(a.key) + ' até <span class="num">' + U.brl(a.price) + '</span></div>' +
            (hit ? '<a class="tag tag--ok" href="#/carta/' + card.id + '?l=' + hit.id + '">Atingido: ' + U.brl(hit.price) + '</a>' : '<span class="tag">Aguardando</span>') +
          '</li>';
        }).join('') + '</ul>' : '<div class="empty"><p>Nenhum alerta ainda. Na página de qualquer carta, use “Avise-me quando baixar”.</p></div>') +
        '</section>' +
        '<section class="sec"><div class="sec__head"><h2>Cartas favoritas</h2></div>' +
        (favs.length ? '<div class="tiles">' + favs.map(c => U.cardTile(c)).join('') + '</div>'
          : '<div class="empty"><h2>Nenhuma favorita ainda</h2><p>Toque no coração de qualquer carta para acompanhar o preço por aqui.</p><a class="btn btn--volt" href="#/busca">Explorar slabs</a></div>') +
        '</section>';
    }
    GD.onStore = render;
    render();
  };

  GD.pages.comparar = function (main) {
    function render() {
      const ls = S.state.compare.map(id => D.LISTING[id]);
      if (!ls.length) {
        main.innerHTML = crumbs('Comparar') + '<div class="empty"><h2>Compare até 3 slabs</h2><p>Na página de uma carta, toque em “Comparar” no slab que quiser. Dá para comparar notas, graduadoras e lojas diferentes.</p><a class="btn btn--volt" href="#/busca?view=slabs">Ver slabs</a></div>';
        return;
      }
      const best = Math.min.apply(null, ls.map(l => l.price));
      const top = Math.max.apply(null, ls.map(D.gradeScore));
      const row = (label, fn) => '<tr><th scope="row">' + label + '</th>' + ls.map(l => '<td>' + fn(l) + '</td>').join('') + '</tr>';
      const popAt = l => { const p = D.popReport(D.CARD[l.card])[l.grader]; const r = p.rows.find(x => x.grade === l.grade); return r ? r.count : 0; };
      main.innerHTML = crumbs('Comparar') + '<h1 class="page-title">Comparar slabs</h1>' +
        '<div class="table-wrap"><table class="cmp">' +
          '<thead><tr><td></td>' + ls.map(l => '<th scope="col"><a href="#/carta/' + l.card + '?l=' + l.id + '" class="cmp__slab">' + U.slab(l) + '</a></th>').join('') + '</tr></thead><tbody>' +
          row('Carta', l => { const c = D.CARD[l.card]; return '<b>' + U.esc(c.name) + '</b><br><span class="muted">' + U.esc(U.setLabel(D.SET[c.set])) + ' · ' + c.num + '</span>'; }) +
          row('Nota', l => U.gchip(l) + (D.gradeScore(l) === top && ls.length > 1 ? ' <span class="tag tag--ok">Maior nota</span>' : '') + '<br><span class="muted">' + D.gradeName(l) + '</span>') +
          row('Subnotas', l => l.subs ? '<span class="num">' + l.subs.join(' · ') + '</span>' : '<span class="muted">—</span>') +
          row('Preço', l => '<b class="num">' + U.brl(l.price) + '</b>' + (l.price === best && ls.length > 1 ? ' <span class="tag tag--ok">Menor preço</span>' : '')) +
          row('Referência da nota', l => '<span class="num">' + U.brl(l.ref) + '</span> <span class="muted">(' + U.pct((l.price / l.ref - 1) * 100) + ')</span>') +
          row('População nessa nota', l => '<span class="num">' + U.int(popAt(l)) + '</span>') +
          row('Idioma', l => D.LANGS[l.lang]) +
          row('Certificado', l => '<span class="num">' + l.grader + ' ' + l.cert + '</span>') +
          row('Loja', l => { const s = D.SELLER[l.seller]; return '<a href="#/loja/' + s.id + '">' + U.esc(s.name) + '</a> ' + U.verified(s) + '<br>' + U.rating(s) + ' <span class="muted">' + U.esc(s.city) + '/' + s.uf + '</span>'; }) +
          row('', l => '<div class="cmp__act"><button type="button" class="btn btn--sm ' + (S.inCart(l.id) ? 'is-on' : 'btn--volt') + '" data-cart="' + l.id + '">' + (S.inCart(l.id) ? 'No carrinho' : 'Adicionar') + '</button><button type="button" class="btn btn--ghost btn--sm" data-compare="' + l.id + '">Remover</button></div>') +
        '</tbody></table></div>';
    }
    GD.onStore = render;
    render();
  };

  GD.pages.notfound = function (main) {
    main.innerHTML = '<div class="empty" style="margin-top:40px"><h2>Página não encontrada</h2><p>O link pode estar incompleto ou o anúncio foi vendido.</p><a class="btn btn--volt" href="#/">Voltar ao início</a></div>';
  };
})(window.GD = window.GD || {});
