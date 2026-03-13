import type { TransactionRecord } from "../types";

interface Props {
  transactions: TransactionRecord[];
  loading: boolean;
  total: number;
  page: number;
  pageSize: number;
  onPageChange: (page: number) => void;
}

export default function TransactionList({
  transactions,
  loading,
  total,
  page,
  pageSize,
  onPageChange,
}: Props) {
  if (loading) {
    return (
      <div className="card" style={{ padding: 32 }}>
        <div className="skeleton" style={{ height: 16, width: "60%", marginBottom: 14 }} />
        <div className="skeleton" style={{ height: 16, width: "80%", marginBottom: 14 }} />
        <div className="skeleton" style={{ height: 16, width: "40%" }} />
      </div>
    );
  }

  if (transactions.length === 0) {
    return (
      <div className="card">
        <div className="state-box">
          <div className="state-box__icon">&#x1f4cb;</div>
          <div className="state-box__title">No transactions yet</div>
          <div className="state-box__desc">
            Transactions will appear here after top-ups or API usage billing.
          </div>
        </div>
      </div>
    );
  }

  const totalPages = Math.ceil(total / pageSize);

  return (
    <div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Type</th>
              <th style={{ textAlign: "right" }}>Amount</th>
              <th>Description</th>
              <th style={{ textAlign: "right" }}>Balance After</th>
            </tr>
          </thead>
          <tbody>
            {transactions.map((tx) => (
              <tr key={tx.id}>
                <td style={{ color: "var(--color-text-secondary)", whiteSpace: "nowrap" }}>
                  {new Date(tx.created_at).toLocaleString("en-US", {
                    month: "short",
                    day: "numeric",
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </td>
                <td>
                  <span
                    className={`badge ${tx.type === "topup" ? "badge--success" : "badge--danger"}`}
                  >
                    {tx.type === "topup" ? "Top-up" : "Charge"}
                  </span>
                </td>
                <td
                  style={{
                    textAlign: "right",
                    fontWeight: 600,
                    fontVariantNumeric: "tabular-nums",
                    color:
                      tx.type === "topup"
                        ? "var(--color-success)"
                        : "var(--color-danger)",
                  }}
                >
                  {tx.type === "topup" ? "+" : "-"}${Number(tx.amount).toFixed(2)}
                </td>
                <td style={{ color: "var(--color-text-secondary)" }}>
                  {tx.description || (
                    <span style={{ color: "var(--color-text-tertiary)" }}>—</span>
                  )}
                </td>
                <td
                  style={{
                    textAlign: "right",
                    fontVariantNumeric: "tabular-nums",
                  }}
                >
                  ${Number(tx.balance_after).toFixed(2)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="pagination">
          <button
            className="btn btn--sm"
            disabled={page <= 1}
            onClick={() => onPageChange(page - 1)}
          >
            Previous
          </button>
          <span>
            Page {page} of {totalPages}
          </span>
          <button
            className="btn btn--sm"
            disabled={page >= totalPages}
            onClick={() => onPageChange(page + 1)}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}
