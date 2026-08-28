import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

import { supabase } from "./supabase";

const NOTIFICATIONS_ENABLED_KEY = "@puffin_notifications_enabled";

/**
 * Configure how notifications behave while the app is open.
 * Safe to call multiple times.
 */
export function configurePushNotifications(): void {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    }),
  });
}

/**
 * Ask for notification permission, fetch the Expo push token for this device
 * and register it in Supabase so the admin can broadcast to all devices.
 */
export async function registerForPushNotifications(): Promise<boolean> {
  const existing = await Notifications.getPermissionsAsync();
  let granted = existing.granted;
  if (!granted) {
    const request = await Notifications.requestPermissionsAsync();
    granted = request.granted;
  }
  if (!granted) return false;

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("default", {
      name: "Puffin Cruises",
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: "#FF8A3D",
    });
  }

  const projectId = process.env.EXPO_PUBLIC_PROJECT_ID;
  if (!projectId) {
    console.warn("[push] missing EXPO_PUBLIC_PROJECT_ID; cannot register token");
    return false;
  }

  const tokenResponse = await Notifications.getExpoPushTokenAsync({ projectId });
  const token = tokenResponse.data;
  if (!token) return false;

  const { error } = await supabase
    .from("push_tokens")
    .upsert({ token, platform: Platform.OS }, { onConflict: "token" });
  if (error) {
    console.error("[push] token save failed", error.message);
    return false;
  }

  await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, "true");
  return true;
}

/** Check if the user has opted into notifications (stored locally). */
export async function isNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Ask permission (if needed) and register this device for broadcasts. */
export async function setNotificationsEnabled(enabled: boolean): Promise<boolean> {
  if (!enabled) {
    await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, "false");
    return false;
  }
  return registerForPushNotifications();
}
