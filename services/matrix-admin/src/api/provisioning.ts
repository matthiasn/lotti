import { provisioningApi } from "./client";
import type {
  BundleEvent,
  BundleStatus,
  CreateBundleResponse,
  PaymentStatus,
  ProvisionedUser,
  ProvisionedUserListResponse,
  PurgeResult,
  Stats,
  Usage,
} from "../types";

export interface ListParams {
  page?: number;
  pageSize?: number;
  status?: BundleStatus | "";
  paymentStatus?: PaymentStatus | "";
}

export async function listBundles(
  params: ListParams = {},
): Promise<ProvisionedUserListResponse> {
  const { data } = await provisioningApi.get<ProvisionedUserListResponse>(
    "/bundles",
    {
      params: {
        page: params.page ?? 1,
        page_size: params.pageSize ?? 20,
        status: params.status || undefined,
        payment_status: params.paymentStatus || undefined,
      },
    },
  );
  return data;
}

export async function createBundle(input: {
  username: string;
  displayName?: string;
  notes?: string;
}): Promise<CreateBundleResponse> {
  const { data } = await provisioningApi.post<CreateBundleResponse>("/bundles", {
    username: input.username,
    display_name: input.displayName || null,
    notes: input.notes ?? "",
  });
  return data;
}

export async function updateBundle(
  bundleId: string,
  input: {
    paymentStatus?: PaymentStatus;
    notes?: string;
    retentionDays?: number;
    retentionExempt?: boolean;
    /** Reset to the service default; `undefined` means "leave unchanged". */
    clearRetentionOverride?: boolean;
  },
): Promise<ProvisionedUser> {
  const { data } = await provisioningApi.patch<ProvisionedUser>(
    `/bundles/${bundleId}`,
    {
      payment_status: input.paymentStatus,
      notes: input.notes,
      retention_days: input.retentionDays,
      retention_exempt: input.retentionExempt,
      clear_retention_override: input.clearRetentionOverride ?? false,
    },
  );
  return data;
}

export async function revokeBundle(
  bundleId: string,
  options: { reason?: string; deactivateAccount?: boolean } = {},
): Promise<ProvisionedUser> {
  const { data } = await provisioningApi.post<ProvisionedUser>(
    `/bundles/${bundleId}/revoke`,
    null,
    {
      params: {
        reason: options.reason ?? "",
        deactivate_account: options.deactivateAccount ?? false,
      },
    },
  );
  return data;
}

export async function getBundleEvents(bundleId: string): Promise<BundleEvent[]> {
  const { data } = await provisioningApi.get<BundleEvent[]>(
    `/bundles/${bundleId}/events`,
  );
  return data;
}

export async function getStats(): Promise<Stats> {
  const { data } = await provisioningApi.get<Stats>("/stats");
  return data;
}

/** Live device and media figures, read straight from Synapse. */
export async function getUsage(bundleId: string): Promise<Usage> {
  const { data } = await provisioningApi.get<Usage>(`/bundles/${bundleId}/usage`);
  return data;
}

/**
 * Purge sync-room history older than the retention window.
 *
 * Removes room events and, unless `includeMedia` is false, the user's media
 * files. Media is stored separately by Synapse and is what actually frees
 * disk, so history-only runs reclaim very little.
 */
export async function purgeRoom(
  bundleId: string,
  retentionDays?: number,
  includeMedia = true,
): Promise<PurgeResult> {
  const { data } = await provisioningApi.post<PurgeResult>(
    `/bundles/${bundleId}/purge`,
    null,
    { params: { retention_days: retentionDays, include_media: includeMedia } },
  );
  return data;
}
