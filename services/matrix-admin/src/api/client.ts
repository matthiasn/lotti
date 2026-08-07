import axios from "axios";

// WARNING: This key is embedded in the JS bundle and visible to anyone with
// access to the admin app. It grants account provisioning on the homeserver, so
// this app must not be exposed publicly — put it behind a reverse proxy with
// its own authentication, or replace this with a session-based flow before
// there is any untrusted access path.
const ADMIN_API_KEY = import.meta.env.VITE_ADMIN_API_KEY || "dev-admin-key";

/** Client for matrix-provisioning-service (proxied via /api). */
export const provisioningApi = axios.create({
  baseURL: "/api/v1",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${ADMIN_API_KEY}`,
  },
});

/** Extract a human-readable message from an axios error. */
export function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const detail = error.response?.data?.detail;
    if (typeof detail === "string") return detail;
    if (Array.isArray(detail) && detail[0]?.msg) return String(detail[0].msg);
    return error.message;
  }
  return error instanceof Error ? error.message : "Unexpected error";
}
