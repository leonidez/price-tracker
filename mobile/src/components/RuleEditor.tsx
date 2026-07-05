import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import type { RuleInput, RuleKind } from "@/api/types";
import { formatCents } from "@/lib/money";
import {
  draftFromRule,
  effectiveThreshold,
  newRuleDraft,
  toRuleInput,
  validateRules,
  type RuleDraft,
} from "@/lib/ruleDraft";
import { CurrencyInput } from "./CurrencyInput";

const KIND_LABELS: Record<RuleKind, string> = {
  below_price: "Drops below a price",
  percent_drop: "Percent off baseline",
  amount_drop: "Dollars off baseline",
};

const PERCENT_PRESETS = [10, 25, 50];

interface Props {
  initialBaselineCents: number;
  initialRules?: { kind: RuleKind; value_cents: number | null; value_pct: number | null }[];
  submitLabel: string;
  submitting?: boolean;
  onSubmit: (baselineCents: number, rules: RuleInput[]) => void;
}

export function RuleEditor({
  initialBaselineCents,
  initialRules,
  submitLabel,
  submitting,
  onSubmit,
}: Props) {
  const [baselineCents, setBaselineCents] = useState(initialBaselineCents);
  const [rules, setRules] = useState<RuleDraft[]>(
    initialRules && initialRules.length > 0 ? initialRules.map(draftFromRule) : [newRuleDraft()],
  );
  const [error, setError] = useState<string | null>(null);

  function updateRule(id: string, patch: Partial<RuleDraft>) {
    setRules((current) => current.map((rule) => (rule.id === id ? { ...rule, ...patch } : rule)));
  }

  function submit() {
    const message = validateRules(rules);
    if (message) {
      setError(message);
      return;
    }
    setError(null);
    onSubmit(baselineCents, rules.map(toRuleInput));
  }

  const threshold = effectiveThreshold(rules, baselineCents);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>Baseline</Text>
      <CurrencyInput cents={baselineCents} onChange={setBaselineCents} />
      <Text style={styles.helper}>Alerts compare against this price.</Text>

      <Text style={[styles.label, styles.rulesHeading]}>Alert rules</Text>
      {rules.map((rule) => (
        <View key={rule.id} style={styles.ruleCard}>
          <View style={styles.kindRow}>
            {(Object.keys(KIND_LABELS) as RuleKind[]).map((kind) => (
              <Pressable
                key={kind}
                onPress={() => updateRule(rule.id, { kind })}
                style={[styles.chip, rule.kind === kind && styles.chipActive]}
              >
                <Text style={[styles.chipText, rule.kind === kind && styles.chipTextActive]}>
                  {KIND_LABELS[kind]}
                </Text>
              </Pressable>
            ))}
          </View>

          {rule.kind === "percent_drop" ? (
            <View style={styles.percentRow}>
              <TextInput
                style={styles.percentInput}
                value={String(rule.valuePct)}
                onChangeText={(text) =>
                  updateRule(rule.id, { valuePct: Number(text.replace(/[^0-9]/g, "")) || 0 })
                }
                keyboardType="number-pad"
                inputMode="numeric"
              />
              <Text style={styles.percentSign}>%</Text>
              {PERCENT_PRESETS.map((preset) => (
                <Pressable
                  key={preset}
                  onPress={() => updateRule(rule.id, { valuePct: preset })}
                  style={styles.preset}
                >
                  <Text style={styles.presetText}>{preset}%</Text>
                </Pressable>
              ))}
            </View>
          ) : (
            <CurrencyInput
              cents={rule.valueCents}
              onChange={(cents) => updateRule(rule.id, { valueCents: cents })}
            />
          )}

          {rules.length > 1 && (
            <Pressable
              onPress={() => setRules((current) => current.filter((r) => r.id !== rule.id))}
            >
              <Text style={styles.remove}>Remove</Text>
            </Pressable>
          )}
        </View>
      ))}

      <Pressable onPress={() => setRules((current) => [...current, newRuleDraft()])}>
        <Text style={styles.addRule}>+ Add another rule</Text>
      </Pressable>

      {threshold !== null && (
        <Text style={styles.preview}>
          You’ll be notified when the price is ≤ {formatCents(Math.max(0, threshold))}.
        </Text>
      )}

      {error && <Text style={styles.error}>{error}</Text>}

      <Pressable
        onPress={submit}
        disabled={submitting}
        style={[styles.submit, submitting && styles.submitDisabled]}
      >
        <Text style={styles.submitText}>{submitting ? "Saving…" : submitLabel}</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, gap: 8 },
  label: { fontSize: 13, textTransform: "uppercase", color: "#888" },
  rulesHeading: { marginTop: 16 },
  helper: { color: "#999", fontSize: 13 },
  ruleCard: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#e0e0e0",
    borderRadius: 12,
    padding: 12,
    gap: 10,
    marginTop: 8,
  },
  kindRow: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 16,
    backgroundColor: "#f0f0f0",
  },
  chipActive: { backgroundColor: "#0a7ea4" },
  chipText: { fontSize: 13, color: "#333" },
  chipTextActive: { color: "#fff" },
  percentRow: { flexDirection: "row", alignItems: "center", gap: 8, flexWrap: "wrap" },
  percentInput: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#c8c8c8",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    minWidth: 64,
  },
  percentSign: { fontSize: 16 },
  preset: { paddingVertical: 6, paddingHorizontal: 10, borderRadius: 16, backgroundColor: "#eef" },
  presetText: { fontSize: 13, color: "#0a7ea4" },
  remove: { color: "#cf222e", fontSize: 14 },
  addRule: { color: "#0a7ea4", fontSize: 15, marginTop: 12 },
  preview: { marginTop: 12, fontSize: 15, color: "#1a7f37" },
  error: { marginTop: 8, color: "#cf222e" },
  submit: {
    marginTop: 20,
    backgroundColor: "#0a7ea4",
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: "center",
  },
  submitDisabled: { opacity: 0.6 },
  submitText: { color: "#fff", fontSize: 16, fontWeight: "600" },
});
