import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

import { supabase } from "@/lib/supabase";

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

async function storeToken(token: string): Promise<void> {
  // Read existing tokens from app_config
  const { data } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "push_tokens")
    .maybeSingle();

  const existing: PushToken[] = Array.isArray(data?.value)
    ? (data.value as PushToken[])
    : [];
  const filtered = existing.filter((t) => t.token !== token);
  filtered.push({
    token,
    platform: Platform.OS,
    createdAt: new Date().toISOString(),
  });

  // Keep only last 500 tokens to avoid unbounded growth
  const trimmed = filtered.slice(-500);

  await supabase.from("app_config").upsert(
    { key: "push_tokens", value: trimmed as unknown as Record<string, unknown> },
    { onConflict: "key" },
  );
}
