interface Props {
  balance: number | null;
  userName: string | null;
  userId: string;
}

export default function BalanceCard({ balance, userName, userId }: Props) {
  return (
    <div className="balance-hero">
      <div className="balance-hero__label">
        {userName || "User"} — Current Balance
      </div>
      <div className="balance-hero__value">
        {balance != null ? `$${Number(balance).toFixed(2)}` : "N/A"}
      </div>
      <div className="balance-hero__sub">
        <span className="mono">{userId}</span>
      </div>
    </div>
  );
}
