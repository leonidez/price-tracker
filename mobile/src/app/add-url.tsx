import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as Clipboard from "expo-clipboard";
import { router } from "expo-router";
import { useEffect, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { ApiError } from "@/api/client";
import { createWatch, dryRunUrl, getStores } from "@/api/endpoints";
import type { RuleInput } from "@/api/types";
import { RuleEditor } from "@/components/RuleEditor";
import { formatCents } from "@/lib/money";

export default function AddByUrlScreen() {
  const queryClient = useQueryClient();
  const storesQuery = useQuery({ queryKey: ["stores"], queryFn: getStores });

  const [url, setUrl] = useState("");
  const [name, setName] = useState("");
  const [storeId, setStoreId] = useState<number | null>(null);
  const [found, setFound] = useState<{ priceCents: number; currency: string } | null>(null);

  // Effective store: explicit choice, else the generic "by URL" store.
  const stores = storesQuery.data ?? [];
  const defaultStoreId =
    stores.find((store) => store.slug === "generic")?.id ?? stores[0]?.id ?? null;
  const selectedStoreId = storeId ?? defaultStoreId;

  // Prefill from the clipboard if it holds a URL.
  useEffect(() => {
    Clipboard.getStringAsync().then((text) => {
      if (!url && /^https?:\/\//i.test(text.trim())) setUrl(text.trim());
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const check = useMutation({
    mutationFn: () =>
      dryRunUrl({ url: url.trim(), store_id: selectedStoreId!, name: name.trim() || undefined }),
    onSuccess: (result) => setFound({ priceCents: result.price_cents, currency: result.currency }),
  });

  const create = useMutation({
    mutationFn: (payload: { baselineCents: number; rules: RuleInput[] }) =>
      createWatch({
        url: url.trim(),
        store_id: selectedStoreId!,
        name: name.trim() || undefined,
        baseline_price_cents: payload.baselineCents,
        rules: payload.rules,
      }),
    onSuccess: (watch) => {
      queryClient.invalidateQueries({ queryKey: ["watches"] });
      router.replace({ pathname: "/watch/[id]", params: { id: String(watch.id) } });
    },
  });

  if (storesQuery.isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator />
      </View>
    );
  }

  // Step 2: rules editor, baseline prefilled to the found price.
  if (found) {
    return (
      <View style={styles.foundWrap}>
        <Text style={styles.foundBanner}>
          We found {formatCents(found.priceCents, found.currency)} ✓
        </Text>
        <RuleEditor
          initialBaselineCents={found.priceCents}
          submitLabel="Create watch"
          submitting={create.isPending}
          onSubmit={(baselineCents, rules) => create.mutate({ baselineCents, rules })}
        />
      </View>
    );
  }

  const checkError =
    check.error instanceof ApiError
      ? check.error.code === "parse_failed"
        ? "We couldn’t read a price from that page. Double-check the URL, or try a different store."
        : check.error.message || check.error.code
      : null;

  // Step 1: URL + store + optional name.
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>Product URL</Text>
      <TextInput
        style={styles.input}
        value={url}
        onChangeText={setUrl}
        placeholder="https://…"
        autoCapitalize="none"
        autoCorrect={false}
        inputMode="url"
      />

      <Text style={styles.label}>Store</Text>
      <View style={styles.storeRow}>
        {stores.map((store) => (
          <Pressable
            key={store.id}
            onPress={() => setStoreId(store.id)}
            style={[styles.chip, selectedStoreId === store.id && styles.chipActive]}
          >
            <Text style={[styles.chipText, selectedStoreId === store.id && styles.chipTextActive]}>
              {store.name}
            </Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.label}>Name (optional)</Text>
      <TextInput
        style={styles.input}
        value={name}
        onChangeText={setName}
        placeholder="e.g. Coffee grinder"
      />

      {check.isPending && (
        <View style={styles.checking}>
          <ActivityIndicator />
          <Text style={styles.checkingText}>Checking the page…</Text>
        </View>
      )}
      {checkError && <Text style={styles.error}>{checkError}</Text>}

      <Pressable
        onPress={() => check.mutate()}
        disabled={!url.trim() || selectedStoreId === null || check.isPending}
        style={[styles.submit, (!url.trim() || check.isPending) && styles.submitDisabled]}
      >
        <Text style={styles.submitText}>Find price</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, gap: 8 },
  centered: { flex: 1, alignItems: "center", justifyContent: "center" },
  foundWrap: { flex: 1 },
  foundBanner: {
    backgroundColor: "#e6f4ea",
    color: "#1a7f37",
    fontSize: 16,
    fontWeight: "600",
    paddingVertical: 12,
    paddingHorizontal: 20,
  },
  label: { fontSize: 13, textTransform: "uppercase", color: "#888", marginTop: 12 },
  input: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#c8c8c8",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
  },
  storeRow: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  chip: { paddingVertical: 6, paddingHorizontal: 12, borderRadius: 16, backgroundColor: "#f0f0f0" },
  chipActive: { backgroundColor: "#0a7ea4" },
  chipText: { fontSize: 14, color: "#333" },
  chipTextActive: { color: "#fff" },
  checking: { flexDirection: "row", alignItems: "center", gap: 8, marginTop: 16 },
  checkingText: { color: "#666" },
  error: { marginTop: 12, color: "#cf222e" },
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
