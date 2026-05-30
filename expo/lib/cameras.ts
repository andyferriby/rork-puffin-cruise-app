import { supabase } from "@/lib/supabase";

export type CameraVideo = {
  id: string; // YouTube video ID (e.g. "dQw4w9WgXcQ")
  label: string; // e.g. "Puffin Colony"
};

export type CamerasConfig = {
  videos: CameraVideo[];
};

const DEFAULT_CAMERAS: CamerasConfig = {
  videos: [
    { id: "", label: "Camera 1" },
    { id: "", label: "Camera 2" },
    { id: "", label: "Camera 3" },
    { id: "", label: "Camera 4" },
  ],
};

export async function fetchCameras(): Promise<CamerasConfig> {
  const { data, error } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "cameras")
    .maybeSingle();
  if (error) {
    console.error("[cameras] fetch error", error.message);
    return DEFAULT_CAMERAS;
  }
  if (!data?.value) return DEFAULT_CAMERAS;
  const val = data.value as Record<string, unknown>;
  if (!Array.isArray(val.videos)) return DEFAULT_CAMERAS;
  return val as unknown as CamerasConfig;
}
