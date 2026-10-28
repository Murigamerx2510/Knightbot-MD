/* GradeDex — vender para a loja: venda instantânea e consignação, com proposta pelo WhatsApp. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui, M = GD.market;
  const esc = U.esc;
  GD.pages = GD.pages || {};

  const MODES = {
    oferta: { title: 'Venda instantânea', label: 'venda instantânea' },
    consignacao: { title: 'Consignação', label: 'consignação' },
  };
  const pctTxt = r => U.dec(r * 100, 0) + '%';
  const crumbs = trail => '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a>' +
    trail.map(t => '<span aria-hidden="true">/</span>' + (t[1] ? '<a href="' + t[1] + '">' + t[0] + '</a>' : '<span>' + t[0] + '</span>')).join('') + '</nav>';

  GD.pages.vender = function (main) {
    const s = M.settings;
    const ex = D.CARD['umbreon-vmax-alt'];
    const exRef = D.fairPrice(ex, 'PSA', 10, null, 'EN');
    const cq = M.consignQuote(exRef);
    main.innerHTML = crumbs([['Vender']]) +
      '<section class="sell-hero">' +
        '<p class="eyebrow">Venda para a ' + esc(D.HOUSE.name) + '</p>' +
        '<h1 class="page-title">Venda seus slabs sem precisar anunciar</h1>' +
        '<p class="lede">Escolha entre dinheiro rápido na venda instantânea ou mais valor deixando a loja vender por você. A proposta vai pelo WhatsApp da loja, e você só envia o slab depois do aceite.</p>' +
      '</section>' +
      '<div class="sell-options">' +
        '<article class="sell-opt panel">' +
          '<p class="eyebrow">Dinheiro rápido</p><h2>Venda instantânea</h2>' +
          '<p class="sell-opt__rate"><b class="num">' + pctTxt(s.instantRate) + '</b> da referência da nota</p>' +
          '<ul class="ticks"><li>Oferta na hora, calculada pelo preço de referência da graduadora e nota</li><li>PIX em até 1 dia útil depois que o slab chega e o certificado confere</li><li>Sem esperar comprador</li></ul>' +
          '<p class="sell-opt__ex">Exemplo: ' + esc(ex.name) + ' PSA 10 → você recebe <b class="num">' + U.brl(M.instantOffer(exRef)) + '</b></p>' +
          '<a class="btn btn--volt btn--lg" href="#/vender/oferta">Pedir oferta</a>' +
        '</article>' +
        '<article class="sell-opt panel">' +
          '<p class="eyebrow">Mais valor</p><h2>Consignação</h2>' +
          '<p class="sell-opt__rate"><b class="num">' + pctTxt(s.consignFee) + '</b> de comissão, só quando vender</p>' +
          '<ul class="ticks"><li>A loja fotografa, anuncia e cuida do envio ao comprador</li><li>Preço sugerido pela referência; você aprova o valor</li><li>PIX quando o comprador confirma o recebimento</li></ul>' +
          '<p class="sell-opt__ex">Exemplo: ' + esc(ex.name) + ' PSA 10 anunciado a ' + U.brl(cq.price) + ' → você recebe ≈ <b class="num">' + U.brl(cq.net) + '</b></p>' +
          '<a class="btn btn--ink btn--lg" href="#/vender/consignacao">Consignar slab</a>' +
        '</article>' +
      '</div>' +
      (M.canManage ? '<div class="owner-strip panel"><div><b>Você administra esta loja.</b> Para anunciar slabs do seu estoque, use o painel.</div><a class="btn btn--volt" href="#/painel/novo">Anunciar slab</a></div>' : '') +
      '<section class="sec"><div class="sec__head"><h2>Como funciona</h2></div><ol class="flow">' +
        '<li><b>Escolha a carta e a nota</b><span>O site calcula a oferta ou o preço sugerido na hora.</span></li>' +
        '<li><b>Mande a proposta</b><span>Um toque abre o WhatsApp da loja com tudo preenchido.</span></li>' +
        '<li><b>Envie o slab</b><span>Depois do aceite, com rastreio e seguro.</span></li>' +
        '<li><b>Receba por PIX</b><span>Na hora da conferência (instantânea) ou quando vender (consignação).</span></li>' +
      '</ol></section>';
  };

  GD.pages.venderForm = function (main, params) {
    const mode = params.mode === 'consignacao' ? 'consignacao' : 'oferta';
    const info = MODES[mode];
    main.innerHTML = crumbs([['Vender', '#/vender'], [info.title]]) +
      '<h1 class="page-title">' + info.title + '</h1>' +
      '<div class="sell-layout">' +
        '<form id="sf" class="sell-form" novalidate>' +
          '<section class="panel"><h2 class="panel__title">Carta</h2><div id="sf-card"></div></section>' +
          '<section class="panel"><h2 class="panel__title">Slab</h2><div id="sf-slab"></div></section>' +
          '<section class="panel"><h2 class="panel__title">Seus dados</h2><div class="form-grid">' +
            '<div class="field"><label for="sf-name">Seu nome</label><input id="sf-name" class="input" autocomplete="name"></div>' +
            '<div class="field"><label for="sf-city">Cidade/UF</label><input id="sf-city" class="input" placeholder="Ex.: Campinas/SP"></div>' +
            '<div class="field field--wide"><label for="sf-notes">Observações (opcional)</label><textarea id="sf-notes" class="input textarea" rows="3" placeholder="Arranhões no case, etiqueta antiga, tem a nota fiscal…"></textarea></div>' +
          '</div></section>' +
        '</form>' +
        '<aside class="quote panel" id="sf-quote" aria-live="polite"></aside>' +
      '</div>';

    const $ = id => main.querySelector('#' + id);
    let card = null, slab = null;
    const picker = GD.forms.cardPicker($('sf-card'), { id: 'sf-cardq', initial: params.card, onChange: c => { card = c; paint(); } });
    card = picker.get();
    slab = GD.forms.slabFields($('sf-slab'), { prefix: 'sf', onChange: paint });

    function proposal(g, ref) {
      const set = D.SET[card.set];
      const lines = [
        'Olá, ' + D.HOUSE.name + '! Quero vender um slab (' + info.label + ').',
        '• Carta: ' + card.name + (card.variant ? ' ' + card.variant : '') + ' — ' + set.name + ' ' + card.num,
        '• Slab: ' + D.gradeKey(g) + ' (' + D.gradeName(g) + ') · ' + D.LANGS[g.lang] + ' · certificado ' + (g.cert || '—'),
      ];
      if (g.subs) lines.push('• Subnotas: ' + g.subs.join(' / ') + ' (centralização, cantos, bordas, superfície)');
      if (mode === 'oferta') lines.push('• Oferta do site: ' + U.brl(M.instantOffer(ref)) + ' (' + pctTxt(M.settings.instantRate) + ' da referência de ' + U.brl(D.roundPrice(ref)) + ')');
      else {
        const q = M.consignQuote(ref);
        lines.push('• Preço sugerido: ' + U.brl(q.price) + ' · comissão ' + pctTxt(M.settings.consignFee) + ' (' + U.brl(q.fee) + ') · recebo ≈ ' + U.brl(q.net));
      }
      const notes = $('sf-notes').value.trim(), name = $('sf-name').value.trim(), city = $('sf-city').value.trim();
      if (notes) lines.push('• Observações: ' + notes);
      if (name || city) lines.push('• ' + [name, city].filter(Boolean).join(' · '));
      return lines.join('\n');
    }

    function paint() {
      const q = $('sf-quote');
      if (!card) {
        q.innerHTML = '<h2 class="panel__title">' + (mode === 'oferta' ? 'Sua oferta' : 'Sua estimativa') + '</h2><p class="muted">Escolha a carta para ver ' + (mode === 'oferta' ? 'quanto a loja paga' : 'o preço sugerido e quanto você recebe') + '.</p>';
        return;
      }
      const g = slab.get();
      const ref = M.reference(card, g);
      const key = D.gradeKey(g);
      const same = D.listingsOf(card.id).filter(l => D.gradeKey(l) === key && l.lang === g.lang);
      const preview = Object.assign({ id: '', card: card.id, price: 0, ref: 0, seller: null }, g);
      let money;
      if (mode === 'oferta') {
        money = '<div class="quote__big"><span class="lbl">Oferta da loja</span><span class="num">' + U.brl(M.instantOffer(ref)) + '</span></div>' +
          '<p class="quote__line">' + pctTxt(M.settings.instantRate) + ' da referência ' + esc(key) + ' (' + D.LANGS[g.lang] + '): <span class="num">' + U.brl(D.roundPrice(ref)) + '</span></p>';
      } else {
        const c = M.consignQuote(ref);
        money = '<div class="quote__big"><span class="lbl">Você recebe ≈</span><span class="num">' + U.brl(c.net) + '</span></div>' +
          '<dl class="quote__dl"><div><dt>Preço sugerido</dt><dd class="num">' + U.brl(c.price) + '</dd></div><div><dt>Comissão (' + pctTxt(M.settings.consignFee) + ')</dt><dd class="num">− ' + U.brl(c.fee) + '</dd></div></dl>';
      }
      const err = slab.certError(true);
      const text = proposal(g, ref);
      const wa = M.waLink(text);
      let send;
      if (err) send = '<p class="form-note">' + esc(err) + ' A loja confere o número antes de aceitar.</p>';
      else if (wa) send = '<a class="btn btn--volt btn--lg btn--block" href="' + esc(wa) + '" target="_blank" rel="noopener">' + U.icons.arrow + 'Enviar proposta pelo WhatsApp</a>';
      else send = '<p class="form-note">' + (M.canManage ? 'Você ainda não informou o WhatsApp da loja. <a href="#/painel/config">Configurar agora</a>.' : 'A loja ainda não informou um WhatsApp. Copie a proposta e envie pelo contato da loja.') + '</p>';
      q.innerHTML = '<h2 class="panel__title">' + (mode === 'oferta' ? 'Sua oferta' : 'Sua estimativa') + '</h2>' +
        '<div class="quote__slab">' + U.slab(preview) + '</div>' +
        money +
        (same.length ? '<p class="quote__line muted">Menor anúncio dessa nota hoje: <span class="num">' + U.brl(same[0].price) + '</span></p>' : '') +
        send +
        (err ? '' : '<button type="button" class="btn btn--ghost btn--block" data-copy-proposal>Copiar proposta</button>') +
        '<details class="quote__text"><summary>Ver texto da proposta</summary><textarea id="sf-text" class="input textarea" rows="8" readonly>' + esc(text) + '</textarea></details>' +
        '<p class="quote__fine">Valores calculados pela referência de mercado da nota. A oferta final depende da conferência do slab.</p>';
    }

    main.addEventListener('input', e => { if (e.target.closest('#sf') && !e.target.closest('#sf-card')) paint(); });
    main.addEventListener('click', e => {
      if (!e.target.closest('[data-copy-proposal]')) return;
      const box = $('sf-text');
      const fallback = () => {
        box.closest('details').open = true;
        box.focus();
        box.select();
        U.toast('Texto selecionado. Use Ctrl+C para copiar.');
      };
      try { navigator.clipboard.writeText(box.value).then(() => U.toast('Proposta copiada.'), fallback); } catch (err) { fallback(); }
    });
    main.addEventListener('submit', e => e.preventDefault());
    // Configurações da loja (taxas, WhatsApp) podem chegar depois: atualiza só a cotação.
    GD.onMarket = paint;
    paint();
  };
})(window.GD = window.GD || {});
