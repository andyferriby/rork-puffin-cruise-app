import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { Alert, Linking, Platform } from "react-native";

const FUNCTIONS_URL = process.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL!;

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

/** Token shape stored in app_config */
export type PushToken = {
  token: string;
  platform: string;
  email?: string;
  createdAt: string;
};

export type PushRegistrationResult = {
  token: string | null;
  isDevice: boolean;
  permissionStatus: "granted" | "denied" | "undetermined" | "error";
  registered: boolean;
  error: string | null;
};

/**
 * Register for push notifications and persist the Expo token to the backend.
 * Returns a diagnostic result object so the caller can show appropriate UI.
 */
export async function registerForPushNotifications(): Promise<PushRegistrationResult> {
  const result: PushRegistrationResult = {
    token: null,
    isDevice: false,
    permissionStatus: "undetermined",
    registered: false,
    error: null,
  };

  if (!Device.isDevice) {
    console.log("[pn] not a physical device, skipping");
    return result;
  }
  result.isDevice = true;

  try {
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;
    if (existingStatus !== "granted") {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }
    result.permissionStatus = finalStatus === "granted" ? "granted" : (finalStatus === "denied" ? "denied" : "undetermined");

    if (finalStatus !== "granted") {
      console.log("[pn] permission denied — status:", finalStatus);
      result.error = finalStatus === "denied"
        ? "Notifications are disabled. Enable them in iOS Settings to receive trip reminders."
        : "Could not get notification permission.";
      return result;
    }

    const tokenData = await Notifications.getExpoPushTokenAsync({ projectId: process.env.EXPO_PUBLIC_PROJECT_ID! });
    result.token = tokenData.data;
    console.log("[pn] got token", tokenData.data.slice(0, 12) + "...");

    // Persist token to backend
    const registered = await storeToken(tokenData.data);
    result.registered = registered;
    if (!registered) {
      result.error = "Could not register token with the server. Check your connection and try again.";
    }

    return result;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[pn] registration error", message);
    result.permissionStatus = "error";
    result.error = message;
    return result;
  }
}

/**
 * Shows an alert guiding the user to iOS Settings if notifications are denied.
 */
export function showPermissionDeniedAlert(): void {
  Alert.alert(
    "Notifications Disabled",
    "To receive trip reminders, weather alerts, and boarding updates, enable notifications in your device settings.",
    [
      { text: "Not Now", style: "cancel" },
      { text: "Open Settings", onPress: () => { void Linking.openSettings(); } },
    ],
  );
}

/**
 * Link the device's push token to a customer email so trip reminders
 * can be targeted to the right person. Call this after a user searches
 * their tickets by email.
 */
export async function linkDeviceToEmail(email: string): Promise<void> {
  try {
    if (!Device.isDevice) return;
    const { status } = await Notifications.getPermissionsAsync();
    if (status !== "granted") return;

    const tokenData = await Notifications.getExpoPushTokenAsync({ projectId: process.env.EXPO_PUBLIC_PROJECT_ID! });
    const token = tokenData.data;

    await fetch(`${FUNCTIONS_URL}/link-device`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token, email: email.trim().toLowerCase(), platform: Platform.OS }),
    });
    console.log("[pn] linked token to", email);
  } catch (err) {
    console.error("[pn] link-device error", err);
  }
}

/**
 * Store the Expo push token via the Cloudflare backend worker.
 * Returns true if the token was successfully persisted.
 */
async function storeToken(token: string): Promise<boolean> {
  try {
    const url = `${FUNCTIONS_URL}/register-device`;
    console.log("[pn] storeToken calling", url);
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token, platform: Platform.OS }),
    });

    const resText = await res.text().catch(() => "");
    if (!res.ok) {
      console.error("[pn] storeToken FAILED", res.status, resText.slice(0, 300));
      return false;
    }

    let result: { ok: boolean; totalTokens: number; persisted?: boolean } = { ok: false, totalTokens: 0 };
    try { result = JSON.parse(resText); } catch { /* ignore parse errors */ }
    console.log("[pn] storeToken OK — total:", result.totalTokens, "persisted:", result.persisted);
    return result.ok || result.persisted === true;
  } catch (err) {
    console.error("[pn] storeToken network error", String(err));
    return false;
  }
}
