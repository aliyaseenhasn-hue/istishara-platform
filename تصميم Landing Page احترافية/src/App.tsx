import { useState, useEffect, useRef, ReactNode } from "react";

// ─── Design Tokens ─────────────────────────────────────────────────────────────
const C = {
  navy:       "#0D1F3C",
  navyDeep:   "#071428",
  navyMid:    "#162E54",
  navyLight:  "#1E3E6E",
  gold:       "#C9A84C",
  goldLight:  "#DFC078",
  goldMuted:  "#A88838",
  goldSubtle: "rgba(201,168,76,0.12)",
  offwhite:   "#F7F6F3",
  surface:    "#EFEEEB",
  white:      "#FFFFFF",
  border:     "rgba(13,31,60,0.08)",
  borderMid:  "rgba(13,31,60,0.14)",
  textPrimary:"#0D1F3C",
  textMid:    "#4A5A74",
  textMuted:  "#8494A8",
};

// ─── Scroll Animation Hook ─────────────────────────────────────────────────────
function useFadeIn(delay = 0) {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setVisible(true); obs.disconnect(); } },
      { threshold: 0.12 }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  return {
    ref,
    style: {
      opacity: visible ? 1 : 0,
      transform: visible ? "translateY(0)" : "translateY(24px)",
      transition: `opacity 0.6s ease ${delay}ms, transform 0.6s ease ${delay}ms`,
    } as React.CSSProperties,
  };
}

// ─── FadeIn Wrapper ────────────────────────────────────────────────────────────
function FadeIn({ children, delay = 0, style = {} }: { children: ReactNode; delay?: number; style?: React.CSSProperties }) {
  const anim = useFadeIn(delay);
  return (
    <div ref={anim.ref} style={{ ...anim.style, ...style }}>
      {children}
    </div>
  );
}

// ─── SVG Icons ────────────────────────────────────────────────────────────────
const Icon = {
  Balance: ({ s = 22 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 22 22" fill="none">
      <path d="M11 3v16M4 19h14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      <path d="M11 3L6.5 10h9L11 3z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
      <path d="M6.5 10c0 1.66-1.12 3-2.5 3S1.5 11.66 1.5 10h5z" stroke="currentColor" strokeWidth="1.3" fill="none"/>
      <path d="M15.5 10c0 1.66-1.12 3-2.5 3s-2.5-1.34-2.5-3h5z" stroke="currentColor" strokeWidth="1.3" fill="none"/>
    </svg>
  ),
  Check: ({ s = 14 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 14 14" fill="none">
      <path d="M2.5 7.5l3 3L11.5 4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  Star: ({ s = 13, filled = false }: { s?: number; filled?: boolean }) => (
    <svg width={s} height={s} viewBox="0 0 13 13" fill={filled ? "currentColor" : "none"}>
      <path d="M6.5 1l1.4 3.8H12l-3.2 2.3 1.2 3.8-3.5-2.5-3.5 2.5 1.2-3.8L1 4.8h4.1L6.5 1z"
        stroke="currentColor" strokeWidth="0.8" strokeLinejoin="round"/>
    </svg>
  ),
  User: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <circle cx="10" cy="6.5" r="3.5" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M3 18c0-3.5 3.1-6.5 7-6.5s7 3 7 6.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
    </svg>
  ),
  Search: ({ s = 18 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 18 18" fill="none">
      <circle cx="8" cy="8" r="5" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M12 12l3.5 3.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
    </svg>
  ),
  Shield: ({ s = 22 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 22 22" fill="none">
      <path d="M11 2.5L3.5 5.5v5.5c0 4.5 3.5 8 7.5 9 4-1 7.5-4.5 7.5-9V5.5L11 2.5z"
        stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
      <path d="M8 11l2 2 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  Briefcase: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <rect x="2" y="7" width="16" height="11" rx="2" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M6.5 7V5a1.5 1.5 0 011.5-1.5h4A1.5 1.5 0 0113.5 5v2" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M2 12h16" stroke="currentColor" strokeWidth="1.4"/>
    </svg>
  ),
  Menu: ({ s = 22 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 22 22" fill="none">
      <path d="M3 6h16M3 11h16M3 16h11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  ),
  Close: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <path d="M5 5l10 10M15 5L5 15" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  ),
  ChevronDown: ({ s = 16 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 16 16" fill="none">
      <path d="M4 6l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  Arrow: ({ s = 17 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 17 17" fill="none">
      <path d="M3.5 8.5h10M9.5 4.5l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  Document: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <path d="M11 2H5a1 1 0 00-1 1v14a1 1 0 001 1h10a1 1 0 001-1V7l-5-5z"
        stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
      <path d="M11 2v5h5M7 10.5h6M7 13.5h4" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
    </svg>
  ),
  Award: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <circle cx="10" cy="8" r="5" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M7 12.5l-2 6 5-2.5 5 2.5-2-6" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
    </svg>
  ),
  Globe: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <circle cx="10" cy="10" r="7.5" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M10 2.5c-2.5 2.5-3.5 4.5-3.5 7.5s1 5 3.5 7.5M10 2.5c2.5 2.5 3.5 4.5 3.5 7.5s-1 5-3.5 7.5M2.5 10h15"
        stroke="currentColor" strokeWidth="1.4"/>
    </svg>
  ),
  Phone: ({ s = 20 }: { s?: number }) => (
    <svg width={s} height={s} viewBox="0 0 20 20" fill="none">
      <rect x="5" y="1.5" width="10" height="17" rx="2" stroke="currentColor" strokeWidth="1.4"/>
      <circle cx="10" cy="15.5" r="0.8" fill="currentColor"/>
    </svg>
  ),
};

// ─── Pill Label ───────────────────────────────────────────────────────────────
function PillLabel({ children, light = false }: { children: ReactNode; light?: boolean }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 7,
      padding: "5px 14px",
      background: light ? "rgba(255,255,255,0.1)" : C.goldSubtle,
      border: `1px solid ${light ? "rgba(255,255,255,0.15)" : "rgba(201,168,76,0.22)"}`,
      borderRadius: 100,
      marginBottom: 18,
    }}>
      <div style={{ width: 5, height: 5, borderRadius: "50%", background: light ? C.goldLight : C.gold, flexShrink: 0 }} />
      <span style={{ fontFamily: "Tajawal", fontSize: 12, fontWeight: 600, color: light ? C.goldLight : C.goldMuted, letterSpacing: 0.4 }}>
        {children}
      </span>
    </div>
  );
}

// ─── Section Heading ──────────────────────────────────────────────────────────
function SectionHeading({ eyebrow, title, subtitle, center = true, light = false }: {
  eyebrow?: string; title: string; subtitle?: string; center?: boolean; light?: boolean;
}) {
  return (
    <FadeIn style={{ textAlign: center ? "center" : "right", marginBottom: 56 }}>
      {eyebrow && (
        <div style={{
          fontFamily: "Tajawal", fontSize: 11, fontWeight: 700,
          color: C.goldMuted, letterSpacing: 2,
          textTransform: "uppercase", marginBottom: 12,
          display: center ? "block" : "inline-block",
        }}>
          {eyebrow}
        </div>
      )}
      <h2 style={{
        fontFamily: "Tajawal", fontWeight: 900,
        fontSize: "clamp(26px, 3.5vw, 40px)",
        color: light ? "#fff" : C.navy,
        lineHeight: 1.25, margin: "0 0 14px",
      }}>
        {title}
      </h2>
      {subtitle && (
        <p style={{
          fontFamily: "Tajawal", fontSize: 17, fontWeight: 400,
          color: light ? "rgba(255,255,255,0.55)" : C.textMid,
          lineHeight: 1.7, maxWidth: 520,
          margin: center ? "0 auto" : "0",
        }}>
          {subtitle}
        </p>
      )}
    </FadeIn>
  );
}

