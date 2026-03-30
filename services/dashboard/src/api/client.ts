import axios from "axios";

// WARNING: This key is embedded in the JS bundle and visible to anyone with access
// to the dashboard. In production, use a session-based auth flow instead.
const API_KEY = import.meta.env.VITE_API_KEY || "dev-admin-key";

/** Client for credits-service (proxied via /api) */
export const creditsApi = axios.create({
  baseURL: "/api/v1",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${API_KEY}`,
  },
});

/** Client for ai-proxy-service (proxied via /v1) */
export const proxyApi = axios.create({
  baseURL: "/v1",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${API_KEY}`,
  },
});
