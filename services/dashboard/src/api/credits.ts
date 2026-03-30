import { creditsApi } from "./client";
import type {
  UserListResponse,
  UserInfo,
  TransactionListResponse,
} from "../types";

export async function fetchUsers(
  page = 1,
  pageSize = 20,
): Promise<UserListResponse> {
  const { data } = await creditsApi.get<UserListResponse>("/users", {
    params: { page, page_size: pageSize },
  });
  return data;
}

export async function fetchUser(userId: string): Promise<UserInfo> {
  const { data } = await creditsApi.get<UserInfo>(
    `/users/${encodeURIComponent(userId)}`,
  );
  return data;
}

export async function fetchTransactions(
  userId: string,
  page = 1,
  pageSize = 20,
): Promise<TransactionListResponse> {
  const { data } = await creditsApi.get<TransactionListResponse>(
    `/users/${encodeURIComponent(userId)}/transactions`,
    { params: { page, page_size: pageSize } },
  );
  return data;
}
