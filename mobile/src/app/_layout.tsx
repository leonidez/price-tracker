import { Stack } from "expo-router";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

import { useNotificationDeepLinks } from "@/lib/push";

const queryClient = new QueryClient();

export default function RootLayout() {
  useNotificationDeepLinks();

  return (
    <QueryClientProvider client={queryClient}>
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="scan" options={{ title: "Scan barcode" }} />
        <Stack.Screen name="watch/[id]" options={{ title: "Watch" }} />
        <Stack.Screen name="add-url" options={{ title: "Add by URL" }} />
        <Stack.Screen name="edit/[id]" options={{ title: "Edit watch" }} />
      </Stack>
    </QueryClientProvider>
  );
}
