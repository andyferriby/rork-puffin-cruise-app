import { OneSignal } from "react-native-onesignal";
import AsyncStorage from "@react-native-async-storage/async-storage";

const NOTIFICATIONS_ENABLED_KEY = "@puffin_notifications_enabled";
const ADMIN_NOTIFICATIONS_ENABLED_KEY = "@puffin_admin_notifications_enabled";

const ONE_SIGNAL_APP_ID = process.env.EXPO_PUBLIC_ONESIGNAL_APP_ID ?? "";
const ADMIN_PUSH_TAG = "admin_alerts";

/** Initialize OneSignal on app startup. Call once from the root layout. */
export function initOneSignal(): void {
  if (!ONE_SIGNAL_APP_ID) {
    console.warn("[onesignal] No App ID set — push notifications disabled");
    return;
  }

  OneSignal.initialize(ONE_SIGNAL_APP_ID);
}

/** Register a callback for notification taps. */
export function onNotificationTap(callback: () => void): void {
  OneSignal.Notifications.addEventListener("click", callback);
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
    OneSignal.Notifications.requestPermission(true);
    OneSignal.User.pushSubscription.optIn();
    if (email) linkEmailToPush(email);
  } else {
    OneSignal.User.pushSubscription.optOut();
  }
}

/** Check if this device is enrolled for private admin booking alerts. */
export async function isAdminNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(ADMIN_NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Enroll or remove this device from private admin booking alerts. */
export async function setAdminNotificationsEnabled(enabled: boolean): Promise<void> {
  await AsyncStorage.setItem(ADMIN_NOTIFICATIONS_ENABLED_KEY, String(enabled));

  if (enabled) {
    OneSignal.Notifications.requestPermission(true);
    OneSignal.User.pushSubscription.optIn();
    OneSignal.User.addTag(ADMIN_PUSH_TAG, "true");
  } else {
    OneSignal.User.removeTag(ADMIN_PUSH_TAG);
  }
}
