import { Image, Pressable, StyleSheet, Text, View } from "react-native";

import type { Watch } from "@/api/types";
import { priceDelta } from "@/lib/format";
import { formatCents } from "@/lib/money";
import { Sparkline } from "./Sparkline";

interface Props {
  watch: Watch;
  onPress: () => void;
}

export function WatchCard({ watch, onPress }: Props) {
  const price = watch.latest_price;
  const name = watch.product.name ?? watch.listing.display_name ?? watch.listing.url;
  const delta = price ? priceDelta(price.price_cents, watch.baseline_price_cents) : null;
  const failing = watch.listing.status === "parse_failed" || watch.listing.status === "blocked";

  return (
    <Pressable onPress={onPress} style={[styles.card, !watch.active && styles.dimmed]}>
      {watch.product.image_url ? (
        <Image source={{ uri: watch.product.image_url }} style={styles.image} />
      ) : (
        <View style={[styles.image, styles.placeholder]}>
          <Text style={styles.placeholderIcon}>🏷️</Text>
        </View>
      )}

      <View style={styles.body}>
        <Text numberOfLines={1} style={styles.name}>
          {name}
        </Text>
        <Text style={styles.store}>{watch.store.name}</Text>
        {failing && <Text style={styles.badge}>⚠️ Can’t check</Text>}
        {watch.sparkline.length > 1 && (
          <View style={styles.spark}>
            <Sparkline
              data={watch.sparkline}
              color={delta?.belowBaseline ? "#1a7f37" : "#8a8f98"}
            />
          </View>
        )}
      </View>

      <View style={styles.priceCol}>
        <Text style={styles.price}>
          {price ? formatCents(price.price_cents, price.currency) : "—"}
        </Text>
        {delta && delta.pct > 0 && (
          <Text style={[styles.delta, delta.belowBaseline ? styles.down : styles.up]}>
            {delta.belowBaseline ? "▼" : "▲"} {delta.pct}%
          </Text>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 12,
    backgroundColor: "#fff",
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#e3e3e3",
  },
  dimmed: { opacity: 0.5 },
  image: { width: 56, height: 56, borderRadius: 8, backgroundColor: "#f0f0f0" },
  placeholder: { alignItems: "center", justifyContent: "center" },
  placeholderIcon: { fontSize: 24 },
  body: { flex: 1, gap: 2 },
  name: { fontSize: 16, fontWeight: "600" },
  store: { fontSize: 13, color: "#666" },
  badge: { fontSize: 12, color: "#b35900" },
  spark: { marginTop: 4 },
  priceCol: { alignItems: "flex-end", gap: 2 },
  price: { fontSize: 20, fontWeight: "700" },
  delta: { fontSize: 13, fontWeight: "600" },
  down: { color: "#1a7f37" },
  up: { color: "#cf222e" },
});
