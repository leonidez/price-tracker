// Relative time + price-delta helpers for the UI.

export function relativeTime(iso: string | null): string {
  if (!iso) return "";
  const then = new Date(iso).getTime();
  const seconds = Math.max(0, Math.round((Date.now() - then) / 1000));
  if (seconds < 60) return "just now";
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  return `${days}d ago`;
}

export interface PriceDelta {
  pct: number;
  belowBaseline: boolean;
}

export function priceDelta(currentCents: number, baselineCents: number): PriceDelta {
  if (baselineCents <= 0) return { pct: 0, belowBaseline: false };
  const diff = baselineCents - currentCents;
  const pct = Math.round((Math.abs(diff) / baselineCents) * 100);
  return { pct, belowBaseline: diff > 0 };
}
