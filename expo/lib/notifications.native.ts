import AsyncStorage from "@react-native-async-storage/async-storage";

const NOTIFICATIONS_ENABLED_KEY = "@puffin_notifications_enabled";
const ADMIN_NOTIFICATIONS_ENABLED_KEY = "@puffin_admin_notifications_enabled";

/** OneSignal has been removed; push setup is intentionally disabled. */
export function initOneSignal(): boolean {
  return false;
}

/** OneSignal has been removed; notification taps are intentionally disabled. */
export function onNotificationTap(_callback: () => void): void {
  // Push notifications removed.
}

/** OneSignal has been removed; email-to-push linking is intentionally disabled. */
export function linkEmailToPush(_email: string): void {
  // Push notifications removed.
}

/** Check if the user has opted into notifications (stored locally). */
export async function isNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Toggle push notifications on/off. */
export async function setNotificationsEnabled(_enabled: boolean, _email?: string): Promise<boolean> {
  await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, "false");
  return false;
}

/** Check if this device is enrolled for private admin booking alerts. */
export async function isAdminNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(ADMIN_NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Enroll or remove this device from private admin booking alerts. */
export async function setAdminNotificationsEnabled(_enabled: boolean): Promise<boolean> {
  await AsyncStorage.setItem(ADMIN_NOTIFICATIONS_ENABLED_KEY, "false");
  return false;
}
