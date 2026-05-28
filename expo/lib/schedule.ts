import { supabase } from "@/lib/supabase";

/**
 * Cruise type defined remotely. Owners edit this JSON in Supabase
 * without having to update the app.
 */
export type Cruise = {
  id: string;
  name: string;
  duration: string;
  description: string;
  adultPrice: number;
  childPrice: number;
  capacity: number;
  emoji: string;
};

export type DaySchedule = {
  date: string; // YYYY-MM-DD
  weather?: string;
  times: { time: string; cruiseId: string; note?: string }[];
};

export type ScheduleConfig = {
  version: number;
  notice?: string;
  contactPhone: string;
  bookingOffice: string;
  cruises: Cruise[];
  days: DaySchedule[];
};

export const DEFAULT_CONFIG: ScheduleConfig = {
  version: 1,
  notice: "All sailing times are subject to tide and sea conditions.",
  contactPhone: "07752 861914",
  bookingOffice: "Amble Harbour Village",
  cruises: [
    {
      id: "puffin-1h",
      name: "1 Hour Puffin Cruise",
      duration: "1 hour",
      description: "Get up close with the puffins of Coquet Island.",
      adultPrice: 18,
      childPrice: 10,
      capacity: 30,
      emoji: "🐧",
    },
    {
      id: "seal",
      name: "Seal Watching Cruise",
      duration: "1.5 hours",
      description: "Cruise the coast to spot our local grey seal colony.",
      adultPrice: 22,
      childPrice: 12,
      capacity: 30,
      emoji: "🦭",
    },
  ],
  days: [
    {
      date: new Date().toISOString().slice(0, 10),
      weather: "Sunny, light breeze",
      times: [
        { time: "10:30", cruiseId: "puffin-1h" },
        { time: "11:30", cruiseId: "puffin-1h" },
        { time: "12:30", cruiseId: "puffin-1h" },
        { time: "13:30", cruiseId: "seal" },
        { time: "14:30", cruiseId: "puffin-1h" },
      ],
    },
  ],
};

export async function fetchSchedule(): Promise<ScheduleConfig> {
  const { data, error } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "schedule")
    .maybeSingle();
  if (error) {
    console.error("[schedule] fetch error", error.message);
    return DEFAULT_CONFIG;
  }
  if (!data?.value) return DEFAULT_CONFIG;
  return data.value as ScheduleConfig;
}
