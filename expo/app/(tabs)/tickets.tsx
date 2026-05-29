import { useQuery } from "@tanstack/react-query";
import { Image } from "expo-image";
import { QrCode, Search, Ticket, Wallet } from "lucide-react-native";
import React, { useMemo, useState } from "react";
import { Alert, Linking, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";
import { walletPassUrl } from "@/lib/api";
import { supabase } from "@/lib/supabase";

type Booking = { id: string; cruise_name: string; cruise_date: string; cruise_time: string; adults: number; children: number; customer_email: string; status: string };

function qrCodeUrl(bookingId: string): string {
  return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(bookingId)}&bgcolor=ffffff&color=0B2A4A`;
}

async function fetchBookings(email: string): Promise<Booking[]> {
  if (!email.trim()) return [];
  const { data, error } = await supabase.from("bookings").select("id, cruise_name, cruise_date, cruise_time, adults, children, customer_email, status").ilike("customer_email", email.trim()).in("status", ["paid", "boarded"]).order("cruise_date", { ascending: false }).limit(20);
  if (error) { console.error("[tickets] fetch", error.message); return []; }
  return (data ?? []) as Booking[];
}

async function openWalletPass(bookingId: string): Promise<void> {
  if (Platform.OS !== "ios") {
    Alert.alert("Apple Wallet", "Apple Wallet passes can be added from an iPhone.");
    return;
  }

  const url = walletPassUrl(bookingId);
  const canOpen = await Linking.canOpenURL(url);
  if (!canOpen) {
    Alert.alert("Wallet unavailable", "This device cannot open Apple Wallet passes right now.");
    return;
  }

  await Linking.openURL(url);
}

export default function TicketsScreen() {
  const insets = useSafeAreaInsets();
  const [email, setEmail] = useState<string>("");
  const { data = [], isFetching, refetch } = useQuery({
    queryKey: ["tickets", email],
    queryFn: async () => {
      const bookings = await fetchBookings(email);

      return bookings;
    },
    enabled: false,
  });
  return <View style={styles.root}><ScrollView contentContainerStyle={{ paddingBottom: 36 }} keyboardShouldPersistTaps="handled">
    <View style={[styles.header, { paddingTop: insets.top + 16 }]}><Text style={styles.title}>Tickets</Text><Text style={styles.subtitle}>Find your QR boarding passes by email.</Text></View>
    <View style={styles.searchCard}><View style={styles.field}><Search size={17} color={theme.textMuted}/><TextInput value={email} onChangeText={setEmail} placeholder="Email used for booking" placeholderTextColor={theme.textMuted} autoCapitalize="none" keyboardType="email-address" style={styles.input}/></View><Pressable onPress={() => refetch()} style={styles.button}><Text style={styles.buttonText}>{isFetching ? "Searching…" : "Find tickets"}</Text></Pressable></View>
    {data.length === 0 ? <View style={styles.empty}><Ticket size={42} color={theme.textMuted}/><Text style={styles.emptyTitle}>No tickets loaded</Text><Text style={styles.emptyText}>Enter your booking email to show your boarding passes.</Text></View> : <View style={styles.list}>{data.map((b) => <View key={b.id} style={styles.ticket}><View style={styles.ticketTop}><View><Text style={styles.cruise}>{b.cruise_name}</Text><Text style={styles.meta}>{new Date(b.cruise_date).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" })} · {b.cruise_time}</Text><Text style={styles.meta}>{b.adults} adult{b.adults === 1 ? "" : "s"} · {b.children} child{b.children === 1 ? "" : "ren"}</Text></View><View style={styles.qr}><Image source={{ uri: qrCodeUrl(b.id) }} style={{ width: 68, height: 68 }} contentFit="contain" /></View></View><View style={styles.dashed}/><View style={styles.ticketBottom}><Text style={styles.status}>{b.status.toUpperCase()}</Text><Pressable onPress={() => openWalletPass(b.id)} style={styles.walletButton}><Wallet size={14} color={theme.white}/><Text style={styles.walletButtonText}>Add to Wallet</Text></Pressable></View></View>)}</View>}
  </ScrollView></View>;
}
const styles = StyleSheet.create({ root:{flex:1,backgroundColor:theme.bg}, header:{paddingHorizontal:20,paddingBottom:14}, title:{fontSize:34,fontWeight:"900",color:theme.text}, subtitle:{marginTop:4,color:theme.textMuted,fontSize:14}, searchCard:{margin:16,padding:16,borderRadius:20,backgroundColor:theme.white,borderWidth:1,borderColor:theme.border,gap:12}, field:{height:48,borderRadius:14,backgroundColor:theme.bg,flexDirection:"row",alignItems:"center",gap:10,paddingHorizontal:12}, input:{flex:1,color:theme.text,fontSize:15}, button:{height:48,borderRadius:14,backgroundColor:theme.sea,alignItems:"center",justifyContent:"center"}, buttonText:{color:theme.white,fontWeight:"900",fontSize:15}, empty:{alignItems:"center",padding:36,margin:16,borderRadius:22,backgroundColor:theme.white,borderWidth:1,borderColor:theme.border}, emptyTitle:{marginTop:14,fontSize:18,fontWeight:"900",color:theme.text}, emptyText:{marginTop:6,textAlign:"center",color:theme.textMuted,lineHeight:20}, list:{padding:16,gap:14}, ticket:{backgroundColor:theme.white,borderRadius:22,padding:16,borderWidth:1,borderColor:theme.border}, ticketTop:{flexDirection:"row",justifyContent:"space-between",gap:12}, cruise:{fontSize:18,fontWeight:"900",color:theme.text}, meta:{marginTop:4,color:theme.textMuted,fontSize:13}, qr:{width:78,height:78,borderRadius:16,backgroundColor:theme.foam,alignItems:"center",justifyContent:"center"}, dashed:{borderStyle:"dashed",borderTopWidth:1,borderColor:theme.border,marginVertical:14}, ticketBottom:{flexDirection:"row",justifyContent:"space-between",alignItems:"center",gap:8}, status:{color:theme.coral,fontSize:12,fontWeight:"900"}, walletButton:{minHeight:36,paddingHorizontal:12,borderRadius:999,backgroundColor:theme.sea,flexDirection:"row",alignItems:"center",justifyContent:"center",gap:6}, walletButtonText:{fontSize:12,color:theme.white,fontWeight:"900"} });