// ─── Header ───────────────────────────────────────────────────────────────────
function Header() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const fn = () => setScrolled(window.scrollY > 24);
    window.addEventListener("scroll", fn, { passive: true });
    return () => window.removeEventListener("scroll", fn);
  }, []);

  const nav = [
    { label: "الرئيسية", href: "#hero" },
    { label: "كيف تعمل؟", href: "#how-it-works" },
    { label: "للمحامين", href: "#for-lawyers" },
    { label: "الأسئلة الشائعة", href: "#faq" },
    { label: "عن استشارة", href: "#stats" },
  ];

  return (
    <>
      <header style={{
        position: "fixed", top: 0, right: 0, left: 0, zIndex: 200,
        height: 70,
        background: scrolled ? "rgba(247,246,243,0.95)" : "transparent",
        backdropFilter: scrolled ? "blur(16px)" : "none",
        borderBottom: `1px solid ${scrolled ? C.border : "transparent"}`,
        transition: "background 0.35s, border-color 0.35s, backdrop-filter 0.35s",
      }}>
        <div style={{ maxWidth: 1300, margin: "0 auto", padding: "0 28px", height: "100%", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          {/* Logo */}
          <a href="#hero" style={{ display: "flex", alignItems: "center", gap: 9, textDecoration: "none" }}>
            <div style={{
              width: 38, height: 38, borderRadius: 9,
              background: C.navy,
              display: "flex", alignItems: "center", justifyContent: "center",
              flexShrink: 0,
            }}>
              <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
                <path d="M11 3.5v15M4.5 18.5h13" stroke={C.gold} strokeWidth="1.5" strokeLinecap="round"/>
                <path d="M11 3.5L7 9.5h8L11 3.5z" stroke={C.gold} strokeWidth="1.3" strokeLinejoin="round"/>
                <path d="M7 9.5H4.5M14.5 9.5H17" stroke={C.gold} strokeWidth="1.3" strokeLinecap="round"/>
              </svg>
            </div>
            <span style={{ fontFamily: "Tajawal", fontWeight: 800, fontSize: 21, color: C.navy, letterSpacing: -0.3 }}>
              استشارة
            </span>
          </a>

          {/* Desktop nav */}
          <nav style={{ display: "flex", alignItems: "center", gap: 2 }} className="hdr-nav">
            {nav.map(l => (
              <a key={l.href} href={l.href} className="nav-link" style={{
                fontFamily: "Tajawal", fontWeight: 500, fontSize: 14.5,
                color: C.textMid, textDecoration: "none",
                padding: "6px 13px", borderRadius: 7,
                transition: "color 0.18s, background 0.18s",
              }}>{l.label}</a>
            ))}
          </nav>

          {/* Actions */}
          <div style={{ display: "flex", gap: 9, alignItems: "center" }}>
            <a href="#" className="hdr-nav" style={{
              fontFamily: "Tajawal", fontWeight: 500, fontSize: 14.5,
              color: C.navy, textDecoration: "none",
              padding: "7px 18px", borderRadius: 8,
              border: `1.5px solid ${C.borderMid}`,
              transition: "all 0.18s",
            }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = C.navy; e.currentTarget.style.background = "rgba(13,31,60,0.04)"; }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = C.borderMid; e.currentTarget.style.background = "transparent"; }}
            >تسجيل الدخول</a>

            <a href="#" style={{
              fontFamily: "Tajawal", fontWeight: 700, fontSize: 14.5,
              color: "#fff", textDecoration: "none",
              padding: "7px 22px", borderRadius: 8,
              background: C.navy,
              transition: "background 0.18s",
            }}
              onMouseEnter={e => e.currentTarget.style.background = C.gold}
              onMouseLeave={e => e.currentTarget.style.background = C.navy}
            >ابدأ الآن</a>

            <button
              onClick={() => setMenuOpen(p => !p)}
              className="hdr-mob"
              style={{ background: "none", border: "none", cursor: "pointer", padding: 4, color: C.navy, display: "none" }}
            >
              {menuOpen ? <Icon.Close s={20} /> : <Icon.Menu s={22} />}
            </button>
          </div>
        </div>
      </header>

      {/* Mobile drawer */}
      {menuOpen && (
        <div style={{
          position: "fixed", top: 70, right: 0, left: 0, zIndex: 199,
          background: "rgba(247,246,243,0.98)", backdropFilter: "blur(16px)",
          padding: "12px 28px 24px",
          borderBottom: `1px solid ${C.border}`,
        }}>
          {nav.map(l => (
            <a key={l.href} href={l.href} onClick={() => setMenuOpen(false)} style={{
              display: "block", padding: "13px 0",
              fontFamily: "Tajawal", fontWeight: 500, fontSize: 16,
              color: C.navy, textDecoration: "none",
              borderBottom: `1px solid ${C.border}`,
            }}>{l.label}</a>
          ))}
          <div style={{ marginTop: 16, display: "flex", gap: 10 }}>
            <a href="#" style={{
              flex: 1, textAlign: "center", padding: "11px",
              borderRadius: 9, border: `1.5px solid ${C.navy}`,
              fontFamily: "Tajawal", fontWeight: 600, fontSize: 15,
              color: C.navy, textDecoration: "none",
            }}>تسجيل الدخول</a>
            <a href="#" style={{
              flex: 1, textAlign: "center", padding: "11px",
              borderRadius: 9, background: C.navy,
              fontFamily: "Tajawal", fontWeight: 700, fontSize: 15,
              color: "#fff", textDecoration: "none",
            }}>ابدأ الآن</a>
          </div>
        </div>
      )}

      <style>{`
        .nav-link:hover { color: ${C.navy} !important; background: rgba(13,31,60,0.05) !important; }
        @media (max-width: 920px) { .hdr-nav { display: none !important; } .hdr-mob { display: flex !important; } }
      `}</style>
    </>
  );
}

// ─── Hero ─────────────────────────────────────────────────────────────────────
function StatusDot({ available }: { available: boolean }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 5,
      padding: "3px 9px", borderRadius: 20,
      background: available ? "rgba(34,197,94,0.1)" : "rgba(148,163,184,0.12)",
      fontSize: 11.5, fontFamily: "Tajawal", fontWeight: 700,
      color: available ? "#16a34a" : "#94a3b8",
    }}>
      <div style={{ width: 5, height: 5, borderRadius: "50%", background: available ? "#22c55e" : "#94a3b8" }} />
      {available ? "متاح" : "مشغول"}
    </div>
  );
}

function MiniLawyerCard({ name, specialty, rating, available }: {
  name: string; specialty: string; rating: number; available: boolean;
}) {
  return (
    <div style={{
      background: C.white, borderRadius: 12, padding: "14px 16px",
      border: `1px solid ${C.border}`,
      boxShadow: "0 1px 8px rgba(13,31,60,0.06)",
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 11, marginBottom: 10 }}>
        <div style={{
          width: 40, height: 40, borderRadius: "50%",
          background: `linear-gradient(135deg, ${C.navyMid}, ${C.navy})`,
          display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
        }}>
          <Icon.User s={17} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 14, color: C.navy, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{name}</div>
          <div style={{ fontFamily: "Tajawal", fontSize: 12, color: C.textMuted }}>{specialty}</div>
        </div>
        <StatusDot available={available} />
      </div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", gap: 2, color: C.gold }}>
          {[1,2,3,4,5].map(i => <Icon.Star key={i} s={11} filled={i <= rating} />)}
        </div>
        <button style={{
          padding: "5px 12px", background: C.navy,
          color: C.white, border: "none", borderRadius: 7,
          fontFamily: "Tajawal", fontSize: 12, fontWeight: 600,
          cursor: "pointer", transition: "background 0.2s",
        }}
          onMouseEnter={e => e.currentTarget.style.background = C.gold}
          onMouseLeave={e => e.currentTarget.style.background = C.navy}
        >طلب استشارة</button>
      </div>
    </div>
  );
}

