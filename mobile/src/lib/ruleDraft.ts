import type { RuleInput, RuleKind } from "@/api/types";

// UI-side rule while editing. Both value fields are kept; the kind decides
// which is used. Money stays in integer cents.
export interface RuleDraft {
  id: string;
  kind: RuleKind;
  valueCents: number;
  valuePct: number;
}

let counter = 0;
export function newRuleDraft(kind: RuleKind = "below_price"): RuleDraft {
  counter += 1;
  return { id: `rule-${counter}`, kind, valueCents: 0, valuePct: 25 };
}

export function draftFromRule(rule: {
  kind: RuleKind;
  value_cents: number | null;
  value_pct: number | null;
}): RuleDraft {
  counter += 1;
  return {
    id: `rule-${counter}`,
    kind: rule.kind,
    valueCents: rule.value_cents ?? 0,
    valuePct: rule.value_pct ?? 25,
  };
}

export function toRuleInput(draft: RuleDraft): RuleInput {
  if (draft.kind === "percent_drop") {
    return { kind: draft.kind, value_pct: draft.valuePct };
  }
  return { kind: draft.kind, value_cents: draft.valueCents };
}

// The price at/below which this rule triggers, given the baseline.
export function thresholdCents(draft: RuleDraft, baselineCents: number): number {
  if (draft.kind === "below_price") return draft.valueCents;
  if (draft.kind === "amount_drop") return baselineCents - draft.valueCents;
  return Math.round((baselineCents * (100 - draft.valuePct)) / 100);
}

// Rules are OR'd, so the effective trigger price is the highest threshold.
export function effectiveThreshold(drafts: RuleDraft[], baselineCents: number): number | null {
  if (drafts.length === 0) return null;
  return Math.max(...drafts.map((draft) => thresholdCents(draft, baselineCents)));
}

// Validation mirrors the backend: ≥1 rule, positive values, pct in 1..100.
export function validateRules(drafts: RuleDraft[]): string | null {
  if (drafts.length === 0) return "Add at least one alert rule.";
  for (const draft of drafts) {
    if (draft.kind === "percent_drop") {
      if (draft.valuePct <= 0 || draft.valuePct > 100) return "Percent must be between 1 and 100.";
    } else if (draft.valueCents <= 0) {
      return "Enter a price greater than zero.";
    }
  }
  return null;
}
