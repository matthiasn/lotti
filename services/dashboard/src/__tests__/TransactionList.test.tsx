import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import TransactionList from "../components/TransactionList";
import type { TransactionRecord } from "../types";

const sampleTx: TransactionRecord[] = [
  {
    id: 1,
    user_id: "u1",
    type: "topup",
    amount: 100.0,
    description: null,
    balance_after: 100.0,
    created_at: "2026-01-01T10:00:00Z",
  },
  {
    id: 2,
    user_id: "u1",
    type: "bill",
    amount: 0.25,
    description: "Gemini call",
    balance_after: 99.75,
    created_at: "2026-01-01T11:00:00Z",
  },
];

describe("TransactionList", () => {
  it("renders skeleton loading state", () => {
    const { container } = render(
      <TransactionList
        transactions={[]}
        loading={true}
        total={0}
        page={1}
        pageSize={20}
        onPageChange={vi.fn()}
      />,
    );
    expect(container.querySelectorAll(".skeleton").length).toBeGreaterThan(0);
  });

  it("renders empty state", () => {
    render(
      <TransactionList
        transactions={[]}
        loading={false}
        total={0}
        page={1}
        pageSize={20}
        onPageChange={vi.fn()}
      />,
    );
    expect(screen.getByText("No transactions yet")).toBeInTheDocument();
  });

  it("renders transaction rows", () => {
    render(
      <TransactionList
        transactions={sampleTx}
        loading={false}
        total={2}
        page={1}
        pageSize={20}
        onPageChange={vi.fn()}
      />,
    );
    expect(screen.getByText("Top-up")).toBeInTheDocument();
    expect(screen.getByText("Charge")).toBeInTheDocument();
    expect(screen.getByText("+$100.00")).toBeInTheDocument();
    expect(screen.getByText("-$0.25")).toBeInTheDocument();
    expect(screen.getByText("Gemini call")).toBeInTheDocument();
  });

  it("shows pagination when multiple pages", () => {
    render(
      <TransactionList
        transactions={sampleTx}
        loading={false}
        total={50}
        page={2}
        pageSize={20}
        onPageChange={vi.fn()}
      />,
    );
    expect(screen.getByText("Page 2 of 3")).toBeInTheDocument();
  });
});
