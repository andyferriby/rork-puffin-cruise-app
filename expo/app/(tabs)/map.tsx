import { LinearGradient } from "expo-linear-gradient";
import { Anchor, Car, MapPin, Navigation, Waves } from "lucide-react-native";
import React, { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";

type Place = { id: string; title: string; subtitle: string; icon: React.ReactNode; x: `${number}%`; y: `${number}%`; category: "All" | "Sailing" | "Parking" | "Landmark" };

const filters = ["All", "Sailing", "Parking", "Landmark"] as const;

export default function MapScreen() {
  const insets = useSafeAreaInsets();
  const [filter, setFilter] = useState<(typeof filters)[number]>("All");
  const places: Place[] = [
    { id: "office", title: "Booking Office", subtitle: "Check in 20 mins early", icon: <Anchor size={16} color={theme.white} />, x: "24%", y: "66%", category: "Sailing" },
    { id: "pier", title: "Boarding Pier", subtitle: "Crew scan QR tickets here", icon: <Navigation size={16} color={theme.white} />, x: "39%", y: "55%", category: "Sailing" },
    { id: "harbour", title: "Harbour Car Park", subtitle: "Closest parking · NE65 0AP", icon: <Car size={16} color={theme.white} />, x: "17%", y: "78%", category: "Parking" },
    { id: "coquet", title: "Coquet Island", subtitle: "Puffins, seals & lighthouse", icon: <MapPin size={16} color={theme.white} />, x: "75%", y: "28%", category: "Landmark" },
  ];
  const visible = places.filter((p) => filter === "All" || p.category === filter);

  return <View style={styles.root}><ScrollView contentContainerStyle={{ paddingBottom: 36 }}>
    <View style={[styles.header, { paddingTop: insets.top + 16 }]}><Text style={styles.title}>Harbour Map</Text><Text style={styles.subtitle}>Find check-in, boarding, parking and the route to Coquet Island.</Text></View>
    <View style={styles.mapCard}><LinearGradient colors={["#CDEAF7", "#7FC5E7", theme.wave]} style={StyleSheet.absoluteFill} />
      <View style={styles.land} /><View style={styles.island} /><View style={styles.route} /><Waves size={34} color="rgba(255,255,255,0.65)" style={styles.wave1} />
      {visible.map((p) => <View key={p.id} style={[styles.pin, { left: p.x, top: p.y }]}>{p.icon}</View>)}
    </View>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filters}>{filters.map((f) => <Pressable key={f} onPress={() => setFilter(f)} style={[styles.filter, filter === f && styles.filterActive]}><Text style={[styles.filterText, filter === f && styles.filterTextActive]}>{f}</Text></Pressable>)}</ScrollView>
    <View style={styles.list}>{visible.map((p) => <View key={p.id} style={styles.place}><View style={styles.placeIcon}>{p.icon}</View><View style={{ flex: 1 }}><Text style={styles.placeTitle}>{p.title}</Text><Text style={styles.placeSub}>{p.subtitle}</Text></View><Text style={styles.category}>{p.category}</Text></View>)}</View>
  </ScrollView></View>;
}

const styles = StyleSheet.create({ root: { flex: 1, backgroundColor: theme.bg }, header: { paddingHorizontal: 20, paddingBottom: 16 }, title: { fontSize: 34, fontWeight: "900", color: theme.text }, subtitle: { marginTop: 5, color: theme.textMuted, fontSize: 14, lineHeight: 20 }, mapCard: { height: 370, margin: 16, borderRadius: 28, overflow: "hidden", borderWidth: 1, borderColor: theme.border }, land: { position: "absolute", left: -50, bottom: -30, width: 260, height: 190, borderRadius: 90, backgroundColor: theme.sand }, island: { position: "absolute", right: 44, top: 78, width: 104, height: 58, borderRadius: 50, backgroundColor: "#D7C28A" }, route: { position: "absolute", left: "38%", top: "35%", width: 145, height: 2, borderStyle: "dashed", borderWidth: 1, borderColor: theme.white, transform: [{ rotate: "-20deg" }] }, wave1: { position: "absolute", right: 38, bottom: 62 }, pin: { position: "absolute", width: 34, height: 34, marginLeft: -17, marginTop: -17, borderRadius: 17, backgroundColor: theme.coral, alignItems: "center", justifyContent: "center", borderWidth: 3, borderColor: theme.white }, filters: { paddingHorizontal: 16, gap: 8 }, filter: { paddingHorizontal: 14, paddingVertical: 9, borderRadius: 999, backgroundColor: theme.white, borderWidth: 1, borderColor: theme.border }, filterActive: { backgroundColor: theme.sea }, filterText: { color: theme.textMuted, fontWeight: "800" }, filterTextActive: { color: theme.white }, list: { padding: 16, gap: 10 }, place: { flexDirection: "row", alignItems: "center", gap: 12, padding: 14, backgroundColor: theme.white, borderRadius: 16, borderWidth: 1, borderColor: theme.border }, placeIcon: { width: 36, height: 36, borderRadius: 12, backgroundColor: theme.sea, alignItems: "center", justifyContent: "center" }, placeTitle: { fontSize: 16, fontWeight: "800", color: theme.text }, placeSub: { marginTop: 2, color: theme.textMuted, fontSize: 13 }, category: { color: theme.coral, fontSize: 11, fontWeight: "900" } });
