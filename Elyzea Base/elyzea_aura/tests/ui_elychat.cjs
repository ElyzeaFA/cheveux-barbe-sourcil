// Test de l'interface ElyChat (aperçu navigateur du téléphone, Chromium headless)
// NODE_PATH=$(npm root -g) node tests/ui_elychat.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 900, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message + ' @ ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(3000);
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.setup = true; E.S.settings.installed = ['elychat', 'elymeet']; E.S.settings.theme = 'light'; document.getElementById('screen').classList.remove('in-setup'); document.getElementById('setup').classList.remove('active'); E.applySettings(); E.S.locked = false; E.goHome(); });
  await p.evaluate(() => { const E = window.__elyzea; E.S.profile.device = { model: 3, tier: 3, label: 'ElyAura 3', apps: 'all', exclude: [], store: true }; E.goHome(); });
  await p.waitForTimeout(400);
  const shot = (n) => p.locator('#screen').screenshot({ path: path.join(out, `elychat_${n}.png`) });
  const wait = (ms = 450) => p.waitForTimeout(ms);
  const noOverflow = async (label) => {
    const r = await p.evaluate(() => { const s = document.getElementById('screen').getBoundingClientRect(); const all = [...document.querySelectorAll('.ec *')].filter(e => { const b = e.getBoundingClientRect(); return b.width > 0 && b.height > 0 && (b.right > s.right + 1 || b.left < s.left - 1) && !e.closest('.emap'); }); return { n: all.length, ex: all.slice(0, 3).map(e => e.className) }; });
    check(r.n === 0, `${label} : rien ne déborde de l'écran${r.n ? ' ' + JSON.stringify(r.ex) : ''}`);
  };

  console.log('— Accueil et compte');
  check((await p.textContent('[data-open="elychat"]')).includes('ElyChat'), 'icône « ElyChat » sur l\'accueil');
  check((await p.textContent('[data-open="elymeet"]')).includes('ElyMeet'), 'icône « ElyMeet » sur l\'accueil (remplace Étincelle)');
  check(await p.$('[data-open="etincelle"]') === null, 'Étincelle n\'est plus sur l\'accueil');
  await shot('00_accueil');
  await p.click('[data-open="elychat"]'); await wait(700);
  check(await p.$('#ec-user') !== null, 'premier lancement : création du compte');
  await p.fill('#ec-user', 'Léna Duval!');
  check(await p.inputValue('#ec-user') === 'lnaduval', 'nom d\'utilisateur nettoyé pendant la saisie');
  await p.click('.ec-color[data-c="#3DDC97"]');
  check((await p.getAttribute('#ec-pv .ec-av', 'style')).includes('#3DDC97'), 'aperçu de l\'avatar avec la couleur choisie');
  await shot('01_compte');
  await p.fill('#ec-user', 'lena.duval'); await p.click('#ec-go'); await wait(700);

  console.log('— Chat');
  check(await p.$$eval('.ec-nav__b', x => x.length) === 4 && await p.$('.ec-nav__cam') !== null, 'barre du bas : Carte, Chat, Caméra, Amis, Profil');
  check(await p.$$eval('.ec-row', x => x.length) === 3, 'trois conversations');
  const first = await p.textContent('.ec-row');
  check(first.includes('Malik') && first.includes('Nouveau snap'), 'Malik en premier : « Nouveau snap »');
  check((await p.textContent('.ec-row[data-u="malik"] .ec-streak')).includes('12'), 'flammes affichées (12)');
  check((await p.textContent('.ec-row[data-u="ines.k"]')).includes('Nouveau chat'), 'Inès : « Nouveau chat »');
  check((await p.textContent('.ec-nav [data-tab="chats"] .ec-dot')) === '3', 'pastille : 2 snaps + 1 chat');
  await shot('02_chat');
  await noOverflow('liste');

  console.log('— Snap reçu (vu une fois)');
  await p.click('.ec-row[data-u="malik"] [data-row]'); await wait(400);
  check(await p.$('.ec-viewer img') !== null && (await p.textContent('.ec-viewer .ec-cap')).includes('jetée'), 'snap plein écran avec sa légende');
  check(await p.$('.ec-ring') !== null, 'minuteur circulaire');
  check((await p.textContent('.ec-viewer__more')).includes('1'), 'encore 1 snap à voir');
  await shot('03_snap');
  await p.click('.ec-viewer'); await wait(400);
  check(await p.$('.ec-viewer') !== null, 'appui : snap suivant');
  await p.waitForTimeout(3400);
  check(await p.$('.ec-viewer') === null, 'minuteur écoulé : le snap se ferme');
  check(!(await p.textContent('.ec-row[data-u="malik"]')).includes('Nouveau snap'), 'plus de nouveau snap de Malik');

  console.log('— Conversation');
  await p.click('.ec-row[data-u="ines.k"] [data-row]'); await wait(500);
  check((await p.textContent('.ec-title')).includes('Inès'), 'conversation avec Inès');
  check((await p.textContent('.ec-thread')).includes('Bean Machine'), 'message reçu affiché');
  check(await p.$('.ec-who--them') !== null, 'nom de l\'expéditeur en couleur, façon Snapchat');
  await p.fill('#ec-msg', 'Oui, dans 10 min !'); await p.press('#ec-msg', 'Enter'); await wait(300);
  check((await p.textContent('.ec-thread')).includes('dans 10 min'), 'message envoyé');
  await p.click('.ec-msg--me'); await wait(300);
  check(await p.$('.ec-msg.saved') !== null, 'appui sur un message : enregistré');
  await shot('04_conversation');
  await noOverflow('conversation');
  await p.click('[data-back]'); await wait(400);

  console.log('— Caméra : nouveau snap');
  await p.click('.ec-nav__cam'); await wait(500);
  check(await p.$$eval('.ec-grid__i', x => x.length) === 5, 'photos de la galerie');
  await shot('05_camera');
  await p.click('.ec-grid__i'); await wait(400);
  await p.fill('#ec-cap', 'Vue de Vinewood');
  await p.click('[data-timer]');
  check((await p.textContent('#ec-dur')) === '10s', 'minuteur réglable (5 s → 10 s)');
  await shot('06_edition');
  await p.click('[data-to]'); await wait(400);
  check(await p.$$eval('.ec-pick', x => x.length) === 3, 'choix parmi les amis');
  await p.click('.ec-pick[data-u="malik"]'); await p.click('.ec-pick[data-u="tom_ls"]'); await wait(200);
  check(await p.$('.ec-sendbar.on') !== null && (await p.textContent('#ec-sel')).includes('Malik'), 'barre d\'envoi avec les noms choisis');
  await shot('07_destinataires');
  await p.click('[data-send]'); await wait(600);
  check((await p.textContent('.ec-row[data-u="malik"]')).includes('Envoyé'), 'après l\'envoi : « Envoyé »');

  console.log('— Carte');
  await p.click('.ec-nav [data-tab="map"]'); await wait(800);
  check(await p.$('.emap__tiles img') !== null, 'carte d\'Elyzea affichée');
  check(await p.$$eval('.ec-pin', x => x.length) === 3, 'Malik, Inès et moi sur la carte');
  check((await p.textContent('.ec-pin:not(.ec-pin--me)', { timeout: 500 }).catch(() => '')) !== '', 'amis avec leur prénom');
  await shot('08_carte');
  await p.evaluate(() => [...document.querySelectorAll('.emap__mk')].find(m => m.textContent.includes('Malik')).click()); await wait(600);
  check(await p.$('.ec-mapcard.on') !== null && (await p.textContent('.ec-mapcard')).includes('En ce moment'), 'fiche de l\'ami (en direct, quartier, boutons)');
  await shot('09_carte_ami');
  await p.click('[data-share]'); await wait(500);
  await p.click('.ec-opt[data-m="off"]'); await p.click('.sheet [data-ok]'); await wait(800);
  check(await p.$('.ec-ghost__b') !== null, 'mode fantôme : bandeau sur la carte');
  await shot('10_fantome');

  console.log('— Amis');
  await p.click('.ec-nav [data-tab="friends"]'); await wait(500);
  check((await p.textContent('#ec-fr')).includes('Sarah'), 'demande reçue de Sarah');
  await p.click('.ec-frow[data-u="sarah"] [data-acc]'); await wait(600);
  check((await p.textContent('#ec-fr')).includes('Mes amis') && !(await p.textContent('#ec-fr')).includes('Demandes reçues'), 'demande acceptée');
  await p.fill('#ec-q', 'jul'); await wait(500);
  check(await p.$('#ec-res [data-add]') !== null, 'recherche : bouton Ajouter');
  await p.click('#ec-res [data-add]'); await wait(400);
  check((await p.textContent('#ec-res')).includes('Demandé'), 'demande envoyée');
  await shot('11_amis');
  await noOverflow('amis');

  console.log('— Profil');
  await p.click('.ec-nav [data-tab="me"]'); await wait(400);
  check((await p.textContent('.ec-score')).includes('ElyScore'), 'ElyScore affiché');
  await shot('12_profil');
  await p.evaluate(() => window.__elyzea.S.settings.theme = 'dark');
  await p.evaluate(() => window.__elyzea.applySettings());
  await p.click('.ec-nav [data-tab="chats"]'); await wait(400);
  await shot('13_chat_sombre');

  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  console.log(`\n${fails ? fails + ' ÉCHEC(S)' : 'TOUT EST OK'}`);
  await b.close();
  process.exit(fails ? 1 : 0);
})();
