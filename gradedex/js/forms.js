/* GradeDex — campos compartilhados dos formulários de venda: seletor de carta e dados do slab. */
(function (GD) {
  'use strict';
  const D = GD.data, U = GD.ui;
  const esc = U.esc;
  GD.forms = {};

  // ---------- Seletor de carta ----------
  // opts: { id, initial (id da carta), onChange(card | null) }
  GD.forms.cardPicker = function (root, opts) {
    let card = opts.initial && D.CARD[opts.initial] ? D.CARD[opts.initial] : null;

    function render() {
      if (card) {
        const set = D.SET[card.set];
        root.innerHTML = '<div class="picked">' + U.swatch(card) +
          '<div class="picked__info"><b>' + esc(card.name) + (card.variant ? ' · ' + esc(card.variant) : '') + '</b>' +
          '<span class="muted">' + esc(U.setFull(set)) + ' · ' + esc(card.num) + ' · ' + esc(card.rarity) + '</span></div>' +
          '<button type="button" class="btn btn--ghost btn--sm" data-pick-change>Trocar</button></div>';
        return;
      }
      root.innerHTML = '<div class="field"><label for="' + opts.id + '">Carta</label>' +
        '<div class="picker"><input id="' + opts.id + '" class="input" type="search" autocomplete="off" placeholder="Nome, coleção ou número (ex.: Umbreon 215)">' +
        '<div class="picker__list" role="listbox" aria-label="Cartas encontradas" hidden></div></div></div>';
    }
    function list(v) {
      const box = root.querySelector('.picker__list');
      const found = v.trim() ? D.matchCards(v).slice(0, 8) : [];
      box.innerHTML = found.map(c =>
        '<button type="button" class="picker__opt" role="option" data-pick="' + c.id + '">' + U.swatch(c) +
        '<span><b>' + esc(c.name) + (c.variant ? ' · ' + esc(c.variant) : '') + '</b><span class="muted">' + esc(U.setLabel(D.SET[c.set])) + ' · ' + esc(c.num) + '</span></span></button>').join('') ||
        (v.trim() ? '<p class="picker__empty">Nenhuma carta do catálogo com esse nome.</p>' : '');
      box.hidden = !box.innerHTML;
    }
    root.addEventListener('input', e => { if (e.target.id === opts.id) list(e.target.value); });
    root.addEventListener('click', e => {
      const pick = e.target.closest('[data-pick]');
      if (pick) { card = D.CARD[pick.dataset.pick]; render(); opts.onChange(card); return; }
      if (e.target.closest('[data-pick-change]')) {
        card = null;
        render();
        opts.onChange(null);
        root.querySelector('input').focus();
      }
    });
    render();
    return { get: () => card };
  };

  // ---------- Dados do slab ----------
  const SUBS = ['Centralização', 'Cantos', 'Bordas', 'Superfície'];
  const SUB_VALUES = [10, 9.5, 9, 8.5, 8, 7.5, 7, 6.5, 6];
  const CERT_HINT = { PSA: 'Só números, 7 a 12 dígitos', BGS: 'Só números, 7 a 12 dígitos', CGC: 'Só números, 7 a 12 dígitos', TAG: 'Letras e números, 6 a 14 caracteres' };
  const certOk = (grader, c) => (grader === 'TAG' ? /^[A-Z0-9]{6,14}$/ : /^\d{7,12}$/).test(c);
  const normCert = v => String(v || '').toUpperCase().replace(/^(PSA|BGS|CGC|TAG)/, '').replace(/[^A-Z0-9]/g, '');
  const defaultSubs = g => (g === 10 ? [10, 10, 10, 9.5] : [g, g, g, g]);

  // opts: { prefix, initial: {grader, grade, subs, special, lang, cert}, onChange(state) }
  GD.forms.slabFields = function (root, opts) {
    const p = opts.prefix;
    const init = opts.initial || {};
    const st = {
      grader: D.GRADERS.indexOf(init.grader) >= 0 ? init.grader : 'PSA',
      grade: init.grade || 10,
      subs: init.subs ? init.subs.slice() : null,
      pristine: init.special === 'pristine',
      lang: init.lang || 'EN',
      cert: init.cert || '',
    };
    if (D.SELL_GRADES[st.grader].indexOf(st.grade) < 0) st.grade = D.SELL_GRADES[st.grader][0];
    if (st.grader === 'BGS' && !st.subs) st.subs = defaultSubs(st.grade);

    function special() {
      if (st.grader === 'BGS') return st.grade === 10 ? (st.subs.every(s => s === 10) ? 'bl' : 'pristine') : null;
      if (st.grader === 'CGC' || st.grader === 'TAG') return st.grade === 10 && st.pristine ? 'pristine' : null;
      return null;
    }
    const value = () => ({ grader: st.grader, grade: st.grade, special: special(), subs: st.grader === 'BGS' ? st.subs.slice() : null, lang: st.lang, cert: st.cert });
    const opt = (v, t, sel) => '<option value="' + v + '"' + (sel ? ' selected' : '') + '>' + t + '</option>';

    function render() {
      const names = D.GRADE_NAMES[st.grader];
      let html = '<div class="form-grid">' +
        '<div class="field"><label for="' + p + '-grader">Graduadora</label><select id="' + p + '-grader" class="input">' +
          D.GRADERS.map(g => opt(g, g, g === st.grader)).join('') + '</select></div>' +
        '<div class="field"><label for="' + p + '-grade">Nota</label><select id="' + p + '-grade" class="input">' +
          D.SELL_GRADES[st.grader].map(g => opt(g, g + ' · ' + (names[g] || ''), g === st.grade)).join('') + '</select></div>';
      if (st.grader === 'BGS') {
        html += '<fieldset class="subs-grid field--wide"><legend class="lbl">Subnotas BGS</legend>' + SUBS.map((n, i) =>
          '<div class="field"><label for="' + p + '-sub' + i + '">' + n + '</label><select id="' + p + '-sub' + i + '" class="input" data-sub="' + i + '">' +
            SUB_VALUES.map(v => opt(v, v, v === st.subs[i])).join('') + '</select></div>').join('') +
          (st.grade === 10 ? '<p class="form-note field--wide">' + (special() === 'bl' ? '<b>Black Label:</b> as quatro subnotas em 10.' : 'Com as quatro subnotas em 10, o slab é Black Label.') + '</p>' : '') +
          '</fieldset>';
      }
      if ((st.grader === 'CGC' || st.grader === 'TAG') && st.grade === 10) {
        html += '<label class="check field--wide"><input type="checkbox" id="' + p + '-pristine"' + (st.pristine ? ' checked' : '') + '><span>Pristine 10 (etiqueta dourada)</span></label>';
      }
      html += '<div class="field"><label for="' + p + '-lang">Idioma da carta</label><select id="' + p + '-lang" class="input">' +
          Object.keys(D.LANGS).map(k => opt(k, D.LANGS[k], k === st.lang)).join('') + '</select></div>' +
        '<div class="field"><label for="' + p + '-cert">Número do certificado</label><input id="' + p + '-cert" class="input num" autocomplete="off" value="' + esc(st.cert) + '" placeholder="' + CERT_HINT[st.grader] + '"></div>' +
      '</div>';
      root.innerHTML = html;
    }

    root.addEventListener('change', e => {
      const t = e.target;
      if (t.id === p + '-grader') {
        st.grader = t.value;
        if (D.SELL_GRADES[st.grader].indexOf(st.grade) < 0) st.grade = D.SELL_GRADES[st.grader][0];
        st.subs = st.grader === 'BGS' ? defaultSubs(st.grade) : null;
        render();
      } else if (t.id === p + '-grade') {
        st.grade = Number(t.value);
        if (st.grader === 'BGS') st.subs = defaultSubs(st.grade);
        render();
      } else if (t.dataset.sub) {
        st.subs[Number(t.dataset.sub)] = Number(t.value);
        render();
      } else if (t.id === p + '-pristine') st.pristine = t.checked;
      else if (t.id === p + '-lang') st.lang = t.value;
      else return;
      opts.onChange(value());
    });
    root.addEventListener('input', e => {
      if (e.target.id !== p + '-cert') return;
      st.cert = normCert(e.target.value);
      e.target.removeAttribute('aria-invalid');
      opts.onChange(value());
    });
    render();

    return {
      get: value,
      // Mensagem de erro do certificado, ou '' quando está tudo certo.
      certError(required) {
        if (!st.cert) return required ? 'Informe o número do certificado.' : '';
        return certOk(st.grader, st.cert) ? '' : 'Certificado ' + st.grader + ' inválido: ' + CERT_HINT[st.grader].toLowerCase() + '.';
      },
      markCert(bad) {
        const el = root.querySelector('#' + p + '-cert');
        if (el) { el.toggleAttribute('aria-invalid', !!bad); if (bad) el.focus(); }
      },
    };
  };
})(window.GD = window.GD || {});
