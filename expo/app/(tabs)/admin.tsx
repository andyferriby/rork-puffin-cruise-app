import AsyncStorage from "@react-native-async-storage/async-storage";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import DateTimePicker, { DateTimePickerEvent } from "@react-native-community/datetimepicker";
import { BarcodeScanningResult, CameraView, useCameraPermissions } from "expo-camera";
import * as Haptics from "expo-haptics";
import { Image } from "expo-image";
import * as Location from "expo-location";
import {
  AlertCircle,
  Anchor,
  Calendar,
  CheckCircle,
  Clock,
  EyeOff,
  Key,
  Lock,
  LogOut,
  MapPin,
  Minus,
  Plus,
  QrCode,
  Radio,
  Save,
  Send,
  ShipWheel,
  ShoppingBag,
  Ticket,
  Trash2,
  Users,
  Video,
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

import { spacing, theme } from "@/constants/theme";
import { fetchSchedule, type Cruise, type DaySchedule, type ScheduleConfig } from "@/lib/schedule";
import { fetchBoatLocation, saveBoatLocation, stopBoatTracking, type BoatLocation } from "@/lib/boatTracker";
import { supabase } from "@/lib/supabase";
import { sendApnsBroadcast } from "@/lib/api";

const ADMIN_PIN_KEY = "@puffin_admin_pin";
const PREPRINTED_TICKET_QR_VALUE = "PUFFIN_SHOP_TICKET_BOARDING";

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

type MembershipRedeemResult = {
  memberId: string;
  email: string;
  active: boolean;
  creditsTotal: number;
  creditsUsed: number;
  creditsRemaining: number;
  expiresAt: string;
  discountPercent: number;
};

type PreprintedBoardingState = {
  count: number;
  lastScanAt: string | null;
};

type PreprintedScanResult = {
  count: number;
  scannedAt: string;
};

function preprintedTicketQrUrl(): string {
  return `https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(PREPRINTED_TICKET_QR_VALUE)}&bgcolor=ffffff&color=0B2A4A`;
}

async function fetchPreprintedBoarding(): Promise<PreprintedBoardingState> {
  const { data, error } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "preprinted_boarding")
    .maybeSingle();
  if (error) {
    console.error("[admin] fetch preprinted boarding", error.message);
    return { count: 0, lastScanAt: null };
  }
  const value = (data?.value ?? {}) as Partial<PreprintedBoardingState>;
  return {
    count: typeof value.count === "number" && Number.isFinite(value.count) ? value.count : 0,
    lastScanAt: typeof value.lastScanAt === "string" ? value.lastScanAt : null,
  };
}

