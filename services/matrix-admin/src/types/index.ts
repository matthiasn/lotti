export type BundleStatus = "unused" | "redeemed" | "rotated" | "revoked";

export type PaymentStatus =
  | "unknown"
  | "paying"
  | "non_paying"
  | "complimentary";

export interface ProvisionedUser {
  bundle_id: string;
  username: string;
  user_mxid: string;
  home_server: string;
  server_name: string;
  room_id: string;
  display_name: string | null;
  status: BundleStatus;
  payment_status: PaymentStatus;
  bundle_fingerprint: string;
  created_at: string;
  first_login_at: string | null;
  rotated_at: string | null;
  revoked_at: string | null;
  last_seen_at: string | null;
  last_polled_at: string | null;
  notes: string;
}

export interface CreateBundleResponse {
  /** Returned once at creation and never stored server-side. */
  bundle: string;
  user: ProvisionedUser;
}

export interface ProvisionedUserListResponse {
  users: ProvisionedUser[];
  total: number;
  page: number;
  page_size: number;
}

export interface Stats {
  total_provisioned: number;
  unused: number;
  redeemed: number;
  rotated: number;
  revoked: number;
  paying: number;
  non_paying: number;
  unknown_payment: number;
  complimentary: number;
  signups_by_day: Record<string, number>;
}

export interface BundleEvent {
  id: number;
  bundle_id: string;
  event_type: string;
  detail: string;
  created_at: string;
}