function HeroVisual() {
  return (
    <div style={{ position: "relative", maxWidth: 440, width: "100%", margin: "0 auto" }}>
      {/* Glow */}
      <div style={{
        position: "absolute", top: "20%", left: "10%",
        width: 280, height: 280,
        background: `radial-gradient(circle, ${C.gold}1A 0%, transparent 65%)`,
        borderRadius: "50%", pointerEvents: "none",
      }} />

      {/* Main card */}
      <div style={{
        background: C.white, borderRadius: 22,
        boxShadow: "0 20px 70px rgba(13,31,60,0.13), 0 4px 16px rgba(13,31,60,0.07)",
        border: `1px solid ${C.border}`, overflow: "hidden",
        position: "relative", zIndex: 2,
      }}>
        {/* Top bar */}
        <div style={{
          background: `linear-gradient(135deg, ${C.navyDeep}, ${C.navyMid})`,
          padding: "16px 20px",
          display: "flex", alignItems: "center", justifyContent: "space-between",
        }}>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <div style={{ width: 8, height: 8, borderRadius: "50%", background: "rgba(255,255,255,0.18)" }} />
            <div style={{ width: 8, height: 8, borderRadius: "50%", background: "rgba(255,255,255,0.18)" }} />
          </div>
          <span style={{ fontFamily: "Tajawal", fontSize: 14, fontWeight: 600, color: "rgba(255,255,255,0.7)" }}>
            المحامون المتاحون
          </span>
          <div style={{
            display: "flex", alignItems: "center", gap: 6,
            background: "rgba(255,255,255,0.08)", borderRadius: 8,
            padding: "5px 11px",
          }}>
            <Icon.Search s={13} />
            <span style={{ fontFamily: "Tajawal", fontSize: 12, color: "rgba(255,255,255,0.35)" }}>بحث...</span>
          </div>
        </div>

        {/* Filter chips */}
        <div style={{
          padding: "12px 16px",
          borderBottom: `1px solid ${C.border}`,
          display: "flex", gap: 7, overflowX: "auto",
        }}>
          {["الكل", "تجاري", "عائلي", "عقارات"].map((tag, i) => (
            <div key={tag} style={{
              padding: "4px 12px", borderRadius: 20, flexShrink: 0,
              background: i === 0 ? C.navy : C.surface,
              border: `1px solid ${i === 0 ? C.navy : C.border}`,
              fontFamily: "Tajawal", fontSize: 12, fontWeight: 600,
              color: i === 0 ? "#fff" : C.textMid,
            }}>{tag}</div>
          ))}
        </div>

        {/* Cards */}
        <div style={{ padding: "14px 16px 18px", display: "flex", flexDirection: "column", gap: 10 }}>
          <MiniLawyerCard name="م. أحمد الجبوري" specialty="قانون تجاري" rating={5} available={true} />
          <MiniLawyerCard name="م. سارة النجار" specialty="قانون الأسرة" rating={4} available={true} />
          <MiniLawyerCard name="م. كريم العبيدي" specialty="قانون عقارات" rating={5} available={false} />
        </div>
      </div>

      {/* Floating badge — security */}
      <div style={{
        position: "absolute", bottom: 32, left: -22, zIndex: 3,
        background: C.white, borderRadius: 14,
        padding: "10px 16px",
        boxShadow: "0 8px 28px rgba(13,31,60,0.12)",
        border: `1px solid ${C.border}`,
        display: "flex", alignItems: "center", gap: 10,
      }}>
        <div style={{
          width: 34, height: 34, borderRadius: 10,
          background: C.goldSubtle, display: "flex", alignItems: "center", justifyContent: "center",
          color: C.gold,
        }}>
          <Icon.Shield s={18} />
        </div>
        <div>
          <div style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 12.5, color: C.navy }}>استشارة آمنة</div>
          <div style={{ fontFamily: "Tajawal", fontSize: 11, color: C.textMuted }}>بيانات محمية</div>
        </div>
      </div>

      {/* Floating badge — count */}
      <div style={{
        position: "absolute", top: 20, left: -18, zIndex: 3,
        background: C.navy, borderRadius: 14, padding: "10px 18px",
        boxShadow: "0 8px 24px rgba(13,31,60,0.22)",
      }}>
        <div style={{ fontFamily: "Tajawal", fontWeight: 900, fontSize: 22, color: C.gold, lineHeight: 1 }}>+100</div>
        <div style={{ fontFamily: "Tajawal", fontSize: 11, color: "rgba(255,255,255,0.55)", marginTop: 2 }}>محامٍ متاح</div>
      </div>
    </div>
  );
}

function Hero() {
  const trusts = ["محامون موثوقون", "طلب إلكتروني بسهولة", "خصوصية وأمان"];

  return (
    <section id="hero" style={{
      minHeight: "100vh", background: C.offwhite,
      display: "flex", alignItems: "center",
      paddingTop: 70, position: "relative", overflow: "hidden",
    }}>
      {/* Background shapes */}
      <div style={{
        position: "absolute", top: -120, right: -120,
        width: 500, height: 500,
        background: `radial-gradient(circle, rgba(13,31,60,0.04) 0%, transparent 65%)`,
        borderRadius: "50%", pointerEvents: "none",
      }} />
      <div style={{
        position: "absolute", bottom: -80, left: -80,
        width: 360, height: 360,
        background: `radial-gradient(circle, ${C.gold}0D 0%, transparent 65%)`,
        borderRadius: "50%", pointerEvents: "none",
      }} />

      <div style={{ maxWidth: 1300, margin: "0 auto", padding: "72px 28px", width: "100%" }}>
        <div className="hero-layout" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 72, alignItems: "center" }}>

          {/* Text side */}
          <div>
            <FadeIn>
              <PillLabel>منصة قانونية رقمية عراقية</PillLabel>
            </FadeIn>
            <FadeIn delay={80}>
              <h1 style={{
                fontFamily: "Tajawal", fontWeight: 900,
                fontSize: "clamp(34px, 4.5vw, 58px)",
                lineHeight: 1.18, color: C.navy,
                margin: "0 0 18px",
              }}>
                استشارتك القانونية<br />
                <span style={{ color: C.gold }}>تبدأ من هنا</span>
              </h1>
            </FadeIn>
            <FadeIn delay={140}>
              <p style={{
                fontFamily: "Tajawal", fontSize: 17.5,
                color: C.textMid, lineHeight: 1.72,
                maxWidth: 460, margin: "0 0 34px",
              }}>
                تواصل مع المحامي المناسب واحصل على استشارة قانونية موثوقة بسهولة وأمان.
              </p>
            </FadeIn>
            <FadeIn delay={200}>
              <div style={{ display: "flex", gap: 12, flexWrap: "wrap", marginBottom: 32 }}>
                <a href="#" style={{
                  display: "inline-flex", alignItems: "center", gap: 8,
                  padding: "13px 28px",
                  background: C.navy, color: "#fff",
                  borderRadius: 10, fontFamily: "Tajawal",
                  fontWeight: 700, fontSize: 15.5,
                  textDecoration: "none",
                  boxShadow: "0 4px 18px rgba(13,31,60,0.22)",
                  transition: "all 0.2s",
                }}
                  onMouseEnter={e => { e.currentTarget.style.background = C.gold; e.currentTarget.style.boxShadow = `0 4px 18px rgba(201,168,76,0.28)`; }}
                  onMouseLeave={e => { e.currentTarget.style.background = C.navy; e.currentTarget.style.boxShadow = "0 4px 18px rgba(13,31,60,0.22)"; }}
                >
                  اطلب استشارة <Icon.Arrow s={17} />
                </a>
                <a href="#for-lawyers" style={{
                  display: "inline-flex", alignItems: "center", gap: 8,
                  padding: "13px 28px",
                  background: "transparent", color: C.navy,
                  borderRadius: 10, fontFamily: "Tajawal",
                  fontWeight: 600, fontSize: 15.5,
                  textDecoration: "none",
                  border: `1.5px solid ${C.borderMid}`,
                  transition: "all 0.2s",
                }}
                  onMouseEnter={e => { e.currentTarget.style.borderColor = C.navy; e.currentTarget.style.background = "rgba(13,31,60,0.04)"; }}
                  onMouseLeave={e => { e.currentTarget.style.borderColor = C.borderMid; e.currentTarget.style.background = "transparent"; }}
                >
                  انضم كمحامي
                </a>
              </div>
            </FadeIn>
            <FadeIn delay={260}>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 18 }}>
                {trusts.map(t => (
                  <div key={t} style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <div style={{
                      width: 19, height: 19, borderRadius: "50%",
                      background: C.goldSubtle, flexShrink: 0,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      color: C.gold,
                    }}>
                      <Icon.Check s={10} />
                    </div>
                    <span style={{ fontFamily: "Tajawal", fontSize: 13.5, color: C.textMid }}>{t}</span>
                  </div>
                ))}
              </div>
            </FadeIn>
          </div>

          {/* Visual side */}
          <FadeIn delay={180} style={{ display: "flex", justifyContent: "center" }}>
            <HeroVisual />
          </FadeIn>
        </div>
      </div>

      <style>{`
        @media (max-width: 920px) {
          .hero-layout { grid-template-columns: 1fr !important; gap: 48px !important; }
          .hero-layout > div:last-child { order: -1; }
        }
      `}</style>
    </section>
  );
}

