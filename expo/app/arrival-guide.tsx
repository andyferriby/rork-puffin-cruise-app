import { LinearGradient } from "expo-linear-gradient";
import { Stack } from "expo-router";
import { Bus, Car, Clock, Info, MapPin, ShieldCheck, Sun } from "lucide-react-native";
import React from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { theme } from "@/constants/theme";

type Item = { emoji: string; title: string; detail: string };
type Section = { title: string; icon: React.ReactNode; items: Item[] };

const sections: Section[] = [
  { title: "Getting Here & Parking", icon: <MapPin size={18} color={theme.coral}/>, items: [
    { emoji: "🗺️", title: "Our Location", detail: "Dave Gray's Puffin Cruises sails from Amble Harbour. Check in at the booking office on Harbour Road before heading to the pier." },
    { emoji: "🅿️", title: "Parking", detail: "Harbour Car Park is the closest option. Leazes Street Car Park is a short walk and can be quieter on peak days." },
    { emoji: "🚌", title: "Public Transport", detail: "The nearest station is Alnmouth, with buses and taxis onward to Amble Harbour." },
  ]},
  { title: "What to Bring", icon: <Sun size={18} color={theme.coral}/>, items: [
    { emoji: "🧥", title: "Warm Layers", detail: "It is cooler at sea even on sunny days. Bring a jumper or waterproof jacket." },
    { emoji: "📸", title: "Camera or Phone", detail: "Puffins and seals are photo-worthy. A zoom lens or binoculars are ideal." },
    { emoji: "👟", title: "Flat Shoes", detail: "Wear non-slip flat shoes. The deck may be wet from spray." },
  ]},
  { title: "On the Day", icon: <Clock size={18} color={theme.coral}/>, items: [
    { emoji: "⏰", title: "Arrive 20 Minutes Early", detail: "We sail on schedule, so please allow time for parking and check-in." },
    { emoji: "🎟️", title: "Check-in", detail: "Show your booking confirmation or QR ticket in the app for scanning." },
    { emoji: "🦺", title: "Safety Briefing", detail: "The skipper gives a short safety talk before departure. Lifejackets are provided." },
  ]},
  { title: "Need to Know", icon: <Info size={18} color={theme.coral}/>, items: [
    { emoji: "🌦️", title: "Weather", detail: "Trips depend on sea conditions. If cancelled, you will be offered a refund or rebooking." },
    { emoji: "♿", title: "Accessibility", detail: "Please call ahead if you need boarding assistance so the crew can prepare the best spot." },
    { emoji: "📞", title: "Contact", detail: "Call the booking office if you are delayed or have questions before travel." },
  ]},
];

export default function ArrivalGuideScreen() {
  return <View style={styles.root}><Stack.Screen options={{ title: "Arrival Guide" }}/><ScrollView contentContainerStyle={{ paddingBottom: 32 }}>
    <View style={styles.hero}><LinearGradient colors={[theme.deep, theme.sea, theme.wave]} style={StyleSheet.absoluteFill}/><Text style={styles.heroEmoji}>⚓</Text><Text style={styles.heroTitle}>Your Arrival Guide</Text><Text style={styles.heroSub}>Everything to know before your cruise.</Text></View>
    <View style={styles.quickRow}><Quick icon={<Car size={18} color={theme.sea}/>} label="Parking"/><Quick icon={<Bus size={18} color={theme.sea}/>} label="Transport"/><Quick icon={<ShieldCheck size={18} color={theme.sea}/>} label="Safety"/></View>
    <View style={styles.sections}>{sections.map((section) => <View key={section.title} style={styles.card}><View style={styles.cardHead}>{section.icon}<Text style={styles.cardTitle}>{section.title}</Text></View>{section.items.map((item) => <View key={item.title} style={styles.item}><Text style={styles.itemEmoji}>{item.emoji}</Text><View style={{ flex: 1 }}><Text style={styles.itemTitle}>{item.title}</Text><Text style={styles.itemDetail}>{item.detail}</Text></View></View>)}</View>)}</View>
  </ScrollView></View>;
}
function Quick({ icon, label }: { icon: React.ReactNode; label: string }) { return <View style={styles.quick}>{icon}<Text style={styles.quickText}>{label}</Text></View>; }
const styles = StyleSheet.create({ root:{flex:1,backgroundColor:theme.bg}, hero:{height:210,paddingHorizontal:24,justifyContent:"flex-end",paddingBottom:28,overflow:"hidden"}, heroEmoji:{fontSize:38}, heroTitle:{marginTop:4,fontSize:30,fontWeight:"900",color:theme.white}, heroSub:{marginTop:6,color:"rgba(255,255,255,0.82)",fontSize:15}, quickRow:{flexDirection:"row",gap:10,padding:16}, quick:{flex:1,alignItems:"center",gap:7,padding:13,borderRadius:16,backgroundColor:theme.white,borderWidth:1,borderColor:theme.border}, quickText:{fontSize:12,fontWeight:"900",color:theme.text}, sections:{paddingHorizontal:16,gap:14}, card:{padding:18,borderRadius:20,backgroundColor:theme.white,borderWidth:1,borderColor:theme.border}, cardHead:{flexDirection:"row",alignItems:"center",gap:9,marginBottom:8}, cardTitle:{fontSize:18,fontWeight:"900",color:theme.text}, item:{flexDirection:"row",gap:13,paddingVertical:12,borderTopWidth:1,borderTopColor:theme.border}, itemEmoji:{fontSize:24,width:34}, itemTitle:{fontSize:15,fontWeight:"900",color:theme.text}, itemDetail:{marginTop:4,fontSize:14,lineHeight:20,color:theme.textMuted} });
