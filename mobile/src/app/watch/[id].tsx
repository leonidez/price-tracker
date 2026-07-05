import type { ReactNode } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router, useLocalSearchParams } from "expo-router";
import {
  ActivityIndicator,
  Alert,
  Button,
  Linking,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

import { deleteWatch, getWatch, updateWatch } from "@/api/endpoints";
import type { NotificationItem, WatchDetail } from "@/api/types";
import { PriceChart } from "@/components/PriceChart";
import { relativeTime } from "@/lib/format";
import { formatCents } from "@/lib/money";
import { describeRule } from "@/lib/rules";

export default function WatchDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const watchId = Number(id);
  const queryClient = useQueryClient();

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["watch", watchId],
    queryFn: () => getWatch(watchId),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["watch", watchId] });
    queryClient.invalidateQueries({ queryKey: ["watches"] });
  };

  const toggleActive = useMutation({
    mutationFn: (active: boolean) => updateWatch(watchId, { active }),
    onSuccess: invalidate,
  });

  const remove = useMutation({
    mutationFn: () => deleteWatch(watchId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["watches"] });
      router.back();
    },
  });

  function confirmDelete() {
    Alert.alert("Delete watch?", "This removes the watch and its price history.", [
      { text: "Cancel", style: "cancel" },
      { text: "Delete", style: "destructive", onPress: () => remove.mutate() },
    ]);
  }

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator />
      </View>
    );
  }

  if (isError || !data) {
    return (
      <View style={styles.centered}>
        <Text>Couldn’t load this watch.</Text>
        <Button title="Retry" onPress={() => refetch()} />
      </View>
    );
  }

  const watch: WatchDetail = data;
  const name = watch.product.name ?? watch.listing.display_name ?? watch.listing.url;
  const failing = watch.listing.status === "parse_failed" || watch.listing.status === "blocked";

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.name}>{name}</Text>
      <Text style={styles.store}>{watch.store.name}</Text>
      <Text style={styles.link} onPress={() => Linking.openURL(watch.listing.url)}>
        Open product page ↗
      </Text>

      {failing && (
        <View style={styles.banner}>
          <Text style={styles.bannerText}>
            ⚠️ We couldn’t read a price from this page recently. Re-pair it to keep tracking.
          </Text>
        </View>
      )}

      <View style={styles.priceRow}>
        <Text style={styles.price}>
          {watch.latest_price
            ? formatCents(watch.latest_price.price_cents, watch.latest_price.currency)
            : "—"}
        </Text>
        {watch.latest_price && !watch.latest_price.in_stock && (
          <Text style={styles.oos}>Out of stock</Text>
        )}
      </View>

      {watch.price_points.length > 1 && (
        <PriceChart points={watch.price_points} baselineCents={watch.baseline_price_cents} />
      )}

      <Section title="Baseline">
        <Text style={styles.value}>{formatCents(watch.baseline_price_cents)}</Text>
      </Section>

      <Section title="Alert rules">
        {watch.rules.map((rule, index) => (
          <Text key={index} style={styles.value}>
            • {describeRule(rule)}
          </Text>
        ))}
      </Section>

      <Section title="Recent notifications">
        {watch.notifications.length === 0 ? (
          <Text style={styles.muted}>None yet</Text>
        ) : (
          watch.notifications.map((note, index) => (
            <Text key={index} style={styles.value}>
              {notificationIcon(note)}{" "}
              {note.notified_price_cents ? formatCents(note.notified_price_cents) : ""}{" "}
              <Text style={styles.muted}>{relativeTime(note.sent_at)}</Text>
            </Text>
          ))
        )}
      </Section>

      <View style={styles.actions}>
        <Button
          title="Edit"
          onPress={() => router.push({ pathname: "/edit/[id]", params: { id: String(watchId) } })}
        />
        <Button
          title={watch.active ? "Pause" : "Resume"}
          onPress={() => toggleActive.mutate(!watch.active)}
          disabled={toggleActive.isPending}
        />
        <Button
          title="Delete"
          color="#cf222e"
          onPress={confirmDelete}
          disabled={remove.isPending}
        />
      </View>
    </ScrollView>
  );
}

function notificationIcon(note: NotificationItem): string {
  return note.kind === "price_alert" ? "📉" : "⚠️";
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, gap: 8 },
  centered: { flex: 1, alignItems: "center", justifyContent: "center", gap: 10 },
  name: { fontSize: 22, fontWeight: "700" },
  store: { fontSize: 15, color: "#666" },
  link: { fontSize: 15, color: "#0a7ea4", marginTop: 2 },
  banner: { backgroundColor: "#fff4e5", borderRadius: 8, padding: 12, marginTop: 8 },
  bannerText: { color: "#8a5300", fontSize: 14 },
  priceRow: { flexDirection: "row", alignItems: "baseline", gap: 10, marginTop: 12 },
  price: { fontSize: 34, fontWeight: "800" },
  oos: { color: "#cf222e", fontSize: 14 },
  section: { marginTop: 16, gap: 4 },
  sectionTitle: { fontSize: 13, textTransform: "uppercase", color: "#888" },
  value: { fontSize: 16 },
  muted: { color: "#999" },
  actions: { flexDirection: "row", justifyContent: "space-between", marginTop: 28 },
});
