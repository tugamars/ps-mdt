var rt = Object.defineProperty;
var ct = (e, t, l) => t in e ? rt(e, t, { enumerable: !0, configurable: !0, writable: !0, value: l }) : e[t] = l;
var Te = (e, t, l) => ct(e, typeof t != "symbol" ? t + "" : t, l);
function _e() {
}
function st(e) {
  return e();
}
function We() {
  return /* @__PURE__ */ Object.create(null);
}
function oe(e) {
  e.forEach(st);
}
function nt(e) {
  return typeof e == "function";
}
function ft(e, t) {
  return e != e ? t == t : e !== t || e && typeof e == "object" || typeof e == "function";
}
let Pe;
function qe(e, t) {
  return e === t ? !0 : (Pe || (Pe = document.createElement("a")), Pe.href = t, e === Pe.href);
}
function vt(e) {
  return Object.keys(e).length === 0;
}
function n(e, t) {
  e.appendChild(t);
}
function W(e, t, l) {
  e.insertBefore(t, l || null);
}
function R(e) {
  e.parentNode && e.parentNode.removeChild(e);
}
function De(e, t) {
  for (let l = 0; l < e.length; l += 1)
    e[l] && e[l].d(t);
}
function u(e) {
  return document.createElement(e);
}
function N(e) {
  return document.createTextNode(e);
}
function x() {
  return N(" ");
}
function He() {
  return N("");
}
function V(e, t, l, s) {
  return e.addEventListener(t, l, s), () => e.removeEventListener(t, l, s);
}
function dt(e) {
  return function(t) {
    return t.preventDefault(), e.call(this, t);
  };
}
function o(e, t, l) {
  l == null ? e.removeAttribute(t) : e.getAttribute(t) !== l && e.setAttribute(t, l);
}
function pt(e) {
  return Array.from(e.childNodes);
}
function O(e, t) {
  t = "" + t, e.data !== t && (e.data = /** @type {string} */
  t);
}
function le(e, t) {
  e.value = t ?? "";
}
function K(e, t, l) {
  e.classList.toggle(t, !!l);
}
let Ce;
function ye(e) {
  Ce = e;
}
function it() {
  if (!Ce) throw new Error("Function called outside component initialization");
  return Ce;
}
function ht(e) {
  it().$$.on_mount.push(e);
}
function bt(e) {
  it().$$.on_destroy.push(e);
}
const he = [], Ee = [];
let be = [];
const Me = [], ot = /* @__PURE__ */ Promise.resolve();
let Oe = !1;
function at() {
  Oe || (Oe = !0, ot.then(ut));
}
function _t() {
  return at(), ot;
}
function Ue(e) {
  be.push(e);
}
const Ae = /* @__PURE__ */ new Set();
let pe = 0;
function ut() {
  if (pe !== 0)
    return;
  const e = Ce;
  do {
    try {
      for (; pe < he.length; ) {
        const t = he[pe];
        pe++, ye(t), mt(t.$$);
      }
    } catch (t) {
      throw he.length = 0, pe = 0, t;
    }
    for (ye(null), he.length = 0, pe = 0; Ee.length; ) Ee.pop()();
    for (let t = 0; t < be.length; t += 1) {
      const l = be[t];
      Ae.has(l) || (Ae.add(l), l());
    }
    be.length = 0;
  } while (he.length);
  for (; Me.length; )
    Me.pop()();
  Oe = !1, Ae.clear(), ye(e);
}
function mt(e) {
  if (e.fragment !== null) {
    e.update(), oe(e.before_update);
    const t = e.dirty;
    e.dirty = [-1], e.fragment && e.fragment.p(e.ctx, t), e.after_update.forEach(Ue);
  }
}
function gt(e) {
  const t = [], l = [];
  be.forEach((s) => e.indexOf(s) === -1 ? t.push(s) : l.push(s)), l.forEach((s) => s()), be = t;
}
const wt = /* @__PURE__ */ new Set();
function kt(e, t) {
  e && e.i && (wt.delete(e), e.i(t));
}
function se(e) {
  return (e == null ? void 0 : e.length) !== void 0 ? e : Array.from(e);
}
function yt(e, t, l) {
  const { fragment: s, after_update: i } = e.$$;
  s && s.m(t, l), Ue(() => {
    const c = e.$$.on_mount.map(st).filter(nt);
    e.$$.on_destroy ? e.$$.on_destroy.push(...c) : oe(c), e.$$.on_mount = [];
  }), i.forEach(Ue);
}
function Ct(e, t) {
  const l = e.$$;
  l.fragment !== null && (gt(l.after_update), oe(l.on_destroy), l.fragment && l.fragment.d(t), l.on_destroy = l.fragment = null, l.ctx = []);
}
function St(e, t) {
  e.$$.dirty[0] === -1 && (he.push(e), at(), e.$$.dirty.fill(0)), e.$$.dirty[t / 31 | 0] |= 1 << t % 31;
}
function It(e, t, l, s, i, c, r = null, p = [-1]) {
  const d = Ce;
  ye(e);
  const f = e.$$ = {
    fragment: null,
    ctx: [],
    // state
    props: c,
    update: _e,
    not_equal: i,
    bound: We(),
    // lifecycle
    on_mount: [],
    on_destroy: [],
    on_disconnect: [],
    before_update: [],
    after_update: [],
    context: new Map(t.context || (d ? d.$$.context : [])),
    // everything else
    callbacks: We(),
    dirty: p,
    skip_bound: !1,
    root: t.target || d.$$.root
  };
  r && r(f.root);
  let y = !1;
  if (f.ctx = l ? l(e, t.props || {}, (v, _, ...g) => {
    const P = g.length ? g[0] : _;
    return f.ctx && i(f.ctx[v], f.ctx[v] = P) && (!f.skip_bound && f.bound[v] && f.bound[v](P), y && St(e, v)), _;
  }) : [], f.update(), y = !0, oe(f.before_update), f.fragment = s ? s(f.ctx) : !1, t.target) {
    if (t.hydrate) {
      const v = pt(t.target);
      f.fragment && f.fragment.l(v), v.forEach(R);
    } else
      f.fragment && f.fragment.c();
    t.intro && kt(e.$$.fragment), yt(e, t.target, t.anchor), ut();
  }
  ye(d);
}
class Nt {
  constructor() {
    /**
     * ### PRIVATE API
     *
     * Do not use, may change at any time
     *
     * @type {any}
     */
    Te(this, "$$");
    /**
     * ### PRIVATE API
     *
     * Do not use, may change at any time
     *
     * @type {any}
     */
    Te(this, "$$set");
  }
  /** @returns {void} */
  $destroy() {
    Ct(this, 1), this.$destroy = _e;
  }
  /**
   * @template {Extract<keyof Events, string>} K
   * @param {K} type
   * @param {((e: Events[K]) => void) | null | undefined} callback
   * @returns {() => void}
   */
  $on(t, l) {
    if (!nt(l))
      return _e;
    const s = this.$$.callbacks[t] || (this.$$.callbacks[t] = []);
    return s.push(l), () => {
      const i = s.indexOf(l);
      i !== -1 && s.splice(i, 1);
    };
  }
  /**
   * @param {Partial<Props>} props
   * @returns {void}
   */
  $set(t) {
    this.$$set && !vt(t) && (this.$$.skip_bound = !0, this.$$set(t), this.$$.skip_bound = !1);
  }
}
const Pt = "4";
typeof window < "u" && (window.__svelte || (window.__svelte = { v: /* @__PURE__ */ new Set() })).v.add(Pt);
function je(e, t, l) {
  const s = e.slice();
  return s[49] = t[l], s;
}
function Fe(e, t, l) {
  const s = e.slice();
  return s[49] = t[l], s;
}
function ze(e, t, l) {
  const s = e.slice();
  return s[54] = t[l], s;
}
function Ge(e, t, l) {
  const s = e.slice();
  return s[49] = t[l], s;
}
function Ve(e) {
  let t, l;
  return {
    c() {
      t = u("div"), l = N(
        /*error*/
        e[13]
      ), o(t, "class", "error svelte-17vubsv");
    },
    m(s, i) {
      W(s, t, i), n(t, l);
    },
    p(s, i) {
      i[0] & /*error*/
      8192 && O(
        l,
        /*error*/
        s[13]
      );
    },
    d(s) {
      s && R(t);
    }
  };
}
function Et(e) {
  let t, l, s, i = (
    /*selectedCase*/
    e[6] ? (
      /*selectedCase*/
      (e[6].caseNumber || /*selectedCase*/
      e[6].case_number || `Case #${/*selectedCase*/
      e[6].id}`) + " — " + /*selectedCase*/
      e[6].title
    ) : "Choose the case that will receive the evidence."
  ), c, r, p, d, f, y, v, _, g, P, S, w, I = !/*canInterviews*/
  e[20] && Be(), E = se(
    /*interviews*/
    e[2]
  ), b = [];
  for (let m = 0; m < E.length; m += 1)
    b[m] = Je(je(e, E, m));
  let D = null;
  E.length || (D = Ke(e));
  let k = (
    /*interviews*/
    e[2].length && Qe(e)
  );
  return {
    c() {
      t = u("div"), l = u("h2"), l.textContent = "Target case", s = u("p"), c = N(i), r = u("div"), p = x(), d = u("div"), f = u("h2"), y = N("Witness interviews "), v = u("button"), v.textContent = "Refresh", _ = u("p"), _.textContent = "Forms in your inventory are added to the target case as evidence.", I && I.c(), g = He();
      for (let m = 0; m < b.length; m += 1)
        b[m].c();
      P = He(), D && D.c(), k && k.c(), o(l, "class", "svelte-17vubsv"), o(s, "class", "svelte-17vubsv"), o(r, "class", "svelte-17vubsv"), o(t, "class", "panel case svelte-17vubsv"), o(v, "class", "svelte-17vubsv"), o(f, "class", "svelte-17vubsv"), o(_, "class", "svelte-17vubsv"), o(d, "class", "panel svelte-17vubsv");
    },
    m(m, h) {
      W(m, t, h), n(t, l), n(t, s), n(s, c), n(t, r), e[44](r), W(m, p, h), W(m, d, h), n(d, f), n(f, y), n(f, v), n(d, _), I && I.m(d, null), n(d, g);
      for (let C = 0; C < b.length; C += 1)
        b[C] && b[C].m(d, null);
      n(d, P), D && D.m(d, null), k && k.m(d, null), S || (w = V(
        v,
        "click",
        /*loadInterviews*/
        e[31]
      ), S = !0);
    },
    p(m, h) {
      if (h[0] & /*selectedCase*/
      64 && i !== (i = /*selectedCase*/
      m[6] ? (
        /*selectedCase*/
        (m[6].caseNumber || /*selectedCase*/
        m[6].case_number || `Case #${/*selectedCase*/
        m[6].id}`) + " — " + /*selectedCase*/
        m[6].title
      ) : "Choose the case that will receive the evidence.") && O(c, i), /*canInterviews*/
      m[20] ? I && (I.d(1), I = null) : I || (I = Be(), I.c(), I.m(d, g)), h[0] & /*interviewKeys, interviews, toggle, loadingInterviews*/
      33816588) {
        E = se(
          /*interviews*/
          m[2]
        );
        let C;
        for (C = 0; C < E.length; C += 1) {
          const j = je(m, E, C);
          b[C] ? b[C].p(j, h) : (b[C] = Je(j), b[C].c(), b[C].m(d, P));
        }
        for (; C < b.length; C += 1)
          b[C].d(1);
        b.length = E.length, !E.length && D ? D.p(m, h) : E.length ? D && (D.d(1), D = null) : (D = Ke(m), D.c(), D.m(d, P));
      }
      /*interviews*/
      m[2].length ? k ? k.p(m, h) : (k = Qe(m), k.c(), k.m(d, null)) : k && (k.d(1), k = null);
    },
    d(m) {
      m && (R(t), R(p), R(d)), e[44](null), I && I.d(), De(b, m), D && D.d(), k && k.d(), S = !1, w();
    }
  };
}
function Dt(e) {
  let t, l, s, i, c, r, p, d, f, y, v, _, g, P, S, w, I, E, b, D, k, m, h, C, j, q = (
    /*selectedPhotos*/
    e[21].length + ""
  ), U, H, ee, Q, X, Se, J, B, ne, ae, te, me, ue, Y, re, ie, ce, fe = (
    /*selectedCase*/
    e[6] ? "Ready to import into the selected case." : "Select a case to continue."
  ), ge, $, ve = (
    /*importing*/
    e[12] ? "Importing…" : "↥ Import photos"
  ), we, de, ke, Ie, a = se(
    /*cards*/
    e[7]
  ), A = [];
  for (let T = 0; T < a.length; T += 1)
    A[T] = Ze(ze(e, a, T));
  let L = null;
  a.length || (L = Xe(e));
  let M = (
    /*selectedCase*/
    e[6] && $e(e)
  ), G = (
    /*photos*/
    e[0].length && xe(e)
  );
  function Re(T, F) {
    return (
      /*photos*/
      T[0].length ? Ot : At
    );
  }
  let Ne = Re(e), Z = Ne(e);
  return {
    c() {
      t = u("div"), l = u("aside"), s = u("div"), i = u("span"), i.textContent = "1", c = u("h2"), c.textContent = "SD cards", r = u("button"), r.textContent = "Refresh cards", p = u("div");
      for (let T = 0; T < A.length; T += 1)
        A[T].c();
      L && L.c(), d = x(), f = u("div"), y = u("section"), v = u("div"), v.innerHTML = '<span class="step-number svelte-17vubsv">2</span><h2 class="svelte-17vubsv">Target case</h2>', _ = u("div"), g = u("div"), M && M.c(), P = x(), S = u("section"), w = u("div"), I = u("span"), I.textContent = "3", E = u("h2"), E.textContent = "Choose photos", G && G.c(), b = u("div"), Z.c(), D = x(), k = u("section"), m = u("div"), h = u("span"), h.textContent = "4", C = u("h2"), C.textContent = "Evidence details", j = u("span"), U = N(q), H = N(" selected"), ee = u("div"), Q = u("div"), X = u("label"), Se = N("Title "), J = u("em"), J.textContent = "required", B = u("input"), ae = u("label"), ae.innerHTML = 'Type<input value="Photos" readonly="" class="svelte-17vubsv"/>', te = u("label"), me = N("Notes "), ue = u("em"), ue.textContent = "optional", Y = u("textarea"), ie = u("footer"), ce = u("span"), ge = N(fe), $ = u("button"), we = N(ve), o(i, "class", "step-number svelte-17vubsv"), o(c, "class", "svelte-17vubsv"), o(r, "class", "link-button svelte-17vubsv"), o(s, "class", "step-heading svelte-17vubsv"), o(p, "class", "step-body svelte-17vubsv"), o(l, "class", "step-card sd-card-panel svelte-17vubsv"), o(v, "class", "step-heading svelte-17vubsv"), o(g, "class", "svelte-17vubsv"), o(_, "class", "step-body svelte-17vubsv"), o(y, "class", "step-card target-case svelte-17vubsv"), o(I, "class", "step-number svelte-17vubsv"), o(E, "class", "svelte-17vubsv"), o(w, "class", "step-heading svelte-17vubsv"), o(b, "class", "step-body svelte-17vubsv"), o(S, "class", "step-card photo-picker svelte-17vubsv"), o(h, "class", "step-number svelte-17vubsv"), o(C, "class", "svelte-17vubsv"), o(j, "class", "selection-count svelte-17vubsv"), o(m, "class", "step-heading svelte-17vubsv"), o(J, "class", "svelte-17vubsv"), o(B, "maxlength", "100"), o(B, "placeholder", "e.g. Scene photographs"), B.disabled = ne = !/*canImport*/
      e[22], o(B, "class", "svelte-17vubsv"), o(X, "class", "svelte-17vubsv"), o(ae, "class", "svelte-17vubsv"), o(Q, "class", "details-grid svelte-17vubsv"), o(ue, "class", "svelte-17vubsv"), o(Y, "maxlength", "4000"), o(Y, "placeholder", "Add context for these photographs..."), Y.disabled = re = !/*canImport*/
      e[22], o(Y, "class", "svelte-17vubsv"), o(te, "class", "notes-label svelte-17vubsv"), o(ee, "class", "step-body svelte-17vubsv"), o(ce, "class", "svelte-17vubsv"), o($, "class", "primary svelte-17vubsv"), $.disabled = de = !/*canImport*/
      e[22] || /*importing*/
      e[12] || !/*selectedCase*/
      e[6] || !/*title*/
      e[9].trim() || !/*selectedPhotos*/
      e[21].length, o(ie, "class", "svelte-17vubsv"), o(k, "class", "step-card evidence-details svelte-17vubsv"), o(f, "class", "photo-flow svelte-17vubsv"), o(t, "class", "photo-workspace svelte-17vubsv");
    },
    m(T, F) {
      W(T, t, F), n(t, l), n(l, s), n(s, i), n(s, c), n(s, r), n(l, p);
      for (let z = 0; z < A.length; z += 1)
        A[z] && A[z].m(p, null);
      L && L.m(p, null), n(t, d), n(t, f), n(f, y), n(y, v), n(y, _), n(_, g), e[40](g), M && M.m(_, null), n(f, P), n(f, S), n(S, w), n(w, I), n(w, E), G && G.m(w, null), n(S, b), Z.m(b, null), n(f, D), n(f, k), n(k, m), n(m, h), n(m, C), n(m, j), n(j, U), n(j, H), n(k, ee), n(ee, Q), n(Q, X), n(X, Se), n(X, J), n(X, B), le(
        B,
        /*title*/
        e[9]
      ), n(Q, ae), n(ee, te), n(te, me), n(te, ue), n(te, Y), le(
        Y,
        /*notes*/
        e[10]
      ), n(k, ie), n(ie, ce), n(ce, ge), n(ie, $), n($, we), ke || (Ie = [
        V(
          r,
          "click",
          /*loadCards*/
          e[27]
        ),
        V(
          B,
          "input",
          /*input0_input_handler_1*/
          e[42]
        ),
        V(
          Y,
          "input",
          /*textarea_input_handler*/
          e[43]
        ),
        V(
          $,
          "click",
          /*importPhotos*/
          e[29]
        )
      ], ke = !0);
    },
    p(T, F) {
      if (F[0] & /*selectedCard, cards, loadPhotos, loading*/
      268437888) {
        a = se(
          /*cards*/
          T[7]
        );
        let z;
        for (z = 0; z < a.length; z += 1) {
          const Le = ze(T, a, z);
          A[z] ? A[z].p(Le, F) : (A[z] = Ze(Le), A[z].c(), A[z].m(p, null));
        }
        for (; z < A.length; z += 1)
          A[z].d(1);
        A.length = a.length, !a.length && L ? L.p(T, F) : a.length ? L && (L.d(1), L = null) : (L = Xe(T), L.c(), L.m(p, null));
      }
      /*selectedCase*/
      T[6] ? M ? M.p(T, F) : (M = $e(T), M.c(), M.m(_, null)) : M && (M.d(1), M = null), /*photos*/
      T[0].length ? G ? G.p(T, F) : (G = xe(T), G.c(), G.m(w, null)) : G && (G.d(1), G = null), Ne === (Ne = Re(T)) && Z ? Z.p(T, F) : (Z.d(1), Z = Ne(T), Z && (Z.c(), Z.m(b, null))), F[0] & /*selectedPhotos*/
      2097152 && q !== (q = /*selectedPhotos*/
      T[21].length + "") && O(U, q), F[0] & /*canImport*/
      4194304 && ne !== (ne = !/*canImport*/
      T[22]) && (B.disabled = ne), F[0] & /*title*/
      512 && B.value !== /*title*/
      T[9] && le(
        B,
        /*title*/
        T[9]
      ), F[0] & /*canImport*/
      4194304 && re !== (re = !/*canImport*/
      T[22]) && (Y.disabled = re), F[0] & /*notes*/
      1024 && le(
        Y,
        /*notes*/
        T[10]
      ), F[0] & /*selectedCase*/
      64 && fe !== (fe = /*selectedCase*/
      T[6] ? "Ready to import into the selected case." : "Select a case to continue.") && O(ge, fe), F[0] & /*importing*/
      4096 && ve !== (ve = /*importing*/
      T[12] ? "Importing…" : "↥ Import photos") && O(we, ve), F[0] & /*canImport, importing, selectedCase, title, selectedPhotos*/
      6296128 && de !== (de = !/*canImport*/
      T[22] || /*importing*/
      T[12] || !/*selectedCase*/
      T[6] || !/*title*/
      T[9].trim() || !/*selectedPhotos*/
      T[21].length) && ($.disabled = de);
    },
    d(T) {
      T && R(t), De(A, T), L && L.d(), e[40](null), M && M.d(), G && G.d(), Z.d(), ke = !1, oe(Ie);
    }
  };
}
function Tt(e) {
  let t, l, s, i, c, r, p, d, f, y, v, _, g, P = (
    /*searchingProperties*/
    e[17] ? "Searching…" : "Search"
  ), S, w, I, E, b = !/*canProperties*/
  e[23] && tt();
  function D(h, C) {
    if (
      /*properties*/
      h[16].length
    ) return Rt;
    if (!/*searchingProperties*/
    h[17]) return Ut;
  }
  let k = D(e), m = k && k(e);
  return {
    c() {
      t = u("div"), l = u("h2"), l.textContent = "Property lookup", s = u("p"), s.textContent = "All matching properties are shown, including vacant properties.", b && b.c(), i = u("form"), c = u("label"), r = N("Street name"), p = u("input"), f = u("label"), y = N("Property number"), v = u("input"), g = u("button"), S = N(P), m && m.c(), o(l, "class", "svelte-17vubsv"), o(s, "class", "svelte-17vubsv"), o(p, "maxlength", "100"), o(p, "placeholder", "Grove Street"), p.disabled = d = !/*canProperties*/
      e[23], o(p, "class", "svelte-17vubsv"), o(c, "class", "svelte-17vubsv"), o(v, "maxlength", "40"), o(v, "placeholder", "123"), v.disabled = _ = !/*canProperties*/
      e[23], o(v, "class", "svelte-17vubsv"), o(f, "class", "svelte-17vubsv"), o(g, "class", "primary svelte-17vubsv"), g.disabled = w = !/*canProperties*/
      e[23] || /*searchingProperties*/
      e[17], o(i, "class", "svelte-17vubsv"), o(t, "class", "panel svelte-17vubsv");
    },
    m(h, C) {
      W(h, t, C), n(t, l), n(t, s), b && b.m(t, null), n(t, i), n(i, c), n(c, r), n(c, p), le(
        p,
        /*street*/
        e[14]
      ), n(i, f), n(f, y), n(f, v), le(
        v,
        /*propertyNumber*/
        e[15]
      ), n(i, g), n(g, S), m && m.m(t, null), I || (E = [
        V(
          p,
          "input",
          /*input0_input_handler*/
          e[37]
        ),
        V(
          v,
          "input",
          /*input1_input_handler*/
          e[38]
        ),
        V(i, "submit", dt(
          /*searchProperties*/
          e[30]
        ))
      ], I = !0);
    },
    p(h, C) {
      /*canProperties*/
      h[23] ? b && (b.d(1), b = null) : b || (b = tt(), b.c(), b.m(t, i)), C[0] & /*canProperties*/
      8388608 && d !== (d = !/*canProperties*/
      h[23]) && (p.disabled = d), C[0] & /*street*/
      16384 && p.value !== /*street*/
      h[14] && le(
        p,
        /*street*/
        h[14]
      ), C[0] & /*canProperties*/
      8388608 && _ !== (_ = !/*canProperties*/
      h[23]) && (v.disabled = _), C[0] & /*propertyNumber*/
      32768 && v.value !== /*propertyNumber*/
      h[15] && le(
        v,
        /*propertyNumber*/
        h[15]
      ), C[0] & /*searchingProperties*/
      131072 && P !== (P = /*searchingProperties*/
      h[17] ? "Searching…" : "Search") && O(S, P), C[0] & /*canProperties, searchingProperties*/
      8519680 && w !== (w = !/*canProperties*/
      h[23] || /*searchingProperties*/
      h[17]) && (g.disabled = w), k === (k = D(h)) && m ? m.p(h, C) : (m && m.d(1), m = k && k(h), m && (m.c(), m.m(t, null)));
    },
    d(h) {
      h && R(t), b && b.d(), m && m.d(), I = !1, oe(E);
    }
  };
}
function Be(e) {
  let t;
  return {
    c() {
      t = u("div"), t.textContent = "Witness Interview Import permission required.", o(t, "class", "warning svelte-17vubsv");
    },
    m(l, s) {
      W(l, t, s);
    },
    d(l) {
      l && R(t);
    }
  };
}
function Ke(e) {
  let t, l = (
    /*loadingInterviews*/
    e[18] ? "Reading inventory…" : "No witness interview forms in inventory."
  ), s;
  return {
    c() {
      t = u("div"), s = N(l), o(t, "class", "empty svelte-17vubsv");
    },
    m(i, c) {
      W(i, t, c), n(t, s);
    },
    p(i, c) {
      c[0] & /*loadingInterviews*/
      262144 && l !== (l = /*loadingInterviews*/
      i[18] ? "Reading inventory…" : "No witness interview forms in inventory.") && O(s, l);
    },
    d(i) {
      i && R(t);
    }
  };
}
function Ye(e) {
  let t, l = (
    /*x*/
    e[49].address + ""
  ), s;
  return {
    c() {
      t = u("small"), s = N(l), o(t, "class", "svelte-17vubsv");
    },
    m(i, c) {
      W(i, t, c), n(t, s);
    },
    p(i, c) {
      c[0] & /*interviews*/
      4 && l !== (l = /*x*/
      i[49].address + "") && O(s, l);
    },
    d(i) {
      i && R(t);
    }
  };
}
function Je(e) {
  let t, l, s = (
    /*x*/
    e[49].witnessName + ""
  ), i, c, r = (
    /*x*/
    (e[49].role || "Witness") + ""
  ), p, d, f = (
    /*x*/
    e[49].date ? "• " + /*x*/
    e[49].date : ""
  ), y, v, _ = (
    /*x*/
    e[49].statement + ""
  ), g, P, S, w = (
    /*x*/
    e[49].address && Ye(e)
  );
  function I() {
    return (
      /*click_handler_5*/
      e[45](
        /*x*/
        e[49]
      )
    );
  }
  return {
    c() {
      t = u("button"), l = u("strong"), i = N(s), c = u("span"), p = N(r), d = x(), y = N(f), v = u("p"), g = N(_), w && w.c(), o(l, "class", "svelte-17vubsv"), o(c, "class", "svelte-17vubsv"), o(v, "class", "svelte-17vubsv"), o(t, "class", "interview svelte-17vubsv"), K(
        t,
        "selected",
        /*interviewKeys*/
        e[3].includes(
          /*x*/
          e[49].key
        )
      );
    },
    m(E, b) {
      W(E, t, b), n(t, l), n(l, i), n(t, c), n(c, p), n(c, d), n(c, y), n(t, v), n(v, g), w && w.m(t, null), P || (S = V(t, "click", I), P = !0);
    },
    p(E, b) {
      e = E, b[0] & /*interviews*/
      4 && s !== (s = /*x*/
      e[49].witnessName + "") && O(i, s), b[0] & /*interviews*/
      4 && r !== (r = /*x*/
      (e[49].role || "Witness") + "") && O(p, r), b[0] & /*interviews*/
      4 && f !== (f = /*x*/
      e[49].date ? "• " + /*x*/
      e[49].date : "") && O(y, f), b[0] & /*interviews*/
      4 && _ !== (_ = /*x*/
      e[49].statement + "") && O(g, _), /*x*/
      e[49].address ? w ? w.p(e, b) : (w = Ye(e), w.c(), w.m(t, null)) : w && (w.d(1), w = null), b[0] & /*interviewKeys, interviews*/
      12 && K(
        t,
        "selected",
        /*interviewKeys*/
        e[3].includes(
          /*x*/
          e[49].key
        )
      );
    },
    d(E) {
      E && R(t), w && w.d(), P = !1, S();
    }
  };
}
function Qe(e) {
  let t, l, s = (
    /*selectedInterviews*/
    e[19].length + ""
  ), i, c, r, p = (
    /*importing*/
    e[12] ? "Importing…" : "Import selected interviews"
  ), d, f, y, v;
  return {
    c() {
      t = u("footer"), l = u("span"), i = N(s), c = N(" selected"), r = u("button"), d = N(p), o(l, "class", "svelte-17vubsv"), o(r, "class", "primary svelte-17vubsv"), r.disabled = f = !/*canInterviews*/
      e[20] || /*importing*/
      e[12] || !/*selectedCase*/
      e[6] || !/*selectedInterviews*/
      e[19].length, o(t, "class", "svelte-17vubsv");
    },
    m(_, g) {
      W(_, t, g), n(t, l), n(l, i), n(l, c), n(t, r), n(r, d), y || (v = V(
        r,
        "click",
        /*importInterviews*/
        e[32]
      ), y = !0);
    },
    p(_, g) {
      g[0] & /*selectedInterviews*/
      524288 && s !== (s = /*selectedInterviews*/
      _[19].length + "") && O(i, s), g[0] & /*importing*/
      4096 && p !== (p = /*importing*/
      _[12] ? "Importing…" : "Import selected interviews") && O(d, p), g[0] & /*canInterviews, importing, selectedCase, selectedInterviews*/
      1577024 && f !== (f = !/*canInterviews*/
      _[20] || /*importing*/
      _[12] || !/*selectedCase*/
      _[6] || !/*selectedInterviews*/
      _[19].length) && (r.disabled = f);
    },
    d(_) {
      _ && R(t), y = !1, v();
    }
  };
}
function Xe(e) {
  let t, l = (
    /*loading*/
    e[11] ? "Reading inventory…" : "No SD cards found."
  ), s;
  return {
    c() {
      t = u("div"), s = N(l), o(t, "class", "empty svelte-17vubsv");
    },
    m(i, c) {
      W(i, t, c), n(t, s);
    },
    p(i, c) {
      c[0] & /*loading*/
      2048 && l !== (l = /*loading*/
      i[11] ? "Reading inventory…" : "No SD cards found.") && O(s, l);
    },
    d(i) {
      i && R(t);
    }
  };
}
function Ze(e) {
  let t, l, s, i, c = (
    /*c*/
    e[54].label + ""
  ), r, p, d, f = (
    /*c*/
    e[54].slot + ""
  ), y, v, _ = (
    /*c*/
    e[54].count + ""
  ), g, P = (
    /*c*/
    e[54].max ? "/" + /*c*/
    e[54].max : ""
  ), S, w, I;
  function E() {
    return (
      /*click_handler_3*/
      e[39](
        /*c*/
        e[54]
      )
    );
  }
  return {
    c() {
      var b;
      t = u("button"), l = u("span"), l.textContent = "▣", s = u("span"), i = u("strong"), r = N(c), p = u("small"), d = N("Inventory slot "), y = N(f), v = u("em"), g = N(_), S = N(P), o(l, "class", "media-icon svelte-17vubsv"), o(i, "class", "svelte-17vubsv"), o(p, "class", "svelte-17vubsv"), o(s, "class", "svelte-17vubsv"), o(v, "class", "svelte-17vubsv"), o(t, "class", "card-row svelte-17vubsv"), K(
        t,
        "chosen",
        /*selectedCard*/
        ((b = e[8]) == null ? void 0 : b.slot) === /*c*/
        e[54].slot
      );
    },
    m(b, D) {
      W(b, t, D), n(t, l), n(t, s), n(s, i), n(i, r), n(s, p), n(p, d), n(p, y), n(t, v), n(v, g), n(v, S), w || (I = V(t, "click", E), w = !0);
    },
    p(b, D) {
      var k;
      e = b, D[0] & /*cards*/
      128 && c !== (c = /*c*/
      e[54].label + "") && O(r, c), D[0] & /*cards*/
      128 && f !== (f = /*c*/
      e[54].slot + "") && O(y, f), D[0] & /*cards*/
      128 && _ !== (_ = /*c*/
      e[54].count + "") && O(g, _), D[0] & /*cards*/
      128 && P !== (P = /*c*/
      e[54].max ? "/" + /*c*/
      e[54].max : "") && O(S, P), D[0] & /*selectedCard, cards*/
      384 && K(
        t,
        "chosen",
        /*selectedCard*/
        ((k = e[8]) == null ? void 0 : k.slot) === /*c*/
        e[54].slot
      );
    },
    d(b) {
      b && R(t), w = !1, I();
    }
  };
}
function $e(e) {
  let t, l, s = (
    /*selectedCase*/
    (e[6].caseNumber || /*selectedCase*/
    e[6].case_number || `Case #${/*selectedCase*/
    e[6].id}`) + ""
  ), i, c, r = (
    /*selectedCase*/
    e[6].title + ""
  ), p, d, f = (
    /*selectedCase*/
    (e[6].status || "Open") + ""
  ), y, v = (
    /*selectedCase*/
    e[6].department ? " · " + /*selectedCase*/
    e[6].department : ""
  ), _;
  return {
    c() {
      t = u("div"), l = u("strong"), i = N(s), c = N(" — "), p = N(r), d = u("small"), y = N(f), _ = N(v), o(l, "class", "svelte-17vubsv"), o(d, "class", "svelte-17vubsv"), o(t, "class", "case-summary svelte-17vubsv");
    },
    m(g, P) {
      W(g, t, P), n(t, l), n(l, i), n(l, c), n(l, p), n(t, d), n(d, y), n(d, _);
    },
    p(g, P) {
      P[0] & /*selectedCase*/
      64 && s !== (s = /*selectedCase*/
      (g[6].caseNumber || /*selectedCase*/
      g[6].case_number || `Case #${/*selectedCase*/
      g[6].id}`) + "") && O(i, s), P[0] & /*selectedCase*/
      64 && r !== (r = /*selectedCase*/
      g[6].title + "") && O(p, r), P[0] & /*selectedCase*/
      64 && f !== (f = /*selectedCase*/
      (g[6].status || "Open") + "") && O(y, f), P[0] & /*selectedCase*/
      64 && v !== (v = /*selectedCase*/
      g[6].department ? " · " + /*selectedCase*/
      g[6].department : "") && O(_, v);
    },
    d(g) {
      g && R(t);
    }
  };
}
function xe(e) {
  let t, l = (
    /*photoKeys*/
    e[1].length === /*photos*/
    e[0].length ? "Clear all" : "Select all"
  ), s, i, c;
  return {
    c() {
      t = u("button"), s = N(l), o(t, "class", "link-button svelte-17vubsv");
    },
    m(r, p) {
      W(r, t, p), n(t, s), i || (c = V(
        t,
        "click",
        /*selectAllPhotos*/
        e[26]
      ), i = !0);
    },
    p(r, p) {
      p[0] & /*photoKeys, photos*/
      3 && l !== (l = /*photoKeys*/
      r[1].length === /*photos*/
      r[0].length ? "Clear all" : "Select all") && O(s, l);
    },
    d(r) {
      r && R(t), i = !1, c();
    }
  };
}
function At(e) {
  let t, l = (
    /*selectedCard*/
    e[8] ? (
      /*loading*/
      e[11] ? "Loading photos…" : "This card is empty."
    ) : "Select an SD card."
  ), s;
  return {
    c() {
      t = u("div"), s = N(l), o(t, "class", "empty svelte-17vubsv");
    },
    m(i, c) {
      W(i, t, c), n(t, s);
    },
    p(i, c) {
      c[0] & /*selectedCard, loading*/
      2304 && l !== (l = /*selectedCard*/
      i[8] ? (
        /*loading*/
        i[11] ? "Loading photos…" : "This card is empty."
      ) : "Select an SD card.") && O(s, l);
    },
    d(i) {
      i && R(t);
    }
  };
}
function Ot(e) {
  let t, l = se(
    /*photos*/
    e[0]
  ), s = [];
  for (let i = 0; i < l.length; i += 1)
    s[i] = et(Fe(e, l, i));
  return {
    c() {
      t = u("div");
      for (let i = 0; i < s.length; i += 1)
        s[i].c();
      o(t, "class", "photos svelte-17vubsv");
    },
    m(i, c) {
      W(i, t, c);
      for (let r = 0; r < s.length; r += 1)
        s[r] && s[r].m(t, null);
    },
    p(i, c) {
      if (c[0] & /*photoKeys, photos, toggle*/
      33554435) {
        l = se(
          /*photos*/
          i[0]
        );
        let r;
        for (r = 0; r < l.length; r += 1) {
          const p = Fe(i, l, r);
          s[r] ? s[r].p(p, c) : (s[r] = et(p), s[r].c(), s[r].m(t, null));
        }
        for (; r < s.length; r += 1)
          s[r].d(1);
        s.length = l.length;
      }
    },
    d(i) {
      i && R(t), De(s, i);
    }
  };
}
function et(e) {
  let t, l, s, i, c, r = (
    /*x*/
    (e[49].location || "Unknown location") + ""
  ), p, d, f = (
    /*x*/
    (e[49].time ? new Date(
      /*x*/
      e[49].time * 1e3
    ).toLocaleString() : "No timestamp") + ""
  ), y, v, _;
  function g() {
    return (
      /*click_handler_4*/
      e[41](
        /*x*/
        e[49]
      )
    );
  }
  return {
    c() {
      t = u("button"), l = u("img"), c = u("strong"), p = N(r), d = u("small"), y = N(f), qe(l.src, s = /*x*/
      e[49].url) || o(l, "src", s), o(l, "alt", i = /*x*/
      e[49].location || "Evidence photo"), o(l, "class", "svelte-17vubsv"), o(c, "class", "svelte-17vubsv"), o(d, "class", "svelte-17vubsv"), o(t, "class", "svelte-17vubsv"), K(
        t,
        "selected",
        /*photoKeys*/
        e[1].includes(
          /*x*/
          e[49].key
        )
      );
    },
    m(P, S) {
      W(P, t, S), n(t, l), n(t, c), n(c, p), n(t, d), n(d, y), v || (_ = V(t, "click", g), v = !0);
    },
    p(P, S) {
      e = P, S[0] & /*photos*/
      1 && !qe(l.src, s = /*x*/
      e[49].url) && o(l, "src", s), S[0] & /*photos*/
      1 && i !== (i = /*x*/
      e[49].location || "Evidence photo") && o(l, "alt", i), S[0] & /*photos*/
      1 && r !== (r = /*x*/
      (e[49].location || "Unknown location") + "") && O(p, r), S[0] & /*photos*/
      1 && f !== (f = /*x*/
      (e[49].time ? new Date(
        /*x*/
        e[49].time * 1e3
      ).toLocaleString() : "No timestamp") + "") && O(y, f), S[0] & /*photoKeys, photos*/
      3 && K(
        t,
        "selected",
        /*photoKeys*/
        e[1].includes(
          /*x*/
          e[49].key
        )
      );
    },
    d(P) {
      P && R(t), v = !1, _();
    }
  };
}
function tt(e) {
  let t;
  return {
    c() {
      t = u("div"), t.textContent = "Property Search permission required.", o(t, "class", "warning svelte-17vubsv");
    },
    m(l, s) {
      W(l, t, s);
    },
    d(l) {
      l && R(t);
    }
  };
}
function Ut(e) {
  let t;
  return {
    c() {
      t = u("div"), t.textContent = "Search a street to find all matching properties.", o(t, "class", "empty svelte-17vubsv");
    },
    m(l, s) {
      W(l, t, s);
    },
    p: _e,
    d(l) {
      l && R(t);
    }
  };
}
function Rt(e) {
  let t, l = se(
    /*properties*/
    e[16]
  ), s = [];
  for (let i = 0; i < l.length; i += 1)
    s[i] = lt(Ge(e, l, i));
  return {
    c() {
      t = u("div");
      for (let i = 0; i < s.length; i += 1)
        s[i].c();
      o(t, "class", "results svelte-17vubsv");
    },
    m(i, c) {
      W(i, t, c);
      for (let r = 0; r < s.length; r += 1)
        s[r] && s[r].m(t, null);
    },
    p(i, c) {
      if (c[0] & /*properties*/
      65536) {
        l = se(
          /*properties*/
          i[16]
        );
        let r;
        for (r = 0; r < l.length; r += 1) {
          const p = Ge(i, l, r);
          s[r] ? s[r].p(p, c) : (s[r] = lt(p), s[r].c(), s[r].m(t, null));
        }
        for (; r < s.length; r += 1)
          s[r].d(1);
        s.length = l.length;
      }
    },
    d(i) {
      i && R(t), De(s, i);
    }
  };
}
function lt(e) {
  let t, l, s, i = (
    /*x*/
    e[49].apartment ? (
      /*x*/
      e[49].apartment + " — "
    ) : ""
  ), c, r, p = (
    /*x*/
    e[49].propertyId + ""
  ), d, f, y = (
    /*x*/
    e[49].street + ""
  ), v, _, g = (
    /*x*/
    (e[49].region || "Unknown region") + ""
  ), P, S, w, I, E = (
    /*x*/
    e[49].ownerName + ""
  ), b, D, k = (
    /*x*/
    (e[49].ownerCitizenId || "No registered owner") + ""
  ), m;
  return {
    c() {
      t = u("article"), l = u("div"), s = u("strong"), c = N(i), r = N("No. "), d = N(p), f = N(", "), v = N(y), _ = u("small"), P = N(g), S = u("div"), w = u("small"), w.textContent = "OCCUPANCY", I = u("strong"), b = N(E), D = u("small"), m = N(k), o(s, "class", "svelte-17vubsv"), o(_, "class", "svelte-17vubsv"), o(l, "class", "svelte-17vubsv"), o(w, "class", "svelte-17vubsv"), o(I, "class", "svelte-17vubsv"), K(
        I,
        "vacant",
        /*x*/
        e[49].vacant
      ), o(D, "class", "svelte-17vubsv"), o(S, "class", "svelte-17vubsv"), o(t, "class", "svelte-17vubsv");
    },
    m(h, C) {
      W(h, t, C), n(t, l), n(l, s), n(s, c), n(s, r), n(s, d), n(s, f), n(s, v), n(l, _), n(_, P), n(t, S), n(S, w), n(S, I), n(I, b), n(S, D), n(D, m);
    },
    p(h, C) {
      C[0] & /*properties*/
      65536 && i !== (i = /*x*/
      h[49].apartment ? (
        /*x*/
        h[49].apartment + " — "
      ) : "") && O(c, i), C[0] & /*properties*/
      65536 && p !== (p = /*x*/
      h[49].propertyId + "") && O(d, p), C[0] & /*properties*/
      65536 && y !== (y = /*x*/
      h[49].street + "") && O(v, y), C[0] & /*properties*/
      65536 && g !== (g = /*x*/
      (h[49].region || "Unknown region") + "") && O(P, g), C[0] & /*properties*/
      65536 && E !== (E = /*x*/
      h[49].ownerName + "") && O(b, E), C[0] & /*properties*/
      65536 && K(
        I,
        "vacant",
        /*x*/
        h[49].vacant
      ), C[0] & /*properties*/
      65536 && k !== (k = /*x*/
      (h[49].ownerCitizenId || "No registered owner") + "") && O(m, k);
    },
    d(h) {
      h && R(t);
    }
  };
}
function Lt(e) {
  let t, l, s, i, c, r = (
    /*activeTab*/
    e[4] === "photos" ? "SD CARD PHOTOS" : "INVESTIGATIONS"
  ), p, d, f = (
    /*activeTab*/
    e[4] === "photos" ? "Import SD Card Photos" : "Case evidence tools"
  ), y, v, _ = (
    /*activeTab*/
    e[4] === "photos" ? "Select a case, an SD card, and the photos to register as case evidence." : "Find properties and import inventory evidence into an investigation."
  ), g, P, S, w, I, E, b, D, k, m, h = (
    /*error*/
    e[13] && Ve(e)
  );
  function C(U, H) {
    return (
      /*activeTab*/
      U[4] === "properties" ? Tt : (
        /*activeTab*/
        U[4] === "photos" ? Dt : Et
      )
    );
  }
  let j = C(e), q = j(e);
  return {
    c() {
      t = u("link"), l = x(), s = u("section"), i = u("header"), c = u("span"), p = N(r), d = u("h1"), y = N(f), v = u("p"), g = N(_), P = x(), S = u("nav"), w = u("button"), w.textContent = "▣ Photos", I = u("button"), I.textContent = "⌂ Property lookup", E = u("button"), E.textContent = "◉ Witness interviews", b = x(), h && h.c(), D = x(), q.c(), o(t, "rel", "stylesheet"), o(t, "href", "/modules/investigations-module/web/dist/style.css"), o(c, "class", "svelte-17vubsv"), o(d, "class", "svelte-17vubsv"), o(v, "class", "svelte-17vubsv"), o(i, "class", "page-header svelte-17vubsv"), o(w, "class", "svelte-17vubsv"), K(
        w,
        "active",
        /*activeTab*/
        e[4] === "photos"
      ), o(I, "class", "svelte-17vubsv"), K(
        I,
        "active",
        /*activeTab*/
        e[4] === "properties"
      ), o(E, "class", "svelte-17vubsv"), K(
        E,
        "active",
        /*activeTab*/
        e[4] === "interviews"
      ), o(S, "class", "svelte-17vubsv"), o(s, "class", "page svelte-17vubsv");
    },
    m(U, H) {
      n(document.head, t), W(U, l, H), W(U, s, H), n(s, i), n(i, c), n(c, p), n(i, d), n(d, y), n(i, v), n(v, g), n(s, P), n(s, S), n(S, w), n(S, I), n(S, E), n(s, b), h && h.m(s, null), n(s, D), q.m(s, null), k || (m = [
        V(
          w,
          "click",
          /*click_handler*/
          e[34]
        ),
        V(
          I,
          "click",
          /*click_handler_1*/
          e[35]
        ),
        V(
          E,
          "click",
          /*click_handler_2*/
          e[36]
        )
      ], k = !0);
    },
    p(U, H) {
      H[0] & /*activeTab*/
      16 && r !== (r = /*activeTab*/
      U[4] === "photos" ? "SD CARD PHOTOS" : "INVESTIGATIONS") && O(p, r), H[0] & /*activeTab*/
      16 && f !== (f = /*activeTab*/
      U[4] === "photos" ? "Import SD Card Photos" : "Case evidence tools") && O(y, f), H[0] & /*activeTab*/
      16 && _ !== (_ = /*activeTab*/
      U[4] === "photos" ? "Select a case, an SD card, and the photos to register as case evidence." : "Find properties and import inventory evidence into an investigation.") && O(g, _), H[0] & /*activeTab*/
      16 && K(
        w,
        "active",
        /*activeTab*/
        U[4] === "photos"
      ), H[0] & /*activeTab*/
      16 && K(
        I,
        "active",
        /*activeTab*/
        U[4] === "properties"
      ), H[0] & /*activeTab*/
      16 && K(
        E,
        "active",
        /*activeTab*/
        U[4] === "interviews"
      ), /*error*/
      U[13] ? h ? h.p(U, H) : (h = Ve(U), h.c(), h.m(s, D)) : h && (h.d(1), h = null), j === (j = C(U)) && q ? q.p(U, H) : (q.d(1), q = j(U), q && (q.c(), q.m(s, null)));
    },
    i: _e,
    o: _e,
    d(U) {
      U && (R(l), R(s)), R(t), h && h.d(), q.d(), k = !1, oe(m);
    }
  };
}
function Wt(e, t, l) {
  let s, i, c, r, p, { moduleApi: d } = t, f = "photos", y, v, _ = null, g = [], P = null, S = [], w = [], I = "", E = "", b = !1, D = !1, k = "", m = "", h = "", C = [], j = !1, q = [], U = [], H = !1;
  function ee() {
    v == null || v.destroy(), v = y ? d.ui.createCaseSearch(y, {
      placeholder: "Search case number or title...",
      onSelect: (a) => {
        l(6, _ = a), l(13, k = "");
      }
    }) : null;
  }
  async function Q(a) {
    f !== a && (v == null || v.destroy(), v = null, l(4, f = a), await _t(), f !== "properties" && ee(), a === "interviews" && !q.length && me());
  }
  ht(() => {
    ee(), B();
  }), bt(() => v == null ? void 0 : v.destroy());
  const X = (a, A) => a.includes(A) ? a.filter((L) => L !== A) : [...a, A], Se = () => l(1, w = w.length === S.length ? [] : S.map((a) => a.key)), J = (a, A) => a instanceof Error ? a.message : A;
  async function B() {
    l(11, b = !0);
    try {
      const a = await d.fetchNui("getSDCards");
      l(7, g = a != null && a.success ? a.cards || [] : []), a != null && a.success || l(13, k = (a == null ? void 0 : a.message) || "Unable to load SD cards.");
    } catch (a) {
      l(13, k = J(a, "Unable to load SD cards."));
    } finally {
      l(11, b = !1);
    }
  }
  async function ne(a) {
    l(8, P = a), l(0, S = []), l(1, w = []), l(11, b = !0);
    try {
      const A = await d.fetchNui("getSDCardPhotos", { slot: a.slot });
      if (!(A != null && A.success)) throw new Error((A == null ? void 0 : A.message) || "Unable to load photos.");
      l(0, S = (A.photos || []).map((L, M) => ({
        ...L,
        key: `${a.slot}:${L.id || M}:${M}`
      })));
    } catch (A) {
      l(13, k = J(A, "Unable to load photos."));
    } finally {
      l(11, b = !1);
    }
  }
  async function ae() {
    if (!(!s || !_ || !I.trim() || !r.length)) {
      l(12, D = !0);
      try {
        const a = await d.fetchNui("importPhotos", {
          caseId: +_.id,
          title: I.trim(),
          notes: E.trim(),
          mode: "combined",
          storageTarget: "evidence",
          photos: r.map(({ url: A, location: L, coords: M, time: G }) => ({ url: A, location: L, coords: M, time: G }))
        });
        if (!(a != null && a.success)) throw new Error((a == null ? void 0 : a.message) || "Photo import failed.");
        d.notify(`Imported ${a.photoCount} photo(s) as case evidence`, "success"), l(1, w = []), l(9, I = ""), l(10, E = "");
      } catch (a) {
        l(13, k = J(a, "Photo import failed."));
      } finally {
        l(12, D = !1);
      }
    }
  }
  async function te() {
    l(17, j = !0), l(13, k = "");
    try {
      const a = await d.fetchNui("searchProperties", { street: m, propertyNumber: h });
      if (!(a != null && a.success)) throw new Error((a == null ? void 0 : a.message) || "Property search failed.");
      l(16, C = a.properties || []);
    } catch (a) {
      l(16, C = []), l(13, k = J(a, "Property search failed."));
    } finally {
      l(17, j = !1);
    }
  }
  async function me() {
    l(18, H = !0), l(13, k = "");
    try {
      const a = await d.fetchNui("getWitnessInterviews");
      if (!(a != null && a.success)) throw new Error((a == null ? void 0 : a.message) || "Unable to load witness interviews.");
      l(2, q = (a.interviews || []).map((A, L) => ({ ...A, key: `${A.id}:${L}` })));
    } catch (a) {
      l(2, q = []), l(13, k = J(a, "Unable to load witness interviews."));
    } finally {
      l(18, H = !1);
    }
  }
  async function ue() {
    if (!(!c || !_ || !p.length)) {
      l(12, D = !0);
      try {
        const a = await d.fetchNui("importWitnessInterviews", {
          caseId: +_.id,
          interviews: p.map(({ slot: A }) => ({ slot: A }))
        });
        if (!(a != null && a.success)) throw new Error((a == null ? void 0 : a.message) || "Interview import failed.");
        d.notify(`Imported ${a.interviewCount} witness interview(s) as evidence`, "success"), l(3, U = []);
      } catch (a) {
        l(13, k = J(a, "Interview import failed."));
      } finally {
        l(12, D = !1);
      }
    }
  }
  const Y = () => Q("photos"), re = () => Q("properties"), ie = () => Q("interviews");
  function ce() {
    m = this.value, l(14, m);
  }
  function fe() {
    h = this.value, l(15, h);
  }
  const ge = (a) => ne(a);
  function $(a) {
    Ee[a ? "unshift" : "push"](() => {
      y = a, l(5, y);
    });
  }
  const ve = (a) => l(1, w = X(w, a.key));
  function we() {
    I = this.value, l(9, I);
  }
  function de() {
    E = this.value, l(10, E);
  }
  function ke(a) {
    Ee[a ? "unshift" : "push"](() => {
      y = a, l(5, y);
    });
  }
  const Ie = (a) => l(3, U = X(U, a.key));
  return e.$$set = (a) => {
    "moduleApi" in a && l(33, d = a.moduleApi);
  }, e.$$.update = () => {
    e.$$.dirty[1] & /*moduleApi*/
    4 && l(22, s = d.hasPermission("investigations-module.import")), e.$$.dirty[1] & /*moduleApi*/
    4 && l(23, i = d.hasPermission("investigations-module.property_search")), e.$$.dirty[1] & /*moduleApi*/
    4 && l(20, c = d.hasPermission("investigations-module.interview_import")), e.$$.dirty[0] & /*photos, photoKeys*/
    3 && l(21, r = S.filter((a) => w.includes(a.key))), e.$$.dirty[0] & /*interviews, interviewKeys*/
    12 && l(19, p = q.filter((a) => U.includes(a.key)));
  }, [
    S,
    w,
    q,
    U,
    f,
    y,
    _,
    g,
    P,
    I,
    E,
    b,
    D,
    k,
    m,
    h,
    C,
    j,
    H,
    p,
    c,
    r,
    s,
    i,
    Q,
    X,
    Se,
    B,
    ne,
    ae,
    te,
    me,
    ue,
    d,
    Y,
    re,
    ie,
    ce,
    fe,
    ge,
    $,
    ve,
    we,
    de,
    ke,
    Ie
  ];
}
class Ht extends Nt {
  constructor(t) {
    super(), It(this, t, Wt, Lt, ft, { moduleApi: 33 }, null, [-1, -1]);
  }
}
export {
  Ht as default
};
