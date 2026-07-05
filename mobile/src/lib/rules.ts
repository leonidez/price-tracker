import type { Rule } from "@/api/types";
import { formatCents } from "./money";

// Human phrasing for an alert rule.
export function describeRule(rule: Rule): string {
  if (rule.kind === "below_price") {
    return `Below ${formatCents(rule.value_cents ?? 0)}`;
  }
  if (rule.kind === "percent_drop") {
    return `${rule.value_pct ?? 0}% below baseline`;
  }
  return `${formatCents(rule.value_cents ?? 0)} off baseline`;
}
