import { provisioningApi } from "./client";
import type {
  BundleEvent,
  BundleStatus,
  CreateBundleResponse,
  PaymentStatus,
  ProvisionedUser,
  ProvisionedUserListResponse,
  Stats,
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
  input: { paymentStatus?: PaymentStatus; notes?: string },
): Promise<ProvisionedUser> {
  const { data } = await provisioningApi.patch<ProvisionedUser>(
    `/bundles/${bundleId}`,
    {
      payment_status: input.paymentStatus,
      notes: input.notes,
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

export async function purgeRoom(
  bundleId: string,
  retentionDays?: number,
): Promise<{ purge_id: string; retention_days: number }> {
  const { data } = await provisioningApi.post(
    `/bundles/${bundleId}/purge`,
    null,
    { params: { retention_days: retentionDays } },
  );
  return data;
}
