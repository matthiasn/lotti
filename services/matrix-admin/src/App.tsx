import { Navigate, NavLink, Route, Routes } from "react-router-dom";
import BundleListPage from "./pages/BundleListPage";
import CreateBundlePage from "./pages/CreateBundlePage";
import OverviewPage from "./pages/OverviewPage";

const NAV = [
  { to: "/overview", label: "Overview" },
  { to: "/bundles", label: "Users" },
  { to: "/bundles/new", label: "Provision" },
];

export default function App() {
  return (
    <div className="app">
      <header className="app__header">
        <strong>Lotti Matrix Admin</strong>
        <nav>
          {NAV.map(({ to, label }) => (
            <NavLink
              key={to}
              to={to}
              end
              className={({ isActive }) => (isActive ? "active" : undefined)}
            >
              {label}
            </NavLink>
          ))}
        </nav>
      </header>

      <main className="app__main">
        <Routes>
          <Route path="/" element={<Navigate to="/bundles" replace />} />
          <Route path="/overview" element={<OverviewPage />} />
          <Route path="/bundles" element={<BundleListPage />} />
          <Route path="/bundles/new" element={<CreateBundlePage />} />
        </Routes>
      </main>
    </div>
  );
}
