// Money is stored/transported as integer cents; format only at the edge.
const CURRENCY_SYMBOLS: Record<string, string> = { USD: "$", EUR: "€", GBP: "£" };

export function formatCents(cents: number, currency = "USD"): string {
  const symbol = CURRENCY_SYMBOLS[currency] ?? "$";
  return `${symbol}${(cents / 100).toFixed(2)}`;
}
