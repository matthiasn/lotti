import { proxyApi } from "./client";
import type {
  UsageQueryResponse,
  UserUsageSummary,
  ModelPricingListResponse,
  ModelPricing,
} from "../types";

export async function fetchUserUsage(
  userId: string,
  page = 1,
  pageSize = 20,
): Promise<UsageQueryResponse> {
  const { data } = await proxyApi.get<UsageQueryResponse>(
    `/usage/user/${encodeURIComponent(userId)}`,
    { params: { page, page_size: pageSize } },
  );
  return data;
}

export async function fetchUserUsageSummary(
  userId: string,
): Promise<UserUsageSummary> {
  const { data } = await proxyApi.get<UserUsageSummary>(
    `/usage/user/${encodeURIComponent(userId)}/summary`,
  );
  return data;
}

export async function fetchSystemUsageSummary(): Promise<UserUsageSummary> {
  const { data } = await proxyApi.get<UserUsageSummary>("/usage/summary");
  return data;
}

export async function fetchPricing(): Promise<ModelPricingListResponse> {
  const { data } = await proxyApi.get<ModelPricingListResponse>("/pricing");
  return data;
}

export async function updatePricing(
  modelId: string,
  input_price_per_1k: number,
  output_price_per_1k: number,
  display_name?: string,
): Promise<ModelPricing> {
  const { data } = await proxyApi.put<ModelPricing>(`/pricing/${encodeURIComponent(modelId)}`, {
    input_price_per_1k,
    output_price_per_1k,
    display_name,
  });
  return data;
}

export async function createPricing(
  model_id: string,
  input_price_per_1k: number,
  output_price_per_1k: number,
  display_name?: string,
): Promise<ModelPricing> {
  const { data } = await proxyApi.post<ModelPricing>("/pricing", {
    model_id,
    input_price_per_1k,
    output_price_per_1k,
    display_name,
  });
  return data;
}
