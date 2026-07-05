import { useEffect, useState } from "react";
import { ActivityIndicator, Button, StyleSheet, Text, View } from "react-native";

import { ApiError, apiBaseUrl } from "@/api/client";
import { getPing } from "@/api/endpoints";
import { getPushPermissionStatus, registerForPush } from "@/lib/push";

type ConnectionState = "idle" | "loading" | "ok" | "error";

export default function SettingsScreen() {
  const [state, setState] = useState<ConnectionState>("idle");
  const [message, setMessage] = useState("");

  const [pushStatus, setPushStatus] = useState("checking…");
  const [pushBusy, setPushBusy] = useState(false);
  const [pushMessage, setPushMessage] = useState("");

  useEffect(() => {
    getPushPermissionStatus().then(setPushStatus);
  }, []);

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

  async function enableNotifications() {
    setPushBusy(true);
    setPushMessage("");
    const result = await registerForPush();
    setPushBusy(false);
    setPushStatus(await getPushPermissionStatus());
    setPushMessage(result.ok ? "Registered ✓" : (result.reason ?? "Could not register"));
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

      <Text style={[styles.label, styles.section]}>Notifications</Text>
      <Text style={styles.value}>Permission: {pushStatus}</Text>
      <View style={styles.button}>
        <Button title="Enable notifications" onPress={enableNotifications} disabled={pushBusy} />
      </View>
      {pushBusy && <ActivityIndicator />}
      {pushMessage !== "" && (
        <Text style={[styles.result, pushMessage.includes("✓") ? styles.ok : styles.error]}>
          {pushMessage}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, gap: 8 },
  label: { fontSize: 13, color: "#888", textTransform: "uppercase" },
  section: { marginTop: 28 },
  value: { fontSize: 16, marginBottom: 8 },
  button: { marginVertical: 8 },
  result: { fontSize: 15, marginTop: 8 },
  ok: { color: "#1a7f37" },
  error: { color: "#cf222e" },
});
