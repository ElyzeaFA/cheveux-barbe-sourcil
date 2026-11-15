/* =====================================================================
   ELYZEA LETTRES · MISE EN PAGE
   Une feuille fait toujours 600 × 848 px (format A4), seulement agrandie / réduite à l'écran :
   la pagination est donc identique à la rédaction et à la lecture, chez tous les joueurs.
   Pagination : on remplit chaque page au mot près en MESURANT le rendu réel (police, papier,
   en-tête sur la 1re page, signature sur la dernière) dans une feuille cachée.
   ===================================================================== */
const LetterLayout = (() => {
  const W = 600, H = 848;
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // Coupures possibles : après une espace (la page suivante commence au mot suivant)
  // ou sur un retour à la ligne (qui disparaît : la page suivante commence à la ligne suivante).
  function breaks(text, a) {
    const out = [];
    for (let i = a; i < text.length; i++) {
      const c = text[i];
      if (c === '\n') out.push({ end: i, next: i + 1 });
      else if (c === ' ' && text[i + 1] !== ' ' && text[i + 1] !== undefined) out.push({ end: i + 1, next: i + 1 });
    }
    out.push({ end: text.length, next: text.length });
    return out;
  }

  // ---------- Rendu HTML ----------
  // sel = { field, start, end } (curseur si start === end) ; ph = textes indicatifs quand un champ est vide
  function fieldSpans(field, text, from, to, sel, caretHere) {
    // découpe [from, to) aux bornes de la sélection, ajoute le curseur
    const cuts = new Set([from, to]);
    const active = sel && sel.field === field;
    if (active) { [sel.start, sel.end].forEach((p) => { if (p > from && p < to) cuts.add(p); }); }
    const pts = [...cuts].sort((x, y) => x - y);
    let html = '';
    const caretAt = active && sel.start === sel.end && caretHere ? sel.start : -1;
    for (let k = 0; k < pts.length - 1; k++) {
      const p0 = pts[k], p1 = pts[k + 1];
      if (caretAt === p0) html += '<span class="caret"></span>';
      const piece = esc(text.slice(p0, p1));
      const inSel = active && sel.start !== sel.end && p0 >= sel.start && p1 <= sel.end;
      const span = `<span data-f="${field}" data-o="${p0}">${piece}</span>`;
      html += inSel ? `<mark>${span}</mark>` : span;
    }
    if (caretAt === to) html += '<span class="caret"></span>';
    return html;
  }

  function bodyHTML(text, a, b, sel, ph, caretOk) {
    if (!text.length) {
      const caret = caretOk && sel && sel.field === 'body' ? '<span class="caret"></span>' : '';
      return `<div class="para">${caret}${ph ? `<span class="ph">${esc(ph)}</span>` : '<span>\u200b</span>'}</div>`;
    }
    let html = '';
    let p0 = a;
    while (p0 <= b) {
      let nl = text.indexOf('\n', p0);
      if (nl === -1 || nl > b) nl = b;
      const line = fieldSpans('body', text, p0, nl, sel, caretOk);
      const empty = nl === p0;
      html += `<div class="para${empty ? ' empty' : ''}" data-ls="${p0}" data-le="${nl}">${line}${empty ? '<span>\u200b</span>' : ''}</div>`;
      if (nl >= b) break;
      p0 = nl + 1;
    }
    return html;
  }

  function singleHTML(field, text, sel, ph) {
    if (!text.length) {
      const caret = sel && sel.field === field ? '<span class="caret"></span>' : '';
      return `${caret}${ph ? `<span class="ph">${esc(ph)}</span>` : '<span>​</span>'}`;
    }
    return fieldSpans(field, text, 0, text.length, sel, true);
  }

  // Une page complète. page = { a, b, head, sign }, opts = { sel, ph, index, total, date }
  function pageHTML(L, page, opts) {
    const o = opts || {};
    const ph = o.ph || {};
    let html = '<div class="page-inner">';
    if (page.head) {
      html += `<div class="p-head"><div class="p-date">${esc(o.date || '')}</div>
        <div class="p-to" data-field="recipient"><span class="p-to-lbl">À</span> ${singleHTML('recipient', L.recipient || '', o.sel, ph.recipient)}</div></div>`;
    }
    // o.caret : le curseur du corps s'affiche sur cette page (une seule page à la fois)
    html += `<div class="p-body${page.sign ? ' last' : ''}" data-field="body" data-a="${page.a}" data-b="${page.b}">${bodyHTML(L.body || '', page.a, page.b, o.sel, page.a === 0 ? ph.body : null, o.caret === true)}</div>`;
    if (page.sign) html += `<div class="p-sign" data-field="signature">${singleHTML('signature', L.signature || '', o.sel, ph.signature)}</div>`;
    html += '</div>';
    if (o.total > 1) html += `<div class="p-num">${o.index + 1} / ${o.total}</div>`;
    return html;
  }

  function pageClass(L) {
    return `page paper-${L.paper || 'creme'} font-${L.font || 'elegante'}`;
  }

  // ---------- Pagination ----------
  let measure = null;
  function measurePage() {
    if (!measure) {
      const box = document.createElement('div');
      box.className = 'measure';
      box.setAttribute('aria-hidden', 'true');
      box.innerHTML = '<div class="page"></div>';
      document.body.appendChild(box);
      measure = box.firstChild;
    }
    return measure;
  }

  function paginate(L, date) {
    const text = L.body || '';
    const m = measurePage();
    m.className = pageClass(L);
    const fits = (a, b, head, sign) => {
      m.innerHTML = pageHTML(L, { a, b, head, sign }, { date, ph: { recipient: ' ', signature: ' ' } });
      const body = m.querySelector('.p-body');
      const inner = m.querySelector('.page-inner');
      // le corps ne déborde pas, et le dernier bloc (signature) reste dans la feuille
      // (mesure des blocs eux-mêmes : les décorations du papier ne comptent pas)
      const last = inner.lastElementChild;
      return body.scrollHeight <= body.clientHeight + 1 && last.offsetTop + last.offsetHeight <= inner.clientHeight + 1;
    };
    const pages = [];
    let a = 0, guard = 0;
    while (guard++ < 200) {
      const head = pages.length === 0;
      if (fits(a, text.length, head, true)) { pages.push({ a, b: text.length, next: text.length, head, sign: true }); break; }
      const cand = breaks(text, a);
      let lo = 0, hi = cand.length - 1, best = -1;
      while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (fits(a, cand[mid].end, head, false)) { best = mid; lo = mid + 1; } else hi = mid - 1;
      }
      let end, next;
      if (best === -1) {
        // un seul « mot » plus long que la page : coupure au caractère
        let l = a + 1, h = text.length, bc = a + 1;
        while (l <= h) { const md = (l + h) >> 1; if (fits(a, md, head, false)) { bc = md; l = md + 1; } else h = md - 1; }
        end = next = bc;
      } else ({ end, next } = cand[best]);
      if (end >= text.length) {
        // tout le texte tient, mais pas la signature : elle passe seule sur la page suivante
        pages.push({ a, b: text.length, next: text.length, head, sign: false });
        pages.push({ a: text.length, b: text.length, next: text.length, head: false, sign: true });
        break;
      }
      pages.push({ a, b: end, next, head, sign: false });
      a = next;
    }
    return pages;
  }

  // Page où se trouve le curseur : la page i contient les positions [a, next[ (la dernière : jusqu'à la fin).
  // Si la signature est seule sur la dernière page, la fin du texte reste sur l'avant-dernière.
  function pageOf(pages, field, pos) {
    if (field === 'recipient') return 0;
    if (field === 'signature') return pages.length - 1;
    const last = pages.length - 1;
    for (let i = 0; i < last; i++) if (pos >= pages[i].a && pos < pages[i].next) return i;
    if (last > 0 && pages[last].a === pages[last].b && pos >= pages[last].a) return last - 1;
    return last;
  }

  // Position dans un champ à partir d'un clic (null si hors du texte)
  function posFromPoint(x, y) {
    let node = null, offset = 0;
    if (document.caretRangeFromPoint) {
      const r = document.caretRangeFromPoint(x, y);
      if (r) { node = r.startContainer; offset = r.startOffset; }
    } else if (document.caretPositionFromPoint) {
      const r = document.caretPositionFromPoint(x, y);
      if (r) { node = r.offsetNode; offset = r.offset; }
    }
    if (!node) return null;
    const span = (node.nodeType === 3 ? node.parentElement : node).closest('[data-o]');
    if (!span || node.nodeType !== 3) return null;
    return { field: span.dataset.f, pos: Number(span.dataset.o) + offset };
  }

  return { W, H, esc, paginate, pageHTML, pageClass, pageOf, posFromPoint };
})();
