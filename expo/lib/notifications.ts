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
    result.permissionStatus = "undetermined";
    result.error = "Push notifications require a physical device.";
    return result;
  }
  result.isDevice = true;

  const projectId = process.env.EXPO_PUBLIC_PROJECT_ID;
  if (!projectId) {
    console.error("[pn] missing EXPO_PUBLIC_PROJECT_ID");
    result.permissionStatus = "error";
    result.error = "Push notification project ID is not configured.";
    return result;
  }

  try {
    // Step 1 – get or request permission
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;

    if (existingStatus !== "granted") {
      // Only request if not already denied — iOS won't re-prompt after denial
      if (existingStatus === "denied") {
        console.log("[pn] permission previously denied — cannot re-prompt");
        result.permissionStatus = "denied";
        result.error = "Notifications are disabled. Open iOS Settings to enable them.";
        return result;
      }

      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
      console.log("[pn] requestPermissionsAsync returned:", finalStatus);
    }

    result.permissionStatus =
      finalStatus === "granted" ? "granted"
      : finalStatus === "denied" ? "denied"
      : "undetermined";

    if (finalStatus !== "granted") {
      console.log("[pn] permission not granted — status:", finalStatus);
      result.error =
        finalStatus === "denied"
          ? "Notifications are disabled. Open iOS Settings to enable them."
          : "Could not get notification permission.";
      return result;
    }

    // Step 2 – get Expo push token
    console.log("[pn] permission granted, requesting Expo push token...");
    const tokenData = await Notifications.getExpoPushTokenAsync({ projectId });
    result.token = tokenData.data;
    console.log("[pn] got token", tokenData.data.slice(0, 12) + "...");

    // Step 3 – persist token to backend
    const registered = await storeToken(tokenData.data);
    result.registered = registered;
    if (!registered) {
      result.error = "Could not register with push server. Check your connection.";
    }

    return result;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[pn] registration error —", message);

    // Translate known Expo push token errors into user-friendly messages
    if (message.includes("Failed to get push token") || message.includes("GCM")) {
      result.error = "Push notification setup is incomplete. Please restart the app.";
    } else if (message.includes("Network") || message.includes("fetch")) {
      result.error = "Network error. Check your connection and try again.";
    } else {
      result.error = message.length > 150 ? "An unexpected error occurred. Please try again." : message;
    }

    result.permissionStatus = "error";
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
