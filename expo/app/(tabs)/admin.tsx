import AsyncStorage from "@react-native-async-storage/async-storage";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import DateTimePicker, { DateTimePickerEvent } from "@react-native-community/datetimepicker";
import { BarcodeScanningResult, CameraView, useCameraPermissions } from "expo-camera";
import * as Haptics from "expo-haptics";
import * as Location from "expo-location";
import {
  AlertCircle,
  Anchor,
  Bell,
  Calendar,
  CheckCircle,
  Key,
  Lock,
  LogOut,
  MapPin,
  Minus,
  Plus,
  QrCode,
  Radio,
  Save,
  ShipWheel,
  Ticket,
  Trash2,
  Users,
  X,
} from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
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

type ScannedBooking = {
  id: string;
  customer_name: string;
  cruise_name: string;
  cruise_date: string;
  cruise_time: string;
  adults: number;
  children: number;
  status: string;
};

type BoardedBooking = {
  id: string;
  customer_name: string;
  cruise_name: string;
  cruise_date: string;
  cruise_time: string;
  adults: number;
  children: number;
  status: string;
};

async function fetchBoardedBookings(): Promise<BoardedBooking[]> {
  const { data, error } = await supabase
    .from("bookings")
    .select("id, customer_name, cruise_name, cruise_date, cruise_time, adults, children, status")
    .eq("status", "boarded")
    .order("cruise_date", { ascending: false })
    .limit(100);
  if (error) {
    console.error("[admin] fetch boarded", error.message);
    return [];
  }
  return (data ?? []) as BoardedBooking[];
}

