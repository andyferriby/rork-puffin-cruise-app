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
  /** Which step failed, for diagnostics */
  failedStep: "none" | "device_check" | "permission_request" | "expo_push_token" | "backend_store" | "unknown";
};

// Cache so repeated calls don't re-request permissions or re-fetch the token
let cachedResult: PushRegistrationResult | null = null;

/** Clear cached result so the next call will run the full flow again. */
export function resetPushRegistrationCache(): void {
  cachedResult = null;
}

/**
 * Register for push notifications and persist the Expo token to the backend.
 * Results are cached — subsequent calls return the same result unless
 * forceRefresh is true or resetPushRegistrationCache() was called.
 */
export async function registerForPushNotifications(forceRefresh = false): Promise<PushRegistrationResult> {
  if (cachedResult && !forceRefresh) {
    console.log("[pn] using cached result —", cachedResult.permissionStatus, cachedResult.registered ? "registered" : "not registered");
    return cachedResult;
  }

  const result: PushRegistrationResult = {
    token: null,
    isDevice: false,
    permissionStatus: "undetermined",
    registered: false,
    error: null,
    failedStep: "none",
  };

  // ── Step 0: device check ──────────────────────────────────────
  if (!Device.isDevice) {
    console.log("[pn:step0] not a physical device, skipping");
    result.failedStep = "device_check";
    result.error = "Push notifications require a physical device.";
    cachedResult = result;
    return result;
  }
  result.isDevice = true;

  const projectId = process.env.EXPO_PUBLIC_PROJECT_ID;
  if (!projectId) {
    console.error("[pn:step0] missing EXPO_PUBLIC_PROJECT_ID");
    result.failedStep = "device_check";
    result.permissionStatus = "error";
    result.error = "Push notification project ID is not configured.";
    cachedResult = result;
    return result;
  }

  // ── Step 1: get or request permission ─────────────────────────
  try {
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;
    console.log("[pn:step1] existing permission:", existingStatus);

    if (existingStatus !== "granted") {
      if (existingStatus === "denied") {
        console.log("[pn:step1] permission previously denied — cannot re-prompt");
        result.permissionStatus = "denied";
        result.failedStep = "permission_request";
        result.error = "Notifications are disabled. Open iOS Settings to enable them.";
        cachedResult = result;
        return result;
      }

      console.log("[pn:step1] requesting permission...");
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
      console.log("[pn:step1] requestPermissionsAsync returned:", finalStatus);
    }

    result.permissionStatus =
      finalStatus === "granted" ? "granted"
      : finalStatus === "denied" ? "denied"
      : "undetermined";

    if (finalStatus !== "granted") {
      console.log("[pn:step1] permission not granted — status:", finalStatus);
      result.failedStep = "permission_request";
      result.error =
        finalStatus === "denied"
          ? "Notifications are disabled. Open iOS Settings to enable them."
          : "Could not get notification permission.";
      cachedResult = result;
      return result;
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[pn:step1] permission error:", msg);
    result.failedStep = "permission_request";
    result.permissionStatus = "error";
    result.error = `Permission check failed: ${msg.length > 100 ? msg.slice(0, 100) + "…" : msg}`;
    cachedResult = result;
    return result;
  }

  // ── Step 2: get Expo push token ──────────────────────────────
  let expoToken: string;
  try {
    console.log("[pn:step2] requesting Expo push token with projectId:", projectId.slice(0, 8) + "...");
    const tokenData = await Notifications.getExpoPushTokenAsync({ projectId });
    expoToken = tokenData.data;
    result.token = expoToken;
    console.log("[pn:step2] got token", expoToken.slice(0, 12) + "...");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    const code = (err as { code?: string }).code ?? "";
    const stack = err instanceof Error ? err.stack ?? "" : "";
    console.error("[pn:step2] getExpoPushTokenAsync failed:", msg);
    console.error("[pn:step2] error code:", code || "(none)");
    if (stack) console.error("[pn:step2] stack:", stack.slice(0, 500));

    result.failedStep = "expo_push_token";
    result.permissionStatus = "error";

    // Always include the raw error so we can diagnose, plus actionable guidance
    const rawDetail = msg.length > 200 ? msg.slice(0, 180) + "…" : msg;

    if (msg.includes("APNs") || msg.includes("remote notification") || code === "E_NO_APNS_TOKEN") {
      result.error =
        `Push capability missing from this build. The expo-notifications plugin is in app.json, but the published build may not include it. Republish the app through Rork and try again.\n\nTechnical: ${rawDetail}`;
    } else if (msg.includes("permission") || msg.includes("not authorized") || msg.includes("denied")) {
      result.error =
        `Notification permission was denied during token registration. This can happen if you dismissed the system dialog. Try again — the system prompt should re-appear.\n\nTechnical: ${rawDetail}`;
    } else {
      // Show the raw error so we can actually diagnose it
      result.error =
        `Push token request failed.\n\nError: ${rawDetail}${code ? `\nCode: ${code}` : ""}\n\nThe expo-notifications plugin is in app.json. If this is a network error, check your internet connection. If it persists, the app may need to be republished through Rork.`;
    }
    cachedResult = result;
    return result;
  }

  // ── Step 3: persist token to backend ─────────────────────────
  try {
    const registered = await storeToken(expoToken);
    result.registered = registered;
    if (!registered) {
      result.failedStep = "backend_store";
      result.error = "Push token obtained but could not register with server. Check your connection.";
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[pn:step3] storeToken threw:", msg);
    result.failedStep = "backend_store";
    result.error = "Could not save push token to server.";
  }

  cachedResult = result;
  return result;
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