// ─── Trust Bar ────────────────────────────────────────────────────────────────
function TrustBar() {
  const items = [
    { icon: <Icon.User s={22} />, label: "محامون متخصصون" },
    { icon: <Icon.Document s={22} />, label: "استشارات منظمة" },
    { icon: <Icon.Shield s={22} />, label: "خصوصية وأمان" },
    { icon: <Icon.Phone s={22} />, label: "تجربة رقمية سهلة" },
  ];

  return (
    <div style={{ background: C.navy, padding: "0 28px" }}>
      <div style={{ maxWidth: 1300, margin: "0 auto" }}>
        <p style={{
          fontFamily: "Tajawal", fontSize: 13, fontWeight: 500,
          color: "rgba(255,255,255,0.38)", letterSpacing: 0.6,
          textAlign: "center", padding: "28px 0 22px",
        }}>
          منصة مصممة لتجعل الوصول إلى الاستشارة القانونية أسهل
        </p>
        <div className="trust-row" style={{
          display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
          gap: 1, background: "rgba(255,255,255,0.05)",
          borderTop: "1px solid rgba(255,255,255,0.05)",
          borderRadius: "10px 10px 0 0", overflow: "hidden",
        }}>
          {items.map((item, i) => (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 12,
              padding: "22px 26px",
              background: C.navy,
              borderLeft: i < 3 ? "1px solid rgba(255,255,255,0.05)" : "none",
              transition: "background 0.2s",
            }}
              onMouseEnter={e => e.currentTarget.style.background = C.navyMid}
              onMouseLeave={e => e.currentTarget.style.background = C.navy}
            >
              <div style={{ color: C.gold, flexShrink: 0 }}>{item.icon}</div>
              <span style={{ fontFamily: "Tajawal", fontSize: 15, fontWeight: 600, color: "#fff" }}>{item.label}</span>
            </div>
          ))}
        </div>
      </div>
      <style>{`
        @media (max-width: 760px) { .trust-row { grid-template-columns: 1fr 1fr !important; } }
        @media (max-width: 440px) { .trust-row { grid-template-columns: 1fr !important; } }
      `}</style>
    </div>
  );
}

// ─── How It Works ─────────────────────────────────────────────────────────────
function HowItWorks() {
  const steps = [
    { num: "01", title: "أنشئ حسابك", desc: "سجل باستخدام رقم هاتفك أو حساب Google.", icon: <Icon.Phone s={22} /> },
    { num: "02", title: "اختر تخصصك", desc: "حدد نوع القضية أو المجال القانوني الذي تحتاج إليه.", icon: <Icon.Search s={22} /> },
    { num: "03", title: "اختر المحامي", desc: "استعرض المحامين وتخصصاتهم وتقييماتهم وتوفرهم.", icon: <Icon.User s={22} /> },
    { num: "04", title: "ابدأ الاستشارة", desc: "أرسل طلبك وابدأ الاستشارة وفق النظام المعتمد في المنصة.", icon: <Icon.Document s={22} /> },
  ];

  return (
    <section id="how-it-works" style={{ padding: "96px 28px", background: C.offwhite }}>
      <div style={{ maxWidth: 1300, margin: "0 auto" }}>
        <SectionHeading
          eyebrow="العملية"
          title="كيف تعمل استشارة؟"
          subtitle="أربع خطوات بسيطة تفصلك عن استشارتك القانونية"
        />

        <div style={{ position: "relative" }}>
          {/* Connector */}
          <div className="connector" style={{
            position: "absolute", top: 44,
            right: "12.5%", left: "12.5%",
            height: 1,
            background: `linear-gradient(to left, transparent 0%, ${C.gold}50 20%, ${C.gold}50 80%, transparent 100%)`,
            zIndex: 0,
          }} />

          <div className="steps-grid" style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 20, position: "relative", zIndex: 1 }}>
            {steps.map((s, i) => (
              <FadeIn key={i} delay={i * 80}>
                <div style={{
                  background: C.white, borderRadius: 16,
                  padding: "26px 22px",
                  border: `1px solid ${C.border}`,
                  transition: "all 0.25s",
                  cursor: "default", height: "100%",
                }}
                  onMouseEnter={e => {
                    e.currentTarget.style.boxShadow = "0 8px 32px rgba(13,31,60,0.09)";
                    e.currentTarget.style.transform = "translateY(-5px)";
                    e.currentTarget.style.borderColor = `${C.gold}44`;
                  }}
                  onMouseLeave={e => {
                    e.currentTarget.style.boxShadow = "none";
                    e.currentTarget.style.transform = "translateY(0)";
                    e.currentTarget.style.borderColor = C.border;
                  }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 18 }}>
                    <div style={{
                      width: 48, height: 48, borderRadius: 13,
                      background: `linear-gradient(135deg, ${C.navyDeep}, ${C.navyMid})`,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      color: C.gold,
                    }}>
                      {s.icon}
                    </div>
                    <span style={{
                      fontFamily: "Tajawal", fontWeight: 900,
                      fontSize: 32, lineHeight: 1,
                      color: "rgba(13,31,60,0.06)",
                    }}>{s.num}</span>
                  </div>
                  <h3 style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 16.5, color: C.navy, margin: "0 0 8px" }}>{s.title}</h3>
                  <p style={{ fontFamily: "Tajawal", fontSize: 13.5, color: C.textMid, lineHeight: 1.65, margin: 0 }}>{s.desc}</p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </div>

      <style>{`
        @media (max-width: 900px) { .steps-grid { grid-template-columns: 1fr 1fr !important; } .connector { display: none !important; } }
        @media (max-width: 500px) { .steps-grid { grid-template-columns: 1fr !important; } }
      `}</style>
    </section>
  );
}

