import { LinearGradient } from "expo-linear-gradient";
import { Anchor, Car, MapPin, Navigation, Utensils, Waves, X } from "lucide-react-native";
import React, { useRef, useState } from "react";
import {
  Animated,
  Linking,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import MapView, { Marker, Polyline } from "react-native-maps";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { theme } from "@/constants/theme";

// ── Types ──────────────────────────────────────────────────────────────────

type Coordinate = { latitude: number; longitude: number };

type Place = {
  id: string;
  title: string;
  subtitle: string;
  coordinate: Coordinate;
  icon: React.ReactNode;
  color: string;
  category: (typeof filters)[number];
};

const filters = ["All", "Sailing", "Parking", "Dining", "Landmark"] as const;

// ── Locations ──────────────────────────────────────────────────────────────

const places: Place[] = [
  {
    id: "office",
    title: "Booking Office",
    subtitle: "Check in 20 mins early at Amble Harbour Village",
    coordinate: { latitude: 55.3336, longitude: -1.5812 },
    icon: <Anchor size={16} color={theme.white} />,
    color: theme.coral,
    category: "Sailing",
  },
  {
    id: "pier",
    title: "Boarding Pier",
    subtitle: "Crew scan QR tickets here — arrive 15 min early",
    coordinate: { latitude: 55.3338, longitude: -1.5803 },
    icon: <Navigation size={16} color={theme.white} />,
    color: theme.sea,
    category: "Sailing",
  },
  {
    id: "harbour",
    title: "Harbour Car Park",
    subtitle: "Closest parking · NE65 0AP — free for Puffin Cruises guests",
    coordinate: { latitude: 55.334, longitude: -1.5825 },
    icon: <Car size={16} color={theme.white} />,
    color: theme.textMuted,
    category: "Parking",
  },
  {
    id: "boathouse",
    title: "The Old Boathouse",
    subtitle: "Seafood restaurant on the harbour front · 1 min walk",
    coordinate: { latitude: 55.3331, longitude: -1.5828 },
    icon: <Utensils size={16} color={theme.white} />,
    color: theme.puffin,
    category: "Dining",
  },
  {
    id: "coquet",
    title: "Coquet Island",
    subtitle: "RSPB reserve — puffins, seals & historic lighthouse",
    coordinate: { latitude: 55.336, longitude: -1.54 },
    icon: <MapPin size={16} color={theme.white} />,
    color: theme.puffin,
    category: "Landmark",
  },
];

// ── Route line ─────────────────────────────────────────────────────────────

const routeCoords: Coordinate[] = [
  { latitude: 55.3338, longitude: -1.5803 },
  { latitude: 55.336, longitude: -1.54 },
];

// ── Region ─────────────────────────────────────────────────────────────────

const initialRegion = {
  latitude: 55.335,
  longitude: -1.561,
  latitudeDelta: 0.04,
  longitudeDelta: 0.04,
};

// ── Screen ─────────────────────────────────────────────────────────────────

export default function MapScreen() {
  const insets = useSafeAreaInsets();
  const mapRef = useRef<MapView>(null);
  const [filter, setFilter] = useState<(typeof filters)[number]>("All");
  const [selected, setSelected] = useState<Place | null>(null);
  const cardAnim = useRef(new Animated.Value(0)).current;

  const visible = places.filter(
    (p) => filter === "All" || p.category === filter,
  );

  const selectPlace = (p: Place) => {
    setSelected(p);
    mapRef.current?.animateToRegion(
      { ...p.coordinate, latitudeDelta: 0.01, longitudeDelta: 0.01 },
      500,
    );
    Animated.spring(cardAnim, {
      toValue: 1,
      useNativeDriver: true,
      tension: 200,
      friction: 20,
    }).start();
  };

  const dismissCard = () => {
    Animated.timing(cardAnim, {
      toValue: 0,
      duration: 200,
      useNativeDriver: true,
    }).start(() => setSelected(null));
  };

  const openDirections = (p: Place) => {
    const ll = `${p.coordinate.latitude},${p.coordinate.longitude}`;
    const url = Platform.select({
      ios: `maps://?daddr=${ll}&dirflg=w`,
      android: `google.navigation:q=${ll}&mode=w`,
      default: `https://maps.google.com/?q=${ll}`,
    });
    Linking.openURL(url!);
  };

  return (
    <View style={styles.root}>
      <ScrollView
        contentContainerStyle={{ paddingBottom: 36 }}
        scrollEnabled={!selected}
      >
        {/* Header */}
        <View style={[styles.header, { paddingTop: insets.top + 16 }]}>
          <Text style={styles.title}>Harbour Map</Text>
          <Text style={styles.subtitle}>
            Find check-in, boarding, parking, dining and the route to Coquet
            Island.
          </Text>
        </View>

        {/* Interactive Map */}
        <View style={styles.mapCard}>
          <MapView
            ref={mapRef}
            style={StyleSheet.absoluteFill}
            initialRegion={initialRegion}
            showsUserLocation={false}
            showsCompass
            showsScale
          >
            {visible.map((p) => (
              <Marker
                key={p.id}
                identifier={p.id}
                coordinate={p.coordinate}
                title={p.title}
                description={p.subtitle}
                onPress={() => selectPlace(p)}
              >
                <View style={[styles.pin, { backgroundColor: p.color }]}>
                  {p.icon}
                </View>
                <View
                  style={[
                    styles.pinArrow,
                    { borderTopColor: p.color },
                  ]}
                />
              </Marker>
            ))}

            <Polyline
              coordinates={routeCoords}
              strokeColor={theme.sea}
              strokeWidth={3}
              lineDashPattern={[6, 4]}
            />
          </MapView>
        </View>

        {/* Selected location card */}
        {selected && (
          <Animated.View
            style={[
              styles.detailCard,
              {
                transform: [
                  {
                    translateY: cardAnim.interpolate({
                      inputRange: [0, 1],
                      outputRange: [80, 0],
                    }),
                  },
                ],
                opacity: cardAnim,
              },
            ]}
          >
            <View
              style={[styles.detailIcon, { backgroundColor: selected.color }]}
            >
              {selected.icon}
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.detailTitle}>{selected.title}</Text>
              <Text style={styles.detailSub}>{selected.subtitle}</Text>
            </View>
            <Pressable
              onPress={() => openDirections(selected)}
              style={[styles.goBtn, { backgroundColor: selected.color }]}
            >
              <Text style={styles.goBtnText}>Directions</Text>
            </Pressable>
            <Pressable onPress={dismissCard} style={styles.dismiss}>
              <X size={18} color={theme.textMuted} />
            </Pressable>
          </Animated.View>
        )}

        {/* Category filters */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.filters}
        >
          {filters.map((f) => (
            <Pressable
              key={f}
              onPress={() => setFilter(f)}
              style={[styles.filter, filter === f && styles.filterActive]}
            >
              <Text
                style={[
                  styles.filterText,
                  filter === f && styles.filterTextActive,
                ]}
              >
                {f}
              </Text>
            </Pressable>
          ))}
        </ScrollView>

        {/* Place list */}
        <View style={styles.list}>
          {visible.map((p) => (
            <Pressable
              key={p.id}
              onPress={() => selectPlace(p)}
              style={({ pressed }) => [
                styles.place,
                pressed && { opacity: 0.85, transform: [{ scale: 0.985 }] },
              ]}
            >
              <View style={[styles.placeIcon, { backgroundColor: p.color }]}>
                {p.icon}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.placeTitle}>{p.title}</Text>
                <Text style={styles.placeSub}>{p.subtitle}</Text>
              </View>
              <Text style={[styles.category, { color: p.color }]}>
                {p.category}
              </Text>
            </Pressable>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

// ── Styles ─────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.bg },

  // Header
  header: { paddingHorizontal: 20, paddingBottom: 16 },
  title: { fontSize: 34, fontWeight: "900" as const, color: theme.text },
  subtitle: {
    marginTop: 5,
    color: theme.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },

  // Map
  mapCard: {
    height: 370,
    margin: 16,
    borderRadius: 28,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: theme.border,
    backgroundColor: "#CDEAF7",
  },

  // Pins
  pin: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 3,
    borderColor: theme.white,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 4,
  },
  pinArrow: {
    width: 0,
    height: 0,
    borderLeftWidth: 6,
    borderRightWidth: 6,
    borderTopWidth: 8,
    borderLeftColor: "transparent",
    borderRightColor: "transparent",
    alignSelf: "center",
    marginTop: -1,
  },

  // Detail card
  detailCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    marginHorizontal: 16,
    marginTop: -8,
    marginBottom: 12,
    padding: 14,
    backgroundColor: theme.white,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: theme.border,
    shadowColor: theme.deep,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.12,
    shadowRadius: 14,
    elevation: 6,
    zIndex: 10,
  },
  detailIcon: {
    width: 42,
    height: 42,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
  },
  detailTitle: { fontSize: 16, fontWeight: "800" as const, color: theme.text },
  detailSub: {
    marginTop: 2,
    color: theme.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  goBtn: {
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: 999,
  },
  goBtnText: { color: theme.white, fontWeight: "800" as const, fontSize: 13 },
  dismiss: {
    position: "absolute",
    top: 8,
    right: 8,
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: theme.foam,
    alignItems: "center",
    justifyContent: "center",
  },

  // Filters
  filters: { paddingHorizontal: 16, gap: 8 },
  filter: {
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: 999,
    backgroundColor: theme.white,
    borderWidth: 1,
    borderColor: theme.border,
  },
  filterActive: { backgroundColor: theme.sea },
  filterText: { color: theme.textMuted, fontWeight: "800" as const },
  filterTextActive: { color: theme.white },

  // Place list
  list: { padding: 16, gap: 10 },
  place: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 14,
    backgroundColor: theme.white,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: theme.border,
  },
  placeIcon: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: theme.sea,
    alignItems: "center",
    justifyContent: "center",
  },
  placeTitle: { fontSize: 16, fontWeight: "800" as const, color: theme.text },
  placeSub: { marginTop: 2, color: theme.textMuted, fontSize: 13 },
  category: { fontSize: 11, fontWeight: "900" as const },
});
