import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform } from "react-native";

import type { OneSignal as OneSignalType } from "react-native-onesignal";

type OneSignalModule = typeof OneSignalType;

let oneSignalModule: OneSignalModule | null | undefined;

function getOneSignal(): OneSignalModule | null {
  if (oneSignalModule !== undefined) return oneSignalModule;

  try {
    // OneSignal is not always available in preview clients/simulators. Keep production push intact,
    // but do not let a missing native module crash app startup.
    oneSignalModule = require("react-native-onesignal").OneSignal as OneSignalModule;
  } catch (err) {
    console.warn(`[onesignal] Native module unavailable on ${Platform.OS}; push disabled for this runtime`);
    oneSignalModule = null;
  }

  return oneSignalModule;
}

const NOTIFICATIONS_ENABLED_KEY = "@puffin_notifications_enabled";
const ADMIN_NOTIFICATIONS_ENABLED_KEY = "@puffin_admin_notifications_enabled";

const ONE_SIGNAL_APP_ID = process.env.EXPO_PUBLIC_ONESIGNAL_APP_ID ?? "";
const ADMIN_PUSH_TAG = "admin_alerts";

let hasInitializedOneSignal = false;

/** Initialize OneSignal on app startup. Call once from the root layout. */
export function initOneSignal(): boolean {
  if (!ONE_SIGNAL_APP_ID) {
    console.warn("[onesignal] No App ID set — push notifications disabled");
    return false;
  }

  const OneSignal = getOneSignal();
  if (!OneSignal) return false;

  if (!hasInitializedOneSignal) {
    try {
      OneSignal.initialize(ONE_SIGNAL_APP_ID);
      hasInitializedOneSignal = true;
    } catch (err) {
      console.error("[onesignal] initialization failed", err);
      return false;
    }
  }

  return true;
}

async function requestPushPermission(): Promise<boolean> {
  if (!initOneSignal()) return false;

  const OneSignal = getOneSignal();
  if (!OneSignal) return false;

  try {
    const granted = await OneSignal.Notifications.requestPermission(true);
    OneSignal.User.pushSubscription.optIn();
    return granted;
  } catch (err) {
    console.error("[onesignal] permission request failed", err);
    return false;
  }
}

/** Register a callback for notification taps. */
export function onNotificationTap(callback: () => void): void {
  if (!initOneSignal()) return;
  const OneSignal = getOneSignal();
  if (!OneSignal) return;
  OneSignal.Notifications.addEventListener("click", callback);
}

/** Link an email to this device so the admin can target them via OneSignal REST API. */
export function linkEmailToPush(email: string): void {
  if (!email.trim() || !initOneSignal()) return;
  const OneSignal = getOneSignal();
  if (!OneSignal) return;
  OneSignal.User.addAlias("external_id", email.toLowerCase().trim());
  OneSignal.User.addEmail(email.toLowerCase().trim());
}

/** Check if the user has opted into notifications (stored locally). */
export async function isNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Toggle push notifications on/off. */
export async function setNotificationsEnabled(enabled: boolean, email?: string): Promise<boolean> {
  if (enabled) {
    const granted = await requestPushPermission();
    await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, String(granted));
    if (granted && email) linkEmailToPush(email);
    return granted;
  }

  await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, "false");
  const OneSignal = getOneSignal();
  if (initOneSignal() && OneSignal) OneSignal.User.pushSubscription.optOut();
  return false;
}

/** Check if this device is enrolled for private admin booking alerts. */
export async function isAdminNotificationsEnabled(): Promise<boolean> {
  const val = await AsyncStorage.getItem(ADMIN_NOTIFICATIONS_ENABLED_KEY);
  return val === "true";
}

/** Enroll or remove this device from private admin booking alerts. */
export async function setAdminNotificationsEnabled(enabled: boolean): Promise<boolean> {
  if (enabled) {
    const granted = await requestPushPermission();
    await AsyncStorage.setItem(ADMIN_NOTIFICATIONS_ENABLED_KEY, String(granted));
    if (granted) {
      try {
        const OneSignal = getOneSignal();
        if (OneSignal) OneSignal.User.addTag(ADMIN_PUSH_TAG, "true");
      } catch (err) {
        console.error("[onesignal] admin tag failed", err);
      }
    }
    return granted;
  }

  await AsyncStorage.setItem(ADMIN_NOTIFICATIONS_ENABLED_KEY, "false");
  const OneSignal = getOneSignal();
  if (initOneSignal() && OneSignal) OneSignal.User.removeTag(ADMIN_PUSH_TAG);
  return false;
}
