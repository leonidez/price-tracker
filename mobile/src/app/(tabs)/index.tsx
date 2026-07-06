import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import {
  ActivityIndicator,
  Button,
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from "react-native";

import { getWatches } from "@/api/endpoints";
import { WatchCard } from "@/components/WatchCard";

export default function WatchesScreen() {
  const { data, isLoading, isError, refetch, isRefetching } = useQuery({
    queryKey: ["watches"],
    queryFn: getWatches,
  });

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator />
      </View>
    );
  }

  if (isError) {
    return (
      <View style={styles.centered}>
        <Text style={styles.message}>Couldn’t load your watches.</Text>
        <Button title="Retry" onPress={() => refetch()} />
      </View>
    );
  }

  const watches = data ?? [];

  if (watches.length === 0) {
    return (
      <View style={styles.centered}>
        <Text style={styles.emptyTitle}>No watches yet</Text>
        <Text style={styles.message}>Scan a barcode in a store to start tracking.</Text>
        <View style={styles.disabledButton}>
          <Button title="Scan a barcode" onPress={() => router.push("/scan")} />
        </View>
        <Button title="Add by URL" onPress={() => router.push("/add-url")} />
      </View>
    );
  }

  return (
    <FlatList
      data={watches}
      keyExtractor={(watch) => String(watch.id)}
      contentContainerStyle={styles.list}
      refreshControl={<RefreshControl refreshing={isRefetching} onRefresh={() => refetch()} />}
      renderItem={({ item }) => (
        <WatchCard
          watch={item}
          onPress={() => router.push({ pathname: "/watch/[id]", params: { id: String(item.id) } })}
        />
      )}
    />
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: "center", justifyContent: "center", gap: 10, padding: 24 },
  list: { padding: 12, gap: 10 },
  message: { fontSize: 15, color: "#666", textAlign: "center" },
  emptyTitle: { fontSize: 20, fontWeight: "600" },
  disabledButton: { marginTop: 4 },
});
