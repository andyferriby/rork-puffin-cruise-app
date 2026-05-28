import { LinearGradient } from "expo-linear-gradient";
import { Bird, CalendarDays, PawPrint, Sparkles } from "lucide-react-native";
import React from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";

type Species = { emoji: string; name: string; season: string; fact: string; accent: string };
const species: Species[] = [
  { emoji: "🐧", name: "Puffins", season: "Best: Apr–Jul", fact: "Coquet Island hosts one of the UK's favourite puffin colonies. Look for orange beaks skimming low over the waves.", accent: theme.puffin },
  { emoji: "🦭", name: "Grey Seals", season: "Year-round", fact: "Often seen hauled out on rocks around the island. Pups arrive later in the season.", accent: theme.sea },
  { emoji: "🕊️", name: "Arctic Terns", season: "May–Aug", fact: "Tiny, fierce and world-travelling. They migrate from pole to pole each year.", accent: theme.coral },
  { emoji: "🦆", name: "Eider Ducks", season: "Spring–Summer", fact: "Locally known as Cuddy ducks, with soft calls and smart black-and-white plumage.", accent: theme.sandDeep },
];

export default function WildlifeScreen() {
  const insets = useSafeAreaInsets();
  return <View style={styles.root}><ScrollView contentContainerStyle={{ paddingBottom: 36 }}>
    <View style={[styles.hero, { paddingTop: insets.top + 22 }]}><LinearGradient colors={[theme.deep, theme.sea, theme.wave]} style={StyleSheet.absoluteFill} /><View style={styles.badge}><PawPrint size={14} color={theme.white}/><Text style={styles.badgeText}>Coquet Island guide</Text></View><Text style={styles.title}>Wildlife Spotter</Text><Text style={styles.subtitle}>Know what to watch for before you reach the island.</Text></View>
    <View style={styles.tip}><Sparkles size={18} color={theme.puffin}/><Text style={styles.tipText}>Top tip: bring binoculars or use your phone's zoom gently — puffins move fast.</Text></View>
    <View style={styles.grid}>{species.map((s) => <View key={s.name} style={styles.card}><View style={[styles.emojiWrap, { backgroundColor: `${s.accent}22` }]}><Text style={styles.emoji}>{s.emoji}</Text></View><View style={{ flex: 1 }}><Text style={styles.name}>{s.name}</Text><View style={styles.season}><CalendarDays size={12} color={s.accent}/><Text style={[styles.seasonText, { color: s.accent }]}>{s.season}</Text></View><Text style={styles.fact}>{s.fact}</Text></View></View>)}</View>
    <View style={styles.note}><Bird size={20} color={theme.sea}/><Text style={styles.noteTitle}>Respect the colony</Text><Text style={styles.noteBody}>Coquet Island is protected. Boats keep a respectful distance and crew commentary helps you spot wildlife without disturbing nesting birds.</Text></View>
  </ScrollView></View>;
}
const styles = StyleSheet.create({ root:{flex:1,backgroundColor:theme.bg}, hero:{paddingHorizontal:20,paddingBottom:34,overflow:"hidden"}, badge:{alignSelf:"flex-start",flexDirection:"row",gap:7,alignItems:"center",paddingHorizontal:10,paddingVertical:7,borderRadius:999,backgroundColor:"rgba(255,255,255,0.16)",marginBottom:16}, badgeText:{color:theme.white,fontWeight:"800",fontSize:12}, title:{fontSize:36,fontWeight:"900",color:theme.white}, subtitle:{marginTop:8,color:"rgba(255,255,255,0.82)",fontSize:16,lineHeight:23}, tip:{margin:16,padding:16,borderRadius:18,backgroundColor:theme.white,flexDirection:"row",gap:12,borderWidth:1,borderColor:theme.border}, tipText:{flex:1,color:theme.text,fontSize:14,lineHeight:20,fontWeight:"600"}, grid:{paddingHorizontal:16,gap:12}, card:{backgroundColor:theme.white,borderRadius:20,padding:16,flexDirection:"row",gap:14,borderWidth:1,borderColor:theme.border}, emojiWrap:{width:58,height:58,borderRadius:18,alignItems:"center",justifyContent:"center"}, emoji:{fontSize:32}, name:{fontSize:19,fontWeight:"900",color:theme.text}, season:{flexDirection:"row",gap:5,alignItems:"center",marginTop:4}, seasonText:{fontSize:12,fontWeight:"900"}, fact:{marginTop:9,color:theme.textMuted,fontSize:14,lineHeight:20}, note:{margin:16,padding:18,borderRadius:20,backgroundColor:theme.foam,borderWidth:1,borderColor:theme.border}, noteTitle:{marginTop:10,fontSize:18,fontWeight:"900",color:theme.text}, noteBody:{marginTop:6,color:theme.textMuted,lineHeight:20} });
