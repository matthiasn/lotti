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
  /** null = follow the service default. */
  retention_days: number | null;
  retention_exempt: boolean;
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

/** Live figures read from the Synapse admin API, not from our database. */
export interface Usage {
  bundle_id: string;
  user_mxid: string;
  device_count: number;
  last_seen_ts: number | null;
  deactivated: boolean;
  media_count: number;
  media_length_bytes: number;
  active_days: number | null;
  /** The service-wide window, for users with no override of their own. */
  retention_days_default: number;
  /** What a purge will actually apply to this user right now. */
  retention_days_effective: number;
}

export interface PurgeResult {
  purge_id: string;
  room_id: string;
  bundle_id: string;
  purge_up_to_ts: number;
  retention_days: number;
  media_deleted: number;
  bytes_freed: number;
  include_media: boolean;
}
