import AsyncStorage from "@react-native-async-storage/async-storage";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as Haptics from "expo-haptics";
import * as Location from "expo-location";
import {
  AlertCircle,
  Bell,
  Calendar,
  Key,
  Lock,
  LogOut,
  MapPin,
  Minus,
  Plus,
  Radio,
  Save,
  ShipWheel,
  Trash2,
} from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";
import { fetchSchedule, type Cruise, type DaySchedule, type ScheduleConfig } from "@/lib/schedule";
import { fetchBoatLocation, saveBoatLocation, stopBoatTracking, type BoatLocation } from "@/lib/boatTracker";
import { supabase } from "@/lib/supabase";

const ADMIN_PIN_KEY = "@puffin_admin_pin";

const BASE = process.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL ?? "";

export default function AdminScreen() {
  const insets = useSafeAreaInsets();
  const qc = useQueryClient();

  const [authenticated, setAuthenticated] = useState<boolean>(false);
  const [pin, setPin] = useState<string>("");
  const [pinError, setPinError] = useState<string | null>(null);
  const [settingPin, setSettingPin] = useState<boolean>(false);

  // Check if PIN exists on mount
  useEffect(() => {
    AsyncStorage.getItem(ADMIN_PIN_KEY).then((saved) => {
      if (!saved) setSettingPin(true);
    });
  }, []);

  const handlePinSubmit = useCallback(async () => {
    const saved = await AsyncStorage.getItem(ADMIN_PIN_KEY);
    if (!saved) {
      // First time — set PIN
      if (pin.length < 4) {
        setPinError("PIN must be at least 4 digits");
        return;
      }
      await AsyncStorage.setItem(ADMIN_PIN_KEY, pin);
      setSettingPin(false);
      setAuthenticated(true);
      setPin("");
      return;
    }
    if (pin === saved) {
      setAuthenticated(true);
      setPin("");
      setPinError(null);
    } else {
      setPinError("Wrong PIN. Try again.");
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  }, [pin]);

  const handleLogout = useCallback(() => {
    setAuthenticated(false);
  }, []);

  if (!authenticated) {
    return (
      <View style={[styles.authRoot, { paddingTop: insets.top }]}>
        <View style={styles.authCard}>
          <View style={styles.authIcon}>
            <Lock size={32} color={theme.sea} />
          </View>
          <Text style={styles.authTitle}>
            {settingPin ? "Create Admin PIN" : "Admin Access"}
          </Text>
          <Text style={styles.authSub}>
            {settingPin
              ? "Set a PIN to protect schedule editing."
              : "Enter your admin PIN to continue."}
          </Text>

          <TextInput
            value={pin}
            onChangeText={(t) => {
              setPin(t.replace(/[^0-9]/g, ""));
              setPinError(null);
            }}
            placeholder="PIN"
            placeholderTextColor={theme.textMuted}
            keyboardType="number-pad"
            secureTextEntry
            maxLength={6}
            style={styles.pinInput}
            onSubmitEditing={handlePinSubmit}
            autoFocus
          />

          {pinError && (
            <View style={styles.pinErrorRow}>
              <AlertCircle size={14} color={theme.coral} />
              <Text style={styles.pinErrorText}>{pinError}</Text>
            </View>
          )}

          <Pressable
            onPress={handlePinSubmit}
            disabled={pin.length < 4}
            style={({ pressed }) => [
              styles.pinBtn,
              pin.length < 4 && { opacity: 0.4 },
              pressed && { opacity: 0.8 },
            ]}
          >
            <Key size={16} color={theme.white} />
            <Text style={styles.pinBtnText}>
              {settingPin ? "Set PIN" : "Unlock"}
            </Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return <AdminEditor insets={insets} onLogout={handleLogout} qc={qc} />;
}

// ── Editor ──────────────────────────────────────────────────────────

function AdminEditor({
  insets,
  onLogout,
  qc,
}: {
  insets: { top: number; bottom: number };
  onLogout: () => void;
  qc: ReturnType<typeof useQueryClient>;
}) {
  const { data: schedule, isLoading } = useQuery({
    queryKey: ["schedule"],
    queryFn: fetchSchedule,
  });

  const { data: boatLocation } = useQuery({
    queryKey: ["boat-location"],
    queryFn: fetchBoatLocation,
    refetchInterval: 15000,
  });

  const [edited, setEdited] = useState<ScheduleConfig | null>(null);
  const [hasChanges, setHasChanges] = useState<boolean>(false);
  const [saving, setSaving] = useState<boolean>(false);
  const [notifying, setNotifying] = useState<boolean>(false);
  const [isTrackingBoat, setIsTrackingBoat] = useState<boolean>(false);
  const [trackingError, setTrackingError] = useState<string | null>(null);

  useEffect(() => {
    if (schedule && !edited) {
      setEdited(JSON.parse(JSON.stringify(schedule)));
    }
  }, [schedule, edited]);

  const updateCruise = useCallback(
    (idx: number, patch: Partial<Cruise>) => {
      if (!edited) return;
      const cruises = [...edited.cruises];
      cruises[idx] = { ...cruises[idx], ...patch };
      setEdited({ ...edited, cruises });
      setHasChanges(true);
    },
    [edited],
  );

  const updateDay = useCallback(
    (idx: number, patch: Partial<DaySchedule>) => {
      if (!edited) return;
      const days = [...edited.days];
      days[idx] = { ...days[idx], ...patch };
      setEdited({ ...edited, days });
      setHasChanges(true);
    },
    [edited],
  );

  const addTime = useCallback(
    (dayIdx: number) => {
      if (!edited) return;
      const days = [...edited.days];
      const defaultCruise = edited.cruises[0]?.id ?? "";
      days[dayIdx] = {
        ...days[dayIdx],
        times: [...days[dayIdx].times, { time: "10:00", cruiseId: defaultCruise }],
      };
      setEdited({ ...edited, days });
      setHasChanges(true);
    },
    [edited],
  );

  const removeTime = useCallback(
    (dayIdx: number, timeIdx: number) => {
      if (!edited) return;
      const days = [...edited.days];
      days[dayIdx] = {
        ...days[dayIdx],
        times: days[dayIdx].times.filter((_, i) => i !== timeIdx),
      };
      setEdited({ ...edited, days });
      setHasChanges(true);
    },
    [edited],
  );

  const updateTime = useCallback(
    (dayIdx: number, timeIdx: number, patch: { time?: string; cruiseId?: string; note?: string }) => {
      if (!edited) return;
      const days = [...edited.days];
      const times = [...days[dayIdx].times];
      times[timeIdx] = { ...times[timeIdx], ...patch };
      days[dayIdx] = { ...days[dayIdx], times };
      setEdited({ ...edited, days });
      setHasChanges(true);
    },
    [edited],
  );

  const addDay = useCallback(() => {
    if (!edited) return;
    const lastDate = edited.days[edited.days.length - 1]?.date;
    const next = lastDate
      ? new Date(new Date(lastDate).getTime() + 86400000).toISOString().slice(0, 10)
      : new Date().toISOString().slice(0, 10);
    setEdited({
      ...edited,
      days: [...edited.days, { date: next, times: [] }],
    });
    setHasChanges(true);
  }, [edited]);

  const removeDay = useCallback(
    (idx: number) => {
      if (!edited) return;
      setEdited({ ...edited, days: edited.days.filter((_, i) => i !== idx) });
      setHasChanges(true);
    },
    [edited],
  );

  const updateMeta = useCallback(
    (key: "notice" | "contactPhone" | "bookingOffice", value: string) => {
      if (!edited) return;
      setEdited({ ...edited, [key]: value });
      setHasChanges(true);
    },
    [edited],
  );

  const handleSave = useCallback(async () => {
    if (!edited) return;
    setSaving(true);
    try {
      const { error } = await supabase
        .from("app_config")
        .upsert(
          { key: "schedule", value: edited as unknown as Record<string, unknown>, updated_at: new Date().toISOString() },
          { onConflict: "key" },
        );
      if (error) throw error;
      qc.invalidateQueries({ queryKey: ["schedule"] });
      setHasChanges(false);
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert("Saved", "Schedule updated. Tap 'Notify' to alert customers.");
    } catch (err) {
      console.error("[admin] save", err);
      Alert.alert("Save failed", err instanceof Error ? err.message : "Please try again.");
    } finally {
      setSaving(false);
    }
  }, [edited, qc]);

  const publishCurrentBoatLocation = useCallback(async () => {
    setTrackingError(null);
    const permission = await Location.requestForegroundPermissionsAsync();
    if (permission.status !== "granted") {
      setTrackingError("Location permission is needed before crew tracking can start.");
      return;
    }

    const position = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.High,
    });
    const nextLocation: BoatLocation = {
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      accuracy: position.coords.accuracy ?? null,
      heading: position.coords.heading ?? null,
      speed: position.coords.speed ?? null,
      updatedAt: new Date().toISOString(),
      isTracking: true,
    };
    await saveBoatLocation(nextLocation);
    qc.invalidateQueries({ queryKey: ["boat-location"] });
  }, [qc]);

  const handleStartTracking = useCallback(async () => {
    setIsTrackingBoat(true);
    try {
      await publishCurrentBoatLocation();
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch (err) {
      console.error("[admin] start boat tracking", err);
      setTrackingError("Could not start tracking. Check location permission and signal.");
      setIsTrackingBoat(false);
    }
  }, [publishCurrentBoatLocation]);

  const handleSendBoatPing = useCallback(async () => {
    try {
      await publishCurrentBoatLocation();
    } catch (err) {
      console.error("[admin] boat ping", err);
      setTrackingError("Could not send the latest boat position.");
    }
  }, [publishCurrentBoatLocation]);

  const handleStopTracking = useCallback(async () => {
    setIsTrackingBoat(false);
    try {
      await stopBoatTracking(boatLocation ?? null);
      qc.invalidateQueries({ queryKey: ["boat-location"] });
    } catch (err) {
      console.error("[admin] stop boat tracking", err);
      setTrackingError("Could not stop tracking. Please try again.");
    }
  }, [boatLocation, qc]);

  useEffect(() => {
    if (!isTrackingBoat) return;
    void publishCurrentBoatLocation();
    const interval = setInterval(() => {
      void publishCurrentBoatLocation();
    }, 20000);
    return () => clearInterval(interval);
  }, [isTrackingBoat, publishCurrentBoatLocation]);

  const handleNotify = useCallback(async () => {
    setNotifying(true);
    try {
      const res = await fetch(`${BASE}/notify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: "New sailing times posted! 🐧",
          body: "Check the app for the latest Puffin Cruises schedule.",
        }),
      });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(txt);
      }
      Alert.alert("Sent", `Push notifications have been dispatched.`);
    } catch (err) {
      console.error("[admin] notify", err);
      Alert.alert("Notify failed", err instanceof Error ? err.message : "Please try again.");
    } finally {
      setNotifying(false);
    }
  }, []);

  if (isLoading || !edited) {
    return (
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center", backgroundColor: theme.bg }}>
        <ActivityIndicator color={theme.sea} />
      </View>
    );
  }

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: theme.bg }}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <View style={[styles.editorHeader, { paddingTop: insets.top + 16 }]}>
        <View style={{ flex: 1 }}>
          <Text style={styles.editorTitle}>Schedule Editor</Text>
          <Text style={styles.editorSub}>Changes are live on save.</Text>
        </View>
        <Pressable onPress={onLogout} style={styles.logoutBtn}>
          <LogOut size={16} color={theme.coral} />
        </Pressable>
      </View>

      <ScrollView
        contentContainerStyle={{ paddingBottom: insets.bottom + 32 }}
        keyboardShouldPersistTaps="handled"
      >
        <Section title="Crew Boat Tracker">
          <View style={styles.trackerCard}>
            <View style={styles.trackerHeader}>
              <View style={[styles.trackerIcon, isTrackingBoat && styles.trackerIconLive]}>
                {isTrackingBoat ? <Radio size={20} color={theme.white} /> : <ShipWheel size={20} color={theme.sea} />}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.trackerTitle}>{isTrackingBoat ? "Live tracking is on" : "Boat tracking is off"}</Text>
                <Text style={styles.trackerSub}>
                  {boatLocation?.updatedAt
                    ? `Last update ${new Date(boatLocation.updatedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
                    : "Start when the crew phone is on board."}
                </Text>
              </View>
            </View>
            {trackingError && <Text style={styles.trackerError}>{trackingError}</Text>}
            <View style={styles.trackerActions}>
              <Pressable
                onPress={isTrackingBoat ? handleStopTracking : handleStartTracking}
                style={[styles.trackerButton, isTrackingBoat ? styles.stopTrackerButton : styles.startTrackerButton]}
              >
                <Text style={[styles.trackerButtonText, isTrackingBoat && styles.stopTrackerText]}>
                  {isTrackingBoat ? "Stop Tracking" : "Start Boat Tracking"}
                </Text>
              </Pressable>
              <Pressable onPress={handleSendBoatPing} style={styles.pingButton}>
                <MapPin size={15} color={theme.sea} />
                <Text style={styles.pingButtonText}>Send Ping</Text>
              </Pressable>
            </View>
            <Text style={styles.trackerNote}>
              Keep this screen open during the trip for live updates every 20 seconds.
            </Text>
          </View>
        </Section>

        {/* Meta */}
        <Section title="Notice">
          <TextInput
            value={edited.notice ?? ""}
            onChangeText={(v) => updateMeta("notice", v)}
            placeholder="e.g. Sailings subject to weather conditions"
            placeholderTextColor={theme.textMuted}
            style={styles.field}
          />
        </Section>
        <Section title="Contact Phone">
          <TextInput
            value={edited.contactPhone}
            onChangeText={(v) => updateMeta("contactPhone", v)}
            placeholder="07752 861914"
            placeholderTextColor={theme.textMuted}
            keyboardType="phone-pad"
            style={styles.field}
          />
        </Section>
        <Section title="Booking Office">
          <TextInput
            value={edited.bookingOffice}
            onChangeText={(v) => updateMeta("bookingOffice", v)}
            placeholder="Amble Harbour Village"
            placeholderTextColor={theme.textMuted}
            style={styles.field}
          />
        </Section>

        {/* Cruises */}
        <Section title="Cruise Types">
          {edited.cruises.map((c, i) => (
            <View key={c.id} style={styles.cruiseCard}>
              <TextInput
                value={c.name}
                onChangeText={(v) => updateCruise(i, { name: v })}
                placeholder="Cruise name"
                placeholderTextColor={theme.textMuted}
                style={styles.inlineField}
              />
              <View style={{ flexDirection: "row", gap: 8 }}>
                <TextInput
                  value={c.emoji}
                  onChangeText={(v) => updateCruise(i, { emoji: v })}
                  style={[styles.inlineField, { flex: 0, width: 52, textAlign: "center" }]}
                  maxLength={2}
                />
                <TextInput
                  value={c.duration}
                  onChangeText={(v) => updateCruise(i, { duration: v })}
                  placeholder="Duration"
                  placeholderTextColor={theme.textMuted}
                  style={[styles.inlineField, { flex: 1 }]}
                />
              </View>
              <View style={{ flexDirection: "row", gap: 8 }}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.hintLabel}>Adult £</Text>
                  <TextInput
                    value={String(c.adultPrice)}
                    onChangeText={(v) => updateCruise(i, { adultPrice: Number(v) || 0 })}
                    keyboardType="numeric"
                    style={styles.inlineField}
                  />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.hintLabel}>Child £</Text>
                  <TextInput
                    value={String(c.childPrice)}
                    onChangeText={(v) => updateCruise(i, { childPrice: Number(v) || 0 })}
                    keyboardType="numeric"
                    style={styles.inlineField}
                  />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.hintLabel}>Capacity</Text>
                  <TextInput
                    value={String(c.capacity)}
                    onChangeText={(v) => updateCruise(i, { capacity: Number(v) || 0 })}
                    keyboardType="numeric"
                    style={styles.inlineField}
                  />
                </View>
              </View>
              <TextInput
                value={c.description}
                onChangeText={(v) => updateCruise(i, { description: v })}
                placeholder="Short description"
                placeholderTextColor={theme.textMuted}
                multiline
                style={[styles.inlineField, { minHeight: 60 }]}
              />
            </View>
          ))}
        </Section>

        {/* Days */}
        <Section title="Sailing Days">
          {edited.days.map((d, dayIdx) => (
            <View key={d.date} style={styles.dayCard}>
              <View style={styles.dayCardHeader}>
                <TextInput
                  value={d.date}
                  onChangeText={(v) => updateDay(dayIdx, { date: v })}
                  placeholder="YYYY-MM-DD"
                  placeholderTextColor={theme.textMuted}
                  style={[styles.inlineField, { flex: 1 }]}
                />
                <TextInput
                  value={d.weather ?? ""}
                  onChangeText={(v) => updateDay(dayIdx, { weather: v || undefined })}
                  placeholder="Weather"
                  placeholderTextColor={theme.textMuted}
                  style={[styles.inlineField, { flex: 0, width: 140 }]}
                />
                <Pressable onPress={() => removeDay(dayIdx)} hitSlop={8}>
                  <Trash2 size={16} color={theme.coral} />
                </Pressable>
              </View>

              {d.times.map((t, timeIdx) => (
                <View key={`${t.time}-${timeIdx}`} style={styles.timeRow}>
                  <TextInput
                    value={t.time}
                    onChangeText={(v) => updateTime(dayIdx, timeIdx, { time: v })}
                    placeholder="HH:MM"
                    placeholderTextColor={theme.textMuted}
                    style={[styles.inlineField, { flex: 0, width: 80 }]}
                  />
                  <View style={{ flex: 1, position: "relative" }}>
                    <TextInput
                      value={t.cruiseId}
                      onChangeText={(v) => updateTime(dayIdx, timeIdx, { cruiseId: v })}
                      placeholder="Cruise ID"
                      placeholderTextColor={theme.textMuted}
                      style={styles.inlineField}
                    />
                    <Text style={styles.hintBelow}>
                      IDs: {edited.cruises.map((c) => `${c.emoji}${c.id}`).join(", ")}
                    </Text>
                  </View>
                  <TextInput
                    value={t.note ?? ""}
                    onChangeText={(v) => updateTime(dayIdx, timeIdx, { note: v || undefined })}
                    placeholder="Note"
                    placeholderTextColor={theme.textMuted}
                    style={[styles.inlineField, { flex: 0, width: 80 }]}
                  />
                  <Pressable onPress={() => removeTime(dayIdx, timeIdx)} hitSlop={8}>
                    <Minus size={16} color={theme.coral} />
                  </Pressable>
                </View>
              ))}

              <Pressable onPress={() => addTime(dayIdx)} style={styles.addBtn}>
                <Plus size={14} color={theme.sea} />
                <Text style={styles.addBtnText}>Add time</Text>
              </Pressable>
            </View>
          ))}

          <Pressable onPress={addDay} style={styles.addDayBtn}>
            <Calendar size={16} color={theme.sea} />
            <Text style={styles.addDayBtnText}>Add day</Text>
          </Pressable>
        </Section>
      </ScrollView>

      {/* Sticky footer */}
      <View style={[styles.footer, { paddingBottom: insets.bottom + 12 }]}>
        <Pressable
          onPress={handleNotify}
          disabled={notifying}
          style={({ pressed }) => [
            styles.footerBtn,
            styles.notifyBtn,
            (pressed || notifying) && { opacity: 0.8 },
          ]}
        >
          {notifying ? (
            <ActivityIndicator color={theme.sea} size="small" />
          ) : (
            <Bell size={18} color={theme.sea} />
          )}
          <Text style={styles.notifyBtnText}>
            {notifying ? "Sending..." : "Notify"}
          </Text>
        </Pressable>

        <Pressable
          onPress={handleSave}
          disabled={!hasChanges || saving}
          style={({ pressed }) => [
            styles.footerBtn,
            styles.saveBtn,
            (!hasChanges || saving) && { opacity: 0.5 },
            pressed && { opacity: 0.85 },
          ]}
        >
          {saving ? (
            <ActivityIndicator color={theme.white} />
          ) : (
            <Save size={18} color={theme.white} />
          )}
          <Text style={styles.saveBtnText}>{saving ? "Saving..." : "Save Schedule"}</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

// ── Shared bits ─────────────────────────────────────────────────────

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <View style={{ gap: 10 }}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  // Auth
  authRoot: {
    flex: 1,
    backgroundColor: theme.bg,
    justifyContent: "center",
    alignItems: "center",
    padding: 24,
  },
  authCard: {
    width: "100%",
    maxWidth: 340,
    alignItems: "center",
    gap: 14,
  },
  authIcon: {
    width: 64,
    height: 64,
    borderRadius: 20,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 8,
  },
  authTitle: { fontSize: 22, fontWeight: "800", color: theme.text },
  authSub: { fontSize: 14, color: theme.textMuted, textAlign: "center" },
  pinInput: {
    width: "100%",
    backgroundColor: theme.white,
    borderWidth: 1.5,
    borderColor: theme.border,
    borderRadius: 14,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 24,
    fontWeight: "700",
    textAlign: "center",
    letterSpacing: 8,
    color: theme.text,
    marginTop: 4,
  },
  pinErrorRow: { flexDirection: "row", alignItems: "center", gap: 6 },
  pinErrorText: { color: theme.coral, fontSize: 13, fontWeight: "600" },
  pinBtn: {
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    backgroundColor: theme.sea,
    paddingVertical: 14,
    borderRadius: 14,
    marginTop: 4,
  },
  pinBtnText: { color: theme.white, fontWeight: "700", fontSize: 15 },

  // Editor
  editorHeader: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 20,
    paddingBottom: 12,
    gap: 12,
  },
  editorTitle: { fontSize: 28, fontWeight: "800", color: theme.text, letterSpacing: -0.3 },
  editorSub: { fontSize: 13, color: theme.textMuted, marginTop: 2 },
  logoutBtn: {
    padding: 10,
    backgroundColor: theme.foam,
    borderRadius: 12,
  },
  section: { paddingHorizontal: 16, marginTop: 20 },
  sectionTitle: {
    fontSize: 13,
    fontWeight: "700",
    color: theme.sea,
    letterSpacing: 0.8,
    textTransform: "uppercase",
    marginBottom: 10,
  },

  field: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    color: theme.text,
  },
  inlineField: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 14,
    color: theme.text,
  },
  hintLabel: { fontSize: 10, color: theme.textMuted, marginBottom: 4, fontWeight: "600" },
  hintBelow: { fontSize: 10, color: theme.textMuted, marginTop: 4 },

  cruiseCard: {
    backgroundColor: theme.card,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 14,
    padding: 12,
    gap: 8,
  },

  dayCard: {
    backgroundColor: theme.card,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 14,
    padding: 12,
    gap: 8,
  },
  dayCardHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  timeRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 6,
  },

  addBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    paddingVertical: 10,
    borderWidth: 1.5,
    borderColor: theme.sea,
    borderRadius: 10,
    borderStyle: "dashed",
    marginTop: 4,
  },
  addBtnText: { color: theme.sea, fontWeight: "600", fontSize: 13 },
  addDayBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 14,
    borderWidth: 1.5,
    borderColor: theme.sea,
    borderRadius: 12,
    borderStyle: "dashed",
    marginTop: 8,
  },
  addDayBtnText: { color: theme.sea, fontWeight: "700", fontSize: 14 },
  trackerCard: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 18,
    padding: 14,
    gap: 12,
  },
  trackerHeader: { flexDirection: "row", alignItems: "center", gap: 12 },
  trackerIcon: {
    width: 44,
    height: 44,
    borderRadius: 16,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
  },
  trackerIconLive: { backgroundColor: theme.coral },
  trackerTitle: { fontSize: 16, fontWeight: "800", color: theme.text },
  trackerSub: { marginTop: 2, color: theme.textMuted, fontSize: 13 },
  trackerError: { color: theme.coral, fontSize: 13, fontWeight: "700" },
  trackerActions: { flexDirection: "row", gap: 10 },
  trackerButton: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 12,
    borderRadius: 13,
  },
  startTrackerButton: { backgroundColor: theme.sea },
  stopTrackerButton: { backgroundColor: theme.foam, borderWidth: 1.5, borderColor: theme.coral },
  trackerButtonText: { color: theme.white, fontWeight: "800", fontSize: 14 },
  stopTrackerText: { color: theme.coral },
  pingButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    paddingHorizontal: 14,
    borderRadius: 13,
    backgroundColor: theme.foam,
  },
  pingButtonText: { color: theme.sea, fontWeight: "800", fontSize: 13 },
  trackerNote: { color: theme.textMuted, fontSize: 12, lineHeight: 17 },

  footer: {
    flexDirection: "row",
    gap: 10,
    paddingHorizontal: 16,
    paddingTop: 12,
    backgroundColor: theme.white,
    borderTopWidth: 1,
    borderTopColor: theme.border,
  },
  footerBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 14,
    borderRadius: 14,
  },
  notifyBtn: {
    flex: 0,
    paddingHorizontal: 20,
    backgroundColor: theme.foam,
    borderWidth: 1.5,
    borderColor: theme.sea,
  },
  notifyBtnText: { color: theme.sea, fontWeight: "700", fontSize: 14 },
  saveBtn: {
    flex: 1,
    backgroundColor: theme.sea,
  },
  saveBtnText: { color: theme.white, fontWeight: "800", fontSize: 15 },
});
