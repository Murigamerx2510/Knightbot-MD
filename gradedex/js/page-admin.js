/* GradeDex — painel do dono: anúncios da loja, novo anúncio (com fotos) e configurações. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui, M = GD.market;
  const esc = U.esc;
  GD.pages = GD.pages || {};

  const TABS = [['', 'Anúncios'], ['novo', 'Novo anúncio'], ['config', 'Configurações']];
  const STATUS = { active: ['Ativo', 'tag--ok'], paused: ['Pausado', ''], sold: ['Vendido', 'tag--volt'] };
  const MAX_PHOTOS = 4;
  const pctTxt = r => U.dec(r * 100, 0) + '%';
  const crumbs = '<nav class="crumbs" aria-label="Você está em"><a href="#/">Início</a><span aria-hidden="true">/</span><span>Painel da loja</span></nav>';
  const fail = err => U.toast((err && err.message) || 'Não foi possível salvar. Tente de novo.');

  GD.pages.painel = function (main, params) {
    if (M.mode === 'pending' || (M.mode === 'shared' && !M.ready)) {
      main.innerHTML = crumbs + '<div class="empty"><p>Carregando a loja…</p></div>';
      return;
    }
    if (!M.canManage) {
      main.innerHTML = crumbs + '<div class="empty"><h2>Painel da loja</h2><p>Só quem administra a ' + esc(D.HOUSE.name) + ' gerencia os anúncios. Se a loja é sua, abra o link entrando no claude.ai com a conta dona dele.</p><a class="btn btn--volt" href="#/vender">Quero vender um slab</a></div>';
      return;
    }
    const tab = params.tab || '';
    const editing = tab === 'novo' && params.edit;
    main.innerHTML = crumbs +
      '<div class="adm-head"><h1 class="page-title">Painel da loja</h1>' +
        (M.mode === 'local'
          ? '<p class="mode-note">' + U.icons.lock + '<span><b>Modo local.</b> Os anúncios ficam salvos só neste navegador. No link publicado da GradeDex, eles aparecem para todo mundo.</span></p>'
          : '<p class="mode-note">' + U.icons.shield + '<span>Os anúncios ficam salvos na loja publicada e aparecem para todos que abrem o link. Só você (e editores que convidar) pode alterar.</span></p>') +
      '</div>' +
      '<nav class="adm-tabs" aria-label="Seções do painel">' + TABS.map(([t, label]) =>
        '<a href="#/painel' + (t ? '/' + t : '') + '"' + (t === tab && !editing ? ' aria-current="page"' : '') + '>' + label + '</a>').join('') +
        (editing ? '<span class="adm-tabs__edit" aria-current="page">Editando anúncio</span>' : '') + '</nav>' +
      '<div id="adm-body"></div>';
    const body = main.querySelector('#adm-body');
    if (tab === 'novo') listingForm(body, params.edit);
    else if (tab === 'config') settingsForm(body);
    else listingsTab(body);
  };

  // ---------- Anúncios ----------
  function listingsTab(wrap) {
    let filter = 'all', confirming = null;
    const sum = arr => arr.reduce((s, d) => s + d.price, 0);

    function row(d) {
      const card = D.CARD[d.card];
      const st = STATUS[d.status];
      const btn = (act, label) => '<button type="button" class="btn btn--ghost btn--sm" data-act="' + act + '" data-id="' + d.id + '">' + label + '</button>';
      const actions = confirming === d.id
        ? '<span class="adm-confirm">Excluir de vez?</span><button type="button" class="btn btn--danger btn--sm" data-act="delete" data-id="' + d.id + '">Excluir</button>' + btn('cancel', 'Cancelar')
        : (d.status === 'active' ? btn('pause', 'Pausar') + btn('sold', 'Vendido') : d.status === 'paused' ? btn('activate', 'Ativar') + btn('sold', 'Vendido') : btn('activate', 'Reativar')) +
          '<a class="btn btn--ghost btn--sm" href="#/painel/novo?edit=' + d.id + '">Editar</a>' + btn('ask-delete', 'Excluir');
      return '<li class="adm-row panel">' +
        '<a class="adm-row__thumb" href="#/carta/' + card.id + (d.status === 'active' ? '?l=gd-' + d.id : '') + '" aria-label="Ver ' + esc(card.name) + '">' + U.swatch(card) + '</a>' +
        '<div class="adm-row__info"><b>' + esc(card.name) + (card.variant ? ' · ' + esc(card.variant) : '') + '</b>' +
          '<span class="muted">' + esc(U.setLabel(D.SET[card.set])) + ' · ' + esc(card.num) + '</span>' +
          '<span class="adm-row__tags">' + U.gchip(d) + '<span class="tag">' + d.lang + '</span><span class="tag num">' + esc(d.cert || 'sem certificado') + '</span>' +
            (d.origin === 'consign' ? '<span class="tag">Consignado' + (d.consignor ? ' · ' + esc(d.consignor) : '') + '</span>' : '') +
            (d.photos.length ? '<span class="tag">' + U.plural(d.photos.length, 'foto', 'fotos') + '</span>' : '') + '</span></div>' +
        '<div class="adm-row__price"><label class="sr" for="pr-' + d.id + '">Preço de ' + esc(card.name) + '</label>' +
          '<input id="pr-' + d.id + '" class="input input--sm num" type="number" min="1" step="any" inputmode="numeric" value="' + d.price + '" data-price="' + d.id + '">' +
          '<button type="button" class="btn btn--ghost btn--sm" data-act="price" data-id="' + d.id + '" disabled>Salvar</button></div>' +
        '<span class="tag adm-row__status ' + st[1] + '">' + st[0] + '</span>' +
        '<div class="adm-row__act">' + actions + '</div>' +
      '</li>';
    }

    function render() {
      const docs = M.docs.slice().sort((a, b) => b.updatedAt - a.updatedAt);
      const by = s => docs.filter(d => d.status === s);
      const act = by('active'), sold = by('sold');
      const rows = filter === 'all' ? docs : by(filter);
      const stat = (t, v) => '<div><dt>' + t + '</dt><dd class="num">' + v + '</dd></div>';
      wrap.innerHTML =
        '<dl class="adm-stats">' + stat('Ativos', act.length) + stat('Valor anunciado', U.brl(sum(act))) + stat('Pausados', by('paused').length) + stat('Vendidos', sold.length + ' · ' + U.brl(sum(sold))) + '</dl>' +
        '<div class="adm-tools"><div class="seg" role="group" aria-label="Filtrar anúncios">' +
          [['all', 'Todos'], ['active', 'Ativos'], ['paused', 'Pausados'], ['sold', 'Vendidos']].map(([v, t]) =>
            '<button type="button" class="seg__btn" data-filter="' + v + '" aria-pressed="' + (filter === v) + '">' + t + '</button>').join('') +
          '</div><a class="btn btn--volt" href="#/painel/novo">Novo anúncio</a></div>' +
        (rows.length ? '<ul class="adm-list">' + rows.map(row).join('') + '</ul>'
          : '<div class="empty"><h2>' + (docs.length ? 'Nada neste filtro' : 'Nenhum anúncio ainda') + '</h2><p>' + (docs.length ? 'Escolha outro filtro para ver os demais anúncios.' : 'Cadastre o primeiro slab da loja: ele aparece na busca, na página da carta e na home com o selo Loja oficial.') + '</p>' +
            (docs.length ? '' : '<a class="btn btn--volt" href="#/painel/novo">Criar primeiro anúncio</a>') + '</div>');
    }

    async function run(act, id) {
      const d = M.doc(id);
      try {
        if (act === 'price') {
          const v = Number(wrap.querySelector('[data-price="' + id + '"]').value);
          if (!(v > 0)) { U.toast('Informe um preço maior que zero.'); return; }
          await M.update(id, { price: Math.round(v) });
          U.toast('Preço atualizado para ' + U.brl(v) + '.');
        } else if (act === 'pause') { await M.update(id, { status: 'paused' }); U.toast('Anúncio pausado: saiu da loja.'); }
        else if (act === 'activate') { await M.update(id, { status: 'active', soldAt: 0 }); U.toast('Anúncio ativo na loja.'); }
        else if (act === 'sold') { await M.update(id, { status: 'sold', soldAt: Date.now() }); U.toast('Marcado como vendido.'); }
        else if (act === 'delete') { confirming = null; await M.remove(id); U.toast('Anúncio excluído.'); }
      } catch (err) { fail(err); }
      if (!d) render();
    }

    wrap.addEventListener('click', e => {
      const f = e.target.closest('[data-filter]');
      if (f) { filter = f.dataset.filter; render(); return; }
      const b = e.target.closest('[data-act]');
      if (!b) return;
      if (b.dataset.act === 'ask-delete') { confirming = b.dataset.id; render(); return; }
      if (b.dataset.act === 'cancel') { confirming = null; render(); return; }
      run(b.dataset.act, b.dataset.id);
    });
    wrap.addEventListener('input', e => {
      const id = e.target.dataset.price;
      if (id) wrap.querySelector('[data-act="price"][data-id="' + id + '"]').disabled = Number(e.target.value) === M.doc(id).price;
    });
    GD.onMarket = render;
    render();
  }

  // ---------- Novo anúncio / edição ----------
  function listingForm(wrap, editId) {
    const doc = editId ? M.doc(editId) : null;
    if (editId && !doc) {
      wrap.innerHTML = '<div class="empty"><h2>Anúncio não encontrado</h2><p>Ele pode ter sido excluído.</p><a class="btn btn--volt" href="#/painel">Voltar aos anúncios</a></div>';
      return;
    }
    let card = doc ? D.CARD[doc.card] : null;
    let photos = doc ? doc.photos.map(v => ({ value: v, url: M.photoUrl(v) })) : [];
    let busy = false;

    wrap.innerHTML = '<form id="lf" class="sell-layout" novalidate>' +
      '<div class="sell-form">' +
        '<section class="panel"><h2 class="panel__title">Carta</h2><div id="lf-card"></div></section>' +
        '<section class="panel"><h2 class="panel__title">Slab</h2><div id="lf-slab"></div></section>' +
        '<section class="panel"><h2 class="panel__title">Fotos do slab</h2>' +
          '<p class="form-note">Frente e verso do slab, até ' + MAX_PHOTOS + ' fotos. O scan oficial da carta já aparece no anúncio.</p>' +
          '<div class="photos" id="lf-photos"></div>' +
          (M.canUploadPhotos() ? '<label class="btn btn--ghost photos__add" for="lf-files">Adicionar fotos</label><input id="lf-files" class="sr" type="file" accept="image/*" multiple>' : '<p class="form-note">Seu acesso atual não permite enviar fotos.</p>') +
        '</section>' +
        '<section class="panel"><h2 class="panel__title">Origem do slab</h2><div class="pay">' +
          '<label class="pay__opt"><input type="radio" name="lf-origin" value="own"' + (!doc || doc.origin === 'own' ? ' checked' : '') + '><span><b>Estoque da loja</b><span class="muted">Slab comprado pela loja, inclusive na venda instantânea</span></span><span></span></label>' +
          '<label class="pay__opt"><input type="radio" name="lf-origin" value="consign"' + (doc && doc.origin === 'consign' ? ' checked' : '') + '><span><b>Consignado</b><span class="muted">A loja vende para um cliente e fica com a comissão</span></span><span></span></label>' +
        '</div><div class="field consignor" id="lf-consignor-box"><label for="lf-consignor">Nome do consignante</label><input id="lf-consignor" class="input" value="' + esc(doc ? doc.consignor : '') + '"></div></section>' +
        '<section class="panel"><h2 class="panel__title"><label for="lf-notes">Observações</label></h2><textarea id="lf-notes" class="input textarea" rows="3" placeholder="Estado do case, detalhes que o comprador deve saber…">' + esc(doc ? doc.notes : '') + '</textarea></section>' +
      '</div>' +
      '<aside class="quote panel">' +
        '<h2 class="panel__title">Preço</h2>' +
        '<div class="field"><label for="lf-price">Preço de venda (R$)</label><input id="lf-price" class="input input--lg num" type="number" min="1" step="any" inputmode="numeric" value="' + (doc ? doc.price : '') + '"></div>' +
        '<div id="lf-sugg" class="sugg"></div>' +
        '<label class="check"><input type="checkbox" id="lf-offers"' + (doc && doc.acceptsOffers ? ' checked' : '') + '><span>Aceita ofertas</span></label>' +
        '<p class="form-note" id="lf-net"></p>' +
        '<p class="form-error" id="lf-err" role="alert" hidden></p>' +
        (doc
          ? '<button type="submit" class="btn btn--volt btn--lg btn--block" data-status="">Salvar alterações</button>'
          : '<button type="submit" class="btn btn--volt btn--lg btn--block" data-status="active">Publicar anúncio</button><button type="submit" class="btn btn--ghost btn--block" data-status="paused">Salvar pausado</button>') +
        '<p class="form-note" id="lf-busy" aria-live="polite"></p>' +
      '</aside>' +
    '</form>';

    const $ = id => wrap.querySelector('#' + id);
    GD.forms.cardPicker($('lf-card'), { id: 'lf-cardq', initial: doc ? doc.card : '', onChange: c => { card = c; paint(); } });
    const slab = GD.forms.slabFields($('lf-slab'), { prefix: 'lf', initial: doc, onChange: paint });
    const origin = () => (wrap.querySelector('input[name="lf-origin"]:checked') || {}).value || 'own';

    function paint() {
      $('lf-consignor-box').hidden = origin() !== 'consign';
      const price = Number($('lf-price').value);
      $('lf-net').textContent = origin() === 'consign' && price > 0
        ? 'Comissão de ' + pctTxt(M.settings.consignFee) + ': ' + U.brl(price * M.settings.consignFee) + ' · consignante recebe ' + U.brl(price * (1 - M.settings.consignFee)) + '.'
        : '';
      if (!card) { $('lf-sugg').innerHTML = '<p class="muted">Escolha a carta para ver a referência de preço.</p>'; return; }
      const g = slab.get();
      const ref = D.roundPrice(M.reference(card, g));
      const key = D.gradeKey(g);
      const others = D.listingsOf(card.id).filter(l => !l.own && D.gradeKey(l) === key && l.lang === g.lang);
      $('lf-sugg').innerHTML =
        '<button type="button" class="sugg__opt" data-use="' + ref + '"><span>Referência ' + esc(key) + ' (' + g.lang + ')</span><b class="num">' + U.brl(ref) + '</b></button>' +
        (others.length ? '<button type="button" class="sugg__opt" data-use="' + others[0].price + '"><span>Menor anúncio dessa nota</span><b class="num">' + U.brl(others[0].price) + '</b></button>' : '') +
        '<p class="form-note">Toque num valor para usar como preço.</p>';
    }

    function renderPhotos() {
      $('lf-photos').innerHTML = photos.map((p, i) =>
        '<figure class="photo"><img src="' + esc(p.url) + '" alt="Foto ' + (i + 1) + ' do slab"><button type="button" class="photo__rm" data-rm="' + i + '" aria-label="Remover foto ' + (i + 1) + '">' + U.icons.x + '</button></figure>').join('');
      const add = wrap.querySelector('.photos__add');
      if (add) add.hidden = photos.length >= MAX_PHOTOS;
    }

    function error(msg) {
      $('lf-err').textContent = msg;
      $('lf-err').hidden = !msg;
    }

    async function save(status) {
      if (busy) return;
      const g = slab.get();
      const price = Number($('lf-price').value);
      const certErr = slab.certError(true);
      if (!card) { error('Escolha a carta do anúncio.'); $('lf-cardq').focus(); return; }
      if (certErr) { error(certErr); slab.markCert(true); return; }
      if (M.certInUse(g.cert, doc && doc.id)) { error('Esse certificado já está anunciado na loja.'); slab.markCert(true); return; }
      if (!(price > 0)) { error('Informe o preço de venda.'); $('lf-price').setAttribute('aria-invalid', 'true'); $('lf-price').focus(); return; }
      if (origin() === 'consign' && !$('lf-consignor').value.trim()) { error('Informe o nome do consignante.'); $('lf-consignor').focus(); return; }
      error('');
      busy = true;
      wrap.querySelectorAll('button[type="submit"]').forEach(b => { b.disabled = true; });
      try {
        const stored = [];
        for (let i = 0; i < photos.length; i++) {
          if (!photos[i].value) {
            $('lf-busy').textContent = 'Enviando foto ' + (i + 1) + ' de ' + photos.length + '…';
            photos[i].value = await M.storePhoto(photos[i].blob);
          }
          stored.push(photos[i].value);
        }
        $('lf-busy').textContent = 'Salvando anúncio…';
        const data = {
          card: card.id, grader: g.grader, grade: g.grade, special: g.special, subs: g.subs, lang: g.lang, cert: g.cert,
          price: Math.round(price), acceptsOffers: $('lf-offers').checked, origin: origin(),
          consignor: origin() === 'consign' ? $('lf-consignor').value.trim() : '', notes: $('lf-notes').value.trim(), photos: stored,
          status: status || (doc ? doc.status : 'active'),
        };
        let id;
        if (doc) {
          await M.update(doc.id, data);
          await M.deletePhotos(doc.photos.filter(p => stored.indexOf(p) < 0));
          id = doc.id;
        } else {
          id = await M.create(data);
        }
        U.toast(doc ? 'Alterações salvas.' : data.status === 'active' ? 'Anúncio publicado na loja.' : 'Anúncio salvo como pausado.');
        GD.go(data.status === 'active' ? '/carta/' + card.id + '?l=gd-' + id : '/painel');
      } catch (err) {
        busy = false;
        $('lf-busy').textContent = '';
        wrap.querySelectorAll('button[type="submit"]').forEach(b => { b.disabled = false; });
        error((err && err.message) || 'Não foi possível salvar. Confira sua conexão e tente de novo.');
      }
    }

    wrap.addEventListener('change', async e => {
      if (e.target.name === 'lf-origin') { paint(); return; }
      if (e.target.id !== 'lf-files') return;
      const files = Array.from(e.target.files || []);
      e.target.value = '';
      for (const f of files) {
        if (photos.length >= MAX_PHOTOS) { U.toast('Máximo de ' + MAX_PHOTOS + ' fotos por anúncio.'); break; }
        try {
          const blob = await M.preparePhoto(f);
          photos.push({ blob, url: URL.createObjectURL(blob) });
          renderPhotos();
        } catch (err) { U.toast(err.message); }
      }
    });
    wrap.addEventListener('input', e => {
      if (e.target.id === 'lf-price') { e.target.removeAttribute('aria-invalid'); paint(); }
    });
    wrap.addEventListener('click', e => {
      const use = e.target.closest('[data-use]');
      if (use) { $('lf-price').value = use.dataset.use; $('lf-price').removeAttribute('aria-invalid'); paint(); return; }
      const rm = e.target.closest('[data-rm]');
      if (rm) { photos.splice(Number(rm.dataset.rm), 1); renderPhotos(); }
    });
    wrap.addEventListener('submit', e => {
      e.preventDefault();
      const status = e.submitter ? e.submitter.dataset.status : '';
      save(doc ? '' : status || 'active');
    });
    // Não redesenha o formulário quando o banco muda; só atualiza a referência e as taxas.
    GD.onMarket = paint;
    renderPhotos();
    paint();
  }

  // ---------- Configurações ----------
  function settingsForm(wrap) {
    const s = M.settings;
    const field = (id, label, value, extra) => '<div class="field' + (extra && extra.wide ? ' field--wide' : '') + '"><label for="' + id + '">' + label + '</label>' +
      '<input id="' + id + '" class="input' + (extra && extra.num ? ' num' : '') + '" value="' + esc(value) + '"' + (extra && extra.attrs ? ' ' + extra.attrs : '') + '>' +
      (extra && extra.note ? '<span class="form-note">' + extra.note + '</span>' : '') + '</div>';
    wrap.innerHTML = '<form id="cf" class="settings" novalidate>' +
      '<section class="panel"><h2 class="panel__title">Loja</h2><div class="form-grid">' +
        field('cf-name', 'Nome da loja', s.storeName, { attrs: 'maxlength="40" autocomplete="organization"' }) +
        field('cf-whats', 'WhatsApp da loja', s.whatsapp, { num: true, attrs: 'inputmode="tel" placeholder="5511987654321"', note: 'Com DDI 55 e DDD, só números. Recebe as propostas de venda e os pedidos.' }) +
        field('cf-city', 'Cidade', s.city, { attrs: 'maxlength="40" autocomplete="address-level2"' }) +
        field('cf-uf', 'UF', s.uf, { attrs: 'maxlength="2" autocomplete="address-level1"' }) +
      '</div></section>' +
      '<section class="panel"><h2 class="panel__title">Compra e consignação</h2><div class="form-grid">' +
        field('cf-rate', 'Oferta da venda instantânea (% da referência)', Math.round(s.instantRate * 100), { num: true, attrs: 'type="number" min="30" max="95" step="1"' }) +
        field('cf-fee', 'Comissão da consignação (%)', Math.round(s.consignFee * 100), { num: true, attrs: 'type="number" min="0" max="40" step="0.5"' }) +
      '</div></section>' +
      '<section class="panel"><h2 class="panel__title">Envio</h2><div class="form-grid">' +
        field('cf-ships', 'Prazo para postar (dias úteis)', s.ships, { num: true, attrs: 'type="number" min="1" max="15" step="1"' }) +
        field('cf-ship', 'Frete base SEDEX (R$)', s.ship, { num: true, attrs: 'type="number" min="0" max="500" step="1"' }) +
      '</div></section>' +
      '<section class="panel"><h2 class="panel__title">Vitrine</h2><label class="check"><input type="checkbox" id="cf-demo"' + (s.showDemo ? ' checked' : '') + '><span>Mostrar os anúncios de demonstração (lojas fictícias) junto com os da loja</span></label></section>' +
      '<p class="form-error" id="cf-err" role="alert" hidden></p>' +
      '<div class="settings__actions"><button type="submit" class="btn btn--volt btn--lg">Salvar configurações</button><span id="cf-test"></span></div>' +
    '</form>';
    const $ = id => wrap.querySelector('#' + id);
    const testLink = n => (n.length >= 10 ? '<a href="https://wa.me/' + n + '" target="_blank" rel="noopener">Testar o WhatsApp</a>' : '');
    $('cf-test').innerHTML = testLink(s.whatsapp);

    wrap.addEventListener('submit', async e => {
      e.preventDefault();
      const whats = $('cf-whats').value.replace(/\D/g, '');
      const rate = Number($('cf-rate').value), fee = Number($('cf-fee').value);
      let msg = '';
      if (whats && (whats.length < 12 || whats.length > 13 || whats.indexOf('55') !== 0)) msg = 'WhatsApp inválido: use 55 + DDD + número, por exemplo 5511987654321.';
      else if (!(rate >= 30 && rate <= 95)) msg = 'A oferta instantânea precisa ficar entre 30% e 95% da referência.';
      else if (!(fee >= 0 && fee <= 40)) msg = 'A comissão precisa ficar entre 0% e 40%.';
      $('cf-err').textContent = msg;
      $('cf-err').hidden = !msg;
      if (msg) return;
      try {
        await M.saveSettings({
          storeName: $('cf-name').value.trim() || 'GradeDex', whatsapp: whats, city: $('cf-city').value.trim(), uf: $('cf-uf').value,
          instantRate: rate / 100, consignFee: fee / 100, ships: Number($('cf-ships').value), ship: Number($('cf-ship').value),
          showDemo: $('cf-demo').checked,
        });
        $('cf-test').innerHTML = testLink(whats);
        U.toast('Configurações salvas.');
      } catch (err) { fail(err); }
    });
    GD.onMarket = () => {};
  }
})(window.GD = window.GD || {});
