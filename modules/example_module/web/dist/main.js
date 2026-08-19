var X = Object.defineProperty;
var Y = (e, t, n) => t in e ? X(e, t, { enumerable: !0, configurable: !0, writable: !0, value: n }) : e[t] = n;
var P = (e, t, n) => Y(e, typeof t != "symbol" ? t + "" : t, n);
function k() {
}
function K(e) {
  return e();
}
function H() {
  return /* @__PURE__ */ Object.create(null);
}
function L(e) {
  e.forEach(K);
}
function Q(e) {
  return typeof e == "function";
}
function Z(e, t) {
  return e != e ? t == t : e !== t || e && typeof e == "object" || typeof e == "function";
}
function ee(e) {
  return Object.keys(e).length === 0;
}
function f(e, t) {
  e.appendChild(t);
}
function M(e, t, n) {
  e.insertBefore(t, n || null);
}
function E(e) {
  e.parentNode && e.parentNode.removeChild(e);
}
function te(e, t) {
  for (let n = 0; n < e.length; n += 1)
    e[n] && e[n].d(t);
}
function a(e) {
  return document.createElement(e);
}
function T(e) {
  return document.createTextNode(e);
}
function $() {
  return T(" ");
}
function m(e, t, n) {
  n == null ? e.removeAttribute(t) : e.getAttribute(t) !== n && e.setAttribute(t, n);
}
function ne(e) {
  return Array.from(e.childNodes);
}
function j(e, t) {
  t = "" + t, e.data !== t && (e.data = /** @type {string} */
  t);
}
function U(e, t, n) {
  e.classList.toggle(t, !!n);
}
let N;
function C(e) {
  N = e;
}
function le() {
  if (!N) throw new Error("Function called outside component initialization");
  return N;
}
function se(e) {
  le().$$.on_mount.push(e);
}
const y = [], V = [];
let x = [];
const q = [], re = /* @__PURE__ */ Promise.resolve();
let I = !1;
function oe() {
  I || (I = !0, re.then(W));
}
function R(e) {
  x.push(e);
}
const F = /* @__PURE__ */ new Set();
let v = 0;
function W() {
  if (v !== 0)
    return;
  const e = N;
  do {
    try {
      for (; v < y.length; ) {
        const t = y[v];
        v++, C(t), ce(t.$$);
      }
    } catch (t) {
      throw y.length = 0, v = 0, t;
    }
    for (C(null), y.length = 0, v = 0; V.length; ) V.pop()();
    for (let t = 0; t < x.length; t += 1) {
      const n = x[t];
      F.has(n) || (F.add(n), n());
    }
    x.length = 0;
  } while (y.length);
  for (; q.length; )
    q.pop()();
  I = !1, F.clear(), C(e);
}
function ce(e) {
  if (e.fragment !== null) {
    e.update(), L(e.before_update);
    const t = e.dirty;
    e.dirty = [-1], e.fragment && e.fragment.p(e.ctx, t), e.after_update.forEach(R);
  }
}
function ie(e) {
  const t = [], n = [];
  x.forEach((l) => e.indexOf(l) === -1 ? t.push(l) : n.push(l)), n.forEach((l) => l()), x = t;
}
const ue = /* @__PURE__ */ new Set();
function fe(e, t) {
  e && e.i && (ue.delete(e), e.i(t));
}
function D(e) {
  return (e == null ? void 0 : e.length) !== void 0 ? e : Array.from(e);
}
function ae(e, t, n) {
  const { fragment: l, after_update: o } = e.$$;
  l && l.m(t, n), R(() => {
    const u = e.$$.on_mount.map(K).filter(Q);
    e.$$.on_destroy ? e.$$.on_destroy.push(...u) : L(u), e.$$.on_mount = [];
  }), o.forEach(R);
}
function de(e, t) {
  const n = e.$$;
  n.fragment !== null && (ie(n.after_update), L(n.on_destroy), n.fragment && n.fragment.d(t), n.on_destroy = n.fragment = null, n.ctx = []);
}
function he(e, t) {
  e.$$.dirty[0] === -1 && (y.push(e), oe(), e.$$.dirty.fill(0)), e.$$.dirty[t / 31 | 0] |= 1 << t % 31;
}
function me(e, t, n, l, o, u, i = null, c = [-1]) {
  const r = N;
  C(e);
  const s = e.$$ = {
    fragment: null,
    ctx: [],
    // state
    props: u,
    update: k,
    not_equal: o,
    bound: H(),
    // lifecycle
    on_mount: [],
    on_destroy: [],
    on_disconnect: [],
    before_update: [],
    after_update: [],
    context: new Map(t.context || (r ? r.$$.context : [])),
    // everything else
    callbacks: H(),
    dirty: c,
    skip_bound: !1,
    root: t.target || r.$$.root
  };
  i && i(s.root);
  let _ = !1;
  if (s.ctx = n ? n(e, t.props || {}, (d, b, ...A) => {
    const p = A.length ? A[0] : b;
    return s.ctx && o(s.ctx[d], s.ctx[d] = p) && (!s.skip_bound && s.bound[d] && s.bound[d](p), _ && he(e, d)), b;
  }) : [], s.update(), _ = !0, L(s.before_update), s.fragment = l ? l(s.ctx) : !1, t.target) {
    if (t.hydrate) {
      const d = ne(t.target);
      s.fragment && s.fragment.l(d), d.forEach(E);
    } else
      s.fragment && s.fragment.c();
    t.intro && fe(e.$$.fragment), ae(e, t.target, t.anchor), W();
  }
  C(r);
}
class _e {
  constructor() {
    /**
     * ### PRIVATE API
     *
     * Do not use, may change at any time
     *
     * @type {any}
     */
    P(this, "$$");
    /**
     * ### PRIVATE API
     *
     * Do not use, may change at any time
     *
     * @type {any}
     */
    P(this, "$$set");
  }
  /** @returns {void} */
  $destroy() {
    de(this, 1), this.$destroy = k;
  }
  /**
   * @template {Extract<keyof Events, string>} K
   * @param {K} type
   * @param {((e: Events[K]) => void) | null | undefined} callback
   * @returns {() => void}
   */
  $on(t, n) {
    if (!Q(n))
      return k;
    const l = this.$$.callbacks[t] || (this.$$.callbacks[t] = []);
    return l.push(n), () => {
      const o = l.indexOf(n);
      o !== -1 && l.splice(o, 1);
    };
  }
  /**
   * @param {Partial<Props>} props
   * @returns {void}
   */
  $set(t) {
    this.$$set && !ee(t) && (this.$$.skip_bound = !0, this.$$set(t), this.$$.skip_bound = !1);
  }
}
const pe = "4";
typeof window < "u" && (window.__svelte || (window.__svelte = { v: /* @__PURE__ */ new Set() })).v.add(pe);
function G(e, t, n) {
  const l = e.slice();
  return l[5] = t[n], l;
}
function ge(e) {
  let t, n, l, o, u = D(
    /*rows*/
    e[1]
  ), i = [];
  for (let c = 0; c < u.length; c += 1)
    i[c] = J(G(e, u, c));
  return {
    c() {
      t = a("table"), n = a("thead"), n.innerHTML = '<tr><th class="svelte-1rldnow">Index</th><th class="svelte-1rldnow">Random value</th></tr>', l = $(), o = a("tbody");
      for (let c = 0; c < i.length; c += 1)
        i[c].c();
      m(t, "class", "svelte-1rldnow");
    },
    m(c, r) {
      M(c, t, r), f(t, n), f(t, l), f(t, o);
      for (let s = 0; s < i.length; s += 1)
        i[s] && i[s].m(o, null);
    },
    p(c, r) {
      if (r & /*rows*/
      2) {
        u = D(
          /*rows*/
          c[1]
        );
        let s;
        for (s = 0; s < u.length; s += 1) {
          const _ = G(c, u, s);
          i[s] ? i[s].p(_, r) : (i[s] = J(_), i[s].c(), i[s].m(o, null));
        }
        for (; s < i.length; s += 1)
          i[s].d(1);
        i.length = u.length;
      }
    },
    d(c) {
      c && E(t), te(i, c);
    }
  };
}
function be(e) {
  let t, n;
  return {
    c() {
      t = a("p"), n = T(
        /*error*/
        e[3]
      ), m(t, "class", "error svelte-1rldnow");
    },
    m(l, o) {
      M(l, t, o), f(t, n);
    },
    p(l, o) {
      o & /*error*/
      8 && j(
        n,
        /*error*/
        l[3]
      );
    },
    d(l) {
      l && E(t);
    }
  };
}
function we(e) {
  let t;
  return {
    c() {
      t = a("p"), t.textContent = "Loading random numbers from the FiveM client…", m(t, "class", "muted svelte-1rldnow");
    },
    m(n, l) {
      M(n, t, l);
    },
    p: k,
    d(n) {
      n && E(t);
    }
  };
}
function J(e) {
  let t, n, l = (
    /*row*/
    e[5].index + ""
  ), o, u, i = (
    /*row*/
    e[5].value + ""
  ), c;
  return {
    c() {
      t = a("tr"), n = a("td"), o = T(l), u = a("td"), c = T(i), m(n, "class", "svelte-1rldnow"), m(u, "class", "svelte-1rldnow");
    },
    m(r, s) {
      M(r, t, s), f(t, n), f(n, o), f(t, u), f(u, c);
    },
    p(r, s) {
      s & /*rows*/
      2 && l !== (l = /*row*/
      r[5].index + "") && j(o, l), s & /*rows*/
      2 && i !== (i = /*row*/
      r[5].value + "") && j(c, i);
    },
    d(r) {
      r && E(t);
    }
  };
}
function ve(e) {
  let t, n, l, o, u, i, c, r, s, _, d = (
    /*hasTestPermission*/
    e[0] ? "The current user has this permission." : "The current user does not have this permission."
  ), b, A, p, O, B;
  function z(h, w) {
    return (
      /*loading*/
      h[2] ? we : (
        /*error*/
        h[3] ? be : ge
      )
    );
  }
  let S = z(e), g = S(e);
  return {
    c() {
      t = a("section"), n = a("h1"), n.textContent = "Example Module", l = $(), o = a("div"), u = a("span"), i = $(), c = a("div"), r = a("strong"), r.textContent = "example_module.test", s = $(), _ = a("p"), b = T(d), A = $(), p = a("div"), O = a("h2"), O.textContent = "Client callback result", B = $(), g.c(), m(n, "class", "svelte-1rldnow"), m(u, "class", "status-dot svelte-1rldnow"), m(_, "class", "svelte-1rldnow"), m(o, "class", "permission-card svelte-1rldnow"), U(
        o,
        "allowed",
        /*hasTestPermission*/
        e[0]
      ), m(O, "class", "svelte-1rldnow"), m(p, "class", "table-card svelte-1rldnow"), m(t, "class", "example-module svelte-1rldnow");
    },
    m(h, w) {
      M(h, t, w), f(t, n), f(t, l), f(t, o), f(o, u), f(o, i), f(o, c), f(c, r), f(c, s), f(c, _), f(_, b), f(t, A), f(t, p), f(p, O), f(p, B), g.m(p, null);
    },
    p(h, [w]) {
      w & /*hasTestPermission*/
      1 && d !== (d = /*hasTestPermission*/
      h[0] ? "The current user has this permission." : "The current user does not have this permission.") && j(b, d), w & /*hasTestPermission*/
      1 && U(
        o,
        "allowed",
        /*hasTestPermission*/
        h[0]
      ), S === (S = z(h)) && g ? g.p(h, w) : (g.d(1), g = S(h), g && (g.c(), g.m(p, null)));
    },
    i: k,
    o: k,
    d(h) {
      h && E(t), g.d();
    }
  };
}
function $e(e, t, n) {
  let { moduleApi: l } = t, o = !1, u = [], i = !0, c = "";
  return se(async () => {
    n(0, o = l.hasPermission("example_module.test"));
    try {
      const r = await l.fetchNui("getRandomNumbers");
      if ((r == null ? void 0 : r.success) === !1)
        throw new Error(r.message || "The client callback failed");
      n(1, u = Array.isArray(r == null ? void 0 : r.numbers) ? r.numbers : []);
    } catch (r) {
      n(3, c = r instanceof Error ? r.message : "Failed to load random numbers");
    } finally {
      n(2, i = !1);
    }
  }), e.$$set = (r) => {
    "moduleApi" in r && n(4, l = r.moduleApi);
  }, [o, u, i, c, l];
}
class xe extends _e {
  constructor(t) {
    super(), me(this, t, $e, ve, Z, { moduleApi: 4 });
  }
}
export {
  xe as default
};
