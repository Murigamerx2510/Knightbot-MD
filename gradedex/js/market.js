/* GradeDex — anúncios da loja oficial e configurações da loja.
   No link publicado no claude.ai usa o banco compartilhado do Artifact: todos leem, só o dono
   (e editores que ele convidar) escreve. Fora dele (index.html local ou outro host), salva neste navegador. */
(function (GD) {
  'use strict';
  const D = GD.data;
  const LKEY = 'gradedex.market.v1';
  const DEFAULTS = { storeName: 'GradeDex', city: '', uf: '', whatsapp: '', instantRate: 0.7, consignFee: 0.12, ships: 1, ship: 30, showDemo: true };
  const ASSET_ID = /^[0-9a-f]{32}$/;

  const M = {
    mode: 'pending',   // pending → shared (banco do Artifact) | readonly (claude.ai sem banco) | local
    ready: false,
    canManage: false,
    docs: [],
    settings: Object.assign({}, DEFAULTS),
  };
  let db = null, assets = null;
  const listeners = [];
  M.on = fn => { listeners.push(fn); };

  // ---------- Validação (dados compartilhados não são confiáveis) ----------
  function cleanListing(id, d) {
    if (!d || !D.CARD[d.card] || D.GRADERS.indexOf(d.grader) < 0) return null;
    const grade = Number(d.grade), price = Number(d.price);
    if (D.SELL_GRADES[d.grader].indexOf(grade) < 0 || !(price > 0 && price < 1e8)) return null;
    return {
      id: String(id),
      card: d.card, grader: d.grader, grade,
      special: d.special === 'bl' || d.special === 'pristine' ? d.special : null,
      subs: Array.isArray(d.subs) && d.subs.length === 4 ? d.subs.map(Number) : null,
      lang: D.LANGS[d.lang] ? d.lang : 'EN',
      cert: String(d.cert || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 14),
      price: Math.round(price),
      status: d.status === 'paused' || d.status === 'sold' ? d.status : 'active',
      origin: d.origin === 'consign' ? 'consign' : 'own',
      consignor: String(d.consignor || '').slice(0, 80),
      acceptsOffers: !!d.acceptsOffers,
      photos: Array.isArray(d.photos) ? d.photos.filter(p => typeof p === 'string' && (ASSET_ID.test(p) || p.indexOf('data:image/') === 0)).slice(0, 4) : [],
      notes: String(d.notes || '').slice(0, 600),
      createdAt: Number(d.createdAt) || Date.now(),
      updatedAt: Number(d.updatedAt) || Number(d.createdAt) || Date.now(),
      soldAt: Number(d.soldAt) || 0,
    };
  }
  function cleanSettings(s) {
    s = s || {};
    const num = (v, lo, hi, def) => { v = Number(v); return v >= lo && v <= hi ? v : def; };
    return {
      storeName: String(s.storeName || DEFAULTS.storeName).slice(0, 40),
      city: String(s.city || '').slice(0, 40),
      uf: String(s.uf || '').toUpperCase().replace(/[^A-Z]/g, '').slice(0, 2),
      whatsapp: String(s.whatsapp || '').replace(/\D/g, '').slice(0, 15),
      instantRate: num(s.instantRate, 0.3, 0.95, DEFAULTS.instantRate),
      consignFee: num(s.consignFee, 0, 0.4, DEFAULTS.consignFee),
      ships: Math.round(num(s.ships, 1, 15, DEFAULTS.ships)),
      ship: num(s.ship, 0, 500, DEFAULTS.ship),
      showDemo: s.showDemo !== false,
    };
  }

  M.photoUrl = p => typeof p !== 'string' ? '' : p.indexOf('data:image/') === 0 ? p : ASSET_ID.test(p) ? '/_blob/' + p : '';

  function toListing(d) {
    const card = D.CARD[d.card];
    return {
      id: 'gd-' + d.id, docId: d.id, card: d.card, grader: d.grader, grade: d.grade, special: d.special, subs: d.subs,
      lang: d.lang, seller: 'gradedex', price: d.price, cert: d.cert,
      ref: D.roundPrice(D.fairPrice(card, d.grader, d.grade, d.special, d.lang)),
      days: Math.max(0, Math.floor((Date.now() - d.createdAt) / 864e5)),
      offer: d.acceptsOffers, own: true, origin: d.origin, consignor: d.consignor,
      photos: d.photos.map(M.photoUrl).filter(Boolean), notes: d.notes,
    };
  }

  function emit() {
    const sold = M.docs.filter(d => d.status === 'sold').length;
    D.setMarket(M.docs.filter(d => d.status === 'active').map(toListing), Object.assign({}, M.settings, { sold }));
    listeners.forEach(fn => { try { fn(); } catch (e) { console.error(e); } });
  }

  // ---------- Início ----------
  function readLocal() {
    try { const raw = localStorage.getItem(LKEY); return raw ? JSON.parse(raw) : {}; } catch (e) { return {}; }
  }
  // Grava antes de trocar o estado: se o navegador recusar, nada muda.
  function commitLocal(docs, settings) {
    try {
      localStorage.setItem(LKEY, JSON.stringify({ docs, settings }));
    } catch (e) {
      throw { code: 'local_full', message: 'Este navegador não tem espaço para salvar. Remova fotos ou anúncios antigos.' };
    }
    M.docs = docs;
    M.settings = settings;
    emit();
  }
  function startLocal() {
    const s = readLocal();
    M.mode = 'local';
    M.canManage = true;
    M.docs = (s.docs || []).map(d => cleanListing(d.id, d)).filter(Boolean);
    M.settings = cleanSettings(s.settings);
    M.ready = true;
    emit();
  }

  M.init = async function () {
    const c = window.claude;
    if (!c || typeof c.use !== 'function') { startLocal(); return; }
    let user = null;
    try { [db, user, assets] = await Promise.all([c.use('db'), c.use('user'), c.use('assets')]); } catch (e) { db = null; }
    if (!db) { M.mode = 'readonly'; M.ready = true; emit(); return; }
    M.mode = 'shared';
    try { M.canManage = !!(user && await user.canEdit()); } catch (e) { M.canManage = false; }
    let gotListings = false, gotSettings = false;
    const arrived = () => { M.ready = gotListings && gotSettings; emit(); };
    db.collection('listings').onSnapshot(snap => {
      M.docs = snap.docs.map(d => cleanListing(d.id, d.data())).filter(Boolean);
      gotListings = true;
      arrived();
    }, () => { gotListings = true; arrived(); });
    db.doc('store/settings').onSnapshot(snap => {
      M.settings = cleanSettings(snap.exists ? snap.data() : null);
      gotSettings = true;
      arrived();
    }, () => { gotSettings = true; arrived(); });
  };

  // ---------- Escrita (só quem gerencia a loja) ----------
  const strip = d => { const o = Object.assign({}, d); delete o.id; return o; };

  M.create = async function (data) {
    const now = Date.now();
    const clean = cleanListing('new', Object.assign({}, data, { createdAt: now, updatedAt: now }));
    if (!clean) throw { code: 'invalid', message: 'Confira a carta, a nota e o preço do anúncio.' };
    const body = strip(clean);
    if (M.mode === 'shared') {
      const ref = db.collection('listings').doc();
      await ref.set(body);
      return ref.id;
    }
    const id = 'L' + now.toString(36) + Math.random().toString(36).slice(2, 6);
    commitLocal(M.docs.concat(cleanListing(id, body)), M.settings);
    return id;
  };

  M.update = async function (id, patch) {
    const cur = M.docs.find(d => d.id === id);
    if (!cur) throw { code: 'missing', message: 'Esse anúncio não existe mais.' };
    const next = cleanListing(id, Object.assign({}, cur, patch, { updatedAt: Date.now() }));
    if (M.mode === 'shared') { await db.doc('listings/' + id).set(strip(next)); return; }
    commitLocal(M.docs.map(d => d.id === id ? next : d), M.settings);
  };

  M.remove = async function (id) {
    const cur = M.docs.find(d => d.id === id);
    if (M.mode === 'shared') {
      await db.doc('listings/' + id).delete();
      if (cur) await M.deletePhotos(cur.photos);
      return;
    }
    commitLocal(M.docs.filter(d => d.id !== id), M.settings);
  };

  M.saveSettings = async function (s) {
    const clean = cleanSettings(s);
    if (M.mode === 'shared') { await db.doc('store/settings').set(clean); return; }
    commitLocal(M.docs, clean);
  };

  // ---------- Fotos do slab ----------
  M.canUploadPhotos = () => M.mode === 'local' || !!assets;

  // Reduz a foto no navegador antes de guardar (JPEG).
  M.preparePhoto = function (file) {
    const max = M.mode === 'local' ? 800 : 1400, quality = M.mode === 'local' ? 0.72 : 0.84;
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.onload = () => {
        const s = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(img.naturalWidth * s);
        canvas.height = Math.round(img.naturalHeight * s);
        canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(url);
        canvas.toBlob(b => (b ? resolve(b) : reject({ message: 'Não foi possível processar a foto.' })), 'image/jpeg', quality);
      };
      img.onerror = () => { URL.revokeObjectURL(url); reject({ message: 'Esse arquivo não é uma imagem que o navegador consiga abrir.' }); };
      img.src = url;
    });
  };

  // Devolve o que vai no anúncio: id do asset (link publicado) ou data URL (modo local).
  M.storePhoto = async function (blob) {
    if (M.mode === 'shared') {
      const r = await assets.upload(blob, { type: 'image/jpeg' });
      return r.id;
    }
    return new Promise((resolve, reject) => {
      const fr = new FileReader();
      fr.onload = () => resolve(fr.result);
      fr.onerror = () => reject({ message: 'Não foi possível ler a foto.' });
      fr.readAsDataURL(blob);
    });
  };

  M.deletePhotos = async function (list) {
    if (M.mode !== 'shared' || !assets) return;
    for (const p of list || []) {
      if (ASSET_ID.test(p)) { try { await assets.delete(p); } catch (e) { /* já removida */ } }
    }
  };

  // ---------- Cotação e contato ----------
  M.reference = (card, g) => D.fairPrice(card, g.grader, g.grade, g.special, g.lang);
  // O epsilon evita que 11500 × 0,7 = 8049,999… vire R$ 8.040.
  M.instantOffer = ref => Math.max(0, Math.floor((ref * M.settings.instantRate + 1e-6) / 10) * 10);
  M.consignQuote = ref => {
    const price = D.roundPrice(ref);
    const fee = Math.round(price * M.settings.consignFee);
    return { price, fee, net: price - fee };
  };
  M.waLink = text => (M.settings.whatsapp.length >= 10 ? 'https://wa.me/' + M.settings.whatsapp + '?text=' + encodeURIComponent(text) : '');
  M.certInUse = (cert, exceptId) => !!cert && (D.demoCertTaken(cert) || M.docs.some(d => d.cert === cert && d.id !== exceptId && d.status !== 'sold'));
  M.doc = id => M.docs.find(d => d.id === id) || null;

  GD.market = M;
})(window.GD = window.GD || {});
