import Constants from "expo-constants";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { useRouter } from "expo-router";
import { useEffect } from "react";
import { Platform } from "react-native";

import { registerDevice } from "@/api/endpoints";

// Foreground handler: show a banner + play a sound while the app is open.
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export interface RegisterResult {
  ok: boolean;
  reason?: string;
}

function projectId(): string | undefined {
  return Constants.expoConfig?.extra?.eas?.projectId as string | undefined;
}

// Request permission, get the Expo push token, and register the device.
// NOTE: remote push requires an EAS dev build — it does not work in Expo Go.
export async function registerForPush(): Promise<RegisterResult> {
  if (!Device.isDevice) {
    return { ok: false, reason: "Push notifications require a physical device." };
  }

  const existing = await Notifications.getPermissionsAsync();
  let status = existing.status;
  if (status !== "granted") {
    const requested = await Notifications.requestPermissionsAsync();
    status = requested.status;
  }
  if (status !== "granted") {
    return { ok: false, reason: "Notifications are turned off. Enable them in Settings." };
  }

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("default", {
      name: "Default",
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  }

  const id = projectId();
  if (!id) {
    return { ok: false, reason: "Missing EAS projectId — run `eas init` (see README)." };
  }

  const token = await Notifications.getExpoPushTokenAsync({ projectId: id });
  await registerDevice({ expo_push_token: token.data, platform: Platform.OS });
  return { ok: true };
}

export async function getPushPermissionStatus(): Promise<string> {
  const { status } = await Notifications.getPermissionsAsync();
  return status;
}

function watchIdFrom(response: Notifications.NotificationResponse | null): string | null {
  const value = response?.notification.request.content.data?.watch_id;
  return value === undefined || value === null ? null : String(value);
}

// Deep-link on notification tap: warm (listener) + cold start (last response).
export function useNotificationDeepLinks() {
  const router = useRouter();

  useEffect(() => {
    let handled = false;
    Notifications.getLastNotificationResponseAsync().then((response) => {
      const watchId = watchIdFrom(response);
      if (watchId && !handled) {
        handled = true;
        router.push({ pathname: "/watch/[id]", params: { id: watchId } });
      }
    });

    const subscription = Notifications.addNotificationResponseReceivedListener((response) => {
      const watchId = watchIdFrom(response);
      if (watchId) router.push({ pathname: "/watch/[id]", params: { id: watchId } });
    });
    return () => subscription.remove();
  }, [router]);
}
