import { Routes, Route, Navigate } from "react-router-dom";
import Layout from "./components/Layout";
import UserListPage from "./pages/UserListPage";
import UserDetailPage from "./pages/UserDetailPage";
import SystemOverviewPage from "./pages/SystemOverviewPage";
import PricingPage from "./pages/PricingPage";

export default function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Navigate to="/users" replace />} />
        <Route path="/users" element={<UserListPage />} />
        <Route path="/users/:userId" element={<UserDetailPage />} />
        <Route path="/overview" element={<SystemOverviewPage />} />
        <Route path="/pricing" element={<PricingPage />} />
      </Routes>
    </Layout>
  );
}
