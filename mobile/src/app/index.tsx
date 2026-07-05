import { StyleSheet, Text, View } from "react-native";

// Placeholder Watches list — the real list lands in #13.
export default function WatchesScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Watches</Text>
      <Text style={styles.subtitle}>Scan something to start tracking (coming soon).</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
    gap: 8,
  },
  title: {
    fontSize: 22,
    fontWeight: "600",
  },
  subtitle: {
    fontSize: 15,
    color: "#666",
    textAlign: "center",
  },
});
