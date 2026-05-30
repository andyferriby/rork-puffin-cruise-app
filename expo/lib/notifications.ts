import AsyncStorage from "@react-native-async-storage/async-storage";

const NOTIFICATIONS_ENABLED_KEY = "@puffin_notifications_enabled";

/** No-op on web — OneSignal is native-only. */
export function initOneSignal(): void {
  // Not available on web
}

/** No-op on web — OneSignal is native-only. */
export function onNotificationTap(_callback: () => void): void {
  // Not available on web
}

/** No-op on web — OneSignal is native-only. */
export function linkEmailToPush(_email: string): void {
  // Not available on web
}

/** Check if the user has opted into notifications (stored locally). */
export async function isNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Toggle push notifications on/off. No-op on web. */
export async function setNotificationsEnabled(enabled: boolean, _email?: string): Promise<void> {
  await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, String(enabled));
}
