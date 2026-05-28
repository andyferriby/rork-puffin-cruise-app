import { supabase } from "@/lib/supabase";

export type BoatLocation = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  heading: number | null;
  speed: number | null;
  updatedAt: string;
  isTracking: boolean;
};

const BOAT_LOCATION_KEY = "boat_location";

const isBoatLocation = (value: unknown): value is BoatLocation => {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<BoatLocation>;
  return (
    typeof candidate.latitude === "number" &&
    typeof candidate.longitude === "number" &&
    typeof candidate.updatedAt === "string" &&
    typeof candidate.isTracking === "boolean"
  );
};

export async function fetchBoatLocation(): Promise<BoatLocation | null> {
  const { data, error } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", BOAT_LOCATION_KEY)
    .maybeSingle();

  if (error) throw error;
  return isBoatLocation(data?.value) ? data.value : null;
}

export async function saveBoatLocation(location: BoatLocation): Promise<void> {
  const { error } = await supabase.from("app_config").upsert(
    {
      key: BOAT_LOCATION_KEY,
      value: location as unknown as Record<string, unknown>,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "key" },
  );

  if (error) throw error;
}

export async function stopBoatTracking(lastLocation: BoatLocation | null): Promise<void> {
  const stoppedLocation: BoatLocation = {
    latitude: lastLocation?.latitude ?? 55.3338,
    longitude: lastLocation?.longitude ?? -1.5803,
    accuracy: lastLocation?.accuracy ?? null,
    heading: lastLocation?.heading ?? null,
    speed: lastLocation?.speed ?? null,
    updatedAt: new Date().toISOString(),
    isTracking: false,
  };

  await saveBoatLocation(stoppedLocation);
}
