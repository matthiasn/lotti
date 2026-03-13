import { NavLink, useLocation } from "react-router-dom";
import type { ReactNode } from "react";

const navItems = [
  {
    to: "/overview",
    label: "Overview",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
        <polyline points="9 22 9 12 15 12 15 22" />
      </svg>
    ),
  },
  {
    to: "/users",
    label: "Users",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
        <circle cx="9" cy="7" r="4" />
        <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
        <path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </svg>
    ),
  },
  {
    to: "/pricing",
    label: "Pricing",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="10" />
        <path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8" />
        <path d="M12 18V6" />
      </svg>
    ),
  },
];

export default function Layout({ children }: { children: ReactNode }) {
  const location = useLocation();
  const pathSegments = location.pathname.split("/").filter(Boolean);

  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      {/* Sidebar */}
      <aside className="sidebar">
        {/* Logo */}
        <div className="sidebar__logo">
          <img
            src="/app_icon.png"
            alt="Lotti"
            className="sidebar__logo-icon"
          />
          <div>
            <div className="sidebar__logo-text">Lotti</div>
            <div className="sidebar__logo-sub">Customer Care</div>
          </div>
        </div>

        {/* Nav links */}
        <nav className="sidebar__nav">
          {navItems.map(({ to, label, icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `sidebar__link${isActive ? " sidebar__link--active" : ""}`
              }
            >
              {icon}
              {label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="sidebar__footer">
          <div className="sidebar__version">v0.1.0 PoC</div>
        </div>
      </aside>

      {/* Main content */}
      <main className="main-content">
        {/* Breadcrumb */}
        <div className="breadcrumb">
          <span>Dashboard</span>
          {pathSegments.map((seg, i) => (
            <span key={i}>
              <span className="breadcrumb__separator">/</span>
              <span
                className={
                  i === pathSegments.length - 1
                    ? "breadcrumb__current"
                    : undefined
                }
              >
                {seg}
              </span>
            </span>
          ))}
        </div>

        <div className="animate-in">{children}</div>
      </main>
    </div>
  );
}