// ─── User Section ─────────────────────────────────────────────────────────────
function UserSection() {
  const [activeFilter, setActiveFilter] = useState("الكل");
  const filters = ["الكل", "قانون تجاري", "قانون الأسرة", "عقارات", "جنائي"];

  const lawyers = [
    { name: "م. أحمد الجبوري", specialty: "قانون تجاري", years: 12, rating: 5, available: true, cases: 240 },
    { name: "م. سارة النجار", specialty: "قانون الأسرة", years: 8, rating: 4, available: true, cases: 185 },
    { name: "م. كريم العبيدي", specialty: "قانون عقارات", years: 15, rating: 5, available: false, cases: 312 },
  ];

  return (
    <section style={{ padding: "96px 28px", background: C.surface }}>
      <div style={{ maxWidth: 1300, margin: "0 auto" }}>
        <div className="user-layout" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 64, alignItems: "center" }}>

          {/* Cards side */}
          <FadeIn>
            <div>
              {/* Filter chips */}
              <div style={{ display: "flex", gap: 7, flexWrap: "wrap", marginBottom: 18 }}>
                {filters.map(f => (
                  <button key={f} onClick={() => setActiveFilter(f)} style={{
                    padding: "6px 15px", borderRadius: 20,
                    border: `1.5px solid ${f === activeFilter ? C.navy : C.border}`,
                    background: f === activeFilter ? C.navy : C.white,
                    color: f === activeFilter ? "#fff" : C.textMid,
                    fontFamily: "Tajawal", fontWeight: 600, fontSize: 13,
                    cursor: "pointer", transition: "all 0.18s",
                  }}>
                    {f}
                  </button>
                ))}
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                {lawyers.map((l, i) => (
                  <div key={i} style={{
                    background: C.white, borderRadius: 14, padding: "16px 18px",
                    border: `1px solid ${C.border}`,
                    display: "flex", alignItems: "center", gap: 14,
                    transition: "all 0.22s", cursor: "pointer",
                  }}
                    onMouseEnter={e => { e.currentTarget.style.boxShadow = "0 6px 24px rgba(13,31,60,0.08)"; e.currentTarget.style.borderColor = `${C.gold}44`; }}
                    onMouseLeave={e => { e.currentTarget.style.boxShadow = "none"; e.currentTarget.style.borderColor = C.border; }}
                  >
                    <div style={{
                      width: 50, height: 50, borderRadius: "50%",
                      background: `linear-gradient(135deg, ${C.navyMid}, ${C.navyDeep})`,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      flexShrink: 0, color: "rgba(201,168,76,0.7)",
                    }}>
                      <Icon.User s={22} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 5 }}>
                        <span style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 15, color: C.navy }}>{l.name}</span>
                        <StatusDot available={l.available} />
                      </div>
                      <div style={{ display: "flex", alignItems: "center", gap: 10, flexWrap: "wrap" }}>
                        <span style={{ fontFamily: "Tajawal", fontSize: 13, color: C.textMid }}>{l.specialty}</span>
                        <span style={{ color: C.border, fontSize: 16 }}>·</span>
                        <span style={{ fontFamily: "Tajawal", fontSize: 13, color: C.textMuted }}>{l.years} سنوات</span>
                        <span style={{ color: C.border, fontSize: 16 }}>·</span>
                        <div style={{ display: "flex", gap: 2, color: C.gold }}>
                          {[1,2,3,4,5].map(s => <Icon.Star key={s} s={11} filled={s <= l.rating} />)}
                        </div>
                      </div>
                    </div>
                    <button style={{
                      padding: "7px 16px", background: C.navy, color: "#fff",
                      border: "none", borderRadius: 8, cursor: "pointer",
                      fontFamily: "Tajawal", fontWeight: 600, fontSize: 13,
                      transition: "background 0.18s", flexShrink: 0,
                    }}
                      onMouseEnter={e => e.currentTarget.style.background = C.gold}
                      onMouseLeave={e => e.currentTarget.style.background = C.navy}
                    >عرض الملف</button>
                  </div>
                ))}
              </div>
            </div>
          </FadeIn>

          {/* Text side */}
          <FadeIn delay={120}>
            <div>
              <PillLabel>للمستخدمين</PillLabel>
              <h2 style={{ fontFamily: "Tajawal", fontWeight: 900, fontSize: "clamp(24px,3.2vw,38px)", color: C.navy, margin: "0 0 16px", lineHeight: 1.25 }}>
                لست متأكدًا من<br />المحامي المناسب؟
              </h2>
              <p style={{ fontFamily: "Tajawal", fontSize: 17, color: C.textMid, lineHeight: 1.72, margin: "0 0 30px", maxWidth: 420 }}>
                استعرض المحامين حسب التخصص والخبرة والتقييم والتوفر، واختر من يناسب احتياجك.
              </p>
              <a href="#" style={{
                display: "inline-flex", alignItems: "center", gap: 8,
                padding: "12px 26px",
                background: C.gold, color: C.navy,
                borderRadius: 10, fontFamily: "Tajawal",
                fontWeight: 700, fontSize: 15, textDecoration: "none",
                transition: "all 0.2s",
              }}
                onMouseEnter={e => { e.currentTarget.style.background = C.goldMuted; e.currentTarget.style.color = "#fff"; }}
                onMouseLeave={e => { e.currentTarget.style.background = C.gold; e.currentTarget.style.color = C.navy; }}
              >
                استعرض جميع المحامين <Icon.Arrow s={16} />
              </a>
            </div>
          </FadeIn>
        </div>
      </div>
      <style>{`
        @media (max-width: 920px) { .user-layout { grid-template-columns: 1fr !important; } .user-layout > div:nth-child(2) { order: -1; } }
      `}</style>
    </section>
  );
}

// ─── Lawyer Profile Card ──────────────────────────────────────────────────────
function FullProfileCard() {
  return (
    <div style={{
      background: C.white, borderRadius: 20,
      boxShadow: "0 18px 60px rgba(13,31,60,0.11), 0 4px 16px rgba(13,31,60,0.06)",
      border: `1px solid ${C.border}`, overflow: "hidden",
    }}>
      {/* Banner */}
      <div style={{
        height: 90,
        background: `linear-gradient(135deg, ${C.navyDeep} 0%, ${C.navyMid} 100%)`,
        position: "relative",
      }}>
        <div style={{
          position: "absolute", bottom: -30, right: 24,
          width: 60, height: 60, borderRadius: "50%",
          background: `linear-gradient(135deg, ${C.navyMid}, ${C.navy})`,
          border: "3px solid #fff",
          display: "flex", alignItems: "center", justifyContent: "center",
          color: "rgba(201,168,76,0.75)",
        }}>
          <Icon.User s={26} />
        </div>
        <div style={{
          position: "absolute", top: 14, left: 20,
        }}>
          <StatusDot available={true} />
        </div>
      </div>

      <div style={{ padding: "40px 24px 24px" }}>
        <div style={{ marginBottom: 14 }}>
          <h3 style={{ fontFamily: "Tajawal", fontWeight: 800, fontSize: 20, color: C.navy, margin: "0 0 3px" }}>م. أحمد الجبوري</h3>
          <p style={{ fontFamily: "Tajawal", fontSize: 13.5, color: C.textMuted, margin: "0 0 12px" }}>محامٍ · 12 سنة خبرة</p>
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {["قانون تجاري", "عقود", "شركات"].map(t => (
              <span key={t} style={{
                padding: "3px 10px", borderRadius: 20,
                background: C.goldSubtle, border: `1px solid rgba(201,168,76,0.2)`,
                fontFamily: "Tajawal", fontSize: 11.5, fontWeight: 600, color: C.goldMuted,
              }}>{t}</span>
            ))}
          </div>
        </div>

        <p style={{ fontFamily: "Tajawal", fontSize: 13.5, color: C.textMid, lineHeight: 1.7, margin: "0 0 16px" }}>
          محامٍ متخصص في القانون التجاري وقانون الشركات مع خبرة واسعة في العقود والنزاعات التجارية الدولية والمحلية.
        </p>

        {/* Stats row */}
        <div style={{
          display: "flex", gap: 0,
          background: C.surface, borderRadius: 12, overflow: "hidden",
          marginBottom: 18,
        }}>
          {[
            { val: "240", lbl: "قضية" },
            { val: "5.0 ★", lbl: "تقييم" },
            { val: "12", lbl: "سنة" },
          ].map((s, i) => (
            <div key={i} style={{
              flex: 1, padding: "14px 10px", textAlign: "center",
              borderLeft: i < 2 ? `1px solid ${C.border}` : "none",
            }}>
              <div style={{ fontFamily: "Tajawal", fontWeight: 800, fontSize: 18, color: C.navy, lineHeight: 1 }}>{s.val}</div>
              <div style={{ fontFamily: "Tajawal", fontSize: 11.5, color: C.textMuted, marginTop: 3 }}>{s.lbl}</div>
            </div>
          ))}
        </div>

        {/* Achievements */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 14, color: C.navy, marginBottom: 10 }}>الخبرات والإنجازات</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {[
              { icon: <Icon.Award s={14} />, text: "عضو نقابة المحامين العراقية" },
              { icon: <Icon.Briefcase s={14} />, text: "خبرة في القانون الدولي والمحلي" },
              { icon: <Icon.Document s={14} />, text: "ماجستير في القانون التجاري — بغداد" },
            ].map((a, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 9 }}>
                <div style={{
                  width: 26, height: 26, borderRadius: 7,
                  background: C.goldSubtle, flexShrink: 0,
                  display: "flex", alignItems: "center", justifyContent: "center", color: C.gold,
                }}>{a.icon}</div>
                <span style={{ fontFamily: "Tajawal", fontSize: 13, color: C.textMid }}>{a.text}</span>
              </div>
            ))}
          </div>
        </div>

        <button style={{
          width: "100%", padding: "12px",
          background: C.navy, color: "#fff",
          border: "none", borderRadius: 10, cursor: "pointer",
          fontFamily: "Tajawal", fontWeight: 700, fontSize: 15,
          transition: "background 0.2s",
        }}
          onMouseEnter={e => e.currentTarget.style.background = C.gold}
          onMouseLeave={e => e.currentTarget.style.background = C.navy}
        >طلب استشارة</button>
      </div>
    </div>
  );
}

