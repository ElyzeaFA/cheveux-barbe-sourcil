// Test de l'interface elyzea_k9 (Chromium headless, données du jeu simulées)
// NODE_PATH=$(npm root -g) node tests/ui_k9.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };

const skillsPolice = [
  { id: 'sniff', label: 'Reniflage', levels: ['Détection basique.', 'Meilleure détection.', 'Meilleure précision.', 'Plus rapide.', 'Maximale.'] },
  { id: 'obey', label: 'Obéissance', levels: ['Hésite.', 'Meilleure réponse.', 'Maîtrise.', 'Rapide.', 'Excellente.'] },
  { id: 'attack', label: 'Attaque', levels: ['Hésitante.', 'Réactive.', 'Maîtrise.', 'Efficace.', 'Très performante.'] },
  { id: 'track', label: 'Pistage', levels: ['Difficile.', 'Meilleure.', 'Précise.', 'Rapide.', 'Très performante.'] },
];
const DATA = {
  ok: true, keys: { menu: 'O', target: 'I' },
  sides: [{ side: 'police', info: { group: 'police' }, duty: true, dog: null }, { side: 'gang', info: { group: 'ballas', groupLabel: 'Ballas' }, duty: true, dog: null }],
  breeds: [
    { id: 'shepherd', label: 'Berger allemand', model: 'a_c_shepherd', desc: 'Polyvalent.', traits: { flair: 4, vitesse: 4, puissance: 4, endurance: 5 }, sides: { police: true, gang: true }, available: true },
    { id: 'labrador', label: 'Labrador', model: 'a_c_retriever', desc: 'Flair exceptionnel.', traits: { flair: 5, vitesse: 4, puissance: 2, endurance: 4 }, sides: { police: true }, available: true },
    { id: 'malinois', label: 'Berger malinois', model: 'a_c_malinois', addon: true, desc: 'Explosif.', traits: { flair: 4, vitesse: 5, puissance: 4, endurance: 5 }, sides: { police: true, gang: true }, available: false },
    { id: 'chop', label: 'Rottweiler « lignée de rue »', model: 'a_c_chop', desc: 'Nerveux.', traits: { flair: 3, vitesse: 4, puissance: 4, endurance: 4 }, sides: { gang: true }, available: true },
  ],
  specialties: [
    { id: 'detection', label: 'Détection de stupéfiants', icon: '👃', main: 'sniff', desc: 'Personnes, véhicules, zones.', caps: { sniff: 5, obey: 5, track: 3, attack: 2 } },
    { id: 'attack', label: 'Attaque et intervention', icon: '⚡', main: 'attack', desc: 'Intimidation, attaque.', caps: { sniff: 2, obey: 5, track: 3, attack: 5 } },
    { id: 'tracking', label: 'Recherche et pistage', icon: '🧭', main: 'track', desc: 'Pistage.', caps: { sniff: 3, obey: 5, track: 5, attack: 2 } },
  ],
  skills: { police: skillsPolice, gang: [{ id: 'attack', label: 'Attaque', levels: ['a', 'b', 'c', 'd', 'e'] }, { id: 'defense', label: 'Défense', levels: ['a', 'b', 'c', 'd', 'e'] }, { id: 'intim', label: 'Intimidation', levels: ['a', 'b', 'c', 'd', 'e'] }] },
  orders: [
    { id: 'follow', label: 'Au pied (suivre)', target: 'none' }, { id: 'stay', label: 'Reste', target: 'none' }, { id: 'sit', label: 'Assis', target: 'none' },
    { id: 'search', label: 'Fouiller la zone', target: 'none', police: true }, { id: 'defend', label: 'Défends-moi', target: 'none' },
    { id: 'sniffp', label: 'Renifler la personne', target: 'player', police: true }, { id: 'sniffv', label: 'Renifler le véhicule', target: 'vehicle', police: true },
    { id: 'intim', label: 'Intimider', target: 'player' }, { id: 'attack', label: 'Attaquer', target: 'player' }, { id: 'track', label: 'Pister', target: 'player', police: true },
  ],
};
function makeDog(name, side) {
  return { id: 1, side, name, breed: 'labrador', specialty: side === 'police' ? 'detection' : null, level: 7, xp: 140, xpNext: 210, maxLevel: 30, points: 3, health: 92, injured: 0, active: true,
    skills: [{ id: 'sniff', label: 'Reniflage', level: 3, cap: 5, cost: 3, levels: skillsPolice[0].levels, trained: 4 }, { id: 'obey', label: 'Obéissance', level: 2, cap: 5, cost: 2, levels: skillsPolice[1].levels, trained: 2 },
      { id: 'attack', label: 'Attaque', level: 2, cap: 2, levels: skillsPolice[2].levels, trained: 0 }, { id: 'track', label: 'Pistage', level: 1, cap: 3, cost: 1, levels: skillsPolice[3].levels, trained: 1 }],
    exercises: [{ id: 'obey', label: 'Obéissance', skill: 'obey', desc: 'Enchaîne les ordres.', seconds: 60, xp: 55, wait: 0 }, { id: 'sniff', label: 'Reniflage', skill: 'sniff', desc: 'Trois leurres.', seconds: 120, xp: 39, wait: 240 }],
    history: [{ kind: 'mission', label: 'Stupéfiants détectés sur une personne', xp: 60, ts: 1800000000 }, { kind: 'level', label: 'Niveau 7 atteint', xp: 0, ts: 1799999000 }],
    missions: { sniff: 5, takedown: 1, found: 2 }, trainXp: 120, missionXp: 300, trainCap: 700, missionCap: 900 };
}

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.evaluate(() => {
    window.__calls = [];
    window.__k9mock = async (name, data) => {
      window.__calls.push([name, data]);
      if (name === 'create') return data.name && data.name.length >= 2 ? { ok: true, dog: window.__dog(data.name, data.side) } : { ok: false, error: 'Nom : 2 à 18 caractères.' };
      if (name === 'upgrade') { const d = window.__cur; const s = d.skills.find(x => x.id === data.skill); s.level++; d.points -= s.cost; s.cost = s.level < s.cap ? s.level : null; return { ok: true, dog: JSON.parse(JSON.stringify(d)) }; }
      return {};
    };
  });
  await p.exposeFunction('__dogJson', (n, s) => JSON.stringify(makeDog(n, s)));
  await p.evaluate(() => { window.__dog = (n, s) => { const d = { name: n, side: s }; return d; }; });
  // remplace __dog par une version synchrone à partir des données Node
  await p.evaluate((dogStr) => { window.__dog = (n, s) => { const d = JSON.parse(dogStr); d.name = n; d.side = s; d.specialty = s === 'police' ? 'detection' : null; window.__cur = d; return JSON.parse(JSON.stringify(d)); }; }, JSON.stringify(makeDog('X', 'police')));
  const shot = (n) => p.screenshot({ path: path.join(out, `k9_${n}.png`) });
  const send = (action, data) => p.evaluate(([a, d]) => window.postMessage({ action: a, data: d }, '*'), [action, data]);
  const wait = (ms = 250) => p.waitForTimeout(ms);

  console.log('— Création (police)');
  await send('open', DATA); await wait();
  check(await p.isVisible('#menu.side'), 'pas de chien : panneau latéral (aperçu réel du modèle à gauche)');
  check((await p.textContent('#title')).includes('Unité cynophile') && await p.$$eval('#sides button', x => x.length) === 2, 'police + groupe : choix du côté');
  check(await p.$$eval('.breed', x => x.length) === 3, 'races de la police (pas la race réservée aux gangs)');
  check(await p.$('.breed.na[disabled]') !== null && (await p.textContent('.breed.na')).includes('non installé'), 'modèle addon absent : grisé');
  check((await p.evaluate(() => window.__calls)).some(c => c[0] === 'preview' && c[1].model === 'a_c_shepherd'), 'aperçu du modèle demandé au jeu');
  await shot('01_races');
  await p.click('.breed[data-breed="labrador"]'); await wait();
  check((await p.evaluate(() => window.__calls)).some(c => c[0] === 'preview' && c[1].model === 'a_c_retriever'), 'autre race : nouvel aperçu');
  await p.click('#next'); await wait();
  check(await p.$eval('#next', x => x.disabled), 'spécialité obligatoire');
  await p.click('.spec[data-spec="detection"]'); await wait();
  await shot('02_specialite');
  await p.click('#next'); await wait();
  await p.fill('#dname', 'R'); await p.click('#create'); await wait();
  check((await p.textContent('#cerr')).includes('Nom'), 'nom trop court : message');
  await p.fill('#dname', 'Rex'); await shot('03_nom'); await p.click('#create'); await wait(400);

  console.log('— Fiche');
  check(await p.isVisible('#menu.center') && (await p.textContent('.dogname h2')).includes('Rex'), 'chien adopté : fiche');
  check((await p.textContent('.meter')).includes('140 / 210 XP') && (await p.textContent('.lvl')).trim() === '7', 'niveau et expérience');
  check((await p.textContent('#tabs')).includes('Dressage3'), 'points de compétence signalés sur l\'onglet');
  await shot('04_fiche');
  check(await p.$('#spawn') !== null && !(await p.isVisible('#store')), 'chien au chenil : bouton « Faire sortir »');
  // le chien est sorti : menu rouvert par le jeu
  const dd = JSON.parse(JSON.stringify(DATA)); dd.sides[0].dog = makeDog('Rex', 'police'); dd.active = { side: 'police', mode: 'follow' };
  await send('open', dd); await wait();
  await p.evaluate((d) => { window.__cur = d; }, makeDog('Rex', 'police'));
  check(await p.isVisible('#store') && (await p.textContent('.state')).includes('Sorti'), 'chien sorti : état et bouton « Renvoyer »');

  console.log('— Dressage');
  await p.click('[data-tab="train"]'); await wait();
  check(await p.$$eval('.skill', x => x.length) === 4 && await p.$('.skill[data-skill="attack"] .tag') !== null, 'compétences, plafond de spécialité affiché');
  check(await p.$$eval('.skill[data-skill="attack"] .dots i.lock', x => x.length) === 3, 'niveaux au-delà du plafond verrouillés');
  await p.click('[data-up="sniff"]'); await wait(300);
  check(await p.$('.skill.flash[data-skill="sniff"]') !== null && (await p.textContent('.points b')) === '0', 'amélioration : retour visuel, points dépensés');
  check(await p.$eval('[data-ex="sniff"]', x => x.disabled) && (await p.textContent('[data-ex="sniff"]')).includes('Repos'), 'exercice en repos (anti-farm)');
  await shot('05_dressage');
  await p.click('[data-ex="obey"]'); await wait();
  check((await p.evaluate(() => window.__calls)).some(c => c[0] === 'exercise' && c[1].id === 'obey'), 'exercice lancé');

  console.log('— Ordres');
  await p.click('[data-tab="orders"]'); await wait();
  check(await p.$$eval('.order', x => x.length) === 10, 'ordres de la police');
  await shot('06_ordres');
  await p.click('[data-order="sniffp"]');
  check((await p.evaluate(() => window.__calls)).some(c => c[0] === 'order' && c[1].order === 'sniffp'), 'ordre envoyé au jeu');
  await p.click('[data-tab="history"]'); await wait();
  check((await p.textContent('.hist')).includes('+60 XP'), 'historique');
  await shot('07_historique');

  console.log('— Gang');
  await p.click('#sides [data-side="gang"]'); await wait();
  check(await p.evaluate(() => document.body.classList.contains('gang')) && (await p.textContent('#title')).includes('groupe'), 'thème du groupe');
  check(await p.$$eval('.breed', x => x.length) === 3 && (await p.textContent('.breeds')).includes('lignée de rue'), 'races du groupe');
  await p.click('#next'); await wait();
  check(await p.$('#dname') !== null, 'groupe : pas d\'étape spécialité');
  await shot('08_gang_creation');

  console.log('— Affichages de jeu');
  await send('close'); await wait();
  await send('target', { show: true, order: 'Renifler la personne', kind: 'player', name: 'Personne · ID 12', dist: 6, index: 1, count: 3, dog: 'Rex' }); await wait();
  check(await p.isVisible('#target') && (await p.textContent('#tgName')) === 'Personne · ID 12' && (await p.textContent('#tgInfo')).includes('1 / 3'), 'ciblage : personne choisie, rang, distance');
  await send('target', { show: true, order: 'Attaquer', kind: 'player', name: 'Personne · ID 7', dist: 12, index: 2, count: 3, warn: 'Dans un véhicule' }); await wait();
  check(await p.isVisible('#tgWarn'), 'avertissement (cible en véhicule)');
  await send('hud', { show: true, title: 'Reniflage', text: 'Le chien marque ! Appuie sur E pour valider.', progress: 0.4, extra: 'Leurres trouvés : 1 / 3', abort: 'Échap : abandonner' }); await wait();
  check(await p.isVisible('#hud') && (await p.textContent('#hudExtra')).includes('1 / 3'), 'affichage d\'exercice');
  await shot('09_ciblage_exercice');
  await send('target', { show: false }); await send('hud', { show: false }); await wait();
  check(!(await p.isVisible('#target')) && !(await p.isVisible('#hud')), 'affichages masqués');

  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  console.log(`\n${fails ? fails + ' ÉCHEC(S)' : 'TOUT EST OK'}`);
  await b.close();
  process.exit(fails ? 1 : 0);
})();
