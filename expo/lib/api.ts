const BASE = process.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL ?? "";

export function walletPassUrl(bookingId: string): string {
  return `${BASE}/wallet/pass?bookingId=${encodeURIComponent(bookingId)}`;
}

export type CreateCheckoutBody = {
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

export type CreateCheckoutResponse = {
  url: string;
  bookingId: string;
};

export async function createCheckout(body: CreateCheckoutBody): Promise<CreateCheckoutResponse> {
  const res = await fetch(`${BASE}/checkout`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Checkout failed: ${res.status} ${text}`);
  }
  return (await res.json()) as CreateCheckoutResponse;
}