// ─── Lawyer Section ───────────────────────────────────────────────────────────
function LawyerSection() {
  const benefits = [
    { icon: <Icon.User s={19} />, title: "ملف مهني احترافي", desc: "أنشئ ملفًا يعرض خبراتك وإنجازاتك بشكل متكامل." },
    { icon: <Icon.Award s={19} />, title: "عرض الخبرات والإنجازات", desc: "أبرز شهاداتك وتخصصاتك وقضاياك الناجحة." },
    { icon: <Icon.Document s={19} />, title: "استقبال طلبات الاستشارة", desc: "تصلك الطلبات مباشرة وتدير وقتك بكفاءة." },
    { icon: <Icon.Globe s={19} />, title: "إدارة الاستشارات إلكترونيًا", desc: "كل شيء رقمي ومنظم في مكان واحد." },
  ];

  return (
    <section id="for-lawyers" style={{ padding: "96px 28px", background: C.offwhite }}>
      <div style={{ maxWidth: 1300, margin: "0 auto" }}>
        <div className="lawyer-layout" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 72, alignItems: "center" }}>

          {/* Text */}
          <FadeIn>
            <div>
              <PillLabel>للمحامين</PillLabel>
              <h2 style={{
                fontFamily: "Tajawal", fontWeight: 900,
                fontSize: "clamp(24px,3.2vw,38px)",
                color: C.navy, margin: "0 0 16px", lineHeight: 1.25,
              }}>
                محامٍ؟ وسّع حضورك المهني<br />
                <span style={{ color: C.gold }}>مع استشارة</span>
              </h2>
              <p style={{ fontFamily: "Tajawal", fontSize: 17, color: C.textMid, lineHeight: 1.72, margin: "0 0 32px", maxWidth: 440 }}>
                أنشئ ملفك المهني، اعرض خبراتك وتخصصاتك، واستقبل طلبات الاستشارة من المستخدمين.
              </p>

              <div style={{ display: "flex", flexDirection: "column", gap: 18, marginBottom: 36 }}>
                {benefits.map((b, i) => (
                  <FadeIn key={i} delay={i * 60}>
                    <div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}>
                      <div style={{
                        width: 40, height: 40, borderRadius: 11,
                        background: C.goldSubtle, flexShrink: 0,
                        display: "flex", alignItems: "center", justifyContent: "center",
                        color: C.gold,
                      }}>{b.icon}</div>
                      <div>
                        <div style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 15, color: C.navy, marginBottom: 3 }}>{b.title}</div>
                        <div style={{ fontFamily: "Tajawal", fontSize: 13.5, color: C.textMid }}>{b.desc}</div>
                      </div>
                    </div>
                  </FadeIn>
                ))}
              </div>

              <a href="#" style={{
                display: "inline-flex", alignItems: "center", gap: 8,
                padding: "13px 28px",
                background: C.navy, color: "#fff",
                borderRadius: 10, fontFamily: "Tajawal",
                fontWeight: 700, fontSize: 15.5, textDecoration: "none",
                transition: "all 0.2s",
              }}
                onMouseEnter={e => { e.currentTarget.style.background = C.gold; e.currentTarget.style.color = C.navy; }}
                onMouseLeave={e => { e.currentTarget.style.background = C.navy; e.currentTarget.style.color = "#fff"; }}
              >
                انضم كمحامي <Icon.Arrow s={17} />
              </a>
            </div>
          </FadeIn>

          {/* Card */}
          <FadeIn delay={160}>
            <FullProfileCard />
          </FadeIn>
        </div>
      </div>
      <style>{`
        @media (max-width: 920px) { .lawyer-layout { grid-template-columns: 1fr !important; } }
      `}</style>
    </section>
  );
}

