// Puffin Cruises backend: Stripe checkout + webhook + Supabase persistence.

import { createOpenSslCompatiblePkcs7Signature } from "@swapnanildhol/passkit-pkcs7-signature";
import { Buffer } from "node:buffer";

const STRIPE_TIMESTAMP_TOLERANCE_SEC = 300;

type Env = {
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
  EXPO_PUBLIC_SUPABASE_URL: string;
  EXPO_PUBLIC_SUPABASE_ANON_KEY: string;
  APPLE_PASS_TYPE_ID?: string;
  APPLE_TEAM_ID?: string;
  APPLE_PASS_CERT_P12_BASE64?: string;
  APPLE_PASS_CERT_PASSWORD?: string;
  APPLE_WWDR_CERT_BASE64?: string;
  APPLE_SIGNER_CERT_PEM?: string;
  APPLE_SIGNER_KEY_PKCS8_PEM?: string;
  APPLE_WWDR_PEM?: string;
  RESEND_API_KEY?: string;
  RESEND_FROM_EMAIL?: string;
};

const APPLE_PASS_TYPE_ID = "pass.com.puffincruises.boarding";
const APPLE_TEAM_ID = "LW262LERGM";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, authorization",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(body: unknown, init?: ResponseInit): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
}

async function verifyStripeSignature(payload: string, header: string, secret: string): Promise<boolean> {
  const entries = header.split(",").map((kv) => {
    const [k, ...rest] = kv.split("=");
    return [k, rest.join("=")] as const;
  });
  const timestamp = entries.find(([k]) => k === "t")?.[1];
  const signatures = entries.filter(([k, v]) => k === "v1" && v).map(([, v]) => v);
  if (!timestamp || signatures.length === 0) return false;

  const ageSec = Math.floor(Date.now() / 1000) - Number(timestamp);
  if (!Number.isFinite(ageSec) || Math.abs(ageSec) > STRIPE_TIMESTAMP_TOLERANCE_SEC) return false;

  const signedPayload = `${timestamp}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signedPayload));
  const computed = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return signatures.some((candidate) => {
    if (computed.length !== candidate.length) return false;
    let mismatch = 0;
    for (let i = 0; i < computed.length; i++) mismatch |= computed.charCodeAt(i) ^ candidate.charCodeAt(i);
    return mismatch === 0;
  });
}

function stripeForm(data: Record<string, string | number>): string {
  return Object.entries(data)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    .join("&");
}

class StripeApiError extends Error {
  status: number;
  detail: unknown;
  constructor(status: number, detail: unknown) {
    super(`stripe failed: ${status}`);
    this.status = status;
    this.detail = detail;
  }
}

async function stripeFetch(env: Env, path: string, body: Record<string, string | number>): Promise<unknown> {
  if (!env.STRIPE_SECRET_KEY) {
    throw new StripeApiError(0, { message: "STRIPE_SECRET_KEY not set" });
  }
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: stripeForm(body),
  });
  const data = (await res.json()) as unknown;
  if (!res.ok) {
    console.error("stripe error", path, res.status, data);
    throw new StripeApiError(res.status, data);
  }
  return data;
}

async function stripeGet(env: Env, path: string): Promise<unknown> {
  if (!env.STRIPE_SECRET_KEY) {
    throw new StripeApiError(0, { message: "STRIPE_SECRET_KEY not set" });
  }
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "GET",
    headers: { Authorization: `Bearer ${env.STRIPE_SECRET_KEY}` },
  });
  const data = (await res.json()) as unknown;
  if (!res.ok) {
    console.error("stripe error", path, res.status, data);
    throw new StripeApiError(res.status, data);
  }
  return data;
}

async function supa(env: Env, path: string, init: RequestInit & { body?: string }): Promise<Response> {
  return fetch(`${env.EXPO_PUBLIC_SUPABASE_URL}/rest/v1${path}`, {
    ...init,
    headers: {
      apikey: env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.EXPO_PUBLIC_SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(init.headers ?? {}),
    },
  });
}

// ── Wallet Pass Generation ──────────────────────────────────────

interface BookingRecord {
  id: string;
  cruise_name: string;
  cruise_date: string;
  cruise_time: string;
  customer_name: string;
  adults: number;
  children: number;
  status: string;
}

async function handleWalletPass(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const bookingId = url.searchParams.get("bookingId");
  if (!bookingId) return json({ error: "missing bookingId" }, { status: 400 });

  // Fetch booking
  const bookingRes = await supa(env, `/bookings?id=eq.${encodeURIComponent(bookingId)}&select=id,cruise_name,cruise_date,cruise_time,customer_name,adults,children,status`, { method: "GET" });
  if (!bookingRes.ok) return json({ error: "booking_not_found" }, { status: 404 });
  const bookings = (await bookingRes.json()) as BookingRecord[];
  const booking = bookings[0];
  if (!booking) return json({ error: "booking_not_found" }, { status: 404 });

  const passTypeIdentifier = env.APPLE_PASS_TYPE_ID ?? APPLE_PASS_TYPE_ID;
  const teamIdentifier = env.APPLE_TEAM_ID ?? APPLE_TEAM_ID;

  const passData = {
    formatVersion: 1,
    passTypeIdentifier,
    serialNumber: booking.id,
    teamIdentifier,
    organizationName: "Dave Gray's Puffin Cruises",
    description: `Boarding pass for ${booking.cruise_name}`,
    logoText: "PUFFIN CRUISES",
    foregroundColor: "rgb(255,255,255)",
    backgroundColor: "rgb(11,42,74)",
    labelColor: "rgb(200,215,230)",
    boardingPass: {
      primaryFields: [
        { key: "cruise", label: "CRUISE", value: booking.cruise_name },
      ],
      secondaryFields: [
        { key: "date", label: "DATE", value: booking.cruise_date },
        { key: "time", label: "TIME", value: booking.cruise_time },
      ],
      auxiliaryFields: [
        { key: "passenger", label: "PASSENGER", value: booking.customer_name },
        { key: "passengers", label: "GROUP", value: `${booking.adults} adult${booking.adults === 1 ? "" : "s"}${booking.children > 0 ? `, ${booking.children} child${booking.children === 1 ? "" : "ren"}` : ""}` },
      ],
      headerFields: [
        { key: "ref", label: "REF", value: booking.id.slice(0, 8).toUpperCase() },
      ],
      transitType: "PKTransitTypeBoat" as const,
    },
    barcode: {
      format: "PKBarcodeFormatQR" as const,
      message: booking.id,
      messageEncoding: "iso-8859-1" as const,
    },
  };

  const passJson = JSON.stringify(passData);
  const encoder = new TextEncoder();
  const baseFiles: ZipSourceFile[] = [
    { name: "pass.json", content: encoder.encode(passJson) },
    { name: "icon.png", content: base64ToBytes(PASS_ICON_PNG_BASE64) },
    { name: "icon@2x.png", content: base64ToBytes(PASS_ICON_PNG_BASE64) },
  ];

  const manifestEntries = await Promise.all(
    baseFiles.map(async (file) => [file.name, await sha1Bytes(file.content)] as const),
  );
  const manifest = Object.fromEntries(manifestEntries) as Record<string, string>;
  const manifestJson = JSON.stringify(manifest);

  // Apple Wallet requires this file to be a detached PKCS#7/CMS signature of manifest.json.
  // Signing material is read only from private backend secrets, never from the mobile bundle.
  const signingMaterial = getWalletSigningMaterial(env);
  if (!signingMaterial) {
    return json(
      {
        error: "wallet_signing_not_configured",
        message: "Apple Wallet signing PEM secrets need to be added to the backend environment.",
      },
      { status: 503 },
    );
  }

  const signature = await createOpenSslCompatiblePkcs7Signature({
    manifest: manifestJson,
    signerCertPem: signingMaterial.signerCertPem,
    privateKeyPkcs8Pem: signingMaterial.privateKeyPkcs8Pem,
    wwdrPem: signingMaterial.wwdrPem,
  });

  const result = createStoredZip([
    ...baseFiles,
    { name: "manifest.json", content: encoder.encode(manifestJson) },
    { name: "signature", content: signature },
  ]);

  return new Response(result, {
    headers: {
      ...corsHeaders,
      "Content-Type": "application/vnd.apple.pkpass",
      "Content-Disposition": `attachment; filename="${booking.id}.pkpass"`,
    },
  });
}

type WalletSigningMaterial = {
  signerCertPem: string;
  privateKeyPkcs8Pem: string;
  wwdrPem: string;
};

function getWalletSigningMaterial(env: Env): WalletSigningMaterial | null {
  const signerCertPem = normalizePemSecret(env.APPLE_SIGNER_CERT_PEM);
  const privateKeyPkcs8Pem = normalizePemSecret(env.APPLE_SIGNER_KEY_PKCS8_PEM);
  const wwdrPem = normalizePemSecret(env.APPLE_WWDR_PEM) ?? certBase64ToPem(env.APPLE_WWDR_CERT_BASE64);

  if (!signerCertPem || !privateKeyPkcs8Pem || !wwdrPem) return null;
  return { signerCertPem, privateKeyPkcs8Pem, wwdrPem };
}

function normalizePemSecret(value?: string): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  return trimmed.includes("-----BEGIN") ? trimmed.replace(/\\n/g, "\n") : trimmed;
}

function certBase64ToPem(value?: string): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  const base64 = trimmed.includes("-----BEGIN")
    ? Buffer.from(trimmed).toString("base64")
    : trimmed.replace(/\s/g, "");
  const body = base64.match(/.{1,64}/g)?.join("\n");
  return body ? `-----BEGIN CERTIFICATE-----\n${body}\n-----END CERTIFICATE-----` : null;
}

async function sha1Bytes(input: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-1", input);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

type ZipSourceFile = { name: string; content: Uint8Array };
type ZipFileEntry = ZipSourceFile & { localHeaderOffset: number; crc: number };

function createStoredZip(sourceFiles: ZipSourceFile[]): Uint8Array {
  const chunks: Uint8Array[] = [];
  const encoder = new TextEncoder();
  const files: ZipFileEntry[] = [];

  for (const sourceFile of sourceFiles) {
    const nameBytes = encoder.encode(sourceFile.name);
    const localHeaderOffset = byteLength(chunks);
    const crc = crc32(sourceFile.content);
    const header = new Uint8Array(30);
    const dv = new DataView(header.buffer);
    dv.setUint32(0, 0x04034b50, true);
    dv.setUint16(4, 20, true);
    dv.setUint16(6, 0, true);
    dv.setUint16(8, 0, true);
    dv.setUint16(10, 0, true);
    dv.setUint16(12, 0, true);
    dv.setUint32(14, crc, true);
    dv.setUint32(18, sourceFile.content.length, true);
    dv.setUint32(22, sourceFile.content.length, true);
    dv.setUint16(26, nameBytes.length, true);
    dv.setUint16(28, 0, true);
    chunks.push(header, nameBytes, sourceFile.content);
    files.push({ ...sourceFile, localHeaderOffset, crc });
  }

  const centralDirectoryOffset = byteLength(chunks);
  for (const file of files) {
    const nameBytes = encoder.encode(file.name);
    const centralDirectory = new Uint8Array(46);
    const dv = new DataView(centralDirectory.buffer);
    dv.setUint32(0, 0x02014b50, true);
    dv.setUint16(4, 20, true);
    dv.setUint16(6, 20, true);
    dv.setUint16(8, 0, true);
    dv.setUint16(10, 0, true);
    dv.setUint16(12, 0, true);
    dv.setUint16(14, 0, true);
    dv.setUint32(16, file.crc, true);
    dv.setUint32(20, file.content.length, true);
    dv.setUint32(24, file.content.length, true);
    dv.setUint16(28, nameBytes.length, true);
    dv.setUint16(30, 0, true);
    dv.setUint16(32, 0, true);
    dv.setUint16(34, 0, true);
    dv.setUint16(36, 0, true);
    dv.setUint32(38, 0, true);
    dv.setUint32(42, file.localHeaderOffset, true);
    chunks.push(centralDirectory, nameBytes);
  }

  const centralDirectorySize = byteLength(chunks) - centralDirectoryOffset;
  const eocd = new Uint8Array(22);
  const dv = new DataView(eocd.buffer);
  dv.setUint32(0, 0x06054b50, true);
  dv.setUint16(4, 0, true);
  dv.setUint16(6, 0, true);
  dv.setUint16(8, files.length, true);
  dv.setUint16(10, files.length, true);
  dv.setUint32(12, centralDirectorySize, true);
  dv.setUint32(16, centralDirectoryOffset, true);
  dv.setUint16(20, 0, true);
  chunks.push(eocd);

  const result = new Uint8Array(byteLength(chunks));
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.length;
  }
  return result;
}

function byteLength(chunks: Uint8Array[]): number {
  return chunks.reduce((sum, chunk) => sum + chunk.length, 0);
}

function base64ToBytes(value: string): Uint8Array {
  return Uint8Array.from(Buffer.from(value, "base64"));
}

// 1x1 PNG used as the required Wallet pass icon assets. The visible pass design is driven by pass.json.
const PASS_ICON_PNG_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGkBgWCFwAAAABJRU5ErkJggg==";

// CRC32 implementation for ZIP format
function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

// ── Email Sending ──────────────────────────────────────────────

async function sendBookingConfirmationEmail(
  env: Env,
  booking: { customer_email: string; customer_name: string; cruise_name: string; cruise_date: string; cruise_time: string; id: string; adults: number; children: number },
): Promise<void> {
  if (!env.RESEND_API_KEY) {
    console.warn("[email] RESEND_API_KEY not set — skipping confirmation email");
    return;
  }

  const formattedDate = new Date(booking.cruise_date).toLocaleDateString("en-GB", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

  const passengerSummary = [
    booking.adults > 0 ? `${booking.adults} adult${booking.adults === 1 ? "" : "s"}` : null,
    booking.children > 0 ? `${booking.children} child${booking.children === 1 ? "" : "ren"}` : null,
  ].filter(Boolean).join(", ");

  const fromEmail = env.RESEND_FROM_EMAIL?.trim() || "bookings@puffincruises.com";

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `Puffin Cruises <${fromEmail}>`,
        to: [booking.customer_email],
        subject: `Booking Confirmed — ${booking.cruise_name}`,
        html: `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:40px 16px;font-family:-apple-system,BlinkMacSystemFont,'SF Pro',system-ui,sans-serif;background:#0B2A4A;color:#fff;text-align:center">
<div style="max-width:440px;margin:0 auto;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.15);border-radius:24px;padding:36px 24px">
<p style="font-size:48px;margin:0 0 12px">🐧</p>
<h1 style="font-size:26px;margin:0 0 8px">You're booked!</h1>
<p style="margin:0 0 6px;opacity:.85;font-size:15px">Reference: <strong>${booking.id.slice(0, 8).toUpperCase()}</strong></p>
<hr style="border:none;border-top:1px solid rgba(255,255,255,0.2);margin:20px 0">
<p style="margin:0 0 4px;font-size:18px;font-weight:700">${booking.cruise_name}</p>
<p style="margin:0 0 4px;opacity:.85">${formattedDate} at ${booking.cruise_time}</p>
<p style="margin:0 0 2px;opacity:.85">${passengerSummary}</p>
<hr style="border:none;border-top:1px solid rgba(255,255,255,0.2);margin:20px 0">
<p style="margin:0 0 4px;opacity:.85"><strong>${booking.customer_name}</strong></p>
<p style="margin:0;opacity:.75;font-size:13px">Open the Puffin Cruises app to view your QR boarding pass or add it to Apple Wallet.</p>
<p style="margin:20px 0 0;opacity:.65;font-size:13px">Amble Harbour, Northumberland</p>
</div></body></html>`,
      }),
    });
    if (!res.ok) {
      const body = await res.text();
      console.error("[email] resend failed", res.status, body);
    } else {
      console.log("[email] confirmation sent to", booking.customer_email);
    }
  } catch (err) {
    console.error("[email] send error", err);
  }
}

// ── Push notifications ──────────────────────────────────────────

const EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send";

type StoredPushToken = { token: string; platform: string; email?: string; createdAt: string };
type ReminderLogEntry = { bookingId: string; type: string; sentAt: string };
type ReminderType = "day_before" | "morning_of" | "hour_before" | "20min_before";

async function getPushTokens(env: Env): Promise<{ tokens: StoredPushToken[]; raw: Record<string, unknown> }> {
  const configRes = await supa(env, `/app_config?key=eq.push_tokens&select=value`, { method: "GET" });
  if (!configRes.ok) {
    const errText = await configRes.text().catch(() => "");
    console.error("[push] getPushTokens supabase read failed", configRes.status, errText.slice(0, 500));
    return { tokens: [], raw: {} };
  }
  const rows = (await configRes.json()) as { value: unknown }[];
  console.log("[push] getPushTokens rows", rows.length, "raw value type", typeof rows[0]?.value);

  if (rows.length === 0) {
    console.log("[push] no push_tokens row in app_config — no device has registered yet");
    return { tokens: [], raw: {} };
  }

  const value = rows[0]?.value;

  // Tolerate both shapes: a legacy raw array, or the object { tokens: [...] }.
  if (Array.isArray(value)) {
    console.log("[push] found legacy array format with", value.length, "tokens");
    // Return raw as empty so callers reconstruct the object shape
    return { tokens: value as StoredPushToken[], raw: {} };
  }
  const raw = (value ?? {}) as Record<string, unknown>;
  const tokens: StoredPushToken[] = Array.isArray(raw?.tokens) ? (raw.tokens as StoredPushToken[]) : [];
  console.log("[push] getPushTokens returning", tokens.length, "tokens");
  return { tokens, raw };
}

async function putPushTokens(env: Env, value: Record<string, unknown>): Promise<void> {
  // Use upsert via POST with Prefer: resolution=merge-duplicates so it
  // won't fail when the row already exists (unlike plain POST).
  const res = await supa(env, `/app_config`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({ key: "push_tokens", value }),
  });
  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    console.error("[push] putPushTokens failed", res.status, errText.slice(0, 500));
  }
}

async function handleNotify(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { title: string; body: string };

  const { tokens, raw } = await getPushTokens(env);

  if (tokens.length === 0) {
    return json({ sent: 0, message: "No registered devices" });
  }

  let sent = 0;
  let failed = 0;

  const messages = tokens.map((t) => ({
    to: t.token,
    title: body.title,
    body: body.body,
    sound: "default" as const,
  }));

  for (const msg of messages) {
    try {
      const res = await fetch(EXPO_PUSH_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(msg),
      });
      if (res.ok) sent++;
      else failed++;
    } catch {
      failed++;
    }
  }

  await supa(env, `/notifications`, {
    method: "POST",
    body: JSON.stringify({
      title: body.title,
      body: body.body,
      sent_at: new Date().toISOString(),
      recipient_count: sent,
    }),
  });

  // Only persist lastNotifiedAt if we have tokens so we don't corrupt the row
  if (tokens.length > 0) {
    await putPushTokens(env, { ...raw, tokens, lastNotifiedAt: new Date().toISOString() });
  }
  console.log("[push] notify result — sent:", sent, "failed:", failed, "total tokens:", tokens.length);
  return json({ sent, failed, totalTokens: tokens.length });
}

// ── Device linking ──────────────────────────────────────────────

async function handleLinkDevice(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { token: string; email: string; platform: string };
  if (!body.token || !body.email) {
    return json({ error: "missing token or email" }, { status: 400 });
  }

  const normalizedEmail = body.email.trim().toLowerCase();
  const { tokens, raw } = await getPushTokens(env);

  // Update existing token or add new one
  const filtered = tokens.filter((t) => t.token !== body.token);
  filtered.push({
    token: body.token,
    platform: body.platform ?? "unknown",
    email: normalizedEmail,
    createdAt: new Date().toISOString(),
  });

  const trimmed = filtered.slice(-500);
  await putPushTokens(env, { ...raw, tokens: trimmed });

  console.log("[link-device] linked token to", normalizedEmail);
  return json({ ok: true, email: normalizedEmail });
}

// ── Trip reminder cron ──────────────────────────────────────────

const REMINDER_CONFIG: { type: ReminderType; label: string; offsetMs: number; title: string }[] = [
  {
    type: "day_before",
    label: "Day before",
    offsetMs: -24 * 60 * 60 * 1000, // 24h before — but we adjust to 10am
    title: "Your Puffin Cruise is tomorrow! 🐧",
  },
  {
    type: "morning_of",
    label: "Morning of",
    offsetMs: -6 * 60 * 60 * 1000, // approx 8am-ish, but we calculate properly
    title: "Today's the day! 🌊",
  },
  {
    type: "hour_before",
    label: "1 hour before",
    offsetMs: -60 * 60 * 1000,
    title: "⏰ Your cruise is in 1 hour!",
  },
  {
    type: "20min_before",
    label: "20 minutes before",
    offsetMs: -20 * 60 * 1000,
    title: "🚢 Boarding now — 20 minutes!",
  },
];

function parseCruiseDateTime(dateStr: string, timeStr: string): Date | null {
  // dateStr: "2026-05-29", timeStr: "14:30"
  const d = new Date(`${dateStr}T${timeStr}:00Z`);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Calculate the ideal send time for a reminder type given the cruise datetime.
 * "day_before" fires at 10:00 the day before.
 * "morning_of" fires at 08:00 on the day of the cruise.
 * "hour_before" fires exactly 1 hour before departure.
 * "20min_before" fires exactly 20 minutes before departure.
 */
function reminderTargetTime(cruiseTime: Date, type: ReminderType): Date {
  const target = new Date(cruiseTime);
  switch (type) {
    case "day_before": {
      target.setDate(target.getDate() - 1);
      target.setHours(10, 0, 0, 0);
      break;
    }
    case "morning_of": {
      target.setHours(8, 0, 0, 0);
      break;
    }
    case "hour_before": {
      target.setHours(target.getHours() - 1);
      break;
    }
    case "20min_before": {
      target.setMinutes(target.getMinutes() - 20);
      break;
    }
  }
  return target;
}

function reminderBody(type: ReminderType, cruiseName: string, cruiseTime: string, cruiseDate: string): string {
  const formattedDate = new Date(cruiseDate).toLocaleDateString("en-GB", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });

  switch (type) {
    case "day_before":
      return `${cruiseName} departs tomorrow at ${cruiseTime}. Check the app for your boarding pass and arrival guide. See you at Amble Harbour! 🐧`;
    case "morning_of":
      return `${cruiseName} departs today at ${cruiseTime} from Amble Harbour. Your QR boarding pass is ready in the app. Fair winds! ⛵️`;
    case "hour_before":
      return `1 hour to go! Head to Amble Harbour now for ${cruiseName}. Show your QR pass from the Tickets tab for boarding.`;
    case "20min_before":
      return `Boarding is open! ${cruiseName} departs in 20 minutes. Have your QR pass ready at Amble Harbour. Enjoy the puffins! 🐧`;
  }
}

async function getReminderLogs(env: Env): Promise<ReminderLogEntry[]> {
  const configRes = await supa(env, `/app_config?key=eq.reminder_logs&select=value`, { method: "GET" });
  if (!configRes.ok) return [];
  const rows = (await configRes.json()) as { value: unknown }[];
  const val = rows[0]?.value;
  return Array.isArray(val) ? (val as ReminderLogEntry[]) : [];
}

async function logReminder(env: Env, bookingId: string, type: ReminderType): Promise<void> {
  const existing = await getReminderLogs(env);
  existing.push({ bookingId, type, sentAt: new Date().toISOString() });
  // Keep last 2000 entries
  const trimmed = existing.slice(-2000);
  await supa(env, `/app_config`, {
    method: "POST",
    body: JSON.stringify({ key: "reminder_logs", value: trimmed }),
  });
}

async function handleTripReminders(request: Request, env: Env): Promise<Response> {
  const now = new Date();
  const thirtyMinutesFromNow = new Date(now.getTime() + 30 * 60 * 1000);

  // Fetch paid bookings within the next 2 days
  const fromDate = new Date();
  fromDate.setDate(fromDate.getDate() - 1); // include yesterday for day-before-reminders that may have been missed
  const toDate = new Date();
  toDate.setDate(toDate.getDate() + 3);

  const fromStr = fromDate.toISOString().slice(0, 10);
  const toStr = toDate.toISOString().slice(0, 10);

  const bookingsRes = await supa(
    env,
    `/bookings?status=eq.paid&cruise_date=gte.${fromStr}&cruise_date=lte.${toStr}&select=id,customer_email,customer_name,cruise_name,cruise_date,cruise_time&order=cruise_date.asc`,
    { method: "GET" },
  );

  if (!bookingsRes.ok) {
    console.error("[reminders] failed to fetch bookings", bookingsRes.status);
    return json({ error: "failed to fetch bookings" }, { status: 500 });
  }

  const bookings = (await bookingsRes.json()) as {
    id: string;
    customer_email: string;
    customer_name: string;
    cruise_name: string;
    cruise_date: string;
    cruise_time: string;
  }[];

  const { tokens } = await getPushTokens(env);
  const reminderLogs = await getReminderLogs(env);
  const sentSet = new Set(reminderLogs.map((l) => `${l.bookingId}|${l.type}`));

  console.log("[reminders] found", tokens.length, "push tokens, checking", bookings.length, "paid bookings");

  let sent = 0;
  let skipped = 0;
  let noLinkedDevice = 0;
  const results: string[] = [];

  for (const booking of bookings) {
    const cruiseDateTime = parseCruiseDateTime(booking.cruise_date, booking.cruise_time);
    if (!cruiseDateTime) continue;
    if (cruiseDateTime < now) continue; // already sailed

    const normalizedEmail = booking.customer_email.trim().toLowerCase();
    const deviceTokens = tokens
      .filter((t) => t.email?.toLowerCase() === normalizedEmail)
      .map((t) => t.token);

    if (deviceTokens.length === 0) {
      noLinkedDevice++;
      continue;
    }

    for (const cfg of REMINDER_CONFIG) {
      const targetTime = reminderTargetTime(cruiseDateTime, cfg.type);

      // Only fire if the target time is within the last 30 minutes and not already sent
      const targetStart = new Date(targetTime.getTime() - 30 * 60 * 1000);
      const isDue = now >= targetStart && now <= thirtyMinutesFromNow;
      const alreadySent = sentSet.has(`${booking.id}|${cfg.type}`);

      if (!isDue || alreadySent) continue;

      const body = reminderBody(cfg.type, booking.cruise_name, booking.cruise_time, booking.cruise_date);

      let pushSuccess = 0;
      for (const token of deviceTokens) {
        try {
          const pushRes = await fetch(EXPO_PUSH_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ to: token, title: cfg.title, body, sound: "default" }),
          });
          if (pushRes.ok) pushSuccess++;
          else {
            const errBody = await pushRes.text();
            console.error("[reminders] push failed", token.slice(0, 12) + "...", pushRes.status, errBody.slice(0, 200));
          }
        } catch (err) {
          console.error("[reminders] push error", err);
        }
      }

      if (pushSuccess > 0) {
        await logReminder(env, booking.id, cfg.type);
        sentSet.add(`${booking.id}|${cfg.type}`);
        sent++;
      }

      results.push(`${booking.id.slice(0, 8)} ${cfg.type}: ${pushSuccess}/${deviceTokens.length} delivered`);
    }
  }

  console.log(`[reminders] done — ${sent} sent, ${noLinkedDevice} bookings without linked devices, ${results.length} checks`);
  return json({ sent, noLinkedDevice, now: now.toISOString(), results: results.slice(-20) });
}

type CheckoutBody = {
  cruiseId: string;
  cruiseName: string;
  date: string;
  time: string;
  adults: number;
  children: number;
  customerName: string;
  customerEmail: string;
  customerPhone: string;
};

async function handleCheckout(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as CheckoutBody;

  // Look up prices from app_config to keep them server-authoritative.
  const configRes = await supa(env, `/app_config?key=eq.schedule&select=value`, { method: "GET" });
  if (!configRes.ok) return json({ error: "config_unavailable" }, { status: 500 });
  const configRows = (await configRes.json()) as { value: { cruises: { id: string; name: string; adultPrice: number; childPrice: number }[] } }[];
  const cruise = configRows[0]?.value.cruises.find((c) => c.id === body.cruiseId);
  if (!cruise) return json({ error: "unknown_cruise" }, { status: 400 });

  const adults = Math.max(0, Math.floor(body.adults));
  const children = Math.max(0, Math.floor(body.children));
  if (adults + children === 0) return json({ error: "no_passengers" }, { status: 400 });

  const amountPence = adults * cruise.adultPrice * 100 + children * cruise.childPrice * 100;

  const bookingInsert = await supa(env, `/bookings`, {
    method: "POST",
    body: JSON.stringify({
      cruise_id: body.cruiseId,
      cruise_name: cruise.name,
      cruise_date: body.date,
      cruise_time: body.time,
      adults,
      children,
      customer_name: body.customerName,
      customer_email: body.customerEmail,
      customer_phone: body.customerPhone,
      amount_total: amountPence,
      currency: "gbp",
      status: "pending",
    }),
  });
  if (!bookingInsert.ok) {
    const text = await bookingInsert.text();
    console.error("booking insert failed", bookingInsert.status, text);
    return json({ error: "booking_failed", status: bookingInsert.status, detail: text }, { status: 500 });
  }
  const booking = ((await bookingInsert.json()) as { id: string }[])[0];

  const origin = new URL(request.url).origin;
  const params: Record<string, string | number> = {
    mode: "payment",
    success_url: `${origin}/booking/success?booking=${booking.id}&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/booking/cancel?booking=${booking.id}`,
    customer_email: body.customerEmail,
    "metadata[booking_id]": booking.id,
    "line_items[0][quantity]": 1,
    "line_items[0][price_data][currency]": "gbp",
    "line_items[0][price_data][unit_amount]": amountPence,
    "line_items[0][price_data][product_data][name]": `${cruise.name} — ${body.date} ${body.time}`,
    "line_items[0][price_data][product_data][description]": `${adults} adult${adults === 1 ? "" : "s"}, ${children} child${children === 1 ? "" : "ren"}`,
  };

  const session = (await stripeFetch(env, "/checkout/sessions", params)) as { id: string; url: string };

  await supa(env, `/bookings?id=eq.${booking.id}`, {
    method: "PATCH",
    body: JSON.stringify({ stripe_session_id: session.id }),
  });

  return json({ url: session.url, bookingId: booking.id });
}

async function handleWebhook(request: Request, env: Env): Promise<Response> {
  const signature = request.headers.get("Stripe-Signature");
  if (!signature) return new Response("missing signature", { status: 400 });
  if (!env.STRIPE_WEBHOOK_SECRET) return new Response("server misconfigured", { status: 500 });

  const payload = await request.text();
  const ok = await verifyStripeSignature(payload, signature, env.STRIPE_WEBHOOK_SECRET);
  if (!ok) return new Response("invalid signature", { status: 400 });

  const event = JSON.parse(payload) as { type: string; data: { object: Record<string, unknown> } };
  if (event.type === "checkout.session.completed") {
    const session = event.data.object as { id: string; metadata?: { booking_id?: string }; payment_intent?: string };
    const bookingId = session.metadata?.booking_id;
    if (bookingId) {
      await supa(env, `/bookings?id=eq.${bookingId}`, {
        method: "PATCH",
        body: JSON.stringify({
          status: "paid",
          stripe_payment_intent: session.payment_intent ?? null,
        }),
      });
      console.log("booking marked paid", bookingId);

      // Send confirmation email
      const bookingRes = await supa(env, `/bookings?id=eq.${encodeURIComponent(bookingId)}&select=id,customer_email,customer_name,cruise_name,cruise_date,cruise_time,adults,children`, { method: "GET" });
      if (bookingRes.ok) {
        const bookings = (await bookingRes.json()) as { id: string; customer_email: string; customer_name: string; cruise_name: string; cruise_date: string; cruise_time: string; adults: number; children: number }[];
        if (bookings[0]) {
          await sendBookingConfirmationEmail(env, bookings[0]);
        }
      }
    }
  }
  return new Response(null, { status: 200 });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

    if (url.pathname === "/ping") return json({ ok: true, now: new Date().toISOString() });

    if (url.pathname === "/checkout" && request.method === "POST") {
      try {
        return await handleCheckout(request, env);
      } catch (err) {
        console.error("checkout error", err);
        if (err instanceof StripeApiError) {
          return json({ error: "stripe_error", status: err.status, detail: err.detail }, { status: 500 });
        }
        const message = err instanceof Error ? err.message : String(err);
        return json({ error: "checkout_error", message }, { status: 500 });
      }
    }

    if (url.pathname === "/webhooks/stripe" && request.method === "POST") {
      return handleWebhook(request, env);
    }

    if (url.pathname === "/notify" && request.method === "POST") {
      try {
        return await handleNotify(request, env);
      } catch (err) {
        console.error("notify error", err);
        return json({ error: "notify_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/link-device" && request.method === "POST") {
      try {
        return await handleLinkDevice(request, env);
      } catch (err) {
        console.error("link-device error", err);
        return json({ error: "link_device_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/debug/push-status" && request.method === "GET") {
      try {
        const { tokens } = await getPushTokens(env);
        const reminderLogs = await getReminderLogs(env);
        // Count bookings that would be checked by cron
        const fromDate = new Date();
        fromDate.setDate(fromDate.getDate() - 1);
        const toDate = new Date();
        toDate.setDate(toDate.getDate() + 3);
        const bookingsRes = await supa(
          env,
          `/bookings?status=eq.paid&cruise_date=gte.${fromDate.toISOString().slice(0, 10)}&cruise_date=lte.${toDate.toISOString().slice(0, 10)}&select=id,customer_email`,
          { method: "GET" },
        );
        let paidBookingCount = 0;
        const emailsWithTokens = new Set(tokens.filter((t) => t.email).map((t) => t.email?.toLowerCase()));
        let linkableBookings = 0;
        if (bookingsRes.ok) {
          const bookings = (await bookingsRes.json()) as { customer_email: string }[];
          paidBookingCount = bookings.length;
          linkableBookings = bookings.filter((b) => emailsWithTokens.has(b.customer_email.trim().toLowerCase())).length;
        }
        return json({
          totalTokens: tokens.length,
          tokensWithEmail: tokens.filter((t) => t.email).length,
          recentReminderLogs: reminderLogs.slice(-20),
          paidBookingsInWindow: paidBookingCount,
          bookingsWithLinkedDevice: linkableBookings,
        });
      } catch (err) {
        console.error("debug push-status error", err);
        return json({ error: "debug_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/cron/trip-reminders" && (request.method === "GET" || request.method === "POST")) {
      try {
        return await handleTripReminders(request, env);
      } catch (err) {
        console.error("trip-reminders error", err);
        return json({ error: "trip_reminders_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/wallet/pass" && request.method === "GET") {
      try {
        return await handleWalletPass(request, env);
      } catch (err) {
        console.error("wallet pass error", err);
        return json({ error: "wallet_pass_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/booking/success") {
      const bookingId = url.searchParams.get("booking") ?? "";
      const sessionId = url.searchParams.get("session_id") ?? "";
      if (bookingId && sessionId) {
        try {
          await confirmPaidBookingFromCheckoutSession(env, bookingId, sessionId);
        } catch (err) {
          console.error("success confirmation error", err);
        }
      }
      return new Response(successHtml(bookingId), {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }
    if (url.pathname === "/booking/cancel") {
      return new Response(cancelHtml(), {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    return json({ ok: true });
  },
} satisfies ExportedHandler<Env>;

async function confirmPaidBookingFromCheckoutSession(env: Env, bookingId: string, sessionId: string): Promise<void> {
  const session = (await stripeGet(env, `/checkout/sessions/${encodeURIComponent(sessionId)}`)) as {
    id: string;
    payment_status?: string;
    metadata?: { booking_id?: string };
    payment_intent?: string | null;
  };

  if (session.payment_status !== "paid" || session.metadata?.booking_id !== bookingId) {
    console.warn("success confirmation ignored", { bookingId, sessionId: session.id, paymentStatus: session.payment_status });
    return;
  }

  await supa(env, `/bookings?id=eq.${encodeURIComponent(bookingId)}`, {
    method: "PATCH",
    body: JSON.stringify({
      status: "paid",
      stripe_payment_intent: session.payment_intent ?? null,
    }),
  });
}

function shell(title: string, inner: string): string {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'SF Pro',system-ui,sans-serif;background:linear-gradient(180deg,#0B2A4A,#0E4D7A);color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;text-align:center}.card{max-width:420px;background:rgba(255,255,255,0.08);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,0.15);border-radius:24px;padding:32px}h1{margin:0 0 12px;font-size:28px}p{margin:0 0 8px;opacity:.85;line-height:1.5}.emoji{font-size:56px;margin-bottom:8px}</style></head><body><div class="card">${inner}</div></body></html>`;
}
function successHtml(id: string): string {
  return shell("Booking Confirmed", `<div class="emoji">🐧</div><h1>You're booked!</h1><p>Reference: <strong>${id.slice(0, 8)}</strong></p><p>We've sent a confirmation to your email. See you at Amble Harbour!</p>`);
}
function cancelHtml(): string {
  return shell("Booking Cancelled", `<div class="emoji">⛵️</div><h1>Booking cancelled</h1><p>No payment was taken. You can try again from the app anytime.</p>`);
}
