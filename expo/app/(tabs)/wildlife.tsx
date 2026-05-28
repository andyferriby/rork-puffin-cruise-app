import { LinearGradient } from "expo-linear-gradient";
import { Bird, CalendarDays, ChevronDown, Fish, Leaf, MapPin, Sparkles } from "lucide-react-native";
import React, { useMemo, useState } from "react";
import { LayoutAnimation, Platform, Pressable, ScrollView, StyleSheet, Text, UIManager, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";

if (Platform.OS === "android" && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

type Category = "Birds" | "Marine Life" | "Coastal Life";

type Species = {
  id: string;
  name: string;
  latinName: string;
  emoji: string;
  description: string;
  funFacts: string[];
  bestSeason: string;
  whereToSpot: string;
  category: Category;
};

const categoryColor: Record<Category, string> = {
  "Birds": theme.sea,
  "Marine Life": theme.wave,
  "Coastal Life": "#3A8C6E",
};

const species: Species[] = [
  {
    id: "puffin",
    name: "Atlantic Puffin",
    latinName: "Fratercula arctica",
    emoji: "🐧",
    description:
      "The star of Coquet Island. Around 45,000 puffins nest here each summer, making it one of the UK's most important puffin colonies. Watch them dive for sand eels, waddle across the cliffs, and return to their burrows with beaks full of fish.",
    funFacts: [
      "Puffins can dive up to 60 metres deep.",
      "They mate for life and return to the same burrow each year.",
      "A baby puffin is called a 'puffling'.",
      "Their colourful beaks fade to grey in winter and brighten for breeding season.",
    ],
    bestSeason: "April – July (peak June)",
    whereToSpot: "All around Coquet Island; best viewed from the upper deck.",
    category: "Birds",
  },
  {
    id: "grey-seal",
    name: "Grey Seal",
    latinName: "Halichoerus grypus",
    emoji: "🦭",
    description:
      "Coquet Island's rocky shores are home to a thriving grey seal colony. These curious, intelligent mammals can often be seen lounging on the rocks or popping their heads above water to watch the boat go by. Pups are born with white coats in autumn.",
    funFacts: [
      "Grey seals can hold their breath for up to 20 minutes.",
      "The UK has around 40% of the world's grey seal population.",
      "Pups triple their birth weight in just 3 weeks on rich milk.",
      "They can recognise individual boat engines and voices.",
    ],
    bestSeason: "Year-round; pups born September – November",
    whereToSpot: "Rocky ledges on the eastern side of Coquet Island.",
    category: "Marine Life",
  },
  {
    id: "arctic-tern",
    name: "Arctic Tern",
    latinName: "Sterna paradisaea",
    emoji: "🕊️",
    description:
      "The ultimate long-distance traveller. Arctic terns migrate from Antarctica to Coquet Island each spring — a round trip of over 70,000 km. Watch these elegant, fork-tailed birds hover and plunge-dive for small fish in the waters around the island.",
    funFacts: [
      "Arctic terns see more daylight than any other creature — they chase the summer at both poles.",
      "They can live over 30 years.",
      "One tracked tern flew 96,000 km in a single year.",
      "They aggressively defend their nests — watch from a safe distance!",
    ],
    bestSeason: "May – August",
    whereToSpot: "Skimming the water near the island's northern shore.",
    category: "Birds",
  },
  {
    id: "roseate-tern",
    name: "Roseate Tern",
    latinName: "Sterna dougallii",
    emoji: "🪶",
    description:
      "Coquet Island hosts the UK's largest colony of roseate terns — one of Britain's rarest breeding seabirds. Their delicate pinkish breast feathers and graceful flight make them a photographer's dream. The RSPB wardens protect them around the clock.",
    funFacts: [
      "Coquet Island holds over 90% of the UK's breeding roseate terns.",
      "They nest in specially built boxes to protect them from gulls.",
      "Their name comes from the rosy flush on their breast plumage.",
      "They are strictly protected — landing on Coquet Island is prohibited.",
    ],
    bestSeason: "May – July",
    whereToSpot: "Nest boxes visible from the boat; look for the pink-tinged breast.",
    category: "Birds",
  },
  {
    id: "common-eider",
    name: "Common Eider",
    latinName: "Somateria mollissima",
    emoji: "🦆",
    description:
      "The UK's heaviest and fastest-flying duck. Eiders are famous for their soft down feathers, which the females pluck from their own breast to line their nests. Listen for their gentle, cooing 'ah-ooo' call drifting across the water.",
    funFacts: [
      "Eiderdown has been harvested sustainably in Northumberland for centuries.",
      "Females fast for the entire 26-day incubation period.",
      "Ducklings form crèches watched over by several females.",
      "They can fly at speeds up to 70 mph.",
    ],
    bestSeason: "Year-round; ducklings May – June",
    whereToSpot: "Close to shore around the island; often in large rafts.",
    category: "Birds",
  },
  {
    id: "harbour-porpoise",
    name: "Harbour Porpoise",
    latinName: "Phocoena phocoena",
    emoji: "🐬",
    description:
      "Keep your eyes peeled for these shy, smaller cousins of dolphins. Harbour porpoises are regular visitors to the waters off Amble. You'll spot a brief glimpse of a small, dark triangular fin rolling through the water — no splash, no acrobatics, just a quiet, magical moment.",
    funFacts: [
      "Porpoises are about 1.5m long — much smaller than dolphins.",
      "They surface quietly without the splash dolphins are known for.",
      "They use echolocation clicks to hunt fish in murky water.",
      "Often seen alone or in small groups of 2–5.",
    ],
    bestSeason: "July – October (most frequent)",
    whereToSpot: "Open water between Amble Harbour and Coquet Island.",
    category: "Marine Life",
  },
  {
    id: "guillemot",
    name: "Common Guillemot",
    latinName: "Uria aalge",
    emoji: "🐦",
    description:
      "Guillemots crowd the cliff ledges of Coquet Island in dense, noisy colonies. These chocolate-brown 'flying penguins' stand upright on the rocks, laying a single pear-shaped egg directly on the bare ledge. Their pointed eggs are designed to roll in a circle rather than off the cliff.",
    funFacts: [
      "Guillemot eggs are pear-shaped to prevent them rolling off ledges.",
      "Each egg has a unique speckled pattern so parents recognise it.",
      "Chicks leap off the cliff into the sea before they can fly — at just 3 weeks old.",
      "The father stays with the chick at sea for up to 2 months.",
    ],
    bestSeason: "April – July",
    whereToSpot: "Dense clusters on the cliff ledges.",
    category: "Birds",
  },
  {
    id: "kittiwake",
    name: "Kittiwake",
    latinName: "Rissa tridactyla",
    emoji: "🕊️",
    description:
      "The most graceful of the gulls, kittiwakes are true ocean-going seabirds that only come to land to breed. Their name comes from their distinctive 'kitti-waak' call. Unlike other gulls, they spend their winters far out in the North Atlantic.",
    funFacts: [
      "Kittiwakes are the only gull species that are truly pelagic (ocean-going).",
      "They build mud-and-grass nests on impossibly narrow cliff ledges.",
      "They have black legs — unlike the pink legs of most gulls.",
      "A kittiwake may fly over 1,000 km to find food for its chicks.",
    ],
    bestSeason: "April – August",
    whereToSpot: "Vertical cliff faces and ledges; listen for the namesake call.",
    category: "Birds",
  },
];

const allCategories: Category[] = ["Birds", "Marine Life", "Coastal Life"];

export default function WildlifeScreen() {
  const insets = useSafeAreaInsets();
  const [selected, setSelected] = useState<Category | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>("puffin");

  const filtered = useMemo(() => {
    if (!selected) return species;
    return species.filter((s) => s.category === selected);
  }, [selected]);

  const toggle = (id: string) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setExpandedId((prev) => (prev === id ? null : id));
  };

  const setCat = (cat: Category | null) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setSelected(cat);
  };

  const iconFor = (cat: Category) => {
    if (cat === "Birds") return Bird;
    if (cat === "Marine Life") return Fish;
    return Leaf;
  };

  return (
    <View style={styles.root}>
      <View style={[styles.hero, { paddingTop: insets.top + 22 }]}>
        <LinearGradient colors={[theme.deep, theme.sea, theme.wave]} style={StyleSheet.absoluteFill} />
        <View style={styles.badge}>
          <Sparkles size={14} color={theme.white} />
          <Text style={styles.badgeText}>Coquet Island guide</Text>
        </View>
        <Text style={styles.title}>Wildlife Spotter</Text>
        <Text style={styles.subtitle}>Tap a species to see fun facts, season and where to spot them.</Text>
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.chipsRow}
      >
        <Chip active={selected === null} color={theme.sea} icon={Sparkles} label="All" onPress={() => setCat(null)} />
        {allCategories.map((cat) => {
          const Icon = iconFor(cat);
          return (
            <Chip
              key={cat}
              active={selected === cat}
              color={categoryColor[cat]}
              icon={Icon}
              label={cat}
              onPress={() => setCat(cat)}
            />
          );
        })}
      </ScrollView>

      <ScrollView contentContainerStyle={{ paddingBottom: 36, paddingHorizontal: 16, gap: 14 }}>
        {filtered.map((sp) => {
          const isOpen = expandedId === sp.id;
          const accent = categoryColor[sp.category];
          return (
            <Pressable
              key={sp.id}
              onPress={() => toggle(sp.id)}
              android_ripple={{ color: `${accent}22` }}
              style={({ pressed }) => [styles.card, pressed && { opacity: 0.96, transform: [{ scale: 0.998 }] }]}
            >
              <View style={[styles.cardHeader]}>
                <LinearGradient
                  colors={[accent, `${accent}99`]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={StyleSheet.absoluteFill}
                />
                <View style={styles.decorCircle} />
                <Text style={styles.emojiBig}>{sp.emoji}</Text>
                <View style={styles.headerText}>
                  <Text style={styles.speciesName}>{sp.name}</Text>
                  <Text style={styles.latin}>{sp.latinName}</Text>
                </View>
                <View style={styles.chevWrap}>
                  <ChevronDown
                    size={20}
                    color={theme.white}
                    style={{ transform: [{ rotate: isOpen ? "180deg" : "0deg" }] }}
                  />
                </View>
              </View>

              {isOpen && (
                <View style={styles.details}>
                  <Text style={styles.description}>{sp.description}</Text>

                  <View style={styles.pillsRow}>
                    <InfoPill icon={CalendarDays} label={sp.bestSeason} color={theme.puffin} />
                    <InfoPill icon={MapPin} label={sp.whereToSpot} color={theme.coral} />
                  </View>

                  <View style={[styles.factsBox, { backgroundColor: `${accent}10` }]}>
                    <Text style={[styles.factsTitle, { color: accent }]}>DID YOU KNOW?</Text>
                    {sp.funFacts.map((fact, i) => (
                      <View key={`${sp.id}-${i}`} style={styles.factRow}>
                        <View style={[styles.factNum, { backgroundColor: accent }]}>
                          <Text style={styles.factNumText}>{i + 1}</Text>
                        </View>
                        <Text style={styles.factText}>{fact}</Text>
                      </View>
                    ))}
                  </View>
                </View>
              )}
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
}

function Chip({
  active,
  color,
  icon: Icon,
  label,
  onPress,
}: {
  active: boolean;
  color: string;
  icon: React.ComponentType<{ size?: number; color?: string }>;
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.chip,
        { backgroundColor: active ? color : `${color}14` },
        pressed && { opacity: 0.85 },
      ]}
    >
      <Icon size={13} color={active ? theme.white : color} />
      <Text style={[styles.chipText, { color: active ? theme.white : color }]}>{label}</Text>
    </Pressable>
  );
}

function InfoPill({
  icon: Icon,
  label,
  color,
}: {
  icon: React.ComponentType<{ size?: number; color?: string }>;
  label: string;
  color: string;
}) {
  return (
    <View style={[styles.pill, { backgroundColor: `${color}1A` }]}>
      <Icon size={11} color={color} />
      <Text style={[styles.pillText, { color }]} numberOfLines={2}>
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.bg },
  hero: { paddingHorizontal: 20, paddingBottom: 26, overflow: "hidden" },
  badge: {
    alignSelf: "flex-start",
    flexDirection: "row",
    gap: 7,
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.16)",
    marginBottom: 16,
  },
  badgeText: { color: theme.white, fontWeight: "800" as const, fontSize: 12 },
  title: { fontSize: 34, fontWeight: "900" as const, color: theme.white },
  subtitle: { marginTop: 8, color: "rgba(255,255,255,0.82)", fontSize: 15, lineHeight: 22 },
  chipsRow: { paddingHorizontal: 16, paddingVertical: 12, gap: 8 },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: 999,
    marginRight: 8,
  },
  chipText: { fontSize: 13, fontWeight: "800" as const },
  card: {
    backgroundColor: theme.card,
    borderRadius: 22,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: theme.border,
    shadowColor: theme.deep,
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 3,
  },
  cardHeader: {
    height: 130,
    paddingHorizontal: 18,
    paddingVertical: 16,
    justifyContent: "flex-end",
    overflow: "hidden",
  },
  decorCircle: {
    position: "absolute",
    width: 110,
    height: 110,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.08)",
    right: -20,
    top: -30,
  },
  emojiBig: { position: "absolute", right: 14, top: 8, fontSize: 76 },
  headerText: { paddingRight: 80 },
  speciesName: { fontSize: 22, fontWeight: "900" as const, color: theme.white },
  latin: { fontSize: 13, fontStyle: "italic", color: "rgba(255,255,255,0.78)", marginTop: 2 },
  chevWrap: {
    position: "absolute",
    top: 14,
    right: 14,
    width: 30,
    height: 30,
    borderRadius: 999,
    backgroundColor: "rgba(0,0,0,0.18)",
    alignItems: "center",
    justifyContent: "center",
  },
  details: { padding: 18, gap: 14 },
  description: { fontSize: 14, lineHeight: 21, color: theme.text },
  pillsRow: { flexDirection: "row", gap: 8, flexWrap: "wrap" },
  pill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    maxWidth: "100%",
  },
  pillText: { fontSize: 11, fontWeight: "700" as const, flexShrink: 1 },
  factsBox: { padding: 14, borderRadius: 14, gap: 8 },
  factsTitle: { fontSize: 11, fontWeight: "900" as const, letterSpacing: 1.2 },
  factRow: { flexDirection: "row", gap: 10, alignItems: "flex-start" },
  factNum: { width: 22, height: 22, borderRadius: 999, alignItems: "center", justifyContent: "center" },
  factNumText: { color: theme.white, fontSize: 11, fontWeight: "900" as const },
  factText: { flex: 1, fontSize: 13, lineHeight: 19, color: theme.text },
});
