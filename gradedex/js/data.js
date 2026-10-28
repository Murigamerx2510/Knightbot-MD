/* GradeDex — catálogo de demonstração.
   Anúncios, preços, certificados, populações e vendas são fictícios e gerados de forma determinística. */
(function (GD) {
  'use strict';

  // ---------- PRNG determinístico ----------
  function hash(str) {
    let h = 2166136261;
    for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }
  function rng(seed) {
    let a = typeof seed === 'string' ? hash(seed) : seed >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const pick = (r, arr) => arr[Math.floor(r() * arr.length)];
  function weighted(r, entries) {
    const total = entries.reduce((s, e) => s + e[1], 0);
    let x = r() * total;
    for (const [v, w] of entries) { if ((x -= w) <= 0) return v; }
    return entries[entries.length - 1][0];
  }
  const norm = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

  // ---------- Referências ----------
  const ERAS = { WotC: 'Vintage WotC', EX: 'EX & POP', SM: 'Sol e Lua', SWSH: 'Espada e Escudo', SV: 'Escarlate e Violeta' };
  const LANGS = { EN: 'Inglês', JP: 'Japonês', PT: 'Português' };

  const TYPES = {
    fire:      { pt: 'Fogo',      a: '#C93E1B', b: '#FFB04A' },
    water:     { pt: 'Água',      a: '#1F67C2', b: '#8FD9F7' },
    grass:     { pt: 'Planta',    a: '#23864A', b: '#B9E58A' },
    lightning: { pt: 'Elétrico',  a: '#D99A06', b: '#FFF08A' },
    psychic:   { pt: 'Psíquico',  a: '#8540BD', b: '#F5A9D8' },
    darkness:  { pt: 'Escuridão', a: '#14232E', b: '#4D8193' },
    colorless: { pt: 'Incolor',   a: '#8D92A6', b: '#F2F2F7' },
    dragon:    { pt: 'Dragão',    a: '#4E6B22', b: '#D8B447' },
    metal:     { pt: 'Metal',     a: '#6D7889', b: '#DEE4EB' },
  };

  const SETS = [
    { id: 'bs',   name: 'Base Set',             year: 1999, era: 'WotC' },
    { id: 'jun',  name: 'Jungle',               year: 1999, era: 'WotC' },
    { id: 'fos',  name: 'Fossil',               year: 1999, era: 'WotC' },
    { id: 'neo1', name: 'Neo Genesis',          year: 2000, era: 'WotC' },
    { id: 'neo4', name: 'Neo Destiny',          year: 2002, era: 'WotC' },
    { id: 'dx',   name: 'EX Deoxys',            year: 2005, era: 'EX' },
    { id: 'pop5', name: 'POP Series 5',         year: 2007, era: 'EX' },
    { id: 'hif',  name: 'Hidden Fates',         pt: 'Destinos Ocultos',      year: 2019, era: 'SM' },
    { id: 'viv',  name: 'Vivid Voltage',        pt: 'Voltagem Vívida',       year: 2020, era: 'SWSH' },
    { id: 'evs',  name: 'Evolving Skies',       pt: 'Céus em Evolução',      year: 2021, era: 'SWSH' },
    { id: 'fst',  name: 'Fusion Strike',        pt: 'Golpe Fusão',           year: 2021, era: 'SWSH' },
    { id: 'brs',  name: 'Brilliant Stars',      pt: 'Astros Cintilantes',    year: 2022, era: 'SWSH' },
    { id: 'lor',  name: 'Lost Origin',          pt: 'Origem Perdida',        year: 2022, era: 'SWSH' },
    { id: 'sit',  name: 'Silver Tempest',       pt: 'Tempestade Prateada',   year: 2022, era: 'SWSH' },
    { id: 'crz',  name: 'Crown Zenith',         pt: 'Realeza Absoluta',      year: 2023, era: 'SWSH' },
    { id: 'obf',  name: 'Obsidian Flames',      pt: 'Obsidiana em Chamas',   year: 2023, era: 'SV' },
    { id: 'mew',  name: '151',                  pt: 'Escarlate e Violeta 151', year: 2023, era: 'SV' },
    { id: 'svp',  name: 'SV Black Star Promos', pt: 'Promos Escarlate e Violeta', year: 2023, era: 'SV' },
    { id: 'ssp',  name: 'Surging Sparks',       pt: 'Fagulhas Impetuosas',   year: 2024, era: 'SV' },
    { id: 'pre',  name: 'Prismatic Evolutions', pt: 'Evoluções Prismáticas', year: 2025, era: 'SV' },
  ];

  // ref = preço de referência em R$ para a nota máxima PSA (10) em inglês.
  // trend = variação desejada nas últimas 4 semanas (%); pop = população PSA aproximada.
  const CARDS = [
    { id: 'charizard-base-1ed', name: 'Charizard', variant: '1ª Edição Shadowless', set: 'bs', num: '4/102', rarity: 'Holo Rara', type: 'fire', hp: 120, ref: 2400000, trend: 3.8, pop: 3600, maxGrade: 9, langs: ['EN'] },
    { id: 'charizard-base',     name: 'Charizard',         set: 'bs',   num: '4/102',     rarity: 'Holo Rara', type: 'fire',      hp: 120, ref: 72000, trend: 2.1,  pop: 21000 },
    { id: 'blastoise-base',     name: 'Blastoise',         set: 'bs',   num: '2/102',     rarity: 'Holo Rara', type: 'water',     hp: 100, ref: 19000, trend: -1.4, pop: 14500 },
    { id: 'venusaur-base',      name: 'Venusaur',          set: 'bs',   num: '15/102',    rarity: 'Holo Rara', type: 'grass',     hp: 100, ref: 13500, trend: 0.8,  pop: 12800 },
    { id: 'mewtwo-base',        name: 'Mewtwo',            set: 'bs',   num: '10/102',    rarity: 'Holo Rara', type: 'psychic',   hp: 60,  ref: 6800,  trend: -2.6, pop: 11200 },
    { id: 'gyarados-base',      name: 'Gyarados',          set: 'bs',   num: '6/102',     rarity: 'Holo Rara', type: 'water',     hp: 100, ref: 4200,  trend: 1.2,  pop: 8100 },
    { id: 'pikachu-base',       name: 'Pikachu',           set: 'bs',   num: '58/102',    rarity: 'Comum',     type: 'lightning', hp: 40,  ref: 1900,  trend: 4.5,  pop: 16400 },
    { id: 'scyther-jungle',     name: 'Scyther',           set: 'jun',  num: '10/64',     rarity: 'Holo Rara', type: 'grass',     hp: 70,  ref: 2600,  trend: -0.6, pop: 5200 },
    { id: 'dragonite-fossil',   name: 'Dragonite',         set: 'fos',  num: '4/62',      rarity: 'Holo Rara', type: 'colorless', hp: 100, ref: 5900,  trend: 1.9,  pop: 6900 },
    { id: 'lugia-neo',          name: 'Lugia',             set: 'neo1', num: '9/111',     rarity: 'Holo Rara', type: 'psychic',   hp: 90,  ref: 34000, trend: 5.2,  pop: 7400 },
    { id: 'typhlosion-neo',     name: 'Typhlosion',        set: 'neo1', num: '17/111',    rarity: 'Holo Rara', type: 'fire',      hp: 100, ref: 6500,  trend: -1.1, pop: 4100 },
    { id: 'shining-charizard',  name: 'Shining Charizard', set: 'neo4', num: '107/105',   rarity: 'Shining',   type: 'fire',      hp: 100, ref: 68000, trend: 2.7,  pop: 5300 },
    { id: 'rayquaza-star',      name: 'Rayquaza ★',        set: 'dx',   num: '107/107',   rarity: 'Gold Star', type: 'dragon',    hp: 100, ref: 46000, trend: 1.5,  pop: 2100, langs: ['EN'] },
    { id: 'umbreon-star',       name: 'Umbreon ★',         set: 'pop5', num: '17/17',     rarity: 'Gold Star', type: 'darkness',  hp: 70,  ref: 58000, trend: 6.9,  pop: 1800, langs: ['EN'] },
    { id: 'charizard-gx-sv49',  name: 'Charizard GX',      set: 'hif',  num: 'SV49/SV94', rarity: 'Shiny',     type: 'fire',      hp: 250, ref: 2100,  trend: -3.2, pop: 21000 },
    { id: 'pikachu-vmax-rainbow', name: 'Pikachu VMAX',    set: 'viv',  num: '188/185',   rarity: 'Secreta',   type: 'lightning', hp: 310, ref: 1700,  trend: 0.4,  pop: 9800, rainbow: true },
    { id: 'umbreon-vmax-alt',   name: 'Umbreon VMAX',      set: 'evs',  num: '215/203',   rarity: 'Alt Art',   type: 'darkness',  hp: 310, ref: 11500, trend: 6.1,  pop: 26000 },
    { id: 'rayquaza-vmax-alt',  name: 'Rayquaza VMAX',     set: 'evs',  num: '218/203',   rarity: 'Alt Art',   type: 'dragon',    hp: 320, ref: 5200,  trend: 2.4,  pop: 19500 },
    { id: 'sylveon-vmax-alt',   name: 'Sylveon VMAX',      set: 'evs',  num: '212/203',   rarity: 'Alt Art',   type: 'psychic',   hp: 310, ref: 2600,  trend: -0.9, pop: 11800 },
    { id: 'glaceon-vmax-alt',   name: 'Glaceon VMAX',      set: 'evs',  num: '209/203',   rarity: 'Alt Art',   type: 'water',     hp: 310, ref: 3100,  trend: 1.1,  pop: 10400 },
    { id: 'gengar-vmax-alt',    name: 'Gengar VMAX',       set: 'fst',  num: '271/264',   rarity: 'Alt Art',   type: 'darkness',  hp: 320, ref: 3400,  trend: 3.3,  pop: 12100 },
    { id: 'espeon-vmax-alt',    name: 'Espeon VMAX',       set: 'fst',  num: '270/264',   rarity: 'Alt Art',   type: 'psychic',   hp: 310, ref: 3000,  trend: 0.2,  pop: 9700 },
    { id: 'charizard-v-alt',    name: 'Charizard V',       set: 'brs',  num: '154/172',   rarity: 'Alt Art',   type: 'fire',      hp: 220, ref: 2300,  trend: -1.8, pop: 17600 },
    { id: 'giratina-v-alt',     name: 'Giratina V',        set: 'lor',  num: '186/196',   rarity: 'Alt Art',   type: 'dragon',    hp: 220, ref: 4100,  trend: 4.0,  pop: 15900 },
    { id: 'lugia-v-alt',        name: 'Lugia V',           set: 'sit',  num: '186/195',   rarity: 'Alt Art',   type: 'colorless', hp: 220, ref: 2900,  trend: 1.6,  pop: 14300 },
    { id: 'giratina-vstar-gold', name: 'Giratina VSTAR',   set: 'crz',  num: 'GG69/GG70', rarity: 'Secreta',   type: 'dragon',    hp: 280, ref: 1500,  trend: -2.2, pop: 13200, gold: true },
    { id: 'charizard-ex-obf',   name: 'Charizard ex',      set: 'obf',  num: '223/197',   rarity: 'SIR',       type: 'darkness',  hp: 330, ref: 1700,  trend: -4.1, pop: 18700 },
    { id: 'charizard-ex-151',   name: 'Charizard ex',      set: 'mew',  num: '199/165',   rarity: 'SIR',       type: 'fire',      hp: 330, ref: 2600,  trend: 1.3,  pop: 24500 },
    { id: 'mew-ex-gold',        name: 'Mew ex',            set: 'mew',  num: '205/165',   rarity: 'Secreta',   type: 'psychic',   hp: 180, ref: 950,   trend: 0.7,  pop: 15200, gold: true },
    { id: 'pikachu-grey-felt',  name: 'Pikachu with Grey Felt Hat', set: 'svp', num: '085', rarity: 'Promo', type: 'lightning', hp: 60, ref: 3300, trend: -5.4, pop: 64000, langs: ['EN'] },
    { id: 'pikachu-ex-ssp',     name: 'Pikachu ex',        set: 'ssp',  num: '238/191',   rarity: 'SIR',       type: 'lightning', hp: 200, ref: 2400,  trend: 3.7,  pop: 16800 },
    { id: 'umbreon-ex-pre',     name: 'Umbreon ex',        set: 'pre',  num: '161/131',   rarity: 'SIR',       type: 'darkness',  hp: 280, ref: 7900,  trend: 8.4,  pop: 21500 },
    { id: 'sylveon-ex-pre',     name: 'Sylveon ex',        set: 'pre',  num: '156/131',   rarity: 'SIR',       type: 'psychic',   hp: 270, ref: 2200,  trend: 2.9,  pop: 12900 },
  ];

  // Id de cada carta no pokemontcg.io, de onde tools/baixar_scans.py baixa os scans.
  const PTCG = {
    'charizard-base-1ed': 'base1-4', 'charizard-base': 'base1-4', 'blastoise-base': 'base1-2', 'venusaur-base': 'base1-15',
    'mewtwo-base': 'base1-10', 'gyarados-base': 'base1-6', 'pikachu-base': 'base1-58', 'scyther-jungle': 'base2-10',
    'dragonite-fossil': 'base3-4', 'lugia-neo': 'neo1-9', 'typhlosion-neo': 'neo1-17', 'shining-charizard': 'neo4-107',
    'rayquaza-star': 'ex8-107', 'umbreon-star': 'pop5-17', 'charizard-gx-sv49': 'sma-SV49', 'pikachu-vmax-rainbow': 'swsh4-188',
    'umbreon-vmax-alt': 'swsh7-215', 'rayquaza-vmax-alt': 'swsh7-218', 'sylveon-vmax-alt': 'swsh7-212', 'glaceon-vmax-alt': 'swsh7-209',
    'gengar-vmax-alt': 'swsh8-271', 'espeon-vmax-alt': 'swsh8-270', 'charizard-v-alt': 'swsh9-154', 'giratina-v-alt': 'swsh11-186',
    'lugia-v-alt': 'swsh12-186', 'giratina-vstar-gold': 'swsh12pt5gg-GG69', 'charizard-ex-obf': 'sv3-223', 'charizard-ex-151': 'sv3pt5-199',
    'mew-ex-gold': 'sv3pt5-205', 'pikachu-grey-felt': 'svp-85', 'pikachu-ex-ssp': 'sv8-238', 'umbreon-ex-pre': 'sv8pt5-161',
    'sylveon-ex-pre': 'sv8pt5-156',
  };
  const SCAN_NOTES = {
    'charizard-base-1ed': 'Scan da versão Unlimited. A 1ª Edição tem o selo Edition 1 e a moldura da arte sem sombra.',
  };

  const RARITY_LOOK = {
    'Holo Rara': { foil: true }, 'Comum': {}, 'Shining': { foil: true }, 'Gold Star': { foil: true, gold: true },
    'Shiny': { full: true, foil: true }, 'Secreta': { full: true, foil: true }, 'Alt Art': { full: true },
    'SIR': { full: true, foil: true }, 'Promo': {},
  };

  const SELLERS = [
    { id: 'cofre-paulista',  name: 'Cofre Paulista',       city: 'São Paulo',      uf: 'SP', rating: 4.97, reviews: 3120, sales: 8740, since: 2017, verified: true,  ships: 1, ship: 32 },
    { id: 'sem-sombra',      name: 'Sem Sombra',           city: 'São Paulo',      uf: 'SP', rating: 4.98, reviews: 1660, sales: 2950, since: 2016, verified: true,  ships: 1, ship: 32, focus: 'vintage' },
    { id: 'kanto-graded',    name: 'Kanto Graded',         city: 'Curitiba',       uf: 'PR', rating: 4.95, reviews: 2210, sales: 5610, since: 2018, verified: true,  ships: 1, ship: 34 },
    { id: 'slab-co-rio',     name: 'Slab & Co. Rio',       city: 'Rio de Janeiro', uf: 'RJ', rating: 4.91, reviews: 1480, sales: 3920, since: 2019, verified: true,  ships: 2, ship: 36 },
    { id: 'gema-rara',       name: 'Gema Rara',            city: 'Campinas',       uf: 'SP', rating: 4.99, reviews: 910,  sales: 2280, since: 2021, verified: true,  ships: 1, ship: 29 },
    { id: 'treinador-mineiro', name: 'Treinador Mineiro',  city: 'Belo Horizonte', uf: 'MG', rating: 4.88, reviews: 640,  sales: 1730, since: 2020, verified: true,  ships: 2, ship: 33 },
    { id: 'pallet-colecionaveis', name: 'Pallet Colecionáveis', city: 'Porto Alegre', uf: 'RS', rating: 4.9, reviews: 1150, sales: 3170, since: 2018, verified: true, ships: 2, ship: 39 },
    { id: 'johto-store',     name: 'Johto Store',          city: 'Fortaleza',      uf: 'CE', rating: 4.93, reviews: 730,  sales: 1880, since: 2019, verified: true,  ships: 2, ship: 46 },
    { id: 'nordeste-slabs',  name: 'Nordeste Slabs',       city: 'Recife',         uf: 'PE', rating: 4.86, reviews: 520,  sales: 1390, since: 2020, verified: true,  ships: 2, ship: 44 },
    { id: 'ilha-holo',       name: 'Ilha Holo',            city: 'Florianópolis',  uf: 'SC', rating: 4.84, reviews: 380,  sales: 1040, since: 2021, verified: false, ships: 3, ship: 38 },
    { id: 'cerrado-cards',   name: 'Cerrado Cards',        city: 'Brasília',       uf: 'DF', rating: 4.79, reviews: 260,  sales: 690,  since: 2022, verified: false, ships: 3, ship: 41 },
    { id: 'prisma-goiano',   name: 'Prisma Goiano',        city: 'Goiânia',        uf: 'GO', rating: 4.82, reviews: 190,  sales: 470,  since: 2023, verified: false, ships: 3, ship: 40 },
  ];

  // ---------- Notas ----------
  const GRADERS = ['PSA', 'BGS', 'CGC', 'TAG'];
  const GRADES = { PSA: [10, 9, 8, 7, 6], BGS: [10, 9.5, 9, 8.5, 8], CGC: [10, 9.5, 9, 8.5, 8], TAG: [10, 9, 8.5, 8] };
  const GRADE_NAMES = {
    PSA: { 10: 'Gem Mint', 9: 'Mint', 8: 'NM-MT', 7: 'Near Mint', 6: 'EX-MT' },
    BGS: { 10: 'Pristine', 9.5: 'Gem Mint', 9: 'Mint', 8.5: 'NM-MT+', 8: 'NM-MT', 7: 'Near Mint', 6: 'EX-MT' },
    CGC: { 10: 'Gem Mint', 9.5: 'Mint+', 9: 'Mint', 8.5: 'NM/Mint+', 8: 'NM/Mint', 7: 'Near Mint', 6: 'Ex/NM' },
    TAG: { 10: 'Gem Mint', 9: 'Mint', 8.5: 'NM-MT+', 8: 'NM-MT', 7: 'Near Mint', 6: 'EX-MT' },
  };
  // Notas aceitas nos formulários de venda (as mesmas do pop report).
  const SELL_GRADES = { PSA: [10, 9, 8, 7, 6], BGS: [10, 9.5, 9, 8.5, 8, 7, 6], CGC: [10, 9.5, 9, 8.5, 8, 7, 6], TAG: [10, 9, 8.5, 8, 7, 6] };
  const W_MODERN  = { 10: 46, 9.5: 20, 9: 22, 8.5: 5, 8: 5, 7: 2, 6: 1 };
  const W_VINTAGE = { 10: 6, 9.5: 7, 9: 30, 8.5: 12, 8: 24, 7: 14, 6: 7 };
  const MULT_MODERN  = { 10: 1, 9.5: .58, 9: .38, 8.5: .3, 8: .26, 7: .2, 6: .16 };
  const MULT_VINTAGE = { 10: 1, 9.5: .38, 9: .14, 8.5: .085, 8: .055, 7: .036, 6: .026 };

  const SET = {}, CARD = {}, SELLER = {};
  SETS.forEach(s => { SET[s.id] = s; });
  SELLERS.forEach(s => { SELLER[s.id] = s; });
  CARDS.forEach(c => {
    const set = SET[c.set];
    c.year = set.year;
    c.era = set.era;
    c.vintage = set.era === 'WotC' || set.era === 'EX';
    c.top = c.maxGrade || 10;
    c.look = Object.assign({ rim: set.era === 'SV' ? 'silver' : 'yellow' }, RARITY_LOOK[c.rarity]);
    if (c.gold) Object.assign(c.look, { gold: true, palette: { a: '#8E6A1C', b: '#F7DE86' } });
    if (c.rainbow) c.look.palette = { a: '#C9479F', b: '#86E3F2' };
    if (c.look.gold) c.look.rim = 'gold';
    c.ptcg = PTCG[c.id];
    c.scan = !!(GD.SCANS && GD.SCANS[c.id]);
    c.scanNote = SCAN_NOTES[c.id] || '';
    CARD[c.id] = c;
  });

  const fmtGrade = g => String(g);
  function gradeName(l) {
    if (l.special === 'bl') return 'Black Label';
    if (l.special === 'pristine') return 'Pristine';
    return GRADE_NAMES[l.grader][l.grade] || '';
  }
  function gradeKey(l) {
    let k = l.grader + ' ' + fmtGrade(l.grade);
    if (l.special === 'bl') k += ' Black Label';
    else if (l.special === 'pristine' && l.grader !== 'BGS') k += ' Pristine';
    return k;
  }
  // Ordenação: nota maior primeiro; Black Label/Pristine acima do 10 comum.
  const gradeScore = l => l.grade + (l.special === 'bl' ? .4 : l.special === 'pristine' ? .2 : 0);

  function fairPrice(card, grader, grade, special, lang) {
    let p = card.ref * (card.vintage ? MULT_VINTAGE : MULT_MODERN)[grade];
    if (grader === 'BGS') p *= special === 'bl' ? 2.4 : special === 'pristine' ? 1.25 : .92;
    else if (grader === 'CGC') p *= special === 'pristine' ? 1.1 : .74;
    else if (grader === 'TAG') p *= special === 'pristine' ? .95 : .7;
    if (lang === 'JP') p *= card.vintage ? .55 : .82;
    if (lang === 'PT') p *= .48;
    return p;
  }
  function roundPrice(p) {
    const step = p >= 20000 ? 100 : p >= 2000 ? 10 : 5;
    return Math.max(step, Math.round(p / step) * step);
  }

  function subgrades(r, grade) {
    if (grade === 10) {
      if (r() < 0.35) return [10, 10, 10, 10];
      const s = [10, 10, 10, 10];
      s[Math.floor(r() * 4)] = 9.5;
      return s;
    }
    return [0, 1, 2, 3].map(() => Math.min(10, Math.max(grade - 0.5, grade + pick(r, [-0.5, 0, 0, 0.5]))));
  }
  function certNo(r, grader) {
    const d = n => { let s = ''; for (let i = 0; i < n; i++) s += Math.floor(r() * 10); return s; };
    if (grader === 'PSA') return String(4 + Math.floor(r() * 6)) + d(7);
    if (grader === 'BGS') return '00' + String(1 + Math.floor(r() * 9)) + d(7);
    if (grader === 'CGC') return '4' + d(9);
    return 'T' + d(8);
  }

  // ---------- Anúncios ----------
  // DEMO: lojas fictícias geradas aqui. Os anúncios da loja oficial chegam por setMarket().
  const DEMO = [];
  const LISTINGS = [], LISTING = {}, BY_CARD = {}, BY_CERT = {};
  CARDS.forEach(card => {
    const r = rng('lst:' + card.id);
    const n = 4 + Math.floor(r() * 6);
    const langs = card.langs || (card.vintage ? ['EN', 'EN', 'EN', 'EN', 'JP'] : ['EN', 'EN', 'EN', 'JP', 'JP', 'PT']);
    const W = card.vintage ? W_VINTAGE : W_MODERN;
    for (let i = 0; i < n; i++) {
      // O primeiro anúncio de cada carta é sempre PSA na nota máxima, em inglês.
      const grader = i === 0 ? 'PSA' : weighted(r, [['PSA', 50], ['BGS', 17], ['CGC', 23], ['TAG', 10]]);
      const options = GRADES[grader].filter(g => g <= card.top);
      const grade = i === 0 ? card.top : weighted(r, options.map(g => [g, W[g]]));
      let special = null, subs = null;
      if (grader === 'BGS') {
        subs = subgrades(r, grade);
        if (grade === 10) special = subs.every(s => s === 10) ? 'bl' : 'pristine';
      }
      if ((grader === 'CGC' || grader === 'TAG') && grade === 10 && r() < 0.3) special = 'pristine';
      const lang = i === 0 ? 'EN' : pick(r, langs);
      const seller = card.vintage && r() < 0.35 ? SELLER['sem-sombra'] : pick(r, SELLERS);
      const ref = fairPrice(card, grader, grade, special, lang);
      const l = {
        id: card.id + '-' + i,
        card: card.id,
        grader, grade, special, subs, lang,
        seller: seller.id,
        price: roundPrice(ref * (0.88 + r() * 0.26)),
        ref: roundPrice(ref),
        cert: certNo(r, grader),
        days: Math.floor(r() * 40),
        offer: r() < 0.3,
      };
      DEMO.push(l);
    }
  });

  // Loja da casa: nome, cidade e prazos vêm das configurações do painel.
  const HOUSE = { id: 'gradedex', name: 'GradeDex', city: '', uf: '', rating: null, reviews: 0, sales: 0, since: new Date().getFullYear(), verified: true, official: true, ships: 1, ship: 30 };
  SELLER.gradedex = HOUSE;
  let showDemo = true;

  // Reconstrói os índices no lugar, para que as referências exportadas continuem válidas.
  function index(list) {
    LISTINGS.length = 0;
    [LISTING, BY_CARD, BY_CERT].forEach(o => Object.keys(o).forEach(k => { delete o[k]; }));
    CARDS.forEach(c => { BY_CARD[c.id] = []; });
    list.forEach(l => {
      LISTINGS.push(l);
      LISTING[l.id] = l;
      BY_CARD[l.card].push(l);
      BY_CERT[l.cert] = l;
    });
    CARDS.forEach(c => BY_CARD[c.id].sort((a, b) => a.price - b.price));
  }
  function setMarket(own, settings) {
    settings = settings || {};
    Object.assign(HOUSE, {
      name: settings.storeName || 'GradeDex', city: settings.city || '', uf: settings.uf || '',
      ships: settings.ships || 1, ship: settings.ship || 30, sales: settings.sold || 0,
    });
    showDemo = settings.showDemo !== false;
    index((showDemo ? DEMO : []).concat(own || []));
  }
  index(DEMO);

  // ---------- Histórico semanal (52 semanas) ----------
  const histCache = {};
  function history(card, grader, grade, special) {
    const key = [card.id, grader, grade, special || ''].join(':');
    if (histCache[key]) return histCache[key];
    const r = rng('h:' + key);
    const weeks = 52;
    const end = fairPrice(card, grader, grade, special, 'EN');
    const recent = card.trend / 100 / 4;
    const longDrift = r() * 0.014 - 0.004;
    const prices = new Array(weeks);
    prices[weeks - 1] = end;
    for (let i = weeks - 2; i >= 0; i--) {
      const late = i >= weeks - 5;
      const drift = late ? recent : longDrift;
      const noise = (r() - 0.5) * (late ? 0.012 : 0.06);
      prices[i] = prices[i + 1] / (1 + drift + noise);
    }
    const now = new Date();
    now.setHours(12, 0, 0, 0);
    const pts = prices.map((p, i) => ({
      t: new Date(now.getTime() - (weeks - 1 - i) * 7 * 864e5),
      p: roundPrice(p),
      n: 1 + Math.floor(r() * (card.vintage ? 4 : 9)),
    }));
    return (histCache[key] = pts);
  }
  const change = (pts, weeksBack) => {
    const a = pts[Math.max(0, pts.length - 1 - weeksBack)].p, b = pts[pts.length - 1].p;
    return (b / a - 1) * 100;
  };
  CARDS.forEach(c => {
    const h = history(c, 'PSA', c.top, null);
    c.market = h[h.length - 1].p;
    c.trend30 = change(h, 4);
    c.trend1y = change(h, 51);
  });

  // ---------- Pop report ----------
  const POP_GRADES = { PSA: [10, 9, 8, 7, 6], BGS: [10, 9.5, 9, 8.5, 8, 7, 6], CGC: [10, 9.5, 9, 8.5, 8, 7, 6], TAG: [10, 9, 8.5, 8, 7, 6] };
  const popCache = {};
  function popReport(card) {
    if (popCache[card.id]) return popCache[card.id];
    const r = rng('pop:' + card.id);
    const gem = card.vintage ? 0.012 + r() * 0.045 : 0.36 + r() * 0.28;
    const curve = card.vintage
      ? { 10: gem, 9.5: .03, 9: .19, 8.5: .09, 8: .26, 7: .17, 6: .09 }
      : { 10: gem, 9.5: .17, 9: .2, 8.5: .04, 8: .06, 7: .025, 6: .012 };
    const share = card.vintage ? { PSA: 1, BGS: .16, CGC: .12, TAG: .02 } : { PSA: 1, BGS: .12, CGC: .34, TAG: .07 };
    const out = {};
    GRADERS.forEach(g => {
      const total = Math.max(12, Math.round(card.pop * share[g] * (0.85 + r() * 0.3)));
      const list = POP_GRADES[g];
      const w = {};
      list.forEach(x => { w[x] = curve[x]; });
      if (!list.includes(9.5)) w[9] += curve[9.5];
      if (!list.includes(8.5)) w[8] += curve[8.5];
      if (g === 'BGS') { w[9.5] += w[10] * 0.9; w[10] *= 0.1; } // na BGS, 9.5 é a nota "gem" comum
      const sum = list.reduce((s, x) => s + w[x], 0);
      const low = Math.max(0.03, 1 - sum);
      const scale = (1 - low) / sum;
      const rows = list.map(x => ({ grade: x, count: Math.round(total * w[x] * scale) }));
      rows.push({ grade: '≤5', count: Math.max(0, total - rows.reduce((s, x) => s + x.count, 0)) });
      const bl = g === 'BGS' ? Math.round(rows[0].count * (card.vintage ? 0.04 : 0.11)) : 0;
      out[g] = { total, rows, gemRate: rows[0].count / total, blackLabel: bl };
    });
    return (popCache[card.id] = out);
  }

  // ---------- Vendas recentes (exemplos) ----------
  function recentSales() {
    const r = rng('sales');
    const out = [];
    let mins = 2;
    for (let i = 0; i < 14; i++) {
      const card = pick(r, CARDS);
      const grader = weighted(r, [['PSA', 60], ['CGC', 22], ['BGS', 18]]);
      const options = GRADES[grader].filter(g => g <= card.top && g >= 8);
      const grade = pick(r, options);
      out.push({ card: card.id, grader, grade, special: null, price: roundPrice(fairPrice(card, grader, grade, null, 'EN') * (0.95 + r() * 0.1)), mins });
      mins += 3 + Math.floor(r() * 17);
    }
    return out;
  }

  // ---------- Busca ----------
  CARDS.forEach(c => {
    const s = SET[c.set];
    c.search = norm([c.name, c.variant, s.name, s.pt, c.num, c.rarity, TYPES[c.type].pt, ERAS[c.era], c.year].join(' '));
  });
  function matchCards(q) {
    const terms = norm(q).split(/\s+/).filter(Boolean);
    if (!terms.length) return CARDS.slice();
    return CARDS.filter(c => terms.every(t => c.search.includes(t)));
  }
  const findCert = q => BY_CERT[String(q || '').trim().toUpperCase()] || null;
  const DEMO_CERTS = new Set(DEMO.map(l => l.cert));

  // Slab só para exibição (carta sem anúncio): PSA na nota máxima, sem certificado.
  const refListing = card => ({
    id: '', card: card.id, grader: 'PSA', grade: card.top, special: null, subs: null, lang: 'EN',
    cert: '', price: card.market, ref: card.market, seller: null, pseudo: true,
  });

  GD.data = {
    ERAS, LANGS, TYPES, SETS, SET, CARDS, CARD, SELLERS, SELLER, LISTINGS, LISTING, HOUSE,
    GRADERS, GRADES, GRADE_NAMES, SELL_GRADES,
    listingsOf: id => BY_CARD[id] || [],
    gradeName, gradeKey, gradeScore, fmtGrade, fairPrice, roundPrice, refListing,
    history, change, popReport, recentSales, matchCards, findCert, norm, rng, hash,
    setMarket, showingDemo: () => showDemo, demoCertTaken: c => DEMO_CERTS.has(c),
  };
})(window.GD = window.GD || {});
