import { supabase } from "@/lib/supabase";

export type WooProduct = {
  id: number;
  name: string;
  slug: string;
  permalink: string;
  price: string;
  regular_price: string;
  sale_price: string;
  on_sale: boolean;
  stock_status: "instock" | "outofstock" | "onbackorder";
  images: { src: string; alt: string }[];
  short_description: string;
};

export type WooConfig = {
  storeUrl: string;
  consumerKey: string;
  consumerSecret: string;
};

const BASE = process.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL ?? "";

/**
 * Fetches WooCommerce products via the backend proxy (keeps keys server-side).
 * Falls back to empty array if WooCommerce is not configured.
 */
export async function fetchProducts(): Promise<WooProduct[]> {
  const { data, error } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "woocommerce")
    .maybeSingle();

  if (error || !data?.value) {
    console.log("[shop] WooCommerce not configured");
    return [];
  }

  const config = data.value as Record<string, unknown>;
  const storeUrl = typeof config.storeUrl === "string" ? config.storeUrl.trim() : "";
  if (!storeUrl) return [];

  try {
    const res = await fetch(`${BASE}/woocommerce/products`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        storeUrl,
        consumerKey: typeof config.consumerKey === "string" ? config.consumerKey : "",
        consumerSecret: typeof config.consumerSecret === "string" ? config.consumerSecret : "",
      }),
    });
    if (!res.ok) {
      console.error("[shop] proxy error", res.status);
      return [];
    }
    const body = (await res.json()) as { products?: WooProduct[] };
    return body.products ?? [];
  } catch (err) {
    console.error("[shop] fetch error", err);
    return [];
  }
}
