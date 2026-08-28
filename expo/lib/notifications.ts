/** Web stub: push registration is native-only. */
export function configurePushNotifications(): void {
  // Push notifications are native-only.
}

export async function registerForPushNotifications(): Promise<boolean> {
  return false;
}

export async function isNotificationsEnabled(): Promise<boolean> {
  return false;
}

export async function setNotificationsEnabled(_enabled: boolean): Promise<boolean> {
  return false;
}
