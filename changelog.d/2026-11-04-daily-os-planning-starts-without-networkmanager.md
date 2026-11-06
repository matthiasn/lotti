### Fixed
- **Daily OS could stay on "Drafting your day" forever, with nothing under
  "Here's what I heard."** Before reading a check-in or drafting a plan, Daily
  OS checks whether the device is online. On Linux machines without
  NetworkManager that check fails outright, and behind WireGuard or Tailscale it
  reports a connection type Daily OS took for "offline", so the planner never
  started. Planning now goes ahead whenever the check can't tell, and VPN
  connections count as online.
