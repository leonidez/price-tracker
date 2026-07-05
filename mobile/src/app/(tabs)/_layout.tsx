import { router, Tabs } from "expo-router";
import { Pressable, Text } from "react-native";

function AddButton() {
  return (
    <Pressable
      onPress={() => router.push("/add-url")}
      hitSlop={12}
      style={{ paddingHorizontal: 16 }}
    >
      <Text style={{ fontSize: 26, color: "#0a7ea4" }}>+</Text>
    </Pressable>
  );
}

export default function TabsLayout() {
  return (
    <Tabs>
      <Tabs.Screen name="index" options={{ title: "Watches", headerRight: () => <AddButton /> }} />
      <Tabs.Screen name="settings" options={{ title: "Settings" }} />
    </Tabs>
  );
}
