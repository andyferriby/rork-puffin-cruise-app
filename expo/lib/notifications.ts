import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

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

/**
 * Register for push notifications and persist the Expo token to Supabase.
 * Returns the token string, or null if unavailable (simulator, denied, etc.).
 */
export async function registerForPushNotifications(): Promise<string | null> {
  if (!Device.isDevice) {
    console.log("[pn] not a physical device, skipping");
    return null;
  }

  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;
  if (existingStatus !== "granted") {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== "granted") {
    console.log("[pn] permission denied");
    return null;
  }

  const tokenData = await Notifications.getExpoPushTokenAsync({ projectId: process.env.EXPO_PUBLIC_PROJECT_ID! });
  const token = tokenData.data;
  console.log("[pn] got token", token.slice(0, 12) + "...");

  // Persist token to Supabase so the Cloudflare worker can reach it
  await storeToken(token);
  return token;
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
 * We route through the backend instead of writing to Supabase directly
 * to avoid RLS INSERT restrictions on the app_config table.
 */
async function storeToken(token: string): Promise<void> {
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
      return;
    }

    let result: { ok: boolean; totalTokens: number; persisted?: boolean } = { ok: false, totalTokens: 0 };
    try { result = JSON.parse(resText); } catch { /* ignore parse errors */ }
    console.log("[pn] storeToken OK — total:", result.totalTokens, "persisted:", result.persisted, "response:", resText.slice(0, 200));
  } catch (err) {
    console.error("[pn] storeToken network error", String(err));
  }
}
