// Test de la TABLETTE d'entreprise et du panneau staff (aperçu navigateur, données de démonstration, Chromium headless)
// NODE_PATH=$(npm root -g) node tests/ui_tablet.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
const LOGO = `data:image/svg+xml;utf8,${encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><rect width='64' height='64' rx='14' fill='#ec4899'/></svg>")}`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.route(/^https?:/, (r) => r.abort());
  await p.addInitScript((logo) => {
    const now = Math.floor(Date.now() / 1000);
    const company = { id: 1, name: 'Vinewood Événements', specialty: 'evenementiel', specialtyLabel: 'Événementiel', specialtyIcon: '🎉', logo, color: '#ec4899',
      description: 'Mariages, anniversaires, soirées privées.\nDevis gratuit par message.', owner: 'Alice Martin', created: '18/11/2026', employees: 2, number: '919-0001', open: true, onDuty: 1 };
    window.__calls = [];
    const grades = [{ id: 1, name: 'Employé', level: 1, isDefault: true, perms: ['duty', 'tablet'], members: 1, active: true }, { id: 2, name: 'Responsable', level: 2, perms: ['duty', 'tablet', 'direction'], members: 0, active: true },
      { id: 3, name: 'Directeur', level: 3, perms: ['finance'], members: 0, active: true }, { id: 4, name: 'Patron', level: 4, perms: ['direction'], members: 1, active: true }];
    const R = {
      dashboard: { company, employees: 2, crew: [{ id: 4, name: 'Dina Lopez', grade: 'Employé', level: 1, status: 'available', session: 1800 }], flow: { in: 3000, out: 600 }, balance: 1900, isOwner: true,
        me: { grade: 'Patron', matricule: 'EN-001', duty: true, status: 'available', times: { session: 600, total: 7200, unpaid: 0, unpaidAmount: 0, rate: 0 } } },
      profile: { company, canEdit: true, specialties: [{ id: 'commerce', label: 'Commerce', icon: '🛍️' }, { id: 'evenementiel', label: 'Événementiel', icon: '🎉' }], colors: ['#7c6cff', '#ec4899', '#10b981'], descriptionMax: 600, job: 'ent_1', society: 'ent_1' },
      finance: { balance: 1900, society: 'ent_1', totalDue: 120, canPay: true, canDeposit: true, canWithdraw: true, now, logs: [{ amount: 3000, reason: 'Dépôt de Alice Martin', t: now - 600 }],
        grades: grades.map((g) => ({ id: g.id, name: g.name, level: g.level, rate: g.id === 1 ? 600 : 0, members: g.members, editable: g.level < 4 })),
        employees: [{ cid: 'DINA', name: 'Dina Lopez', matricule: 'EN-002', grade: 'Employé', level: 1, seconds: 720, total: 4320, rate: 600, due: 120, online: true, duty: true }],
        sums: { 'in:deposit': { total: 3000, n: 1 }, 'out:salary': { total: 600, n: 1 }, 'out:withdraw': { total: 500, n: 1 } }, all: { 'in:deposit': { total: 3000, n: 1 } } },
      rateHistory: { list: [{ grade_name: 'Employé', rate: 600, actor_name: 'Alice Martin', t: now - 3600 }] },
      transactions: { list: [{ txid: 'TX-1', type: 'in', category: 'deposit', amount: 3000, reason: 'Capital', actor_name: 'Alice Martin', target_name: 'Alice Martin', t: now - 600 }] },
      employees: { list: [{ cid: 'DINA', name: 'Dina Lopez', matricule: 'EN-002', gradeId: 1, grade: 'Employé', level: 1, total: 4320, unpaid: 720, unpaidAmount: 120, online: true, duty: true }], grades, myLevel: 4, myCid: 'ALICE' },
      employee: { employee: { cid: 'DINA', name: 'Dina Lopez', matricule: 'EN-002', gradeId: 1, grade: 'Employé', level: 1, total: 4320, unpaid: 720, unpaidAmount: 120, online: true, duty: true, canAct: true, sessions: [], history: [] } },
      grades: { list: grades, myLevel: 4, myPerms: { duty: true, tablet: true, direction: true, finance: true }, permList: [{ key: 'duty', group: 'Service', label: 'Prendre son service' }, { key: 'profile', group: 'Vitrine', label: 'Modifier la vitrine' }], canGrades: true, canPerms: true },
      history: { list: [{ actor_name: 'Alice Martin', target_name: 'Dina Lopez', action: 'Recrutement', new_grade: 'Employé', t: now - 900 }] },
      recruitPreview: { target: { id: 4, name: 'Dina Lopez', distance: 1.8, job: 'Sans emploi', already: false, pending: false }, grades: grades.slice(0, 3), defaultGrade: 1 },
    };
    window.EDemo = (name, data) => {
      if (name === 'req') { window.__calls.push(data); if (data.action === 'profileSave' || data.action === 'deposit') return { ok: true, message: 'OK' }; return R[data.action] || { error: 'inconnu' }; }
      if (name === 'adm') { window.__calls.push(data); return { ok: true, message: 'OK', list: [Object.assign({ enabled: true, balance: 1900, job: 'ent_1', ownerCid: 'ALICE' }, company)] }; }
      return {};
    };
  }, LOGO);
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(400);
  const st = { shop: 1, shopName: 'Vinewood Événements', logo: LOGO, grade: 'Patron', matricule: 'EN-001', duty: true, status: 'available', perms: Object.fromEntries(['duty', 'tablet', 'open', 'profile', 'direction', 'recruit', 'employees_view', 'employees_edit', 'promote', 'demote', 'fire', 'history_view', 'grades_manage', 'perms_manage', 'finance', 'deposit', 'withdraw', 'payroll'].map((k) => [k, true])) };
  await p.evaluate((st) => window.postMessage({ action: 'tablet', show: true, state: st, cfg: { statuses: [{ id: 'available', label: 'Disponible', color: '#22c55e' }] } }, '*'), st);
  await p.waitForTimeout(600);
  const shot = (n) => p.screenshot({ path: path.join(out, `tab_${n}.png`) });
  const nav = await p.$$eval('[data-nav]', (x) => x.map((n) => n.dataset.nav));
  check(nav.join(',') === 'dashboard,profile,recruit,employees,grades,perms,history,finance,transactions', 'menu : tableau de bord, vitrine, direction, finance');
  check(await p.$eval('.brand .shield', (e) => e.classList.contains('img')), 'logo de l\'entreprise en haut du menu');
  const dash = await p.textContent('#tabBody');
  check(dash.includes('919-0001') && dash.includes('Devis gratuit') && dash.includes('Dina Lopez') && dash.includes('Dissoudre'), 'tableau de bord : numéro public, vitrine, équipe en service, dissolution (fondateur)');
  await shot('01_tableau');
  await p.click('[data-nav="profile"]'); await p.waitForTimeout(400);
  check(await p.inputValue('#vDesc') === 'Mariages, anniversaires, soirées privées.\nDevis gratuit par message.', 'vitrine : description avec retours à la ligne');
  await p.fill('#vDesc', 'Nouvelle description de test.');
  await p.click('[data-vcol="#10b981"]'); await p.waitForTimeout(200);
  check(await p.inputValue('#vDesc') === 'Nouvelle description de test.', 'texte gardé en changeant de couleur');
  await p.click('[data-vsave]'); await p.waitForTimeout(400);
  const ps = (await p.evaluate(() => window.__calls)).find((c) => c.action === 'profileSave');
  check(ps && ps.data.color === '#10b981' && ps.data.description === 'Nouvelle description de test.' && ps.data.specialty === 'evenementiel', 'vitrine enregistrée (couleur, description, spécialité)');
  await shot('02_vitrine');
  await p.click('[data-nav="finance"]'); await p.waitForTimeout(500);
  check(await p.$('[data-fmove="deposit"]') !== null && await p.$('[data-fmove="withdraw"]') !== null, 'finance : déposer / retirer');
  await p.click('[data-fmove="deposit"]'); await p.waitForTimeout(200);
  await p.fill('[data-cfv="amount"]', '2500'); await p.click('[data-cf="yes"]'); await p.waitForTimeout(400);
  const dep = (await p.evaluate(() => window.__calls)).find((c) => c.action === 'deposit');
  check(dep && dep.data.amount === 2500, 'dépôt de 2 500 $ envoyé');
  await shot('03_finance');
  for (const pg of ['recruit', 'employees', 'grades', 'perms', 'history', 'transactions']) {
    await p.click(`[data-nav="${pg}"]`); await p.waitForTimeout(350);
    check(!(await p.textContent('#tabBody')).includes('inconnu'), `page « ${pg} » affichée`);
  }
  await p.click('[data-nav="dashboard"]'); await p.waitForTimeout(300);
  await p.click('[data-dissolve]'); await p.waitForTimeout(200);
  check((await p.textContent('#confirm')).includes('Vinewood Événements'), 'dissolution : demande de retaper le nom');
  await p.keyboard.press('Escape'); await p.waitForTimeout(200);
  await p.evaluate(() => { window.postMessage({ action: 'tablet', show: false }, '*'); window.postMessage({ action: 'admin', show: true, data: EDemo('adm', { action: 'list' }) }, '*'); });
  await p.waitForTimeout(400);
  check((await p.textContent('#admin')).includes('Vinewood Événements') && await p.$('#admin [data-ad="suspend"]') !== null, 'panneau staff : liste et actions');
  await p.screenshot({ path: path.join(out, 'tab_04_staff.png') });
  check(errs.length === 0, `aucune erreur JavaScript (${errs.join(' | ')})`);
  await b.close();
  console.log(fails ? `\n${fails} ÉCHEC(S)` : '\nTOUT EST OK');
  process.exit(fails ? 1 : 0);
})();
