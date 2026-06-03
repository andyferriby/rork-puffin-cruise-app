import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform } from "react-native";
import Purchases, { CustomerInfo, PurchasesOffering } from "react-native-purchases";

const BASE = process.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL ?? "";
const MEMBER_ID_KEY = "@puffin_member_id";
const TEST_KEY = "test_SCHOyVPxfMqXbovqKbIDwIqpRgN";
const IOS_LIVE_KEY = "appl_otLFzRBmUwDxcahJfwKDGkvvLxm";
const ENTITLEMENT = "membership";

let configured = false;

function revenueCatKey(): string {
  if (Platform.OS === "web") return process.env.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY ?? TEST_KEY;
  return Platform.select({
    ios: process.env.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY ?? IOS_LIVE_KEY,
    android: process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_API_KEY,
    default: process.env.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY,
  }) ?? TEST_KEY;
}

export async function getMemberId(): Promise<string> {
  const existing = await AsyncStorage.getItem(MEMBER_ID_KEY);
  if (existing) return existing;
  const next = `mem_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
  await AsyncStorage.setItem(MEMBER_ID_KEY, next);
  return next;
}

export async function configureMembershipPurchases(): Promise<string> {
  const memberId = await getMemberId();
  if (!configured) {
    Purchases.configure({ apiKey: revenueCatKey(), appUserID: memberId });
    configured = true;
  }
  return memberId;
}

export function hasMembership(info: CustomerInfo | null | undefined): boolean {
  return Boolean(info?.entitlements.active[ENTITLEMENT]);
}

export async function getMembershipOffering(): Promise<PurchasesOffering | null> {
  await configureMembershipPurchases();
  const offerings = await Purchases.getOfferings();
  return offerings.current ?? null;
}

export async function getMembershipCustomerInfo(): Promise<CustomerInfo> {
  await configureMembershipPurchases();
  return Purchases.getCustomerInfo();
}

export type MembershipPass = {
  memberId: string;
  email: string;
  active: boolean;
  creditsTotal: number;
  creditsUsed: number;
  creditsRemaining: number;
  expiresAt: string;
  discountPercent: number;
  updatedAt: string;
};

export async function syncMembership(email: string): Promise<MembershipPass> {
  const memberId = await configureMembershipPurchases();
  const info = await Purchases.getCustomerInfo();
  const active = hasMembership(info);
  const entitlement = info.entitlements.active[ENTITLEMENT];
  const expiresAt = entitlement?.expirationDate ?? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();
  const res = await fetch(`${BASE}/membership/sync`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ memberId, email: email.trim().toLowerCase(), active, expiresAt }),
  });
  if (!res.ok) throw new Error(await res.text());
  return (await res.json()) as MembershipPass;
}

export async function restoreMembership(): Promise<CustomerInfo> {
  await configureMembershipPurchases();
  return Purchases.restorePurchases();
}