async function savePreprintedBoarding(next: PreprintedBoardingState): Promise<void> {
  const { error } = await supabase
    .from("app_config")
    .upsert(
      { key: "preprinted_boarding", value: next as unknown as Record<string, unknown>, updated_at: new Date().toISOString() },
      { onConflict: "key" },
    );
  if (error) throw error;
}

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
    setMembershipResult: (m: MembershipRedeemResult | null) => void;
    setPreprintedScanResult: (r: PreprintedScanResult | null) => void;
    setScannerError: (e: string | null) => void;
    onPreprintedTicketScanned: () => Promise<PreprintedScanResult>;
  },
): Promise<void> {
  const { setScannedBooking, setMembershipResult, setPreprintedScanResult, setScannerError, onPreprintedTicketScanned } = callbacks;
  const scannedValue = data.trim();
  try {
    setMembershipResult(null);
    setPreprintedScanResult(null);
    if (scannedValue === PREPRINTED_TICKET_QR_VALUE) {
      const result = await onPreprintedTicketScanned();
      setScannedBooking(null);
      setMembershipResult(null);
      setPreprintedScanResult(result);
      setScannerError(null);
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      return;
    }
    if (scannedValue.startsWith("PUFFIN_MEMBER:")) {
      const res = await fetch(`${BASE}/membership/redeem`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId: scannedValue }),
      });
      const body = (await res.json()) as MembershipRedeemResult | { error?: string; record?: MembershipRedeemResult };
      if (!res.ok) {
        const errBody = body as { error?: string; record?: MembershipRedeemResult };
        const errorText = errBody.error === "no_credits_remaining"
          ? "This member has no trip credits remaining."
          : errBody.error === "membership_inactive"
            ? "This membership is inactive or expired."
            : "Membership pass could not be redeemed.";
        setMembershipResult(errBody.record ?? null);
        setScannerError(errorText);
        return;
      }
      setScannedBooking(null);
      setPreprintedScanResult(null);
      setMembershipResult(body as MembershipRedeemResult);
      setScannerError(null);
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      return;
    }

    const { data: bookings, error } = await supabase
      .from("bookings")
      .select("id, customer_name, cruise_name, cruise_date, cruise_time, adults, children, status")
      .eq("id", scannedValue)
      .limit(1);

    if (error) throw error;
    if (!bookings || bookings.length === 0) {
      setScannerError("No booking or membership found for this QR code.");
      return;
    }
    const booking = bookings[0] as ScannedBooking;
    setPreprintedScanResult(null);
    setScannedBooking(booking);
    setScannerError(null);
    if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  } catch (err) {
    console.error("[admin] scan lookup", err);
    setScannerError("Could not process this QR code. Check your connection.");
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
  const trackerHidden = Boolean(boatLocation?.isHidden);

  const [edited, setEdited] = useState<ScheduleConfig | null>(null);
  const [hasChanges, setHasChanges] = useState<boolean>(false);
  const [saving, setSaving] = useState<boolean>(false);
  const [isTrackingBoat, setIsTrackingBoat] = useState<boolean>(false);
  const [trackingError, setTrackingError] = useState<string | null>(null);
  const [pickerDayIdx, setPickerDayIdx] = useState<number | null>(null);
  const [pickerTimeTarget, setPickerTimeTarget] = useState<{ dayIdx: number; timeIdx: number } | null>(null);

  // Scanner state
  const [scannerOpen, setScannerOpen] = useState<boolean>(false);
  const [scannedBooking, setScannedBooking] = useState<ScannedBooking | null>(null);
  const [membershipResult, setMembershipResult] = useState<MembershipRedeemResult | null>(null);
  const [preprintedScanResult, setPreprintedScanResult] = useState<PreprintedScanResult | null>(null);
  const [scannerError, setScannerError] = useState<string | null>(null);
  const [markingBoarded, setMarkingBoarded] = useState<boolean>(false);
  const [adjustingPreprinted, setAdjustingPreprinted] = useState<boolean>(false);
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

  const {
    data: preprintedBoarding = { count: 0, lastScanAt: null },
    refetch: refetchPreprintedBoarding,
  } = useQuery({
    queryKey: ["preprinted-boarding"],
    queryFn: fetchPreprintedBoarding,
    staleTime: 5_000,
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

  const totalPeopleOnBoard = boardedTotals.adults + boardedTotals.children + preprintedBoarding.count;

  const handlePreprintedTicketScanned = useCallback(async (): Promise<PreprintedScanResult> => {
    const latest = await fetchPreprintedBoarding();
    const scannedAt = new Date().toISOString();
    const next: PreprintedBoardingState = { count: latest.count + 1, lastScanAt: scannedAt };
    await savePreprintedBoarding(next);
    qc.setQueryData(["preprinted-boarding"], next);
    return { count: next.count, scannedAt };
  }, [qc]);

  const adjustPreprintedBoarding = useCallback(async (delta: number): Promise<void> => {
    setAdjustingPreprinted(true);
    try {
      const latest = await fetchPreprintedBoarding();
      const nextCount = Math.max(0, latest.count + delta);
      const next: PreprintedBoardingState = {
        count: nextCount,
        lastScanAt: delta > 0 ? new Date().toISOString() : latest.lastScanAt,
      };
      await savePreprintedBoarding(next);
      qc.setQueryData(["preprinted-boarding"], next);
      if (Platform.OS !== "web") Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } catch (err) {
      console.error("[admin] adjust preprinted boarding", err);
      Alert.alert("Counter failed", "Could not update the shop ticket counter. Please try again.");
    } finally {
      setAdjustingPreprinted(false);
    }
  }, [qc]);

  const handleBarcodeScanned = useCallback(
    (result: BarcodeScanningResult) => {
      // Guard with a ref so rapid camera frames don't fire dozens of
      // overlapping lookups (which caused repeated haptics / no settled result).
      if (scanLockRef.current) return;
      scanLockRef.current = true;
      if (Platform.OS !== "web") Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      handleBarcodeScan(result.data, {
        setScannedBooking,
        setMembershipResult,
        setPreprintedScanResult,
        setScannerError,
        onPreprintedTicketScanned: handlePreprintedTicketScanned,
      });
    },
    [handlePreprintedTicketScanned],
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

  const addCruise = useCallback(() => {
    if (!edited) return;
    const newCruise: Cruise = {
      id: `cruise-${Date.now()}`,
      name: "New Cruise",
      duration: "1 hour",
      description: "",
      adultPrice: 18,
      childPrice: 10,
      capacity: 30,
      emoji: "⛵",
    };
    setEdited({ ...edited, cruises: [...edited.cruises, newCruise] });
    setHasChanges(true);
  }, [edited]);

  const removeCruise = useCallback(
    (idx: number) => {
      if (!edited) return;
      const cruise = edited.cruises[idx];
      if (!cruise) return;

      // Count sailings still referencing this cruise
      const referenced = edited.days.reduce(
        (acc, d) => acc + d.times.filter((t) => t.cruiseId === cruise.id).length,
        0,
      );

      const doRemove = () => {
        const cruises = edited.cruises.filter((_, i) => i !== idx);
        // Clear any sailing times that referenced the removed cruise
        const days = edited.days.map((d) => ({
          ...d,
          times: d.times.filter((t) => t.cruiseId !== cruise.id),
        }));
        setEdited({ ...edited, cruises, days });
        setHasChanges(true);
      };

      if (referenced > 0) {
        Alert.alert(
          "Remove cruise?",
          "\"" + cruise.name + "\" is used by " + referenced + " sailing" + (referenced === 1 ? "" : "s") + ". Those sailings will also be removed.",
          [
            { text: "Cancel", style: "cancel" },
            { text: "Remove", style: "destructive", onPress: doRemove },
          ],
        );
      } else {
        Alert.alert(
          "Remove cruise?",
          "Remove \"" + cruise.name + "\"? You can add it back later.",
          [
            { text: "Cancel", style: "cancel" },
            { text: "Remove", style: "destructive", onPress: doRemove },
          ],
        );
      }
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

  const timeStringToDate = useCallback((time: string): Date => {
    const [hoursRaw, minutesRaw] = time.split(":");
    const hours = Number(hoursRaw);
    const minutes = Number(minutesRaw);
    const date = new Date();
    date.setHours(Number.isFinite(hours) ? hours : 10, Number.isFinite(minutes) ? minutes : 0, 0, 0);
    return date;
  }, []);

  const formatPickerTime = useCallback((date: Date): string => {
    const hours = String(date.getHours()).padStart(2, "0");
    const minutes = String(date.getMinutes()).padStart(2, "0");
    return `${hours}:${minutes}`;
  }, []);

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
      setPickerTimeTarget(null);
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
      isHidden: boatLocation?.isHidden ?? false,
    };
    await saveBoatLocation(nextLocation);
    qc.invalidateQueries({ queryKey: ["boat-location"] });
  }, [qc, boatLocation]);

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

  const [hidingTracker, setHidingTracker] = useState<boolean>(false);
  const handleToggleTrackerHidden = useCallback(async () => {
    setHidingTracker(true);
    try {
      const latest = await fetchBoatLocation();
      const base: BoatLocation = latest ?? {
        latitude: 55.3338,
        longitude: -1.5803,
        accuracy: null,
        heading: null,
        speed: null,
        updatedAt: new Date().toISOString(),
        isTracking: false,
      };
      await saveBoatLocation({ ...base, isHidden: !trackerHidden });
      qc.invalidateQueries({ queryKey: ["boat-location"] });
      if (Platform.OS !== "web") Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } catch (err) {
      console.error("[admin] toggle tracker hidden", err);
      setTrackingError("Could not update tracker visibility. Please try again.");
    } finally {
      setHidingTracker(false);
    }
  }, [qc, trackerHidden]);

  const [resettingBoarded, setResettingBoarded] = useState<boolean>(false);
  const handleResetBoarded = useCallback(() => {
    Alert.alert(
      "Reset On Board",
      `This will clear ${totalPeopleOnBoard} people from the on-board count, including app bookings and shop paper tickets. App bookings will go back to "paid" status. This cannot be undone.`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Reset All",
          style: "destructive",
          onPress: async () => {
            setResettingBoarded(true);
            try {
              const { error } = await supabase
                .from("bookings")
                .update({ status: "paid" })
                .eq("status", "boarded");
              if (error) throw error;
              await savePreprintedBoarding({ count: 0, lastScanAt: null });
              qc.setQueryData(["preprinted-boarding"], { count: 0, lastScanAt: null });
              refetchBoarded();
              refetchPreprintedBoarding();
              if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            } catch (err) {
              console.error("[admin] reset boarded", err);
              Alert.alert("Reset failed", err instanceof Error ? err.message : "Please try again.");
            } finally {
              setResettingBoarded(false);
            }
          },
        },
      ],
    );
  }, [qc, refetchBoarded, refetchPreprintedBoarding, totalPeopleOnBoard]);

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
            <View style={[styles.hideRow, trackerHidden && styles.hideRowActive]}>
              <View style={[styles.hideRowIcon, trackerHidden && styles.hideRowIconActive]}>
                <EyeOff size={16} color={trackerHidden ? theme.white : theme.textMuted} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={[styles.hideRowTitle, trackerHidden && styles.hideRowTitleOn]}>
                  {trackerHidden ? "Location hidden from customers" : "Hide location from customers"}
                </Text>
                <Text style={[styles.hideRowSub, trackerHidden && styles.hideRowSubOn]}>
                  {trackerHidden
                    ? "Customers can't see the boat. Tap the switch to show it again."
                    : "For private charters — hides the live boat from customer maps."}
                </Text>
              </View>
              {hidingTracker ? (
                <ActivityIndicator color={theme.sea} size="small" />
              ) : (
                <Pressable
                  onPress={handleToggleTrackerHidden}
                  hitSlop={8}
                  style={[styles.hideSwitch, trackerHidden && styles.hideSwitchOn]}
                >
                  <View style={[styles.hideKnob, trackerHidden && styles.hideKnobOn]} />
                </Pressable>
              )}
            </View>
          </View>
        </Section>

        {/* On Board List */}
        <Section title="Currently On Board">
          <View style={styles.onboardCard}>
            {boardedBookings.length === 0 && preprintedBoarding.count === 0 ? (
              <View style={styles.onboardEmpty}>
                <Anchor size={28} color={theme.textMuted} />
                <Text style={styles.onboardEmptyTitle}>No one on board yet</Text>
                <Text style={styles.onboardEmptySub}>
                  Scan app tickets or the fixed shop ticket QR to count people boarding.
                </Text>
              </View>
            ) : (
              <>
                {preprintedBoarding.count > 0 && (
                  <View style={styles.preprintedOnboardRow}>
                    <View style={styles.onboardRowLeft}>
                      <Text style={styles.onboardName}>Shop paper tickets</Text>
                      <Text style={styles.onboardCruise}>
                        Fixed QR scans{preprintedBoarding.lastScanAt ? ` · last ${new Date(preprintedBoarding.lastScanAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : ""}
                      </Text>
                    </View>
                    <View style={styles.preprintedCounterControls}>
                      <Pressable
                        onPress={() => adjustPreprintedBoarding(-1)}
                        disabled={adjustingPreprinted}
                        hitSlop={8}
                        style={styles.preprintedStepButton}
                      >
                        <Minus size={14} color={theme.sea} />
                      </Pressable>
                      <View style={styles.onboardCountBadge}>
                        <Users size={11} color={theme.sea} />
                        <Text style={styles.onboardCountText}>{preprintedBoarding.count}</Text>
                      </View>
                      <Pressable
                        onPress={() => adjustPreprintedBoarding(1)}
                        disabled={adjustingPreprinted}
                        hitSlop={8}
                        style={styles.preprintedStepButton}
                      >
                        <Plus size={14} color={theme.sea} />
                      </Pressable>
                    </View>
                  </View>
                )}

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
                      {totalPeopleOnBoard}
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
                    <View style={[styles.onboardTotalChip, styles.onboardTotalChipPaper]}>
                      <Text style={styles.onboardTotalChipLabel}>Shop tickets</Text>
                      <Text style={styles.onboardTotalChipValue}>
                        {preprintedBoarding.count}
                      </Text>
                    </View>
                  </View>

                  {/* Reset for next trip */}
                  <Pressable
                    onPress={handleResetBoarded}
                    disabled={resettingBoarded}
                    style={({ pressed }) => [
                      styles.resetBtn,
                      resettingBoarded && { opacity: 0.5 },
                      pressed && { opacity: 0.85 },
                    ]}
                  >
                    {resettingBoarded ? (
                      <ActivityIndicator color={theme.coral} size="small" />
                    ) : (
                      <Trash2 size={16} color={theme.coral} />
                    )}
                    <Text style={styles.resetBtnText}>
                      {resettingBoarded ? "Resetting…" : "Reset for Next Trip"}
                    </Text>
                  </Pressable>
                </View>
              </>
            )}
          </View>
        </Section>

        <Section title="Shop Paper Ticket QR">
          <View style={styles.paperQrCard}>
            <View style={styles.paperQrHeader}>
              <View style={{ flex: 1 }}>
                <Text style={styles.paperQrTitle}>Use this one QR on every preprinted ticket</Text>
                <Text style={styles.paperQrSub}>Each scan adds 1 person to the on-board counter. It does not check whether the ticket is real.</Text>
              </View>
              <View style={styles.paperQrImageWrap}>
                <Image source={{ uri: preprintedTicketQrUrl() }} style={styles.paperQrImage} contentFit="contain" />
              </View>
            </View>
            <View style={styles.paperQrCodeBox}>
              <Text style={styles.paperQrCodeLabel}>QR VALUE</Text>
              <Text style={styles.paperQrCodeText}>{PREPRINTED_TICKET_QR_VALUE}</Text>
            </View>
          </View>
        </Section>

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
                  setMembershipResult(null);
                  setPreprintedScanResult(null);
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
                      setMembershipResult(null);
                      setPreprintedScanResult(null);
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
                <Text style={styles.scannerHint}>Point camera at a boarding pass, member pass, or shop paper-ticket QR</Text>
              </View>
            )}

            {scannerError && (
              <View style={styles.scannerErrorRow}>
                <AlertCircle size={14} color={theme.coral} />
                <Text style={styles.scannerErrorText}>{scannerError}</Text>
              </View>
            )}

            {preprintedScanResult && (
              <View style={styles.scannedResult}>
                <View style={styles.scannedStatusRow}>
                  <CheckCircle size={18} color={theme.sea} />
                  <Text style={styles.scannedStatusText}>Shop Ticket Counted</Text>
                </View>
                <Text style={styles.scannedName}>+1 person on board</Text>
                <Text style={styles.scannedCruise}>Preprinted shop ticket</Text>
                <Text style={styles.scannedMeta}>Scanned {new Date(preprintedScanResult.scannedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</Text>
                <View style={styles.scannedStatusBadge}>
                  <Text style={styles.scannedStatusBadgeText}>{preprintedScanResult.count} SHOP TICKET{preprintedScanResult.count === 1 ? "" : "S"} ON BOARD</Text>
                </View>
                <Pressable
                  onPress={() => {
                    setPreprintedScanResult(null);
                    setScannerError(null);
                    scanLockRef.current = false;
                  }}
                  style={styles.scanAnother}
                >
                  <Text style={styles.scanAnotherText}>Scan Another</Text>
                </Pressable>
              </View>
            )}

            {membershipResult && (
              <View style={styles.scannedResult}>
                <View style={styles.scannedStatusRow}>
                  <CheckCircle size={18} color={theme.sea} />
                  <Text style={styles.scannedStatusText}>Membership Trip Redeemed</Text>
                </View>
                <Text style={styles.scannedName}>{membershipResult.email}</Text>
                <Text style={styles.scannedCruise}>Annual Puffin Membership</Text>
                <Text style={styles.scannedMeta}>10% shop discount included</Text>
                <View style={styles.scannedStatusBadge}>
                  <Text style={styles.scannedStatusBadgeText}>{membershipResult.creditsRemaining} / {membershipResult.creditsTotal} TRIPS LEFT</Text>
                </View>
                <Text style={styles.scannedMeta}>Valid until {new Date(membershipResult.expiresAt).toLocaleDateString("en-GB")}</Text>
                <Pressable
                  onPress={() => {
                    setMembershipResult(null);
                    setPreprintedScanResult(null);
                    setScannerError(null);
                    scanLockRef.current = false;
                  }}
                  style={styles.scanAnother}
                >
                  <Text style={styles.scanAnotherText}>Scan Another</Text>
                </Pressable>
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
                    setMembershipResult(null);
                    setPreprintedScanResult(null);
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

        <Section title="Send Push">
          <SendPushSection />
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
              <View style={styles.cruiseCardHeader}>
                <Text style={styles.cruiseIdLabel}>ID: {c.id}</Text>
                <Pressable onPress={() => removeCruise(i)} hitSlop={8} style={styles.cruiseDeleteBtn}>
                  <Trash2 size={16} color={theme.coral} />
                </Pressable>
              </View>
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
                value={c.id}
                onChangeText={(v) => updateCruise(i, { id: v })}
                placeholder="Cruise ID (used in sailings)"
                placeholderTextColor={theme.textMuted}
                autoCapitalize="none"
                autoCorrect={false}
                style={[styles.inlineField, { fontSize: 12 }]}
              />
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
          <Pressable onPress={addCruise} style={styles.addCruiseBtn}>
            <Plus size={16} color={theme.sea} />
            <Text style={styles.addCruiseBtnText}>Add Cruise Type</Text>
          </Pressable>
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
                  <View style={styles.timePickerColumn}>
                    <Pressable
                      onPress={() => setPickerTimeTarget({ dayIdx, timeIdx })}
                      style={styles.timePickerField}
                    >
                      <Clock size={13} color={theme.sea} />
                      <Text style={styles.timePickerText}>{t.time}</Text>
                    </Pressable>
                    {pickerTimeTarget?.dayIdx === dayIdx && pickerTimeTarget.timeIdx === timeIdx && (
                      <View style={styles.timePickerWrapper}>
                        <View style={styles.datePickerHeader}>
                          <Text style={styles.datePickerTitle}>Select Time</Text>
                          <Pressable onPress={() => setPickerTimeTarget(null)} hitSlop={8}>
                            <X size={16} color={theme.textMuted} />
                          </Pressable>
                        </View>
                        <DateTimePicker
                          value={timeStringToDate(t.time)}
                          mode="time"
                          display={Platform.OS === "ios" ? "spinner" : "default"}
                          minuteInterval={5}
                          themeVariant="light"
                          onChange={(event: DateTimePickerEvent, selectedDate?: Date) => {
                            if (Platform.OS === "android") {
                              setPickerTimeTarget(null);
                            }
                            if (event.type === "dismissed") {
                              setPickerTimeTarget(null);
                              return;
                            }
                            if (selectedDate) {
                              updateTime(dayIdx, timeIdx, { time: formatPickerTime(selectedDate) });
                              if (Platform.OS === "ios") setPickerTimeTarget(null);
                            }
                          }}
                        />
                      </View>
                    )}
                  </View>
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

        <CamerasSection />
        <WooSection />
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

// ── YouTube Cameras Manager ───────────────────────────────────

function CamerasSection() {
  const [videoIds, setVideoIds] = useState<string[]>(["", "", "", ""]);
  const [labels, setLabels] = useState<string[]>(["Puffin Colony", "North Cliffs", "East Shore", "Harbour View"]);
  const [saving, setSaving] = useState<boolean>(false);
  const [loaded, setLoaded] = useState<boolean>(false);
  const [saved, setSaved] = useState<boolean>(false);

  useEffect(() => {
    supabase
      .from("app_config")
      .select("value")
      .eq("key", "cameras")
      .maybeSingle()
      .then(({ data }) => {
        if (data?.value) {
          const val = data.value as Record<string, unknown>;
          if (Array.isArray(val.videos)) {
            const videos = val.videos as { id: string; label: string }[];
            setVideoIds(videos.map((v) => v.id ?? ""));
            setLabels(videos.map((v) => v.label ?? ""));
          }
        }
        setLoaded(true);
      });
  }, []);

  const handleSave = useCallback(async () => {
    setSaving(true);
    try {
      const videos = videoIds.map((id, i) => ({
        id: id.trim(),
        label: labels[i]?.trim() || `Camera ${i + 1}`,
      }));
      const { error } = await supabase
        .from("app_config")
        .upsert(
          { key: "cameras", value: { videos } as unknown as Record<string, unknown>, updated_at: new Date().toISOString() },
          { onConflict: "key" },
        );
      if (error) throw error;
      setSaved(true);
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      console.error("[admin] cameras save", err);
      Alert.alert("Save failed", err instanceof Error ? err.message : "Please try again.");
    } finally {
      setSaving(false);
    }
  }, [videoIds, labels]);

  if (!loaded) {
    return (
      <Section title="Live Cameras">
        <View style={styles.notifyCard}>
          <ActivityIndicator color={theme.sea} />
        </View>
      </Section>
    );
  }

  return (
    <Section title="Live Cameras">
      <View style={styles.notifyCard}>
        <Text style={styles.notifyLabel}>
          Enter YouTube video IDs for the 4 Coquet Island live camera streams. Links change every 24 hours — update here daily.
        </Text>

        {videoIds.map((vid, i) => (
          <View key={i} style={{ gap: 4, marginTop: i === 0 ? 0 : 10 }}>
            <Text style={styles.hintLabel}>Camera {i + 1} Label</Text>
            <TextInput
              value={labels[i] ?? ""}
              onChangeText={(v) => {
                const next = [...labels];
                next[i] = v;
                setLabels(next);
              }}
              placeholder="e.g. Puffin Colony"
              placeholderTextColor={theme.textMuted}
              style={styles.field}
            />
            <Text style={[styles.hintLabel, { marginTop: 4 }]}>YouTube Video ID</Text>
            <TextInput
              value={vid}
              onChangeText={(v) => {
                const next = [...videoIds];
                next[i] = v;
                setVideoIds(next);
              }}
              placeholder="e.g. dQw4w9WgXcQ"
              placeholderTextColor={theme.textMuted}
              autoCapitalize="none"
              autoCorrect={false}
              style={styles.field}
            />
          </View>
        ))}

        <Pressable
          onPress={handleSave}
          disabled={saving}
          style={({ pressed }) => [
            styles.notifySendBtn,
            saving && { opacity: 0.5 },
            pressed && { opacity: 0.85 },
            { marginTop: spacing.md },
          ]}
        >
          {saving ? (
            <ActivityIndicator color={theme.white} size="small" />
          ) : saved ? (
            <CheckCircle size={18} color={theme.white} />
          ) : (
            <Video size={18} color={theme.white} />
          )}
          <Text style={styles.notifySendBtnText}>
            {saving ? "Saving…" : saved ? "Saved!" : "Save Camera Links"}
          </Text>
        </Pressable>
      </View>
    </Section>
  );
}

// ── WooCommerce Config ─────────────────────────────────────────

function WooSection() {
  const [storeUrl, setStoreUrl] = useState<string>("");
  const [consumerKey, setConsumerKey] = useState<string>("");
  const [consumerSecret, setConsumerSecret] = useState<string>("");
  const [saving, setSaving] = useState<boolean>(false);
  const [loaded, setLoaded] = useState<boolean>(false);
  const [saved, setSaved] = useState<boolean>(false);

  useEffect(() => {
    supabase
      .from("app_config")
      .select("value")
      .eq("key", "woocommerce")
      .maybeSingle()
      .then(({ data }) => {
        if (data?.value) {
          const val = data.value as Record<string, unknown>;
          setStoreUrl(typeof val.storeUrl === "string" ? val.storeUrl : "");
          setConsumerKey(typeof val.consumerKey === "string" ? val.consumerKey : "");
          setConsumerSecret(typeof val.consumerSecret === "string" ? val.consumerSecret : "");
        }
        setLoaded(true);
      });
  }, []);

  const handleSave = useCallback(async () => {
    setSaving(true);
    try {
      const { error } = await supabase
        .from("app_config")
        .upsert(
          {
            key: "woocommerce",
            value: {
              storeUrl: storeUrl.trim(),
              consumerKey: consumerKey.trim(),
              consumerSecret: consumerSecret.trim(),
            } as unknown as Record<string, unknown>,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "key" },
        );
      if (error) throw error;
      setSaved(true);
      if (Platform.OS !== "web") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      console.error("[admin] woocommerce save", err);
      Alert.alert("Save failed", err instanceof Error ? err.message : "Please try again.");
    } finally {
      setSaving(false);
    }
  }, [storeUrl, consumerKey, consumerSecret]);

  if (!loaded) {
    return (
      <Section title="WooCommerce Shop">
        <View style={styles.notifyCard}>
          <ActivityIndicator color={theme.sea} />
        </View>
      </Section>
    );
  }

  return (
    <Section title="WooCommerce Shop">
      <View style={styles.notifyCard}>
        <Text style={styles.notifyLabel}>
          Connect your WooCommerce store to show products in the Shop tab. Find your consumer keys in WooCommerce → Settings → Advanced → REST API.
        </Text>

        <Text style={styles.hintLabel}>Store URL</Text>
        <TextInput
          value={storeUrl}
          onChangeText={setStoreUrl}
          placeholder="https://puffincruises.com"
          placeholderTextColor={theme.textMuted}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="url"
          style={styles.field}
        />

        <Text style={styles.hintLabel}>Consumer Key</Text>
        <TextInput
          value={consumerKey}
          onChangeText={setConsumerKey}
          placeholder="ck_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
          placeholderTextColor={theme.textMuted}
          autoCapitalize="none"
          autoCorrect={false}
          style={styles.field}
        />

        <Text style={styles.hintLabel}>Consumer Secret</Text>
        <TextInput
          value={consumerSecret}
          onChangeText={setConsumerSecret}
          placeholder="cs_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
          placeholderTextColor={theme.textMuted}
          autoCapitalize="none"
          autoCorrect={false}
          style={styles.field}
        />

        <Pressable
          onPress={handleSave}
          disabled={saving}
          style={({ pressed }) => [
            styles.notifySendBtn,
            saving && { opacity: 0.5 },
            pressed && { opacity: 0.85 },
            { marginTop: spacing.md },
          ]}
        >
          {saving ? (
            <ActivityIndicator color={theme.white} size="small" />
          ) : saved ? (
            <CheckCircle size={18} color={theme.white} />
          ) : (
            <ShoppingBag size={18} color={theme.white} />
          )}
          <Text style={styles.notifySendBtnText}>
            {saving ? "Saving…" : saved ? "Saved!" : "Save Shop Config"}
          </Text>
        </Pressable>
      </View>
    </Section>
  );
}

// ── Send Push ─────────────────────────────────────────────────────

function SendPushSection() {
  const [pushTitle, setPushTitle] = useState("");
  const [pushBody, setPushBody] = useState("");
  const [sendingPush, setSendingPush] = useState(false);
  const [deviceCount, setDeviceCount] = useState<number | null>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const { count, error } = await supabase
          .from("push_tokens")
          .select("token", { count: "exact", head: true });
        if (!active) return;
        if (error) throw error;
        setDeviceCount(count ?? 0);
      } catch {
        if (active) setDeviceCount(0);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  const sendPush = async (): Promise<void> => {
    const title = pushTitle.trim();
    const body = pushBody.trim();
    if (!title || !body) {
      Alert.alert("Missing details", "Add a title and a message first.");
      return;
    }
    setSendingPush(true);
    try {
      const { data, error } = await supabase.from("push_tokens").select("token, platform");
      if (error) throw error;
      const rows = ((data ?? []) as { token: string; platform: string | null }[]).filter((row) => row.token);
      if (rows.length === 0) {
        Alert.alert("No devices", "No devices have registered for push yet.");
        return;
      }
      const expoTokens = rows
        .filter((row) => row.token.startsWith("Expo"))
        .map((row) => row.token);
      for (let i = 0; i < expoTokens.length; i += 90) {
        const chunk = expoTokens.slice(i, i + 90);
        const res = await fetch("https://exp.host/--/api/v2/push/send", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(
            chunk.map((token) => ({ to: token, title, body, sound: "default" }))
          ),
        });
        if (!res.ok) throw new Error("Expo push API " + res.status);
      }
      let apnsSent = 0;
      try {
        apnsSent = (await sendApnsBroadcast(title, body)).sent;
      } catch (apnsErr) {
        console.error("[admin] apns broadcast", apnsErr);
        if (expoTokens.length === 0) throw apnsErr;
      }
      const delivered = expoTokens.length + apnsSent;
      setPushTitle("");
      setPushBody("");
      Alert.alert(
        "Sent",
        "Notification sent to " + delivered + " device" + (delivered === 1 ? "" : "s") + "."
      );
    } catch (err) {
      console.error("[admin] send push", err);
      Alert.alert(
        "Error",
        "Could not send the push. Check that the push_tokens table exists in Supabase."
      );
    } finally {
      setSendingPush(false);
    }
  };

  return (
    <View style={styles.pushCard}>
      <View style={styles.pushHeaderRow}>
        <Send size={18} color={theme.sea} />
        <Text style={styles.pushHeaderTitle}>Broadcast to all app users</Text>
      </View>
      <Text style={styles.pushDeviceCount}>
        {deviceCount === null
          ? "Checking devices..."
          : deviceCount + " registered device" + (deviceCount === 1 ? "" : "s")}
      </Text>
      <TextInput
        value={pushTitle}
        onChangeText={setPushTitle}
        placeholder="Title (e.g. Sailing update)"
        placeholderTextColor={theme.textMuted}
        style={styles.pushInput}
        maxLength={60}
      />
      <TextInput
        value={pushBody}
        onChangeText={setPushBody}
        placeholder="Message (e.g. The 2pm sailing is running as normal)"
        placeholderTextColor={theme.textMuted}
        style={[styles.pushInput, styles.pushInputMultiline]}
        multiline
        numberOfLines={3}
        maxLength={300}
      />
      <Pressable
        onPress={sendPush}
        disabled={sendingPush}
        style={[styles.pushSendButton, sendingPush && { opacity: 0.6 }]}
      >
        {sendingPush ? (
          <ActivityIndicator color={theme.white} size="small" />
        ) : (
          <Send size={16} color={theme.white} />
        )}
        <Text style={styles.pushSendButtonText}>
          {sendingPush ? "Sending..." : "Send to All Devices"}
        </Text>
      </Pressable>
    </View>
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
  cruiseCardHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  cruiseIdLabel: {
    fontSize: 11,
    fontWeight: "600",
    color: theme.textMuted,
    fontFamily: "monospace",
  },
  cruiseDeleteBtn: {
    padding: 6,
    borderRadius: 8,
    backgroundColor: "#FFF3F0",
  },
  addCruiseBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 14,
    borderWidth: 1.5,
    borderColor: theme.sea,
    borderRadius: 12,
    borderStyle: "dashed",
    marginTop: 4,
  },
  addCruiseBtnText: { color: theme.sea, fontWeight: "700", fontSize: 14 },

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
  timePickerColumn: {
    width: 94,
    gap: 6,
  },
  timePickerField: {
    minHeight: 40,
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    backgroundColor: theme.white,
    borderWidth: 1.5,
    borderColor: theme.sea,
    borderRadius: 10,
    paddingHorizontal: 10,
  },
  timePickerText: {
    fontSize: 14,
    fontWeight: "800",
    color: theme.text,
  },
  timePickerWrapper: {
    width: 210,
    backgroundColor: theme.white,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: theme.border,
    overflow: "hidden",
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
  hideRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 12,
    borderRadius: 14,
    backgroundColor: theme.bg,
    borderWidth: 1,
    borderColor: theme.border,
  },
  hideRowActive: { backgroundColor: theme.deep, borderColor: theme.deep },
  hideRowIcon: {
    width: 34,
    height: 34,
    borderRadius: 11,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
  },
  hideRowIconActive: { backgroundColor: theme.coral },
  hideRowTitle: { fontSize: 14, fontWeight: "800", color: theme.text },
  hideRowTitleOn: { color: theme.white },
  hideRowSub: { marginTop: 2, fontSize: 12, lineHeight: 16, color: theme.textMuted },
  hideRowSubOn: { color: "rgba(255,255,255,0.65)" },
  hideSwitch: {
    width: 46,
    height: 27,
    borderRadius: 14,
    backgroundColor: "#D8E1EA",
    justifyContent: "center",
    paddingHorizontal: 3,
  },
  hideSwitchOn: { backgroundColor: theme.coral },
  hideKnob: {
    width: 21,
    height: 21,
    borderRadius: 11,
    backgroundColor: theme.white,
    shadowColor: "#000",
    shadowOpacity: 0.15,
    shadowRadius: 3,
    shadowOffset: { width: 0, height: 1 },
    elevation: 2,
  },
  hideKnobOn: { alignSelf: "flex-end" },

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
  paperQrCard: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 18,
    padding: 14,
    gap: 12,
  },
  paperQrHeader: {
    flexDirection: "row",
    gap: 14,
    alignItems: "center",
  },
  paperQrTitle: {
    fontSize: 16,
    fontWeight: "900",
    color: theme.text,
  },
  paperQrSub: {
    marginTop: 5,
    fontSize: 13,
    lineHeight: 18,
    color: theme.textMuted,
  },
  paperQrImageWrap: {
    width: 98,
    height: 98,
    borderRadius: 16,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
  },
  paperQrImage: {
    width: 86,
    height: 86,
  },
  paperQrCodeBox: {
    backgroundColor: theme.bg,
    borderRadius: 12,
    padding: 10,
    gap: 3,
  },
  paperQrCodeLabel: {
    fontSize: 10,
    fontWeight: "900",
    color: theme.textMuted,
    letterSpacing: 0.8,
  },
  paperQrCodeText: {
    fontSize: 12,
    fontWeight: "800",
    color: theme.sea,
    fontFamily: "monospace",
  },
  pushCard: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 18,
    padding: 14,
    gap: 10,
  },
  pushHeaderRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  pushHeaderTitle: {
    fontSize: 15,
    fontWeight: "900",
    color: theme.text,
  },
  pushDeviceCount: {
    fontSize: 12.5,
    fontWeight: "600",
    color: theme.textMuted,
  },
  pushInput: {
    backgroundColor: theme.bg,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 14,
    color: theme.text,
  },
  pushInputMultiline: {
    minHeight: 84,
    textAlignVertical: "top",
  },
  pushSendButton: {
    backgroundColor: theme.sea,
    borderRadius: 14,
    paddingVertical: 13,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
  },
  pushSendButtonText: {
    color: theme.white,
    fontSize: 15,
    fontWeight: "800",
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
  preprintedOnboardRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 10,
    paddingHorizontal: 10,
    gap: 10,
    backgroundColor: "#F7F2E7",
    borderRadius: 14,
    marginBottom: 4,
  },
  preprintedCounterControls: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  preprintedStepButton: {
    width: 34,
    height: 34,
    borderRadius: 11,
    backgroundColor: theme.white,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: theme.border,
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
  onboardTotalChipPaper: {
    backgroundColor: "#F7F2E7",
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

  // Notify
  notifyCard: {
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 18,
    padding: 14,
    gap: 12,
  },
  notifyLabel: {
    fontSize: 12,
    fontWeight: "700",
    color: theme.textMuted,
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  adminAlertRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  adminAlertSub: {
    color: theme.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  adminAlertToggle: {
    minWidth: 76,
    minHeight: 42,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: theme.sea,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    backgroundColor: theme.white,
  },
  adminAlertToggleOn: {
    backgroundColor: theme.sea,
  },
  adminAlertToggleText: {
    color: theme.sea,
    fontSize: 13,
    fontWeight: "900",
  },
  adminAlertToggleTextOn: {
    color: theme.white,
  },
  notifyTargetRow: {
    flexDirection: "row",
    gap: 8,
  },
  notifyTargetBtn: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    paddingVertical: 10,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: theme.border,
    backgroundColor: theme.bg,
  },
  notifyTargetBtnActive: {
    borderColor: theme.sea,
    backgroundColor: theme.sea,
  },
  notifyTargetText: {
    fontSize: 13,
    fontWeight: "700",
    color: theme.textMuted,
  },
  notifyTargetTextActive: {
    color: theme.white,
  },
  notifySendBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 14,
    borderRadius: 14,
    backgroundColor: theme.puffin,
  },
  notifySendBtnText: {
    color: theme.white,
    fontSize: 15,
    fontWeight: "800",
  },

  // Reset boarded
  resetBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: theme.coral,
    backgroundColor: "#FFF3F0",
    marginTop: 4,
  },
  resetBtnText: {
    color: theme.coral,
    fontSize: 14,
    fontWeight: "800",
  },
});
