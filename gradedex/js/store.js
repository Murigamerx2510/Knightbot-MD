/* GradeDex — estado do visitante (carrinho, favoritos, alertas, comparação).
   Fica só neste navegador; se o armazenamento estiver bloqueado, tudo funciona em memória. */
(function (GD) {
  'use strict';
  const KEY = 'gradedex.v1';
  const D = GD.data;
  const s = { cart: [], favs: [], compare: [], alerts: {}, recent: [], ship: {}, insure: true, theme: null };

  try {
    const raw = localStorage.getItem(KEY);
    if (raw) Object.assign(s, JSON.parse(raw));
  } catch (e) { /* armazenamento indisponível */ }

  // Descarta ids que não existem mais no catálogo. Anúncios da loja oficial ("gd-") chegam depois,
  // pelo banco; as páginas ignoram os que não estiverem mais à venda.
  const known = id => D.LISTING[id] || String(id).indexOf('gd-') === 0;
  s.cart = s.cart.filter(known);
  s.compare = s.compare.filter(known);
  s.favs = s.favs.filter(id => D.CARD[id]);
  s.recent = s.recent.filter(id => D.CARD[id]);
  Object.keys(s.alerts).forEach(id => { if (!D.CARD[id]) delete s.alerts[id]; });

  const listeners = [];
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* ignora */ }
    listeners.forEach(fn => fn(s));
  }
  const toggle = (arr, id) => { const i = arr.indexOf(id); if (i >= 0) arr.splice(i, 1); else arr.push(id); return i < 0; };

  GD.store = {
    state: s,
    on(fn) { listeners.push(fn); },

    inCart: id => s.cart.includes(id),
    toggleCart(id) { const added = toggle(s.cart, id); save(); return added; },
    removeCart(id) { s.cart = s.cart.filter(x => x !== id); save(); },
    clearCart() { s.cart = []; save(); },
    setShip(sellerId, method) { s.ship[sellerId] = method; save(); },
    setInsure(on) { s.insure = !!on; save(); },

    isFav: id => s.favs.includes(id),
    toggleFav(id) { const added = toggle(s.favs, id); save(); return added; },

    inCompare: id => s.compare.includes(id),
    toggleCompare(id) {
      if (!s.compare.includes(id) && s.compare.length >= 3) return null;
      const added = toggle(s.compare, id); save(); return added;
    },

    alertOf: cardId => s.alerts[cardId] || null,
    setAlert(cardId, key, price) { s.alerts[cardId] = { key, price, at: Date.now() }; save(); },
    removeAlert(cardId) { delete s.alerts[cardId]; save(); },

    pushRecent(cardId) {
      s.recent = [cardId].concat(s.recent.filter(x => x !== cardId)).slice(0, 12);
      try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* ignora */ }
    },

    setTheme(t) { s.theme = t; save(); },
  };
})(window.GD = window.GD || {});
