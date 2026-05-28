import AsyncStorage from "@react-native-async-storage/async-storage";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import { ArrowRight } from "lucide-react-native";
import React, { useMemo, useState } from "react";
import { FlatList, Pressable, StyleSheet, Text, useWindowDimensions, View, type ViewToken } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";

const ONBOARDING_KEY = "@puffin_has_seen_onboarding";

type Slide = { emoji: string; title: string; subtitle: string; colors: readonly [string, string] };

const slides: Slide[] = [
  { emoji: "⛴️", title: "Welcome to\nPuffin Cruises", subtitle: "Book family-run wildlife adventures from Amble Harbour to Coquet Island.", colors: [theme.deep, theme.sea] },
  { emoji: "📅", title: "Book Your\nAdventure", subtitle: "Choose your cruise, sailing time, passengers and pay securely by card.", colors: [theme.sea, theme.wave] },
  { emoji: "🦭", title: "Meet the\nWildlife", subtitle: "Use the wildlife guide to spot puffins, seals, Arctic terns and island birds.", colors: [theme.coral, theme.puffin] },
  { emoji: "🎟️", title: "Tickets &\nRewards", subtitle: "Keep boarding passes in the app and earn Puffin Club perks as you sail.", colors: [theme.puffin, theme.sandDeep] },
  { emoji: "⚓", title: "Ready to\nSet Sail?", subtitle: "Check the arrival guide before you come and refer friends for rewards.", colors: [theme.ink, theme.deep] },
];

export { ONBOARDING_KEY };

export default function OnboardingScreen() {
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const [page, setPage] = useState<number>(0);
  const listRef = React.useRef<FlatList<Slide>>(null);
  const isLast = page === slides.length - 1;

  const finish = async (): Promise<void> => {
    await AsyncStorage.setItem(ONBOARDING_KEY, "true");
    router.replace("/(tabs)");
  };

  const goNext = (): void => {
    const next = Math.min(page + 1, slides.length - 1);
    listRef.current?.scrollToIndex({ index: next, animated: true });
    setPage(next);
  };

  const onViewableItemsChanged = useMemo(() => ({ viewableItems }: { viewableItems: ViewToken[] }) => {
    const first = viewableItems[0];
    if (first && typeof first.index === "number") setPage(first.index);
  }, []);

  const viewabilityConfig = useMemo(() => ({ itemVisiblePercentThreshold: 60 }), []);

  return (
    <View style={styles.root}>
      <LinearGradient colors={[theme.ink, theme.deep]} style={StyleSheet.absoluteFill} />
      <View style={[styles.top, { paddingTop: insets.top + 12 }]}>
        {!isLast ? <Pressable onPress={finish}><Text style={styles.skip}>Skip</Text></Pressable> : <View />}
      </View>
      <FlatList
        ref={listRef}
        data={slides}
        keyExtractor={(item) => item.title}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onViewableItemsChanged={onViewableItemsChanged}
        viewabilityConfig={viewabilityConfig}
        getItemLayout={(_, index) => ({ length: width, offset: width * index, index })}
        renderItem={({ item }) => (
          <View style={[styles.slide, { width }]}>
            <LinearGradient colors={item.colors} style={styles.orb}>
              <Text style={styles.emoji}>{item.emoji}</Text>
            </LinearGradient>
            <Text style={styles.title}>{item.title}</Text>
            <Text style={styles.subtitle}>{item.subtitle}</Text>
          </View>
        )}
      />
      <View style={[styles.bottom, { paddingBottom: insets.bottom + 28 }]}>
        <View style={styles.dots}>{slides.map((slide, index) => <View key={slide.title} style={[styles.dot, page === index && styles.dotActive]} />)}</View>
        <Pressable onPress={isLast ? finish : goNext} style={styles.button}>
          <Text style={styles.buttonText}>{isLast ? "Get Started" : "Next"}</Text>
          {!isLast && <ArrowRight size={18} color={theme.ink} />}
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.ink },
  top: { position: "absolute", zIndex: 2, right: 24 },
  skip: { color: "rgba(255,255,255,0.72)", fontSize: 16, fontWeight: "700" },
  slide: { flex: 1, alignItems: "center", justifyContent: "center", paddingHorizontal: 34 },
  orb: { width: 166, height: 166, borderRadius: 83, alignItems: "center", justifyContent: "center", borderWidth: 3, borderColor: "rgba(255,255,255,0.22)" },
  emoji: { fontSize: 66 },
  title: { marginTop: 42, color: theme.white, fontSize: 34, lineHeight: 38, fontWeight: "900", textAlign: "center" },
  subtitle: { marginTop: 18, color: "rgba(255,255,255,0.78)", fontSize: 17, lineHeight: 25, textAlign: "center" },
  bottom: { position: "absolute", left: 24, right: 24, bottom: 0 },
  dots: { flexDirection: "row", justifyContent: "center", gap: 9, marginBottom: 28 },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: "rgba(255,255,255,0.32)" },
  dotActive: { width: 30, backgroundColor: theme.white },
  button: { height: 56, borderRadius: 16, backgroundColor: theme.white, alignItems: "center", justifyContent: "center", flexDirection: "row", gap: 8 },
  buttonText: { color: theme.ink, fontSize: 18, fontWeight: "800" },
});
