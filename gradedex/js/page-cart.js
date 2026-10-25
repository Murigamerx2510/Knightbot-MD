/* GradeDex — carrinho multi-loja e checkout simulado (nenhum pagamento é processado). */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui, S = GD.store;
  GD.pages = GD.pages || {};

  const FREE_FROM = 5000;      // frete grátis por loja acima deste subtotal
  const INSURE_RATE = 0.015;   // seguro sobre o valor declarado
  const PIX_OFF = 0.05;

  function shipOptions(seller, subtotal) {
    const free = subtotal >= FREE_FROM;
    return [
      { id: 'sedex', name: 'SEDEX', days: seller.ships + 2, price: free ? 0 : seller.ship },
      { id: 'pac', name: 'PAC', days: seller.ships + 6, price: free ? 0 : Math.round(seller.ship * 0.62) },
    ];
  }

  // Agrupa o carrinho por loja e calcula frete, seguro e totais.
  function summary() {
    const st = S.state;
    const groups = {};
    st.cart.forEach(id => {
      const l = D.LISTING[id];
      (groups[l.seller] = groups[l.seller] || []).push(l);
    });
    const out = Object.keys(groups).map(sid => {
      const seller = D.SELLER[sid];
      const items = groups[sid];
      const subtotal = items.reduce((s, l) => s + l.price, 0);
      const opts = shipOptions(seller, subtotal);
      const ship = opts.find(o => o.id === st.ship[sid]) || opts[0];
      return { seller, items, subtotal, opts, ship };
    });
    const items = out.reduce((s, g) => s + g.subtotal, 0);
    const shipping = out.reduce((s, g) => s + g.ship.price, 0);
    const insurance = st.insure ? Math.round(items * INSURE_RATE * 100) / 100 : 0;
    const total = items + shipping + insurance;
    return { groups: out, count: st.cart.length, items, shipping, insurance, total, pix: Math.round(total * (1 - PIX_OFF) * 100) / 100 };
  }

  function totalsBox(sm, cta) {
    return '<aside class="totals panel" aria-label="Resumo do pedido">' +
      '<h2>Resumo</h2>' +
      '<dl>' +
        '<div><dt>' + U.plural(sm.count, 'slab', 'slabs') + '</dt><dd class="num">' + U.brl(sm.items, true) + '</dd></div>' +
        '<div><dt>Frete (' + U.plural(sm.groups.length, 'loja', 'lojas') + ')</dt><dd class="num">' + (sm.shipping ? U.brl(sm.shipping, true) : 'Grátis') + '</dd></div>' +
        '<div><dt>Seguro de envio</dt><dd class="num">' + (sm.insurance ? U.brl(sm.insurance, true) : '—') + '</dd></div>' +
        '<div class="totals__sum"><dt>Total</dt><dd class="num">' + U.brl(sm.total, true) + '</dd></div>' +
      '</dl>' +
      '<p class="totals__pix">ou <b class="num">' + U.brl(sm.pix, true) + '</b> no PIX (5% de desconto)</p>' +
      '<label class="check"><input type="checkbox" id="insure"' + (S.state.insure ? ' checked' : '') + '><span>Seguro de envio (1,5% do valor declarado)</span></label>' +
      cta +
      '<p class="totals__safe">' + U.icons.shield + '<span>O pagamento fica retido até você confirmar o recebimento de cada slab.</span></p>' +
    '</aside>';
  }

  GD.pages.carrinho = function (main) {
    function render() {
      const sm = summary();
      if (!sm.count) {
        main.innerHTML = '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><span>Carrinho</span></nav>' +
          '<div class="empty"><h2>Seu carrinho está vazio</h2><p>Cada slab é único: quando você adiciona, ele fica reservado no carrinho até o pagamento.</p><a class="btn btn--volt" href="#/busca">Explorar slabs</a></div>';
        return;
      }
      main.innerHTML = '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><span>Carrinho</span></nav>' +
        '<h1 class="page-title">Carrinho</h1>' +
        '<div class="cart-layout">' +
          '<div class="cart-groups">' + sm.groups.map(g =>
            '<section class="cart-group panel" aria-label="Itens de ' + U.esc(g.seller.name) + '">' +
              '<header class="cart-group__head"><div><a class="cart-group__seller" href="#/loja/' + g.seller.id + '">' + U.esc(g.seller.name) + '</a> ' + U.verified(g.seller) + '<span class="muted"> · ' + U.esc(g.seller.city) + '/' + g.seller.uf + '</span></div><span class="muted">' + U.rating(g.seller) + '</span></header>' +
              '<ul class="cart-items">' + g.items.map(l => {
                const c = D.CARD[l.card];
                return '<li class="cart-item">' +
                  '<a class="cart-item__slab" href="#/carta/' + c.id + '?l=' + l.id + '">' + U.slab(l) + '</a>' +
                  '<div class="cart-item__info"><a class="cart-item__name" href="#/carta/' + c.id + '?l=' + l.id + '">' + U.esc(c.name) + '</a>' +
                    '<span class="muted">' + U.esc(U.setLabel(D.SET[c.set])) + ' · ' + c.num + '</span>' +
                    '<span class="cart-item__tags">' + U.gchip(l) + '<span class="tag">' + l.lang + '</span><span class="tag num">' + l.grader + ' ' + l.cert + '</span></span></div>' +
                  '<div class="cart-item__end"><span class="num cart-item__price">' + U.brl(l.price) + '</span><button type="button" class="link-btn" data-remove="' + l.id + '">Remover</button></div>' +
                '</li>';
              }).join('') + '</ul>' +
              '<fieldset class="ship"><legend>Envio desta loja' + (g.subtotal >= FREE_FROM ? ' · <span class="up">frete grátis acima de ' + U.brl(FREE_FROM) + '</span>' : '') + '</legend>' + g.opts.map(o =>
                '<label class="ship__opt"><input type="radio" name="ship-' + g.seller.id + '" value="' + o.id + '" data-ship="' + g.seller.id + '"' + (o.id === g.ship.id ? ' checked' : '') + '><span><b>' + o.name + '</b> · até ' + o.days + ' dias úteis</span><span class="num">' + (o.price ? U.brl(o.price) : 'Grátis') + '</span></label>').join('') +
              '</fieldset>' +
            '</section>').join('') +
          '</div>' +
          totalsBox(sm, '<a class="btn btn--volt btn--lg btn--block" href="#/checkout">Ir para o pagamento</a>') +
        '</div>';
    }
    main.addEventListener('click', e => {
      const rm = e.target.closest('[data-remove]');
      if (rm) { S.removeCart(rm.dataset.remove); U.toast('Slab removido do carrinho.'); }
    });
    main.addEventListener('change', e => {
      if (e.target.dataset.ship) S.setShip(e.target.dataset.ship, e.target.value);
      if (e.target.id === 'insure') S.setInsure(e.target.checked);
    });
    GD.onStore = render;
    render();
  };

  GD.pages.checkout = function (main) {
    const sm = summary();
    if (!sm.count) { GD.go('/carrinho', true); return; }
    main.innerHTML = '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><a href="#/carrinho">Carrinho</a><span aria-hidden="true">/</span><span>Pagamento</span></nav>' +
      '<h1 class="page-title">Pagamento</h1>' +
      '<p class="demo-note">' + U.icons.lock + '<span>Loja demonstrativa: nenhum dado sai deste navegador e nenhum pagamento é processado. Não use dados reais.</span></p>' +
      '<div class="cart-layout">' +
        '<form id="co" class="checkout" novalidate>' +
          '<section class="panel"><h2 class="panel__title">Entrega</h2><div class="form-grid">' +
            '<div class="field"><label for="co-name">Nome completo</label><input id="co-name" class="input" required autocomplete="name"></div>' +
            '<div class="field"><label for="co-cep">CEP</label><input id="co-cep" class="input num" required inputmode="numeric" maxlength="9" placeholder="00000-000" autocomplete="postal-code"></div>' +
            '<div class="field field--wide"><label for="co-street">Endereço</label><input id="co-street" class="input" required autocomplete="address-line1"></div>' +
            '<div class="field"><label for="co-no">Número</label><input id="co-no" class="input" required inputmode="numeric"></div>' +
            '<div class="field"><label for="co-extra">Complemento</label><input id="co-extra" class="input" autocomplete="address-line2"></div>' +
            '<div class="field"><label for="co-city">Cidade</label><input id="co-city" class="input" required autocomplete="address-level2"></div>' +
            '<div class="field"><label for="co-uf">UF</label><input id="co-uf" class="input" required maxlength="2" autocomplete="address-level1"></div>' +
          '</div></section>' +
          '<section class="panel"><h2 class="panel__title">Forma de pagamento</h2><div class="pay">' +
            '<label class="pay__opt"><input type="radio" name="pay" value="pix" checked><span><b>PIX</b><span class="muted">Aprovação imediata · 5% de desconto</span></span><span class="num" id="co-pix"></span></label>' +
            '<label class="pay__opt"><input type="radio" name="pay" value="card"><span><b>Cartão de crédito</b><span class="muted" id="co-inst"></span></span><span class="num" id="co-card"></span></label>' +
          '</div><p class="muted form-note">Na loja real, o pagamento seria feito em ambiente do intermediador. Aqui a etapa é apenas ilustrativa.</p></section>' +
          '<p class="form-error" id="co-err" role="alert" hidden></p>' +
          '<button type="submit" class="btn btn--volt btn--lg btn--block">Confirmar pedido (simulação)</button>' +
        '</form>' +
        '<div id="co-totals"></div>' +
      '</div>';

    const $ = id => main.querySelector('#' + id);
    main.addEventListener('input', e => {
      if (e.target.id === 'co-cep') {
        const d = e.target.value.replace(/\D/g, '').slice(0, 8);
        e.target.value = d.length > 5 ? d.slice(0, 5) + '-' + d.slice(5) : d;
      }
      if (e.target.id === 'co-uf') e.target.value = e.target.value.toUpperCase().replace(/[^A-Z]/g, '');
      if (e.target.getAttribute('aria-invalid')) e.target.removeAttribute('aria-invalid');
    });
    function paint() {
      const cur = summary();
      $('co-totals').innerHTML = totalsBox(cur, '');
      $('co-pix').textContent = U.brl(cur.pix, true);
      $('co-card').textContent = U.brl(cur.total, true);
      $('co-inst').textContent = 'Até 10x de ' + U.brl(cur.total / 10, true) + ' sem juros';
    }
    main.addEventListener('change', e => { if (e.target.id === 'insure') S.setInsure(e.target.checked); });
    GD.onStore = paint;
    paint();
    main.addEventListener('submit', e => {
      e.preventDefault();
      const req = Array.from(main.querySelectorAll('#co [required]'));
      const bad = req.filter(i => !i.value.trim() || (i.id === 'co-cep' && i.value.replace(/\D/g, '').length !== 8) || (i.id === 'co-uf' && i.value.length !== 2));
      req.forEach(i => i.toggleAttribute('aria-invalid', bad.includes(i)));
      if (bad.length) {
        $('co-err').textContent = 'Preencha ' + (bad.length === 1 ? 'o campo destacado' : 'os ' + bad.length + ' campos destacados') + ' para continuar. O CEP precisa de 8 dígitos e a UF de 2 letras.';
        $('co-err').hidden = false;
        bad[0].focus();
        return;
      }
      const pay = new FormData($('co')).get('pay');
      const sm = summary();
      const order = {
        no: 'GD-' + new Date().getFullYear() + '-' + String(D.hash(S.state.cart.join() + Date.now()) % 100000).padStart(5, '0'),
        total: pay === 'pix' ? sm.pix : sm.total, pay, groups: sm.groups.length, count: sm.count,
        city: $('co-city').value.trim(), uf: $('co-uf').value,
      };
      S.clearCart();
      GD.lastOrder = order;
      GD.go('/pedido');
    });
  };

  GD.pages.pedido = function (main) {
    const o = GD.lastOrder;
    if (!o) { GD.go('/', true); return; }
    const steps = [
      ['Pagamento confirmado', o.pay === 'pix' ? 'PIX aprovado na hora.' : 'Cartão aprovado.'],
      ['Lojas preparam o envio', 'Cada loja embala o slab em case rígido e envia com rastreio.'],
      ['Em trânsito', 'Você acompanha o rastreio de cada pacote.'],
      ['Você confirma o recebimento', 'Só então o valor é liberado para as lojas.'],
    ];
    main.innerHTML = '<div class="done panel">' +
      '<span class="done__icon">' + U.icons.check + '</span>' +
      '<p class="eyebrow">Pedido simulado</p>' +
      '<h1 class="page-title">Pedido ' + o.no + ' registrado</h1>' +
      '<p class="muted">' + U.plural(o.count, 'slab', 'slabs') + ' de ' + U.plural(o.groups, 'loja', 'lojas') + ' · total ' + U.brl(o.total, true) + ' · entrega em ' + U.esc(o.city) + '/' + U.esc(o.uf) + '</p>' +
      '<ol class="steps">' + steps.map((s, i) => '<li class="' + (i === 0 ? 'is-done' : '') + '"><b>' + s[0] + '</b><span>' + s[1] + '</span></li>').join('') + '</ol>' +
      '<a class="btn btn--volt" href="#/busca">Continuar comprando</a>' +
    '</div>';
  };
})(window.GD = window.GD || {});
