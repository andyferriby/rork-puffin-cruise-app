import { LinearGradient } from "expo-linear-gradient";
import * as Haptics from "expo-haptics";
import { Camera, Check, CloudSun, Compass, LifeBuoy, Palmtree, ShipWheel, Sparkles, Star, Waves } from "lucide-react-native";
import React, { useCallback, useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";

type Sighting = {
  id: string;
  name: string;
  emoji: string;
  hint: string;
  points: number;
};

type TrailStop = {
  id: string;
  title: string;
  clue: string;
  icon: React.ComponentType<{ size?: number; color?: string }>;
};

const sightings: Sighting[] = [
  { id: "puffin", name: "Puffin", emoji: "🐧", hint: "Look for colourful beaks near the burrows", points: 20 },
  { id: "seal", name: "Grey seal", emoji: "🦭", hint: "Watch the rocks on the island edge", points: 15 },
  { id: "tern", name: "Tern", emoji: "🕊️", hint: "Fast white birds diving for fish", points: 10 },
  { id: "eider", name: "Eider duck", emoji: "🦆", hint: "Listen for the soft cooing call", points: 10 },
  { id: "porpoise", name: "Porpoise", emoji: "🐬", hint: "A quick dark fin in open water", points: 30 },
];

const trailStops: TrailStop[] = [
  { id: "harbour", title: "Harbour lookout", clue: "Count three working boats before departure.", icon: ShipWheel },
  { id: "waves", title: "Wave watcher", clue: "Spot the tallest splash as the boat turns seaward.", icon: Waves },
  { id: "island", title: "Island ranger", clue: "Find the lighthouse and point it out to your grown-up.", icon: Compass },
  { id: "safe", title: "Safety skipper", clue: "Show where your lifejacket would be in an emergency.", icon: LifeBuoy },
];

export default function TripScreen() {
  const insets = useSafeAreaInsets();
  const [seenIds, setSeenIds] = useState<string[]>(["puffin"]);
  const [trailIds, setTrailIds] = useState<string[]>(["harbour"]);

  const totalPoints = useMemo<number>(() => {
    return sightings.reduce((sum, item) => sum + (seenIds.includes(item.id) ? item.points : 0), 0);
  }, [seenIds]);

  const toggleSighting = useCallback((id: string) => {
    Haptics.selectionAsync().catch(() => undefined);
    setSeenIds((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }, []);

  const toggleTrail = useCallback((id: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => undefined);
    setTrailIds((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }, []);

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={{ paddingBottom: 38 }} showsVerticalScrollIndicator={false}>
        <View style={[styles.hero, { paddingTop: insets.top + 20 }]}> 
          <LinearGradient colors={[theme.ink, theme.deep, "#0E6A83"]} style={StyleSheet.absoluteFill} />
          <View style={styles.moon} />
          <View style={styles.badge}><Sparkles size={14} color={theme.sand} /><Text style={styles.badgeText}>Live trip mode</Text></View>
          <Text style={styles.title}>Today&apos;s Puffin Adventure</Text>
          <Text style={styles.subtitle}>Boarding, sea outlook, wildlife spotting, kids trail and memory card in one place.</Text>
          <View style={styles.statusCard}>
            <View><Text style={styles.statusLabel}>NEXT CHECK-IN</Text><Text style={styles.statusValue}>Amble Harbour · 12:40</Text></View>
            <View style={styles.liveDot}><Text style={styles.liveText}>LIVE</Text></View>
          </View>
        </View>

        <View style={styles.sectionPad}>
          <View style={styles.weatherCard}>
            <LinearGradient colors={["#EAF7FF", "#FFF5DF"]} style={StyleSheet.absoluteFill} />
            <View style={styles.weatherTop}><CloudSun size={30} color={theme.puffin} /><View><Text style={styles.cardTitle}>Weather & sea conditions</Text><Text style={styles.cardSub}>Updated by crew before sailing</Text></View></View>
            <View style={styles.conditionGrid}>
              <Metric label="Sea" value="Moderate" />
              <Metric label="Wind" value="NE 9 mph" />
              <Metric label="Temp" value="15°C" />
            </View>
            <Text style={styles.advice}>Bring a light jacket — it feels cooler around Coquet Island. Sailing expected to run as planned.</Text>
          </View>

          <View style={styles.memoryCard}>
            <View style={styles.memoryIcon}><Camera size={22} color={theme.white} /></View>
            <View style={{ flex: 1 }}><Text style={styles.memoryTitle}>Photo memories</Text><Text style={styles.memoryText}>After your trip, your best snaps and spotted wildlife become a shareable cruise memory card.</Text></View>
          </View>
        </View>

        <View style={styles.sectionHeader}><Text style={styles.sectionTitle}>Wildlife sighting log</Text><Text style={styles.points}>{totalPoints} pts</Text></View>
        <View style={styles.sightingsList}>
          {sightings.map((item) => {
            const active = seenIds.includes(item.id);
            return <Pressable key={item.id} onPress={() => toggleSighting(item.id)} style={({ pressed }) => [styles.sightingCard, active && styles.sightingActive, pressed && { transform: [{ scale: 0.98 }] }]}>
              <Text style={styles.sightingEmoji}>{item.emoji}</Text>
              <View style={{ flex: 1 }}><Text style={styles.sightingName}>{item.name}</Text><Text style={styles.sightingHint}>{item.hint}</Text></View>
              <View style={[styles.checkBubble, active && styles.checkBubbleActive]}>{active ? <Check size={16} color={theme.white} /> : <Text style={styles.plus}>+</Text>}</View>
            </Pressable>;
          })}
        </View>

        <View style={styles.sectionHeader}><Text style={styles.sectionTitle}>Kids activity trail</Text><Text style={styles.points}>{trailIds.length}/{trailStops.length}</Text></View>
        <View style={styles.trailWrap}>
          {trailStops.map((stop) => {
            const done = trailIds.includes(stop.id);
            const Icon = stop.icon;
            return <Pressable key={stop.id} onPress={() => toggleTrail(stop.id)} style={[styles.trailCard, done && styles.trailDone]}>
              <Icon size={22} color={done ? theme.white : theme.sea} />
              <Text style={[styles.trailTitle, done && { color: theme.white }]}>{stop.title}</Text>
              <Text style={[styles.trailClue, done && { color: "rgba(255,255,255,0.82)" }]}>{stop.clue}</Text>
            </Pressable>;
          })}
        </View>

        <View style={styles.badgePanel}>
          <Palmtree size={22} color={theme.puffin} />
          <View style={{ flex: 1 }}><Text style={styles.badgeTitle}>Junior Island Ranger</Text><Text style={styles.badgeCopy}>Complete the trail and spot 3 animals to unlock a souvenir badge screen.</Text></View>
          <Star size={20} color={theme.sandDeep} fill={theme.sandDeep} />
        </View>
      </ScrollView>
    </View>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return <View style={styles.metric}><Text style={styles.metricLabel}>{label}</Text><Text style={styles.metricValue}>{value}</Text></View>;
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.bg },
  hero: { paddingHorizontal: 20, paddingBottom: 26, overflow: "hidden" },
  moon: { position: "absolute", width: 150, height: 150, borderRadius: 999, backgroundColor: "rgba(244,227,193,0.18)", right: -35, top: 45 },
  badge: { alignSelf: "flex-start", flexDirection: "row", alignItems: "center", gap: 7, paddingHorizontal: 11, paddingVertical: 7, borderRadius: 999, backgroundColor: "rgba(255,255,255,0.13)", marginBottom: 15 },
  badgeText: { color: theme.white, fontSize: 12, fontWeight: "900" as const },
  title: { color: theme.white, fontSize: 35, lineHeight: 38, fontWeight: "900" as const, letterSpacing: -0.8 },
  subtitle: { color: "rgba(255,255,255,0.8)", fontSize: 15, lineHeight: 22, marginTop: 9 },
  statusCard: { marginTop: 20, padding: 15, borderRadius: 20, backgroundColor: "rgba(255,255,255,0.13)", borderWidth: 1, borderColor: "rgba(255,255,255,0.18)", flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  statusLabel: { color: theme.sand, fontSize: 11, fontWeight: "900" as const, letterSpacing: 1 },
  statusValue: { color: theme.white, fontSize: 16, fontWeight: "900" as const, marginTop: 4 },
  liveDot: { backgroundColor: theme.coral, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6 },
  liveText: { color: theme.white, fontSize: 11, fontWeight: "900" as const },
  sectionPad: { padding: 16, gap: 12 },
  weatherCard: { borderRadius: 24, padding: 16, overflow: "hidden", borderWidth: 1, borderColor: theme.border },
  weatherTop: { flexDirection: "row", alignItems: "center", gap: 12 },
  cardTitle: { fontSize: 19, fontWeight: "900" as const, color: theme.text },
  cardSub: { color: theme.textMuted, marginTop: 2, fontSize: 13 },
  conditionGrid: { flexDirection: "row", gap: 8, marginTop: 15 },
  metric: { flex: 1, backgroundColor: "rgba(255,255,255,0.7)", borderRadius: 16, padding: 11 },
  metricLabel: { color: theme.textMuted, fontSize: 11, fontWeight: "800" as const },
  metricValue: { color: theme.deep, fontSize: 14, fontWeight: "900" as const, marginTop: 4 },
  advice: { color: theme.text, fontSize: 13, lineHeight: 19, marginTop: 13 },
  memoryCard: { flexDirection: "row", gap: 12, padding: 16, borderRadius: 22, backgroundColor: theme.white, borderWidth: 1, borderColor: theme.border },
  memoryIcon: { width: 46, height: 46, borderRadius: 16, backgroundColor: theme.sea, alignItems: "center", justifyContent: "center" },
  memoryTitle: { fontSize: 17, fontWeight: "900" as const, color: theme.text },
  memoryText: { color: theme.textMuted, lineHeight: 19, marginTop: 3, fontSize: 13 },
  sectionHeader: { paddingHorizontal: 16, marginTop: 8, marginBottom: 10, flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  sectionTitle: { fontSize: 22, fontWeight: "900" as const, color: theme.text },
  points: { color: theme.puffin, fontWeight: "900" as const },
  sightingsList: { paddingHorizontal: 16, gap: 10 },
  sightingCard: { flexDirection: "row", alignItems: "center", gap: 12, padding: 13, borderRadius: 20, backgroundColor: theme.white, borderWidth: 1, borderColor: theme.border },
  sightingActive: { borderColor: "rgba(255,138,61,0.45)", backgroundColor: "#FFF8EE" },
  sightingEmoji: { fontSize: 32 },
  sightingName: { color: theme.text, fontSize: 16, fontWeight: "900" as const },
  sightingHint: { color: theme.textMuted, fontSize: 12, marginTop: 3 },
  checkBubble: { width: 30, height: 30, borderRadius: 999, backgroundColor: theme.foam, alignItems: "center", justifyContent: "center" },
  checkBubbleActive: { backgroundColor: theme.puffin },
  plus: { color: theme.sea, fontSize: 20, fontWeight: "900" as const },
  trailWrap: { paddingHorizontal: 16, flexDirection: "row", flexWrap: "wrap", gap: 10 },
  trailCard: { width: "48%", minHeight: 142, padding: 14, borderRadius: 22, backgroundColor: theme.white, borderWidth: 1, borderColor: theme.border, gap: 8 },
  trailDone: { backgroundColor: theme.sea, borderColor: theme.sea },
  trailTitle: { color: theme.text, fontSize: 15, fontWeight: "900" as const },
  trailClue: { color: theme.textMuted, fontSize: 12, lineHeight: 17 },
  badgePanel: { margin: 16, padding: 16, borderRadius: 22, backgroundColor: theme.sand, flexDirection: "row", alignItems: "center", gap: 12 },
  badgeTitle: { fontSize: 17, color: theme.deep, fontWeight: "900" as const },
  badgeCopy: { color: theme.sea, fontSize: 12, lineHeight: 17, marginTop: 3 },
});
