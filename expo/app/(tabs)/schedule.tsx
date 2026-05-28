import { router } from "expo-router";
import { ChevronRight, Cloud, Waves } from "lucide-react-native";
import React, { useMemo, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";
import { fetchSchedule } from "@/lib/schedule";
import { useQuery } from "@tanstack/react-query";

export default function ScheduleScreen() {
  const insets = useSafeAreaInsets();
  const { data, isLoading } = useQuery({
    queryKey: ["schedule"],
    queryFn: fetchSchedule,
  });

  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const days = data?.days ?? [];
  const active = useMemo(
    () => days.find((d) => d.date === selectedDate) ?? days[0],
    [days, selectedDate],
  );
  const cruisesById = useMemo(() => {
    const map: Record<string, { name: string; emoji: string; duration: string }> = {};
    data?.cruises.forEach((c) => {
      map[c.id] = { name: c.name, emoji: c.emoji, duration: c.duration };
    });
    return map;
  }, [data?.cruises]);

  return (
    <View style={{ flex: 1, backgroundColor: theme.bg }}>
      <View style={[styles.header, { paddingTop: insets.top + 16 }]}>
        <Text style={styles.title}>Sailings</Text>
        <Text style={styles.subtitle}>Tide-dependent. Tap a time to book.</Text>
      </View>

      {isLoading && (
        <View style={{ padding: 40, alignItems: "center" }}>
          <ActivityIndicator color={theme.sea} />
        </View>
      )}

      {/* Date picker */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.daysRow}
      >
        {days.map((d) => {
          const isActive = (selectedDate ?? days[0]?.date) === d.date;
          const dt = new Date(d.date);
          return (
            <Pressable
              key={d.date}
              onPress={() => setSelectedDate(d.date)}
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

      <ScrollView contentContainerStyle={{ paddingBottom: 40 }}>
        {active && (
          <View style={styles.dayCard}>
            <View style={styles.dayHeader}>
              <Text style={styles.dayDate}>
                {new Date(active.date).toLocaleDateString("en-GB", {
                  weekday: "long",
                  day: "numeric",
                  month: "long",
                })}
              </Text>
              {active.weather && (
                <View style={styles.weatherPill}>
                  <Cloud size={12} color={theme.sea} />
                  <Text style={styles.weatherText}>{active.weather}</Text>
                </View>
              )}
            </View>

            <View style={{ gap: 10, marginTop: 16 }}>
              {active.times.map((t, idx) => {
                const c = cruisesById[t.cruiseId];
                return (
                  <Pressable
                    key={`${t.time}-${idx}`}
                    onPress={() => router.push("/(tabs)/book")}
                    style={({ pressed }) => [
                      styles.timeRow,
                      pressed && { backgroundColor: theme.foam },
                    ]}
                  >
                    <View style={styles.timeBlock}>
                      <Text style={styles.timeText}>{t.time}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.timeCruise}>
                        {c?.emoji} {c?.name ?? t.cruiseId}
                      </Text>
                      <Text style={styles.timeDuration}>{c?.duration}</Text>
                      {t.note && <Text style={styles.timeNote}>{t.note}</Text>}
                    </View>
                    <ChevronRight size={20} color={theme.textMuted} />
                  </Pressable>
                );
              })}
              {active.times.length === 0 && (
                <View style={styles.empty}>
                  <Waves size={28} color={theme.textMuted} />
                  <Text style={styles.emptyText}>No sailings this day</Text>
                </View>
              )}
            </View>
          </View>
        )}

        {data?.notice && (
          <View style={styles.notice}>
            <Text style={styles.noticeText}>⚓️ {data.notice}</Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: 20,
    paddingBottom: 16,
    backgroundColor: theme.bg,
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
  daysRow: {
    paddingHorizontal: 16,
    gap: 8,
    paddingVertical: 8,
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
  dayChipDow: {
    fontSize: 11,
    fontWeight: "700",
    color: theme.textMuted,
    letterSpacing: 0.5,
  },
  dayChipNum: {
    fontSize: 22,
    fontWeight: "800",
    color: theme.text,
    marginVertical: 2,
  },
  dayChipMo: {
    fontSize: 11,
    color: theme.textMuted,
    fontWeight: "600",
  },
  dayChipTextActive: {
    color: theme.white,
  },
  dayCard: {
    marginHorizontal: 16,
    marginTop: 12,
    padding: 18,
    backgroundColor: theme.card,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: theme.border,
  },
  dayHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    flexWrap: "wrap",
    gap: 8,
  },
  dayDate: {
    fontSize: 17,
    fontWeight: "700",
    color: theme.text,
  },
  weatherPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    backgroundColor: theme.foam,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
  },
  weatherText: {
    fontSize: 12,
    color: theme.sea,
    fontWeight: "600",
  },
  timeRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 12,
    borderRadius: 12,
  },
  timeBlock: {
    width: 64,
    paddingVertical: 10,
    backgroundColor: theme.deep,
    borderRadius: 10,
    alignItems: "center",
  },
  timeText: {
    color: theme.white,
    fontWeight: "800",
    fontSize: 15,
  },
  timeCruise: {
    fontSize: 15,
    fontWeight: "700",
    color: theme.text,
  },
  timeDuration: {
    fontSize: 12,
    color: theme.textMuted,
    marginTop: 2,
  },
  timeNote: {
    fontSize: 12,
    color: theme.coral,
    marginTop: 2,
    fontWeight: "600",
  },
  empty: {
    padding: 32,
    alignItems: "center",
    gap: 8,
  },
  emptyText: {
    color: theme.textMuted,
    fontSize: 14,
  },
  notice: {
    marginHorizontal: 16,
    marginTop: 16,
    padding: 14,
    backgroundColor: theme.foam,
    borderRadius: 12,
  },
  noticeText: {
    color: theme.deep,
    fontSize: 13,
    lineHeight: 19,
  },
});
