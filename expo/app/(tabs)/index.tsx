import { LinearGradient } from "expo-linear-gradient";
import { Link, router } from "expo-router";
import { Anchor, Calendar, MapPin, Phone, Star, Tv } from "lucide-react-native";
import React, { useCallback } from "react";
import {
  Image,
  Linking,
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

export default function HomeScreen() {
  const insets = useSafeAreaInsets();
  const { data } = useQuery({ queryKey: ["schedule"], queryFn: fetchSchedule });

  const callOffice = useCallback(() => {
    const phone = data?.contactPhone ?? "07752 861914";
    Linking.openURL(`tel:${phone.replace(/\s/g, "")}`);
  }, [data?.contactPhone]);

  const today = data?.days[0];

  return (
    <View style={{ flex: 1, backgroundColor: theme.bg }}>
      <ScrollView
        contentContainerStyle={{ paddingBottom: 40 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Hero */}
        <View style={[styles.hero, { paddingTop: insets.top + 24 }]}>
          <LinearGradient
            colors={[theme.deep, theme.sea, theme.wave]}
            style={StyleSheet.absoluteFill}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
          />
          {/* sun */}
          <View style={styles.sun} />
          {/* waves */}
          <View style={styles.waves}>
            <View style={[styles.wave, { opacity: 0.25 }]} />
            <View style={[styles.wave, { opacity: 0.4, bottom: -6 }]} />
          </View>

          <View style={styles.heroContent}>
            <View style={styles.badge}>
              <Tv size={12} color={theme.white} />
              <Text style={styles.badgeText}>As seen on Robson Green&apos;s Weekend Escapes</Text>
            </View>
            <Text style={styles.heroTitle}>Dave Gray&apos;s{"\n"}Puffin Cruises</Text>
            <Text style={styles.heroSub}>
              Family-run wildlife adventures around Coquet Island for over 40 years.
            </Text>

            <View style={styles.heroMeta}>
              <View style={styles.metaPill}>
                <MapPin size={13} color={theme.white} />
                <Text style={styles.metaText}>Amble Harbour</Text>
              </View>
              <View style={styles.metaPill}>
                <Star size={13} color={theme.sand} fill={theme.sand} />
                <Text style={styles.metaText}>40+ years</Text>
              </View>
            </View>
          </View>
        </View>

        {/* Today's sailings preview */}
        {today && (
          <Pressable
            onPress={() => router.push("/(tabs)/schedule")}
            style={({ pressed }) => [styles.todayCard, pressed && { opacity: 0.9 }]}
          >
            <View style={styles.todayHeader}>
              <View>
                <Text style={styles.todayLabel}>TODAY&apos;S SAILINGS</Text>
                <Text style={styles.todayDate}>
                  {new Date(today.date).toLocaleDateString("en-GB", {
                    weekday: "long",
                    day: "numeric",
                    month: "long",
                  })}
                </Text>
              </View>
              <Calendar size={22} color={theme.sea} />
            </View>
            <Text style={styles.weather}>{today.weather ?? "Tide-dependent schedule"}</Text>
            <View style={styles.timesRow}>
              {today.times.slice(0, 5).map((t) => (
                <View key={`${t.time}-${t.cruiseId}`} style={styles.timeChip}>
                  <Text style={styles.timeChipText}>{t.time}</Text>
                </View>
              ))}
            </View>
            <Text style={styles.viewAll}>See full schedule →</Text>
          </Pressable>
        )}

        {/* Cruise types */}
        <Text style={styles.sectionTitle}>Our Cruises</Text>
        <View style={{ gap: 12, paddingHorizontal: 16 }}>
          {data?.cruises.map((c) => (
            <Link key={c.id} href={{ pathname: "/(tabs)/book" }} asChild>
              <Pressable
                style={({ pressed }) => [
                  styles.cruiseCard,
                  pressed && { transform: [{ scale: 0.98 }] },
                ]}
              >
                <View style={styles.cruiseEmojiWrap}>
                  <Text style={styles.cruiseEmoji}>{c.emoji}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.cruiseTitle}>{c.name}</Text>
                  <Text style={styles.cruiseMeta}>
                    {c.duration} · From £{c.childPrice} child / £{c.adultPrice} adult
                  </Text>
                  <Text style={styles.cruiseDesc} numberOfLines={2}>
                    {c.description}
                  </Text>
                </View>
              </Pressable>
            </Link>
          ))}
        </View>

        {/* CTA */}
        <View style={styles.ctaRow}>
          <Pressable
            onPress={() => router.push("/(tabs)/book")}
            style={({ pressed }) => [styles.primaryBtn, pressed && { opacity: 0.85 }]}
          >
            <Anchor size={18} color={theme.white} />
            <Text style={styles.primaryBtnText}>Book a Cruise</Text>
          </Pressable>
          <Pressable
            onPress={callOffice}
            style={({ pressed }) => [styles.secondaryBtn, pressed && { opacity: 0.85 }]}
          >
            <Phone size={18} color={theme.sea} />
            <Text style={styles.secondaryBtnText}>Call</Text>
          </Pressable>
        </View>

        {/* Notice */}
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
  hero: {
    paddingBottom: 32,
    overflow: "hidden",
  },
  sun: {
    position: "absolute",
    width: 140,
    height: 140,
    borderRadius: 70,
    backgroundColor: theme.sand,
    opacity: 0.35,
    top: 60,
    right: -30,
  },
  waves: {
    position: "absolute",
    bottom: -8,
    left: 0,
    right: 0,
    height: 40,
  },
  wave: {
    position: "absolute",
    bottom: 0,
    left: -40,
    right: -40,
    height: 30,
    backgroundColor: theme.foam,
    borderTopLeftRadius: 200,
    borderTopRightRadius: 200,
    transform: [{ scaleX: 2 }],
  },
  heroContent: {
    paddingHorizontal: 20,
    paddingTop: 8,
  },
  badge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    alignSelf: "flex-start",
    backgroundColor: "rgba(255,255,255,0.15)",
    borderColor: "rgba(255,255,255,0.25)",
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    marginBottom: 16,
  },
  badgeText: {
    color: theme.white,
    fontSize: 11,
    fontWeight: "600",
  },
  heroTitle: {
    color: theme.white,
    fontSize: 38,
    fontWeight: "800",
    letterSpacing: -0.5,
    lineHeight: 42,
  },
  heroSub: {
    color: "rgba(255,255,255,0.85)",
    fontSize: 15,
    marginTop: 12,
    lineHeight: 22,
    maxWidth: 320,
  },
  heroMeta: {
    flexDirection: "row",
    gap: 8,
    marginTop: 20,
  },
  metaPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    backgroundColor: "rgba(255,255,255,0.12)",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 999,
  },
  metaText: {
    color: theme.white,
    fontSize: 12,
    fontWeight: "600",
  },
  todayCard: {
    marginHorizontal: 16,
    marginTop: -16,
    backgroundColor: theme.card,
    borderRadius: 20,
    padding: 18,
    shadowColor: theme.deep,
    shadowOpacity: 0.12,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 4,
  },
  todayHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  todayLabel: {
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1.2,
    color: theme.sea,
  },
  todayDate: {
    fontSize: 18,
    fontWeight: "700",
    color: theme.text,
    marginTop: 4,
  },
  weather: {
    fontSize: 13,
    color: theme.textMuted,
    marginTop: 6,
  },
  timesRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
    marginTop: 14,
  },
  timeChip: {
    backgroundColor: theme.foam,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 10,
  },
  timeChipText: {
    color: theme.sea,
    fontWeight: "700",
    fontSize: 13,
  },
  viewAll: {
    color: theme.sea,
    fontWeight: "600",
    fontSize: 13,
    marginTop: 14,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: "800",
    color: theme.text,
    paddingHorizontal: 16,
    marginTop: 28,
    marginBottom: 12,
    letterSpacing: -0.3,
  },
  cruiseCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
    backgroundColor: theme.white,
    borderRadius: 18,
    padding: 16,
    borderWidth: 1,
    borderColor: theme.border,
  },
  cruiseEmojiWrap: {
    width: 60,
    height: 60,
    borderRadius: 16,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
  },
  cruiseEmoji: {
    fontSize: 32,
  },
  cruiseTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: theme.text,
  },
  cruiseMeta: {
    fontSize: 12,
    color: theme.sea,
    fontWeight: "600",
    marginTop: 2,
  },
  cruiseDesc: {
    fontSize: 13,
    color: theme.textMuted,
    marginTop: 4,
    lineHeight: 18,
  },
  ctaRow: {
    flexDirection: "row",
    gap: 10,
    paddingHorizontal: 16,
    marginTop: 24,
  },
  primaryBtn: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    backgroundColor: theme.sea,
    paddingVertical: 16,
    borderRadius: 14,
  },
  primaryBtnText: {
    color: theme.white,
    fontWeight: "700",
    fontSize: 15,
  },
  secondaryBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    backgroundColor: theme.white,
    borderWidth: 1.5,
    borderColor: theme.sea,
    paddingVertical: 16,
    paddingHorizontal: 22,
    borderRadius: 14,
  },
  secondaryBtnText: {
    color: theme.sea,
    fontWeight: "700",
    fontSize: 15,
  },
  notice: {
    marginHorizontal: 16,
    marginTop: 20,
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
