import { useQuery } from "@tanstack/react-query";
import * as Haptics from "expo-haptics";
import * as WebBrowser from "expo-web-browser";
import {
  Calendar,
  Check,
  ChevronDown,
  Clock,
  CreditCard,
  Mail,
  Minus,
  Phone,
  Plus,
  User,
} from "lucide-react-native";
import React, { useMemo, useState } from "react";
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
import { createCheckout } from "@/lib/api";
import { fetchSchedule } from "@/lib/schedule";

export default function BookScreen() {
  const insets = useSafeAreaInsets();
  const { data, isLoading } = useQuery({
    queryKey: ["schedule"],
    queryFn: fetchSchedule,
  });

  const [cruiseId, setCruiseId] = useState<string | null>(null);
  const [date, setDate] = useState<string | null>(null);
  const [time, setTime] = useState<string | null>(null);
  const [adults, setAdults] = useState<number>(2);
  const [children, setChildren] = useState<number>(0);
  const [name, setName] = useState<string>("");
  const [email, setEmail] = useState<string>("");
  const [phone, setPhone] = useState<string>("");
  const [submitting, setSubmitting] = useState<boolean>(false);

  const cruise = useMemo(
    () => data?.cruises.find((c) => c.id === cruiseId) ?? null,
    [data?.cruises, cruiseId],
  );

  const availableTimes = useMemo(() => {
    if (!data || !date) return [] as { time: string; cruiseId: string }[];
    const day = data.days.find((d) => d.date === date);
    if (!day) return [];
    if (!cruiseId) return day.times;
    return day.times.filter((t) => t.cruiseId === cruiseId);
  }, [data, date, cruiseId]);

  const total = useMemo(() => {
    if (!cruise) return 0;
    return adults * cruise.adultPrice + children * cruise.childPrice;
  }, [cruise, adults, children]);

  const canSubmit =
    !!cruise &&
    !!date &&
    !!time &&
    adults + children > 0 &&
    name.trim().length > 1 &&
    /.+@.+\..+/.test(email);

  const submit = async () => {
    if (!canSubmit || !cruise || !date || !time) return;
    setSubmitting(true);
    try {
      if (Platform.OS !== "web") {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      }
      const res = await createCheckout({
        cruiseId: cruise.id,
        cruiseName: cruise.name,
        date,
        time,
        adults,
        children,
        customerName: name.trim(),
        customerEmail: email.trim(),
        customerPhone: phone.trim(),
      });
      await WebBrowser.openBrowserAsync(res.url);
    } catch (err) {
      console.error("[book] checkout", err);
      Alert.alert(
        "Booking error",
        err instanceof Error ? err.message : "Please try again.",
      );
    } finally {
      setSubmitting(false);
    }
  };

  if (isLoading || !data) {
    return (
      <View style={{ flex: 1, justifyContent: "center", backgroundColor: theme.bg }}>
        <ActivityIndicator color={theme.sea} />
      </View>
    );
  }

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: theme.bg }}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView
        contentContainerStyle={{ paddingBottom: 140 }}
        keyboardShouldPersistTaps="handled"
      >
        <View style={[styles.header, { paddingTop: insets.top + 16 }]}>
          <Text style={styles.title}>Book a Cruise</Text>
          <Text style={styles.subtitle}>Secure payment by Stripe</Text>
        </View>

        {/* Step 1 — Cruise */}
        <Step number={1} label="Choose a cruise" />
        <View style={{ paddingHorizontal: 16, gap: 10 }}>
          {data.cruises.map((c) => {
            const selected = c.id === cruiseId;
            return (
              <Pressable
                key={c.id}
                onPress={() => {
                  setCruiseId(c.id);
                  setTime(null);
                }}
                style={[styles.choiceCard, selected && styles.choiceCardActive]}
              >
                <Text style={styles.choiceEmoji}>{c.emoji}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.choiceTitle}>{c.name}</Text>
                  <Text style={styles.choiceMeta}>
                    {c.duration} · £{c.adultPrice} adult / £{c.childPrice} child
                  </Text>
                </View>
                {selected && <Check size={20} color={theme.sea} />}
              </Pressable>
            );
          })}
        </View>

        {/* Step 2 — Date */}
        <Step number={2} label="Pick a date" />
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.daysRow}
        >
          {data.days.map((d) => {
            const isActive = d.date === date;
            const dt = new Date(d.date);
            return (
              <Pressable
                key={d.date}
                onPress={() => {
                  setDate(d.date);
                  setTime(null);
                }}
                style={[styles.dayChip, isActive && styles.dayChipActive]}
              >
                <Text
                  style={[styles.dayChipDow, isActive && styles.dayChipTextActive]}
                >
                  {dt.toLocaleDateString("en-GB", { weekday: "short" }).toUpperCase()}
                </Text>
                <Text
                  style={[styles.dayChipNum, isActive && styles.dayChipTextActive]}
                >
                  {dt.getDate()}
                </Text>
                <Text
                  style={[styles.dayChipMo, isActive && styles.dayChipTextActive]}
                >
                  {dt.toLocaleDateString("en-GB", { month: "short" })}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Step 3 — Time */}
        <Step number={3} label="Choose a sailing time" />
        <View style={styles.timesGrid}>
          {date ? (
            availableTimes.length > 0 ? (
              availableTimes.map((t, idx) => {
                const selected = time === t.time && cruiseId === t.cruiseId;
                return (
                  <Pressable
                    key={`${t.time}-${idx}`}
                    onPress={() => {
                      setTime(t.time);
                      setCruiseId(t.cruiseId);
                    }}
                    style={[
                      styles.timeChip,
                      selected && styles.timeChipActive,
                    ]}
                  >
                    <Clock
                      size={14}
                      color={selected ? theme.white : theme.sea}
                    />
                    <Text
                      style={[
                        styles.timeChipText,
                        selected && { color: theme.white },
                      ]}
                    >
                      {t.time}
                    </Text>
                  </Pressable>
                );
              })
            ) : (
              <Text style={styles.hint}>No sailings match that combination.</Text>
            )
          ) : (
            <Text style={styles.hint}>Pick a date to see times.</Text>
          )}
        </View>

        {/* Step 4 — Passengers */}
        <Step number={4} label="Passengers" />
        <View style={styles.paxBox}>
          <PaxRow
            label="Adults"
            sub={cruise ? `£${cruise.adultPrice} each` : ""}
            value={adults}
            onChange={setAdults}
            min={0}
          />
          <View style={styles.divider} />
          <PaxRow
            label="Children"
            sub={cruise ? `£${cruise.childPrice} each (under 16)` : ""}
            value={children}
            onChange={setChildren}
            min={0}
          />
        </View>

        {/* Step 5 — Contact */}
        <Step number={5} label="Your details" />
        <View style={{ paddingHorizontal: 16, gap: 10 }}>
          <Field icon={<User size={16} color={theme.textMuted} />}>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder="Full name"
              placeholderTextColor={theme.textMuted}
              style={styles.input}
              autoCapitalize="words"
            />
          </Field>
          <Field icon={<Mail size={16} color={theme.textMuted} />}>
            <TextInput
              value={email}
              onChangeText={setEmail}
              placeholder="Email"
              placeholderTextColor={theme.textMuted}
              style={styles.input}
              keyboardType="email-address"
              autoCapitalize="none"
            />
          </Field>
          <Field icon={<Phone size={16} color={theme.textMuted} />}>
            <TextInput
              value={phone}
              onChangeText={setPhone}
              placeholder="Phone (optional)"
              placeholderTextColor={theme.textMuted}
              style={styles.input}
              keyboardType="phone-pad"
            />
          </Field>
        </View>
      </ScrollView>

      {/* Sticky footer */}
      <View style={[styles.footer, { paddingBottom: insets.bottom + 12 }]}>
        <View style={{ flex: 1 }}>
          <Text style={styles.totalLabel}>Total</Text>
          <Text style={styles.totalValue}>£{total.toFixed(2)}</Text>
        </View>
        <Pressable
          onPress={submit}
          disabled={!canSubmit || submitting}
          style={({ pressed }) => [
            styles.payBtn,
            (!canSubmit || submitting) && { opacity: 0.5 },
            pressed && { opacity: 0.85 },
          ]}
        >
          {submitting ? (
            <ActivityIndicator color={theme.white} />
          ) : (
            <>
              <CreditCard size={18} color={theme.white} />
              <Text style={styles.payBtnText}>Pay & Book</Text>
            </>
          )}
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

function Step({ number, label }: { number: number; label: string }) {
  return (
    <View style={styles.step}>
      <View style={styles.stepNum}>
        <Text style={styles.stepNumText}>{number}</Text>
      </View>
      <Text style={styles.stepLabel}>{label}</Text>
    </View>
  );
}

function PaxRow({
  label,
  sub,
  value,
  onChange,
  min,
}: {
  label: string;
  sub: string;
  value: number;
  onChange: (n: number) => void;
  min: number;
}) {
  return (
    <View style={styles.paxRow}>
      <View style={{ flex: 1 }}>
        <Text style={styles.paxLabel}>{label}</Text>
        {!!sub && <Text style={styles.paxSub}>{sub}</Text>}
      </View>
      <Pressable
        onPress={() => onChange(Math.max(min, value - 1))}
        style={styles.stepperBtn}
      >
        <Minus size={16} color={theme.sea} />
      </Pressable>
      <Text style={styles.stepperValue}>{value}</Text>
      <Pressable
        onPress={() => onChange(value + 1)}
        style={styles.stepperBtn}
      >
        <Plus size={16} color={theme.sea} />
      </Pressable>
    </View>
  );
}

function Field({ icon, children }: { icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <View style={styles.field}>
      {icon}
      <View style={{ flex: 1 }}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: 20,
    paddingBottom: 8,
  },
  title: {
    fontSize: 34,
    fontWeight: "800",
    color: theme.text,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 14,
    color: theme.textMuted,
    marginTop: 4,
  },
  step: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 16,
    marginTop: 24,
    marginBottom: 10,
  },
  stepNum: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: theme.sea,
    alignItems: "center",
    justifyContent: "center",
  },
  stepNumText: {
    color: theme.white,
    fontSize: 11,
    fontWeight: "800",
  },
  stepLabel: {
    fontSize: 16,
    fontWeight: "700",
    color: theme.text,
  },
  choiceCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
    backgroundColor: theme.white,
    borderWidth: 1.5,
    borderColor: theme.border,
    padding: 14,
    borderRadius: 14,
  },
  choiceCardActive: {
    borderColor: theme.sea,
    backgroundColor: theme.foam,
  },
  choiceEmoji: { fontSize: 28 },
  choiceTitle: { fontSize: 15, fontWeight: "700", color: theme.text },
  choiceMeta: { fontSize: 12, color: theme.textMuted, marginTop: 2 },
  daysRow: {
    paddingHorizontal: 16,
    gap: 8,
  },
  dayChip: {
    width: 64,
    paddingVertical: 12,
    backgroundColor: theme.white,
    borderRadius: 14,
    alignItems: "center",
    borderWidth: 1,
    borderColor: theme.border,
  },
  dayChipActive: {
    backgroundColor: theme.sea,
    borderColor: theme.sea,
  },
  dayChipDow: { fontSize: 11, fontWeight: "700", color: theme.textMuted, letterSpacing: 0.5 },
  dayChipNum: { fontSize: 22, fontWeight: "800", color: theme.text, marginVertical: 2 },
  dayChipMo: { fontSize: 11, color: theme.textMuted, fontWeight: "600" },
  dayChipTextActive: { color: theme.white },
  timesGrid: {
    paddingHorizontal: 16,
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  timeChip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 10,
    backgroundColor: theme.white,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: theme.border,
  },
  timeChipActive: {
    backgroundColor: theme.sea,
    borderColor: theme.sea,
  },
  timeChipText: {
    color: theme.sea,
    fontWeight: "700",
    fontSize: 14,
  },
  hint: {
    color: theme.textMuted,
    fontSize: 14,
    paddingHorizontal: 4,
  },
  paxBox: {
    marginHorizontal: 16,
    backgroundColor: theme.white,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: theme.border,
    overflow: "hidden",
  },
  paxRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 14,
  },
  paxLabel: { fontSize: 15, fontWeight: "700", color: theme.text },
  paxSub: { fontSize: 12, color: theme.textMuted, marginTop: 2 },
  stepperBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
  },
  stepperValue: {
    minWidth: 24,
    textAlign: "center",
    fontWeight: "800",
    fontSize: 16,
    color: theme.text,
  },
  divider: {
    height: 1,
    backgroundColor: theme.border,
    marginHorizontal: 14,
  },
  field: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 4,
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
    borderRadius: 12,
  },
  input: {
    flex: 1,
    paddingVertical: 12,
    fontSize: 15,
    color: theme.text,
  },
  footer: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 16,
    paddingTop: 12,
    backgroundColor: theme.white,
    borderTopWidth: 1,
    borderTopColor: theme.border,
  },
  totalLabel: {
    fontSize: 11,
    fontWeight: "700",
    color: theme.textMuted,
    letterSpacing: 0.5,
  },
  totalValue: {
    fontSize: 24,
    fontWeight: "800",
    color: theme.text,
  },
  payBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    backgroundColor: theme.sea,
    paddingHorizontal: 22,
    paddingVertical: 14,
    borderRadius: 14,
  },
  payBtnText: {
    color: theme.white,
    fontWeight: "800",
    fontSize: 15,
  },
});
