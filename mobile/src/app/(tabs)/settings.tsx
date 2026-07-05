import { useState } from "react";
import { ActivityIndicator, Button, StyleSheet, Text, View } from "react-native";

import { ApiError, apiBaseUrl } from "@/api/client";
import { getPing } from "@/api/endpoints";

type ConnectionState = "idle" | "loading" | "ok" | "error";

export default function SettingsScreen() {
  const [state, setState] = useState<ConnectionState>("idle");
  const [message, setMessage] = useState("");

  async function testConnection() {
    setState("loading");
    setMessage("");
    try {
      const result = await getPing();
      if (result.ok) {
        setState("ok");
        setMessage("Connected ✓");
      } else {
        setState("error");
        setMessage("Unexpected response from server");
      }
    } catch (error) {
      setState("error");
      if (error instanceof ApiError) {
        setMessage(
          `Error ${error.status}: ${error.code}${error.message ? ` — ${error.message}` : ""}`,
        );
      } else {
        setMessage(error instanceof Error ? error.message : "Network error");
      }
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.label}>API URL</Text>
      <Text style={styles.value}>{apiBaseUrl || "(not set — see .env.example)"}</Text>

      <View style={styles.button}>
        <Button title="Test connection" onPress={testConnection} disabled={state === "loading"} />
      </View>

      {state === "loading" && <ActivityIndicator />}
      {(state === "ok" || state === "error") && (
        <Text style={[styles.result, state === "ok" ? styles.ok : styles.error]}>{message}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
    gap: 8,
  },
  label: {
    fontSize: 13,
    color: "#888",
    textTransform: "uppercase",
  },
  value: {
    fontSize: 16,
    marginBottom: 16,
  },
  button: {
    marginVertical: 8,
  },
  result: {
    fontSize: 15,
    marginTop: 8,
  },
  ok: {
    color: "#1a7f37",
  },
  error: {
    color: "#cf222e",
  },
});
