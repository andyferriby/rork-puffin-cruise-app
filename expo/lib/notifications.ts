import { OneSignal } from "react-native-onesignal";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform } from "react-native";

const NOTIFICATIONS_ENABLED_KEY = "@puffin_notifications_enabled";

const ONE_SIGNAL_APP_ID = process.env.EXPO_PUBLIC_ONESIGNAL_APP_ID ?? "";

/** Initialize OneSignal on app startup. Call once from the root layout. */
export function initOneSignal(): void {
  if (!ONE_SIGNAL_APP_ID) {
    console.warn("[onesignal] No App ID set — push notifications disabled");
    return;
  }

  OneSignal.initialize(ONE_SIGNAL_APP_ID);
}

/** Link an email to this device so the admin can target them via OneSignal REST API. */
export function linkEmailToPush(email: string): void {
  if (!email.trim()) return;
  OneSignal.User.addAlias("external_id", email.toLowerCase().trim());
  OneSignal.User.addEmail(email.toLowerCase().trim());
}

/** Check if the user has opted into notifications (stored locally). */
export async function isNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Toggle push notifications on/off. */
export async function setNotificationsEnabled(enabled: boolean, email?: string): Promise<void> {
  await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, String(enabled));

  if (enabled) {
    OneSignal.User.pushSubscription.optIn();
    if (email) linkEmailToPush(email);
  } else {
    OneSignal.User.pushSubscription.optOut();
  }
}