async function handleBarcodeScan(
  data: string,
  callbacks: {
    setScannedBooking: (b: ScannedBooking | null) => void;
    setScannerError: (e: string | null) => void;
  },
): Promise<void> {
  const { setScannedBooking, setScannerError } = callbacks;
  try {
    const { data: bookings, error } = await supabase
      .from("bookings")
      .select("id, customer_name, cruise_name, cruise_date, cruise_time, adults, children, status")
      .eq("id", data.trim())
      .limit(1);

    if (error) throw error;
    if (!bookings || bookings.length === 0) {
      setScannerError("No booking found for this QR code.");
      return;
    }
    const booking = bookings[0] as ScannedBooking;
    setScannedBooking(booking);
    setScannerError(null);
    if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  } catch (err) {
    console.error("[admin] scan lookup", err);
    setScannerError("Could not look up booking. Check your connection.");
  }
}

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
  const [isTrackingBoat, setIsTrackingBoat] = useState<boolean>(false);
  const [trackingError, setTrackingError] = useState<string | null>(null);
  const [pickerDayIdx, setPickerDayIdx] = useState<number | null>(null);

  // Scanner state
  const [scannerOpen, setScannerOpen] = useState<boolean>(false);
  const [scannedBooking, setScannedBooking] = useState<ScannedBooking | null>(null);
  const [scannerError, setScannerError] = useState<string | null>(null);
  const [markingBoarded, setMarkingBoarded] = useState<boolean>(false);
  const [cameraPerm, requestCameraPerm] = useCameraPermissions();
  const scanLockRef = useRef<boolean>(false);

  // On-board list
  const {
    data: boardedBookings = [],
    refetch: refetchBoarded,
  } = useQuery({
    queryKey: ["boarded-bookings"],
    queryFn: fetchBoardedBookings,
    staleTime: 10_000,
  });

  const boardedTotals = useMemo(() => {
    let adults = 0;
    let children = 0;
    for (const b of boardedBookings) {
      adults += b.adults;
      children += b.children;
    }
    return { adults, children };
  }, [boardedBookings]);

  const handleBarcodeScanned = useCallback(
    (result: BarcodeScanningResult) => {
      // Guard with a ref so rapid camera frames don't fire dozens of
      // overlapping lookups (which caused repeated haptics / no settled result).
      if (scanLockRef.current) return;
      scanLockRef.current = true;
      if (Platform.OS !== "web") Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      handleBarcodeScan(result.data, {
        setScannedBooking,
        setScannerError,
      });
    },
    [],
  );

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
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, "0");
    const dd = String(today.getDate()).padStart(2, "0");
    const newIdx = edited.days.length;
    setEdited({
      ...edited,
      days: [...edited.days, { date: `${yyyy}-${mm}-${dd}`, times: [] }],
    });
    setHasChanges(true);
    setPickerDayIdx(newIdx);
  }, [edited]);

  const removeDay = useCallback(
    (idx: number) => {
      if (!edited) return;
      setEdited({ ...edited, days: edited.days.filter((_, i) => i !== idx) });
      setHasChanges(true);
      setPickerDayIdx(null);
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

        {/* On Board List */}
        <Section title="Currently On Board">
          <View style={styles.onboardCard}>
            {boardedBookings.length === 0 ? (
              <View style={styles.onboardEmpty}>
                <Anchor size={28} color={theme.textMuted} />
                <Text style={styles.onboardEmptyTitle}>No one on board yet</Text>
                <Text style={styles.onboardEmptySub}>
                  Scan and mark tickets as boarded to build the passenger manifest.
                </Text>
              </View>
            ) : (
              <>
                {boardedBookings.map((b, i) => (
                  <View
                    key={b.id}
                    style={[
                      styles.onboardRow,
                      i < boardedBookings.length - 1 && styles.onboardRowBorder,
                    ]}
                  >
                    <View style={styles.onboardRowLeft}>
                      <Text style={styles.onboardName} numberOfLines={1}>
                        {b.customer_name}
                      </Text>
                      <Text style={styles.onboardCruise} numberOfLines={1}>
                        {b.cruise_name} · {b.cruise_time}
                      </Text>
                    </View>
                    <View style={styles.onboardRowRight}>
                      <View style={styles.onboardCountBadge}>
                        <Users size={11} color={theme.sea} />
                        <Text style={styles.onboardCountText}>
                          {b.adults + b.children}
                        </Text>
                      </View>
                      <Text style={styles.onboardBreakdown}>
                        {b.adults}A / {b.children}C
                      </Text>
                    </View>
                  </View>
                ))}

                {/* Totals */}
                <View style={styles.onboardDivider} />
                <View style={styles.onboardTotals}>
                  <View style={styles.onboardTotalItem}>
                    <Text style={styles.onboardTotalLabel}>Total on board</Text>
                    <Text style={styles.onboardTotalValue}>
                      {boardedTotals.adults + boardedTotals.children}
                    </Text>
                  </View>
                  <View style={styles.onboardTotalSplit}>
                    <View style={styles.onboardTotalChip}>
                      <Text style={styles.onboardTotalChipLabel}>Adults</Text>
                      <Text style={styles.onboardTotalChipValue}>
                        {boardedTotals.adults}
                      </Text>
                    </View>
                    <View style={[styles.onboardTotalChip, styles.onboardTotalChipAlt]}>
                      <Text style={styles.onboardTotalChipLabel}>Children</Text>
                      <Text style={styles.onboardTotalChipValue}>
                        {boardedTotals.children}
                      </Text>
                    </View>
                  </View>
                </View>
              </>
            )}
          </View>
        </Section>

        {/* Meta */}
        {/* Ticket Scanner */}
        <Section title="Ticket Scanner">
          <View style={styles.scannerCard}>
            {!scannerOpen ? (
              <Pressable
                onPress={async () => {
                  if (!cameraPerm) return;
                  if (!cameraPerm.granted) {
                    const result = await requestCameraPerm();
                    if (!result.granted) {
                      setScannerError("Camera permission is needed to scan tickets.");
                      return;
                    }
                  }
                  setScannerError(null);
                  setScannedBooking(null);
                  scanLockRef.current = false;
                  setScannerOpen(true);
                }}
                style={[styles.scannerButton, !cameraPerm && { opacity: 0.5 }]}
                disabled={!cameraPerm}
              >
                <QrCode size={20} color={theme.white} />
                <Text style={styles.scannerButtonText}>Open Scanner</Text>
              </Pressable>
            ) : (
              <View style={styles.scannerActive}>
                <View style={styles.scannerHeader}>
                  <Text style={styles.scannerTitle}>Scan QR Code</Text>
                  <Pressable
                    onPress={() => {
                      setScannerOpen(false);
                      setScannedBooking(null);
                      scanLockRef.current = false;
                      setScannerError(null);
                    }}
                    hitSlop={8}
                  >
                    <X size={20} color={theme.text} />
                  </Pressable>
                </View>
                <View style={styles.cameraWrapper}>
                  <CameraView
                    style={styles.camera}
                    barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
                    onBarcodeScanned={handleBarcodeScanned}
                  />
                  <View style={styles.scannerOverlay}>
                    <View style={styles.scannerFrame} />
                  </View>
                </View>
                <Text style={styles.scannerHint}>Point camera at the QR code on a boarding pass</Text>
              </View>
            )}

            {scannerError && (
              <View style={styles.scannerErrorRow}>
                <AlertCircle size={14} color={theme.coral} />
                <Text style={styles.scannerErrorText}>{scannerError}</Text>
              </View>
            )}

            {scannedBooking && (
              <View style={styles.scannedResult}>
                <View style={styles.scannedStatusRow}>
                  <CheckCircle size={18} color={theme.sea} />
                  <Text style={styles.scannedStatusText}>Booking Found</Text>
                </View>
                <Text style={styles.scannedName}>{scannedBooking.customer_name}</Text>
                <Text style={styles.scannedCruise}>{scannedBooking.cruise_name}</Text>
                <Text style={styles.scannedMeta}>
                  {new Date(scannedBooking.cruise_date).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" })} · {scannedBooking.cruise_time}
                </Text>
                <Text style={styles.scannedMeta}>
                  {scannedBooking.adults} adult{scannedBooking.adults === 1 ? "" : "s"} · {scannedBooking.children} child{scannedBooking.children === 1 ? "" : "ren"}
                </Text>
                <View style={styles.scannedStatusBadge}>
                  <Text style={styles.scannedStatusBadgeText}>{scannedBooking.status.toUpperCase()}</Text>
                </View>

                {scannedBooking.status !== "boarded" && scannedBooking.status === "paid" && (
                  <Pressable
                    onPress={async () => {
                      setMarkingBoarded(true);
                      try {
                        const { error } = await supabase
                          .from("bookings")
                          .update({ status: "boarded" })
                          .eq("id", scannedBooking.id);
                        if (error) throw error;
                        setScannedBooking({ ...scannedBooking, status: "boarded" });
                        refetchBoarded();
                        if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
                      } catch (err) {
                        console.error("[admin] mark boarded", err);
                        Alert.alert("Error", "Could not mark as boarded. Please try again.");
                      } finally {
                        setMarkingBoarded(false);
                      }
                    }}
                    disabled={markingBoarded}
                    style={[styles.boardedButton, markingBoarded && { opacity: 0.6 }]}
                  >
                    {markingBoarded ? (
                      <ActivityIndicator color={theme.white} size="small" />
                    ) : (
                      <CheckCircle size={16} color={theme.white} />
                    )}
                    <Text style={styles.boardedButtonText}>
                      {markingBoarded ? "Marking..." : "Mark as Boarded"}
                    </Text>
                  </Pressable>
                )}

                {scannedBooking.status === "boarded" && (
                  <View style={styles.alreadyBoarded}>
                    <CheckCircle size={16} color={theme.sea} />
                    <Text style={styles.alreadyBoardedText}>Already boarded</Text>
                  </View>
                )}

                {scannedBooking.status === "pending" && (
                  <View style={styles.pendingWarning}>
                    <AlertCircle size={14} color={theme.coral} />
                    <Text style={styles.pendingWarningText}>Payment not yet confirmed. Cannot board until paid.</Text>
                  </View>
                )}

                <Pressable
                  onPress={() => {
                    setScannedBooking(null);
                    setScannerError(null);
                    scanLockRef.current = false;
                  }}
                  style={styles.scanAnother}
                >
                  <Text style={styles.scanAnotherText}>Scan Another</Text>
                </Pressable>
              </View>
            )}
          </View>
        </Section>

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
            <View key={`${d.date}-${dayIdx}`} style={styles.dayCard}>
              <View style={styles.dayCardHeader}>
                <Pressable
                  onPress={() => setPickerDayIdx(pickerDayIdx === dayIdx ? null : dayIdx)}
                  style={styles.dateField}
                >
                  <Calendar size={14} color={theme.sea} />
                  <Text style={styles.dateFieldText}>
                    {(() => {
                      const parts = d.date.split("-");
                      if (parts.length !== 3) return d.date;
                      return `${parts[2]}/${parts[1]}/${parts[0]}`;
                    })()}
                  </Text>
                </Pressable>
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

              {pickerDayIdx === dayIdx && (
                <View style={styles.datePickerWrapper}>
                  <View style={styles.datePickerHeader}>
                    <Text style={styles.datePickerTitle}>Select Date</Text>
                    <Pressable onPress={() => setPickerDayIdx(null)} hitSlop={8}>
                      <X size={16} color={theme.textMuted} />
                    </Pressable>
                  </View>
                  <DateTimePicker
                    value={(() => {
                      const p = d.date.split("-");
                      if (p.length === 3) return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
                      return new Date();
                    })()}
                    mode="date"
                    display={Platform.OS === "ios" ? "inline" : "default"}
                    themeVariant="light"
                    onChange={(event: DateTimePickerEvent, selectedDate?: Date) => {
                      if (Platform.OS === "android") {
                        setPickerDayIdx(null);
                      }
                      if (event.type === "dismissed") {
                        setPickerDayIdx(null);
                        return;
                      }
                      if (selectedDate) {
                        const yyyy = selectedDate.getFullYear();
                        const mm = String(selectedDate.getMonth() + 1).padStart(2, "0");
                        const dd = String(selectedDate.getDate()).padStart(2, "0");
                        updateDay(dayIdx, { date: `${yyyy}-${mm}-${dd}` });
                        if (Platform.OS === "ios") setPickerDayIdx(null);
                      }
                    }}
                  />
                </View>
              )}

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

  // Date picker
  dateField: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    backgroundColor: theme.white,
    borderWidth: 1.5,
    borderColor: theme.sea,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  dateFieldText: {
    fontSize: 14,
    fontWeight: "700",
    color: theme.text,
  },
  datePickerWrapper: {
    backgroundColor: theme.white,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: theme.border,
    overflow: "hidden",
  },
  datePickerHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 14,
    paddingTop: 14,
    paddingBottom: 4,
  },
  datePickerTitle: {
    fontSize: 14,
    fontWeight: "700",
    color: theme.sea,
  },

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
  saveBtn: {
    flex: 1,
    backgroundColor: theme.sea,
  },
  saveBtnText: { color: theme.white, fontWeight: "800", fontSize: 15 },

  // Scanner
  scannerCard: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 18,
    padding: 14,
    gap: 12,
  },
  scannerButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
    backgroundColor: theme.sea,
    paddingVertical: 14,
    borderRadius: 14,
  },
  scannerButtonText: { color: theme.white, fontWeight: "800", fontSize: 15 },
  scannerActive: { gap: 10 },
  scannerHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  scannerTitle: { fontSize: 16, fontWeight: "800", color: theme.text },
  cameraWrapper: {
    height: 220,
    borderRadius: 16,
    overflow: "hidden",
    backgroundColor: "#000",
  },
  camera: { flex: 1 },
  scannerOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
  },
  scannerFrame: {
    width: 160,
    height: 160,
    borderWidth: 2,
    borderColor: "rgba(255,255,255,0.7)",
    borderRadius: 16,
    backgroundColor: "transparent",
  },
  scannerHint: {
    textAlign: "center",
    color: theme.textMuted,
    fontSize: 13,
  },
  scannerErrorRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    backgroundColor: theme.foam,
    padding: 10,
    borderRadius: 10,
  },
  scannerErrorText: { color: theme.coral, fontSize: 13, fontWeight: "600" },
  scannedResult: {
    backgroundColor: theme.foam,
    borderRadius: 14,
    padding: 14,
    gap: 6,
  },
  scannedStatusRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  scannedStatusText: {
    color: theme.sea,
    fontWeight: "800",
    fontSize: 14,
  },
  scannedName: {
    fontSize: 18,
    fontWeight: "800",
    color: theme.text,
    marginTop: 4,
  },
  scannedCruise: {
    fontSize: 15,
    fontWeight: "700",
    color: theme.text,
  },
  scannedMeta: {
    fontSize: 13,
    color: theme.textMuted,
  },
  scannedStatusBadge: {
    alignSelf: "flex-start",
    backgroundColor: theme.white,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    marginTop: 4,
  },
  scannedStatusBadgeText: {
    fontSize: 11,
    fontWeight: "800",
    color: theme.coral,
  },
  boardedButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    backgroundColor: theme.sea,
    paddingVertical: 12,
    borderRadius: 12,
    marginTop: 8,
  },
  boardedButtonText: {
    color: theme.white,
    fontWeight: "800",
    fontSize: 14,
  },
  alreadyBoarded: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    backgroundColor: theme.white,
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 12,
    marginTop: 8,
  },
  alreadyBoardedText: {
    color: theme.sea,
    fontWeight: "700",
    fontSize: 14,
  },
  pendingWarning: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    backgroundColor: "#FFF3F0",
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 12,
    marginTop: 4,
  },
  pendingWarningText: {
    color: theme.coral,
    fontSize: 13,
    fontWeight: "600",
    flex: 1,
  },
  scanAnother: {
    alignItems: "center",
    paddingVertical: 8,
    marginTop: 4,
  },
  scanAnotherText: {
    color: theme.sea,
    fontWeight: "700",
    fontSize: 13,
  },

  // On Board list
  onboardCard: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 18,
    padding: 14,
    gap: 2,
  },
  onboardEmpty: {
    alignItems: "center",
    paddingVertical: 24,
    gap: 8,
  },
  onboardEmptyTitle: {
    fontSize: 15,
    fontWeight: "700",
    color: theme.text,
  },
  onboardEmptySub: {
    fontSize: 13,
    color: theme.textMuted,
    textAlign: "center",
    lineHeight: 18,
  },
  onboardRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 10,
    gap: 10,
  },
  onboardRowBorder: {
    borderBottomWidth: 1,
    borderBottomColor: theme.border,
  },
  onboardRowLeft: {
    flex: 1,
    minWidth: 0,
  },
  onboardName: {
    fontSize: 15,
    fontWeight: "700",
    color: theme.text,
  },
  onboardCruise: {
    fontSize: 12,
    color: theme.textMuted,
    marginTop: 2,
  },
  onboardRowRight: {
    alignItems: "flex-end",
    gap: 2,
  },
  onboardCountBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    backgroundColor: theme.foam,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  onboardCountText: {
    fontSize: 13,
    fontWeight: "800",
    color: theme.sea,
  },
  onboardBreakdown: {
    fontSize: 10,
    fontWeight: "600",
    color: theme.textMuted,
  },
  onboardDivider: {
    height: 1,
    backgroundColor: theme.border,
    marginVertical: 10,
  },
  onboardTotals: {
    gap: 10,
  },
  onboardTotalItem: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  onboardTotalLabel: {
    fontSize: 13,
    fontWeight: "700",
    color: theme.textMuted,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  onboardTotalValue: {
    fontSize: 24,
    fontWeight: "900",
    color: theme.text,
  },
  onboardTotalSplit: {
    flexDirection: "row",
    gap: 8,
  },
  onboardTotalChip: {
    flex: 1,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    backgroundColor: theme.foam,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  onboardTotalChipAlt: {
    backgroundColor: "#FFF3F0",
  },
  onboardTotalChipLabel: {
    fontSize: 13,
    fontWeight: "700",
    color: theme.sea,
  },
  onboardTotalChipValue: {
    fontSize: 18,
    fontWeight: "900",
    color: theme.text,
  },
});
