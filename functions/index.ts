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
  const manifest: Record<string, string> = {
    "pass.json": await sha1(passJson),
  };

  // Build the .pkpass zip in memory
  const chunks: Uint8Array[] = [];
  const encoder = new TextEncoder();

  function addFile(name: string, content: Uint8Array) {
    const nameBytes = encoder.encode(name);
    const header = new Uint8Array(30 + nameBytes.length);
    const dv = new DataView(header.buffer);
    dv.setUint32(0, 0x04034b50, true); // local file header signature
    dv.setUint16(8, 0, true); // compression: none
    dv.setUint32(14, crc32(content), true);
    dv.setUint32(18, content.length, true);
    dv.setUint32(22, content.length, true);
    dv.setUint16(26, nameBytes.length, true);
    dv.setUint16(28, 0, true); // extra field length
    chunks.push(header);
    chunks.push(nameBytes);
    chunks.push(content);

    return { name, header, content };
  }

  const files: { name: string; header: Uint8Array; content: Uint8Array }[] = [];
  files.push(addFile("pass.json", encoder.encode(passJson)));

  const manifestJson = JSON.stringify(manifest);
  files.push(addFile("manifest.json", encoder.encode(manifestJson)));

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
  files.push(addFile("signature", signature));

  // Central directory
  let cdOffset = 0;
  for (const f of files) {
    cdOffset += 30 + encoder.encode(f.name).length + f.content.length;
  }

  for (const f of files) {
    const nameBytes = encoder.encode(f.name);
    const cd = new Uint8Array(46 + nameBytes.length);
    const dv = new DataView(cd.buffer);
    dv.setUint32(0, 0x02014b50, true);
    dv.setUint16(8, 0, true);
    dv.setUint16(10, 0, true);
    dv.setUint32(12, crc32(f.content), true);
    dv.setUint32(16, f.content.length, true);
    dv.setUint32(20, f.content.length, true);
    dv.setUint16(24, nameBytes.length, true);
    dv.setUint16(28, 0, true);
    dv.setUint16(30, 0, true);
    dv.setUint16(32, 0, true);
    dv.setUint32(34, 0, true);
    dv.setUint32(38, 0, true);
    dv.setUint32(42, 0, true);
    chunks.push(cd);
    chunks.push(nameBytes);
  }

  // End of central directory
  const totalCdSize = files.reduce((sum, f) => sum + 46 + encoder.encode(f.name).length, 0);
  const eocd = new Uint8Array(22);
  const dv2 = new DataView(eocd.buffer);
  dv2.setUint32(0, 0x06054b50, true);
  dv2.setUint16(8, files.length, true);
  dv2.setUint16(10, files.length, true);
  dv2.setUint32(12, totalCdSize, true);
  dv2.setUint32(16, cdOffset, true);
  chunks.push(eocd);

  const totalLength = chunks.reduce((s, c) => s + c.length, 0);
  const result = new Uint8Array(totalLength);
  let offset = 0;
  for (const c of chunks) {
    result.set(c, offset);
    offset += c.length;
  }

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

async function sha1(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-1", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

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

async function handleNotify(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { title: string; body: string };

  // Fetch push tokens from app_config
  const configRes = await supa(env, `/app_config?key=eq.push_tokens&select=value`, { method: "GET" });
  if (!configRes.ok) return json({ error: "config_unavailable" }, { status: 500 });
  const rows = (await configRes.json()) as { value: unknown }[];
  const pushData = rows[0]?.value as { tokens?: { token: string; platform: string; createdAt: string }[] } | undefined;
  const tokens = pushData?.tokens ?? [];

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

  // Expo push API accepts chunks; send individually for reliability
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

  // Store notification in the notifications table
  await supa(env, `/notifications`, {
    method: "POST",
    body: JSON.stringify({
      title: body.title,
      body: body.body,
      sent_at: new Date().toISOString(),
      recipient_count: sent,
    }),
  });

  // Update last-notified timestamp
  await supa(env, `/app_config`, {
    method: "POST",
    body: JSON.stringify({
      key: "push_tokens",
      value: { ...pushData, lastNotifiedAt: new Date().toISOString() },
    }),
  });

  return json({ sent, failed });
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
    success_url: `${origin}/booking/success?booking=${booking.id}`,
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

    if (url.pathname === "/wallet/pass" && request.method === "GET") {
      try {
        return await handleWalletPass(request, env);
      } catch (err) {
        console.error("wallet pass error", err);
        return json({ error: "wallet_pass_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/booking/success") {
      return new Response(successHtml(url.searchParams.get("booking") ?? ""), {
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

function shell(title: string, inner: string): string {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'SF Pro',system-ui,sans-serif;background:linear-gradient(180deg,#0B2A4A,#0E4D7A);color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;text-align:center}.card{max-width:420px;background:rgba(255,255,255,0.08);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,0.15);border-radius:24px;padding:32px}h1{margin:0 0 12px;font-size:28px}p{margin:0 0 8px;opacity:.85;line-height:1.5}.emoji{font-size:56px;margin-bottom:8px}</style></head><body><div class="card">${inner}</div></body></html>`;
}
function successHtml(id: string): string {
  return shell("Booking Confirmed", `<div class="emoji">🐧</div><h1>You're booked!</h1><p>Reference: <strong>${id.slice(0, 8)}</strong></p><p>We've sent a confirmation to your email. See you at Amble Harbour!</p>`);
}
function cancelHtml(): string {
  return shell("Booking Cancelled", `<div class="emoji">⛵️</div><h1>Booking cancelled</h1><p>No payment was taken. You can try again from the app anytime.</p>`);
}