// ─── Security ─────────────────────────────────────────────────────────────────
function SecuritySection() {
  const items = [
    { icon: <Icon.Shield s={28} />, title: "حماية البيانات", desc: "جميع بياناتك مشفرة ومحمية وفق أعلى معايير الأمان الرقمي." },
    { icon: <Icon.Check s={28} />, title: "حسابات موثقة", desc: "كل محامٍ على المنصة موثق ومعتمد من نقابة المحامين العراقية." },
    { icon: <Icon.Balance s={28} />, title: "تجربة قانونية منظمة", desc: "كل استشارة تسير وفق إجراءات واضحة وشفافة تحمي الطرفين." },
  ];

  return (
    <section style={{ padding: "96px 28px", background: C.surface }}>
      <div style={{ maxWidth: 1300, margin: "0 auto" }}>
        <SectionHeading
          eyebrow="الخصوصية"
          title="خصوصيتك أولويتنا"
          subtitle="نؤمن بأن الاستشارة القانونية تستحق بيئة آمنة وخاصة بالكامل."
        />

        <div className="sec-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 22 }}>
          {items.map((item, i) => (
            <FadeIn key={i} delay={i * 80}>
              <div style={{
                background: C.white, borderRadius: 18,
                padding: "38px 30px", textAlign: "center",
                border: `1px solid ${C.border}`,
                transition: "all 0.25s", height: "100%",
              }}
                onMouseEnter={e => { e.currentTarget.style.boxShadow = "0 10px 36px rgba(13,31,60,0.09)"; e.currentTarget.style.transform = "translateY(-5px)"; e.currentTarget.style.borderColor = `${C.gold}33`; }}
                onMouseLeave={e => { e.currentTarget.style.boxShadow = "none"; e.currentTarget.style.transform = "translateY(0)"; e.currentTarget.style.borderColor = C.border; }}
              >
                <div style={{
                  width: 64, height: 64, borderRadius: 17, margin: "0 auto 20px",
                  background: `linear-gradient(135deg, ${C.navyDeep}, ${C.navyMid})`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  color: C.gold,
                }}>{item.icon}</div>
                <h3 style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 18, color: C.navy, margin: "0 0 10px" }}>{item.title}</h3>
                <p style={{ fontFamily: "Tajawal", fontSize: 14, color: C.textMid, lineHeight: 1.7, margin: 0 }}>{item.desc}</p>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
      <style>{`
        @media (max-width: 760px) { .sec-grid { grid-template-columns: 1fr !important; } }
      `}</style>
    </section>
  );
}

// ─── Stats ────────────────────────────────────────────────────────────────────
function StatsSection() {
  const stats = [
    { value: "+100", label: "محامٍ" },
    { value: "+500", label: "استشارة" },
    { value: "+20", label: "تخصص قانوني" },
    { value: "+1000", label: "مستخدم" },
  ];

  return (
    <section id="stats" style={{ padding: "88px 28px", background: C.navyDeep }}>
      <div style={{ maxWidth: 1300, margin: "0 auto" }}>
        <FadeIn>
          <h2 style={{
            fontFamily: "Tajawal", fontWeight: 900,
            fontSize: "clamp(22px, 3vw, 36px)",
            color: "#fff", textAlign: "center", margin: "0 0 52px",
          }}>
            منصة واحدة للوصول إلى الخدمات القانونية
          </h2>
        </FadeIn>

        <div className="stats-grid" style={{
          display: "grid", gridTemplateColumns: "repeat(4,1fr)",
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.06)",
          borderRadius: 18, overflow: "hidden",
        }}>
          {stats.map((s, i) => (
            <FadeIn key={i} delay={i * 70}>
              <div style={{
                padding: "38px 24px", textAlign: "center",
                borderLeft: i < 3 ? "1px solid rgba(255,255,255,0.06)" : "none",
                transition: "background 0.2s",
              }}
                onMouseEnter={e => e.currentTarget.style.background = "rgba(255,255,255,0.04)"}
                onMouseLeave={e => e.currentTarget.style.background = "transparent"}
              >
                <div style={{
                  fontFamily: "Tajawal", fontWeight: 900,
                  fontSize: "clamp(36px,4vw,52px)",
                  color: C.gold, lineHeight: 1, marginBottom: 8,
                }}>{s.value}</div>
                <div style={{ fontFamily: "Tajawal", fontSize: 16, fontWeight: 500, color: "rgba(255,255,255,0.5)" }}>{s.label}</div>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
      <style>{`
        @media (max-width: 760px) { .stats-grid { grid-template-columns: 1fr 1fr !important; } }
        @media (max-width: 460px) { .stats-grid { grid-template-columns: 1fr !important; } }
      `}</style>
    </section>
  );
}

// ─── FAQ ──────────────────────────────────────────────────────────────────────
function FAQ() {
  const [open, setOpen] = useState<number | null>(0);

  const faqs = [
    { q: "كيف يمكنني طلب استشارة؟", a: "سجل في المنصة، ابحث عن المحامي المناسب، واضغط على 'طلب استشارة' وأرسل تفاصيل قضيتك." },
    { q: "هل أستطيع اختيار المحامي؟", a: "نعم، يمكنك استعراض جميع المحامين المتاحين وتصفيتهم حسب التخصص والخبرة والتقييم ثم اختيار من يناسبك." },
    { q: "كيف يتم التواصل مع المحامي؟", a: "يتم التواصل عبر نظام الرسائل الآمن داخل المنصة، مع إمكانية طلب مكالمة مرئية وفق اتفاق الطرفين." },
    { q: "هل يمكنني التسجيل باستخدام Google؟", a: "نعم، تدعم المنصة التسجيل عبر Google وكذلك رقم الهاتف للراحة والسرعة." },
    { q: "كيف ينضم المحامي إلى المنصة؟", a: "يقدم المحامي طلب انضمام مع وثائق الاعتماد والترخيص، يتم مراجعتها والتحقق منها قبل تفعيل الملف." },
    { q: "هل بياناتي محفوظة؟", a: "نعم، جميع بياناتك مشفرة ومحمية، ولا تتم مشاركتها مع أي طرف ثالث بدون موافقتك الصريحة." },
    { q: "كيف يتم الدفع؟", a: "يتم الدفع بطرق إلكترونية آمنة داخل المنصة، ويُحدد رسم الاستشارة مسبقًا قبل تأكيد الطلب." },
  ];

  return (
    <section id="faq" style={{ padding: "96px 28px", background: C.offwhite }}>
      <div style={{ maxWidth: 760, margin: "0 auto" }}>
        <SectionHeading
          eyebrow="أسئلة وأجوبة"
          title="الأسئلة الأكثر شيوعًا"
        />

        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {faqs.map((faq, i) => (
            <FadeIn key={i} delay={i * 40}>
              <div style={{
                background: C.white, borderRadius: 12,
                border: `1px solid ${open === i ? `${C.gold}44` : C.border}`,
                overflow: "hidden", transition: "border-color 0.2s",
              }}>
                <button onClick={() => setOpen(open === i ? null : i)} style={{
                  width: "100%", padding: "18px 22px",
                  background: "none", border: "none",
                  display: "flex", alignItems: "center", justifyContent: "space-between",
                  cursor: "pointer", textAlign: "right", gap: 12,
                }}>
                  <span style={{
                    fontFamily: "Tajawal", fontWeight: 600, fontSize: 16,
                    color: open === i ? C.gold : C.navy,
                    transition: "color 0.2s", flex: 1, textAlign: "right",
                  }}>{faq.q}</span>
                  <div style={{
                    width: 28, height: 28, borderRadius: "50%", flexShrink: 0,
                    background: open === i ? C.navy : C.surface,
                    display: "flex", alignItems: "center", justifyContent: "center",
                    transition: "all 0.25s",
                    transform: open === i ? "rotate(180deg)" : "rotate(0deg)",
                  }}>
                    <Icon.ChevronDown s={14} />
                  </div>
                </button>
                {open === i && (
                  <div style={{ padding: "0 22px 18px", borderTop: `1px solid ${C.border}` }}>
                    <p style={{
                      fontFamily: "Tajawal", fontSize: 15, color: C.textMid,
                      lineHeight: 1.72, margin: "14px 0 0",
                    }}>{faq.a}</p>
                  </div>
                )}
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─── Final CTA ────────────────────────────────────────────────────────────────
function FinalCTA() {
  return (
    <section style={{
      padding: "96px 28px",
      background: C.navyDeep,
      position: "relative", overflow: "hidden",
    }}>
      <div style={{
        position: "absolute", top: -100, right: -100,
        width: 450, height: 450,
        background: `radial-gradient(circle, ${C.gold}12 0%, transparent 60%)`,
        borderRadius: "50%", pointerEvents: "none",
      }} />
      <div style={{
        position: "absolute", bottom: -80, left: -80,
        width: 350, height: 350,
        background: `radial-gradient(circle, ${C.navyMid}80 0%, transparent 60%)`,
        borderRadius: "50%", pointerEvents: "none",
      }} />

      <div style={{ maxWidth: 640, margin: "0 auto", textAlign: "center", position: "relative", zIndex: 1 }}>
        <FadeIn>
          <PillLabel light>ابدأ رحلتك القانونية</PillLabel>

          <h2 style={{
            fontFamily: "Tajawal", fontWeight: 900,
            fontSize: "clamp(28px, 4vw, 50px)",
            color: "#fff", lineHeight: 1.22, margin: "0 0 18px",
          }}>
            جاهز للحصول على<br />
            <span style={{ color: C.gold }}>استشارتك القانونية؟</span>
          </h2>

          <p style={{
            fontFamily: "Tajawal", fontSize: 17.5,
            color: "rgba(255,255,255,0.5)", lineHeight: 1.7, margin: "0 0 38px",
          }}>
            ابدأ الآن واكتشف طريقة أسهل للوصول إلى المحامي المناسب.
          </p>

          <div style={{ display: "flex", gap: 12, justifyContent: "center", flexWrap: "wrap" }}>
            <a href="#" style={{
              display: "inline-flex", alignItems: "center", gap: 8,
              padding: "14px 32px",
              background: C.gold, color: C.navy,
              borderRadius: 10, fontFamily: "Tajawal",
              fontWeight: 700, fontSize: 16, textDecoration: "none",
              boxShadow: `0 4px 22px rgba(201,168,76,0.28)`,
              transition: "all 0.2s",
            }}
              onMouseEnter={e => { e.currentTarget.style.background = C.goldLight; e.currentTarget.style.boxShadow = `0 6px 28px rgba(201,168,76,0.38)`; }}
              onMouseLeave={e => { e.currentTarget.style.background = C.gold; e.currentTarget.style.boxShadow = `0 4px 22px rgba(201,168,76,0.28)`; }}
            >
              ابدأ الآن <Icon.Arrow s={17} />
            </a>
            <a href="#for-lawyers" style={{
              display: "inline-flex", alignItems: "center", gap: 8,
              padding: "14px 32px",
              background: "transparent", color: "#fff",
              borderRadius: 10, fontFamily: "Tajawal",
              fontWeight: 600, fontSize: 16, textDecoration: "none",
              border: "1.5px solid rgba(255,255,255,0.18)",
              transition: "all 0.2s",
            }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = "rgba(255,255,255,0.45)"; e.currentTarget.style.background = "rgba(255,255,255,0.05)"; }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = "rgba(255,255,255,0.18)"; e.currentTarget.style.background = "transparent"; }}
            >
              انضم كمحامي
            </a>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}

// ─── Footer ───────────────────────────────────────────────────────────────────
function Footer() {
  const pages = [
    { label: "الرئيسية", href: "#hero" },
    { label: "عن استشارة", href: "#stats" },
    { label: "كيف تعمل؟", href: "#how-it-works" },
    { label: "للمحامين", href: "#for-lawyers" },
    { label: "الأسئلة الشائعة", href: "#faq" },
    { label: "تواصل معنا", href: "#" },
  ];
  const legal = [
    { label: "سياسة الخصوصية", href: "#" },
    { label: "شروط الاستخدام", href: "#" },
    { label: "سياسة المنصة", href: "#" },
  ];
  const socials = [
    { label: "f", name: "Facebook" },
    { label: "in", name: "Instagram" },
    { label: "li", name: "LinkedIn" },
    { label: "wa", name: "WhatsApp" },
  ];

  return (
    <footer style={{ background: C.navyDeep, borderTop: "1px solid rgba(255,255,255,0.04)" }}>
      <div style={{ maxWidth: 1300, margin: "0 auto", padding: "60px 28px 0" }}>
        <div className="footer-grid" style={{
          display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr",
          gap: 40, paddingBottom: 48,
          borderBottom: "1px solid rgba(255,255,255,0.06)",
        }}>
          {/* Brand */}
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 9, marginBottom: 14 }}>
              <div style={{
                width: 36, height: 36, borderRadius: 9,
                background: "rgba(255,255,255,0.06)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }}>
                <svg width="20" height="20" viewBox="0 0 22 22" fill="none">
                  <path d="M11 3.5v15M4.5 18.5h13" stroke={C.gold} strokeWidth="1.5" strokeLinecap="round"/>
                  <path d="M11 3.5L7 9.5h8L11 3.5z" stroke={C.gold} strokeWidth="1.3" strokeLinejoin="round"/>
                </svg>
              </div>
              <span style={{ fontFamily: "Tajawal", fontWeight: 800, fontSize: 20, color: "#fff" }}>استشارة</span>
            </div>
            <p style={{ fontFamily: "Tajawal", fontSize: 13.5, color: "rgba(255,255,255,0.38)", lineHeight: 1.7, maxWidth: 220 }}>
              الوصول إلى الاستشارة القانونية أصبح أسهل.
            </p>
            <div style={{ display: "flex", gap: 8, marginTop: 18 }}>
              {socials.map(s => (
                <a key={s.name} href="#" title={s.name} style={{
                  width: 34, height: 34, borderRadius: 8,
                  background: "rgba(255,255,255,0.06)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  color: "rgba(255,255,255,0.45)",
                  textDecoration: "none", fontFamily: "Tajawal", fontSize: 10, fontWeight: 700,
                  transition: "all 0.18s",
                }}
                  onMouseEnter={e => { e.currentTarget.style.background = C.gold; e.currentTarget.style.color = C.navy; }}
                  onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.06)"; e.currentTarget.style.color = "rgba(255,255,255,0.45)"; }}
                >{s.label}</a>
              ))}
            </div>
          </div>

          {/* Pages */}
          <div>
            <h4 style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 14, color: "#fff", marginBottom: 16, marginTop: 0 }}>الصفحات</h4>
            {pages.map(l => (
              <a key={l.label} href={l.href} style={{
                display: "block", fontFamily: "Tajawal", fontSize: 13.5,
                color: "rgba(255,255,255,0.4)", textDecoration: "none",
                marginBottom: 10, transition: "color 0.18s",
              }}
                onMouseEnter={e => e.currentTarget.style.color = C.gold}
                onMouseLeave={e => e.currentTarget.style.color = "rgba(255,255,255,0.4)"}
              >{l.label}</a>
            ))}
          </div>

          {/* Legal */}
          <div>
            <h4 style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 14, color: "#fff", marginBottom: 16, marginTop: 0 }}>قانوني</h4>
            {legal.map(l => (
              <a key={l.label} href={l.href} style={{
                display: "block", fontFamily: "Tajawal", fontSize: 13.5,
                color: "rgba(255,255,255,0.4)", textDecoration: "none",
                marginBottom: 10, transition: "color 0.18s",
              }}
                onMouseEnter={e => e.currentTarget.style.color = C.gold}
                onMouseLeave={e => e.currentTarget.style.color = "rgba(255,255,255,0.4)"}
              >{l.label}</a>
            ))}
          </div>

          {/* Contact */}
          <div>
            <h4 style={{ fontFamily: "Tajawal", fontWeight: 700, fontSize: 14, color: "#fff", marginBottom: 16, marginTop: 0 }}>تواصل</h4>
            {["info@istishara.iq", "بغداد، العراق"].map(item => (
              <div key={item} style={{
                fontFamily: "Tajawal", fontSize: 13.5,
                color: "rgba(255,255,255,0.4)", marginBottom: 10,
              }}>{item}</div>
            ))}
          </div>
        </div>

        <div style={{ padding: "20px 0", textAlign: "center" }}>
          <span style={{ fontFamily: "Tajawal", fontSize: 13, color: "rgba(255,255,255,0.25)" }}>
            © 2026 استشارة — جميع الحقوق محفوظة
          </span>
        </div>
      </div>

      <style>{`
        @media (max-width: 900px) { .footer-grid { grid-template-columns: 1fr 1fr !important; } }
        @media (max-width: 500px) { .footer-grid { grid-template-columns: 1fr !important; } }
      `}</style>
    </footer>
  );
}

// ─── Root ─────────────────────────────────────────────────────────────────────
export default function App() {
  return (
    <div style={{ direction: "rtl", fontFamily: "Tajawal, sans-serif", background: C.offwhite }}>
      <Header />
      <main>
        <Hero />
        <TrustBar />
        <HowItWorks />
        <UserSection />
        <LawyerSection />
        <SecuritySection />
        <StatsSection />
        <FAQ />
        <FinalCTA />
      </main>
      <Footer />
    </div>
  );
}
