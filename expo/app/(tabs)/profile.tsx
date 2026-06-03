import AsyncStorage from "@react-native-async-storage/async-storage";
import { useQuery } from "@tanstack/react-query";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import { Gift, MapPinned, Share2, Star, Trophy } from "lucide-react-native";
import React, { useEffect, useMemo, useState } from "react";
import { Linking, Pressable, ScrollView, Share, StyleSheet, Text, TextInput, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";
import { supabase } from "@/lib/supabase";

type Booking = { id: string; cruise_date: string; cruise_name: string; customer_email: string; status: string };
type Tier = { name: string; emoji: string; minTrips: number; colors: readonly [string, string]; benefits: string[] };

const REFERRAL_KEY = "@puffin_referral_code";
const tiers: Tier[] = [
  { name: "Bronze", emoji: "🥉", minTrips: 0, colors: ["#CD7F32", "#8B5521"], benefits: ["Access to Puffin Club", "Birthday treat on us"] },
  { name: "Silver", emoji: "🥈", minTrips: 3, colors: ["#B8C6D4", "#6B7B8D"], benefits: ["5% off future bookings", "Priority boarding", "Free hot drink"] },
  { name: "Gold", emoji: "🥇", minTrips: 6, colors: ["#E8C84A", "#A67C1E"], benefits: ["10% off future bookings", "Best seats", "Sunset sail invites"] },
  { name: "Platinum", emoji: "💎", minTrips: 12, colors: ["#9BAAEA", "#4A5DB0"], benefits: ["15% off bookings", "VIP boarding", "Free guest pass twice a year"] },
];

async function fetchBookings(email: string): Promise<Booking[]> {
  if (!email.trim()) return [];
  const { data, error } = await supabase.from("bookings").select("id, cruise_date, cruise_name, customer_email, status").ilike("customer_email", email.trim()).order("cruise_date", { ascending: false }).limit(40);
  if (error) { console.error("[profile] bookings", error.message); return []; }
  return (data ?? []) as Booking[];
}

function makeCode(): string { return `PUFFIN-${Math.random().toString(36).slice(2, 8).toUpperCase()}`; }

export default function ProfileScreen() {
  const insets = useSafeAreaInsets();
  const [email, setEmail] = useState<string>("");
  const [referralCode, setReferralCode] = useState<string>("");
  const { data = [], refetch, isFetching } = useQuery({ queryKey: ["profile-bookings", email], queryFn: () => fetchBookings(email), enabled: false });

  useEffect(() => {
    AsyncStorage.getItem(REFERRAL_KEY).then(async (saved) => { const code = saved ?? makeCode(); setReferralCode(code); if (!saved) await AsyncStorage.setItem(REFERRAL_KEY, code); });
  }, []);

  const completedTrips = data.filter((b) => b.status === "paid" || new Date(b.cruise_date) < new Date()).length;
  const tier = useMemo<Tier>(() => [...tiers].reverse().find((t) => completedTrips >= t.minTrips) ?? tiers[0], [completedTrips]);
  const next = tiers.find((t) => t.minTrips > completedTrips) ?? null;
  const progress = next ? completedTrips / next.minTrips : 1;

  const shareReferral = async (): Promise<void> => { await Share.share({ message: `Book a Puffin Cruise from Amble and use my referral code ${referralCode} for rewards: ${process.env.EXPO_PUBLIC_RORK_AUTH_URL ?? ""}` }); };

  return <View style={styles.root}><ScrollView contentContainerStyle={{ paddingBottom: 36 }} keyboardShouldPersistTaps="handled">
    <View style={[styles.header, { paddingTop: insets.top + 16 }]}><Text style={styles.title}>Profile</Text><Text style={styles.subtitle}>Puffin Club rewards, referrals and arrival info.</Text></View>

    <View style={styles.lookup}><Text style={styles.lookupTitle}>Load your rewards</Text><TextInput value={email} onChangeText={setEmail} placeholder="Email used for bookings" placeholderTextColor={theme.textMuted} keyboardType="email-address" autoCapitalize="none" style={styles.input}/><Pressable onPress={() => refetch()} style={styles.lookupBtn}><Text style={styles.lookupBtnText}>{isFetching ? "Loading…" : "Load trips"}</Text></Pressable></View>
    <LinearGradient colors={tier.colors} style={styles.loyalty}><View style={styles.loyaltyHead}><Text style={styles.tierEmoji}>{tier.emoji}</Text><View><Text style={styles.tierTitle}>Puffin Club · {tier.name}</Text><Text style={styles.tierMeta}>{completedTrips} trips · {completedTrips * 100} points</Text></View></View><View style={styles.progressTrack}><View style={[styles.progressFill, { width: `${Math.max(8, progress * 100)}%` }]}/></View><Text style={styles.nextText}>{next ? `${next.minTrips - completedTrips} more trip${next.minTrips - completedTrips === 1 ? "" : "s"} to ${next.name}` : "Top tier unlocked"}</Text></LinearGradient>
    <View style={styles.card}><View style={styles.cardHead}><Star size={17} color={theme.puffin}/><Text style={styles.cardTitle}>Your Benefits</Text></View>{tier.benefits.map((b) => <View key={b} style={styles.benefit}><Text style={styles.check}>✓</Text><Text style={styles.benefitText}>{b}</Text></View>)}</View>
    <View style={styles.actions}><Pressable onPress={shareReferral} style={styles.action}><Share2 size={22} color={theme.sea}/><Text style={styles.actionTitle}>Refer a friend</Text><Text style={styles.actionSub}>{referralCode || "Loading code…"}</Text></Pressable><Pressable onPress={() => router.push("/arrival-guide")} style={styles.action}><MapPinned size={22} color={theme.sea}/><Text style={styles.actionTitle}>Arrival guide</Text><Text style={styles.actionSub}>Parking, check-in, what to bring</Text></Pressable></View>
    <View style={styles.card}><View style={styles.cardHead}><Trophy size={17} color={theme.puffin}/><Text style={styles.cardTitle}>Trip History</Text></View>{data.length === 0 ? <Text style={styles.empty}>Load your email to see past and upcoming cruises.</Text> : data.slice(0, 6).map((b) => <View key={b.id} style={styles.trip}><Gift size={16} color={theme.sea}/><View><Text style={styles.tripTitle}>{b.cruise_name}</Text><Text style={styles.tripDate}>{new Date(b.cruise_date).toLocaleDateString("en-GB")}</Text></View></View>)}</View>
  </ScrollView></View>;
}
const styles = StyleSheet.create({
  root:{flex:1,backgroundColor:theme.bg},
  header:{paddingHorizontal:20,paddingBottom:14},
  title:{fontSize:34,fontWeight:"900",color:theme.text},
  subtitle:{marginTop:4,color:theme.textMuted,fontSize:14},
  lookup:{margin:16,padding:16,borderRadius:20,backgroundColor:theme.white,borderWidth:1,borderColor:theme.border,gap:10},
  lookupTitle:{fontSize:17,fontWeight:"900",color:theme.text},
  input:{height:48,borderRadius:14,backgroundColor:theme.bg,paddingHorizontal:14,color:theme.text},
  lookupBtn:{height:48,borderRadius:14,backgroundColor:theme.sea,alignItems:"center",justifyContent:"center"},
  lookupBtnText:{color:theme.white,fontWeight:"900"},
  loyalty:{marginHorizontal:16,padding:20,borderRadius:22},
  loyaltyHead:{flexDirection:"row",alignItems:"center",gap:12},
  tierEmoji:{fontSize:42},
  tierTitle:{color:theme.white,fontSize:20,fontWeight:"900"},
  tierMeta:{marginTop:3,color:"rgba(255,255,255,0.8)",fontWeight:"700"},
  progressTrack:{height:8,borderRadius:4,backgroundColor:"rgba(255,255,255,0.25)",marginTop:18,overflow:"hidden"},
  progressFill:{height:8,borderRadius:4,backgroundColor:theme.white},
  nextText:{marginTop:9,color:"rgba(255,255,255,0.82)",fontWeight:"800",fontSize:12},
  card:{margin:16,marginBottom:0,padding:18,borderRadius:20,backgroundColor:theme.white,borderWidth:1,borderColor:theme.border},
  cardHead:{flexDirection:"row",alignItems:"center",gap:8,marginBottom:10},
  cardTitle:{fontSize:18,fontWeight:"900",color:theme.text},
  benefit:{flexDirection:"row",alignItems:"center",gap:10,paddingVertical:8},
  check:{color:theme.sea,fontWeight:"900",fontSize:17},
  benefitText:{color:theme.text,fontSize:15},
  actions:{padding:16,gap:12},
  action:{padding:18,borderRadius:20,backgroundColor:theme.foam,borderWidth:1,borderColor:theme.border},
  actionTitle:{marginTop:10,fontSize:17,fontWeight:"900",color:theme.text},
  actionSub:{marginTop:4,color:theme.textMuted,fontSize:13},
  empty:{color:theme.textMuted,lineHeight:20},
  trip:{flexDirection:"row",alignItems:"center",gap:10,paddingVertical:6},
  tripTitle:{fontWeight:"800",color:theme.text},
  tripDate:{marginTop:2,color:theme.textMuted,fontSize:13},
});
