/** User information from credits service */
export interface UserInfo {
  user_id: string;
  display_name: string | null;
  created_at: string;
  balance: number | null;
}

export interface UserListResponse {
  users: UserInfo[];
  total: number;
  page: number;
  page_size: number;
}

/** Transaction record from credits service */
export interface TransactionRecord {
  id: number;
  user_id: string;
  type: "topup" | "bill";
  amount: number;
  description: string | null;
  balance_after: number;
  created_at: string;
}

export interface TransactionListResponse {
  transactions: TransactionRecord[];
  total: number;
  page: number;
  page_size: number;
}

/** Usage log entry from ai-proxy service */
export interface UsageLogEntry {
  id: number;
  user_id: string;
  model: string;
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
  cost_usd: number;
  request_id: string;
  created_at: string;
}

export interface UsageQueryResponse {
  entries: UsageLogEntry[];
  total: number;
  page: number;
  page_size: number;
}

export interface UserUsageSummary {
  total_requests: number;
  total_prompt_tokens: number;
  total_completion_tokens: number;
  total_tokens: number;
  total_cost_usd: number;
  by_model: Record<string, ModelUsage>;
}

export interface ModelUsage {
  requests: number;
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
  total_cost_usd: number;
}

/** Model pricing from ai-proxy service */
export interface ModelPricing {
  model_id: string;
  display_name: string | null;
  input_price_per_1k: number;
  output_price_per_1k: number;
  updated_at: string;
}

export interface ModelPricingListResponse {
  models: ModelPricing[];
}
