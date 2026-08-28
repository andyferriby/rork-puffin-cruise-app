import { router } from "expo-router";
import {
  ChevronRight,
  Compass,
  Images,
  Map,
  PawPrint,
  Shield,
  ShoppingBag,
  Ticket,
  User,
  Video,
} from "lucide-react-native";
import React from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { theme } from "@/constants/theme";

type MoreItem = {
  href: string;
  label: string;
  desc: string;
  icon: React.ComponentType<{ color: string; size: number }>;
  tint: string;
};

type MoreSection = {
  title: string;
  items: MoreItem[];
};

const SECTIONS: MoreSection[] = [
  {
    title: "Your Visit",
    items: [
      { href: "/tickets", label: "My Tickets", desc: "View your boarding passes", icon: Ticket, tint: theme.coral },
      { href: "/trip", label: "Live Trip", desc: "Follow the boat in real time", icon: Compass, tint: theme.wave },
      { href: "/map", label: "Map", desc: "Find us at Amble Harbour", icon: Map, tint: theme.sea },
      { href: "/cameras", label: "Live Cameras", desc: "See the harbour right now", icon: Video, tint: theme.puffin },
    ],
  },
  {
    title: "Explore",
    items: [
      { href: "/wildlife", label: "Wildlife", desc: "Puffins, seals and more", icon: PawPrint, tint: theme.sandDeep },
      { href: "/gallery", label: "Gallery", desc: "Photos from the water", icon: Images, tint: theme.sea },
      { href: "/shop", label: "Shop", desc: "Gifts and merchandise", icon: ShoppingBag, tint: theme.coral },
    ],
  },
  {
    title: "Account",
    items: [
      { href: "/profile", label: "Profile", desc: "Settings and preferences", icon: User, tint: theme.sea },
      { href: "/admin", label: "Crew Admin", desc: "Scanner and schedule tools", icon: Shield, tint: theme.ink },
    ],
  },
];

export default function MoreScreen() {
  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.heading}>More</Text>
      <Text style={styles.subheading}>Everything for your day at Amble</Text>

      {SECTIONS.map((section) => (
        <View key={section.title} style={styles.section}>
          <Text style={styles.sectionTitle}>{section.title}</Text>
          <View style={styles.card}>
            {section.items.map((item, index) => {
              const Icon = item.icon;
              return (
                <Pressable
                  key={item.href}
                  onPress={() => router.push(item.href as never)}
                  style={({ pressed }) => [styles.row, pressed && styles.rowPressed, index > 0 && styles.rowDivider]}
                >
                  <View style={[styles.iconWrap, { backgroundColor: `${item.tint}18` }]}>
                    <Icon color={item.tint} size={20} />
                  </View>
                  <View style={styles.rowText}>
                    <Text style={styles.rowLabel}>{item.label}</Text>
                    <Text style={styles.rowDesc}>{item.desc}</Text>
                  </View>
                  <ChevronRight color={theme.textMuted} size={18} />
                </Pressable>
              );
            })}
          </View>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: theme.bg,
  },
  content: {
    paddingTop: 64,
    paddingHorizontal: 16,
    paddingBottom: 32,
  },
  heading: {
    fontSize: 30,
    fontWeight: "900",
    color: theme.text,
  },
  subheading: {
    marginTop: 4,
    marginBottom: 20,
    fontSize: 14,
    color: theme.textMuted,
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    marginBottom: 8,
    marginLeft: 4,
    fontSize: 12,
    fontWeight: "800",
    letterSpacing: 1,
    textTransform: "uppercase",
    color: theme.textMuted,
  },
  card: {
    backgroundColor: theme.white,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: theme.border,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 13,
  },
  rowPressed: {
    backgroundColor: theme.foam,
  },
  rowDivider: {
    borderTopWidth: 1,
    borderTopColor: theme.border,
  },
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  rowText: {
    flex: 1,
    gap: 2,
  },
  rowLabel: {
    fontSize: 15,
    fontWeight: "800",
    color: theme.text,
  },
  rowDesc: {
    fontSize: 12.5,
    color: theme.textMuted,
  },
});
