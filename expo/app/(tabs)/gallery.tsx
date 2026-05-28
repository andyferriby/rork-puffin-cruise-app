import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as Haptics from "expo-haptics";
import { Image } from "expo-image";
import * as ImagePicker from "expo-image-picker";
import { Camera, ImagePlus, X } from "lucide-react-native";
import React, { useCallback, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Dimensions,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";
import { supabase } from "@/lib/supabase";

type Photo = {
  id: string;
  image_url: string;
  caption: string | null;
  guest_name: string | null;
  created_at: string;
};

const COL_GAP = 6;
const COLS = 2;
const WIDTH = Dimensions.get("window").width;
const TILE = (WIDTH - 32 - COL_GAP * (COLS - 1)) / COLS;

async function fetchPhotos(): Promise<Photo[]> {
  const { data, error } = await supabase
    .from("gallery_photos")
    .select("id, image_url, caption, guest_name, created_at")
    .eq("approved", true)
    .order("created_at", { ascending: false })
    .limit(120);
  if (error) {
    console.error("[gallery] fetch", error.message);
    return [];
  }
  return (data ?? []) as Photo[];
}

export default function GalleryScreen() {
  const insets = useSafeAreaInsets();
  const qc = useQueryClient();
  const { data: photos, isLoading } = useQuery({
    queryKey: ["gallery"],
    queryFn: fetchPhotos,
  });

  const [uploadOpen, setUploadOpen] = useState<boolean>(false);
  const [pendingUri, setPendingUri] = useState<string | null>(null);
  const [caption, setCaption] = useState<string>("");
  const [guestName, setGuestName] = useState<string>("");

  const uploadMutation = useMutation({
    mutationFn: async () => {
      if (!pendingUri) throw new Error("No image");
      const ext = pendingUri.split(".").pop()?.toLowerCase() ?? "jpg";
      const path = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

      const response = await fetch(pendingUri);
      const blob = await response.blob();
      const arrayBuffer = await new Response(blob).arrayBuffer();

      const { error: upErr } = await supabase.storage
        .from("gallery")
        .upload(path, arrayBuffer, {
          contentType: blob.type || `image/${ext}`,
          upsert: false,
        });
      if (upErr) throw upErr;

      const { data: pub } = supabase.storage.from("gallery").getPublicUrl(path);

      const { error: insertErr } = await supabase.from("gallery_photos").insert({
        image_url: pub.publicUrl,
        caption: caption.trim() || null,
        guest_name: guestName.trim() || null,
      });
      if (insertErr) throw insertErr;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["gallery"] });
      setUploadOpen(false);
      setPendingUri(null);
      setCaption("");
      setGuestName("");
      if (Platform.OS !== "web") {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
    },
    onError: (err) => {
      console.error("[gallery] upload", err);
      Alert.alert("Upload failed", err instanceof Error ? err.message : "Please try again.");
    },
  });

  const pick = useCallback(async (source: "camera" | "library") => {
    if (source === "camera") {
      const perm = await ImagePicker.requestCameraPermissionsAsync();
      if (!perm.granted) {
        Alert.alert("Camera access needed", "Please allow camera access to take a photo.");
        return;
      }
      const result = await ImagePicker.launchCameraAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        quality: 0.7,
        allowsEditing: false,
      });
      if (!result.canceled) {
        setPendingUri(result.assets[0].uri);
        setUploadOpen(true);
      }
    } else {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        quality: 0.7,
        allowsEditing: false,
      });
      if (!result.canceled) {
        setPendingUri(result.assets[0].uri);
        setUploadOpen(true);
      }
    }
  }, []);

  return (
    <View style={{ flex: 1, backgroundColor: theme.bg }}>
      <View style={[styles.header, { paddingTop: insets.top + 16 }]}>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>Guest Gallery</Text>
          <Text style={styles.subtitle}>
            Share your favourite moments from on board.
          </Text>
        </View>
      </View>

      <View style={styles.actions}>
        <Pressable
          onPress={() => pick("camera")}
          style={({ pressed }) => [styles.actionBtn, pressed && { opacity: 0.85 }]}
        >
          <Camera size={18} color={theme.white} />
          <Text style={styles.actionText}>Take photo</Text>
        </Pressable>
        <Pressable
          onPress={() => pick("library")}
          style={({ pressed }) => [styles.actionBtnSecondary, pressed && { opacity: 0.85 }]}
        >
          <ImagePlus size={18} color={theme.sea} />
          <Text style={styles.actionTextSecondary}>From library</Text>
        </Pressable>
      </View>

      {isLoading ? (
        <View style={{ padding: 40, alignItems: "center" }}>
          <ActivityIndicator color={theme.sea} />
        </View>
      ) : photos && photos.length > 0 ? (
        <ScrollView
          contentContainerStyle={styles.grid}
          showsVerticalScrollIndicator={false}
        >
          {photos.map((p) => (
            <View key={p.id} style={styles.tile}>
              <Image
                source={{ uri: p.image_url }}
                style={StyleSheet.absoluteFill}
                contentFit="cover"
                transition={150}
              />
              {(p.caption || p.guest_name) && (
                <View style={styles.tileOverlay}>
                  {p.caption && (
                    <Text style={styles.tileCaption} numberOfLines={2}>
                      {p.caption}
                    </Text>
                  )}
                  {p.guest_name && (
                    <Text style={styles.tileGuest}>— {p.guest_name}</Text>
                  )}
                </View>
              )}
            </View>
          ))}
        </ScrollView>
      ) : (
        <View style={styles.empty}>
          <Text style={styles.emptyEmoji}>📸</Text>
          <Text style={styles.emptyTitle}>Be the first to share a photo</Text>
          <Text style={styles.emptySub}>
            Snap a puffin, seal or sunset and add it to the public gallery.
          </Text>
        </View>
      )}

      <Modal visible={uploadOpen} animationType="slide" transparent>
        <View style={styles.modalRoot}>
          <View style={styles.modalCard}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Share your photo</Text>
              <Pressable onPress={() => setUploadOpen(false)}>
                <X size={22} color={theme.textMuted} />
              </Pressable>
            </View>
            {pendingUri && (
              <Image
                source={{ uri: pendingUri }}
                style={styles.preview}
                contentFit="cover"
              />
            )}
            <TextInput
              placeholder="Caption (optional)"
              placeholderTextColor={theme.textMuted}
              value={caption}
              onChangeText={setCaption}
              style={styles.input}
              maxLength={140}
            />
            <TextInput
              placeholder="Your name (optional)"
              placeholderTextColor={theme.textMuted}
              value={guestName}
              onChangeText={setGuestName}
              style={styles.input}
              maxLength={40}
            />
            <Pressable
              onPress={() => uploadMutation.mutate()}
              disabled={uploadMutation.isPending}
              style={({ pressed }) => [
                styles.uploadBtn,
                (pressed || uploadMutation.isPending) && { opacity: 0.8 },
              ]}
            >
              {uploadMutation.isPending ? (
                <ActivityIndicator color={theme.white} />
              ) : (
                <Text style={styles.uploadBtnText}>Post to gallery</Text>
              )}
            </Pressable>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: 20,
    paddingBottom: 12,
  },
  title: {
    fontSize: 34,
    fontWeight: "800",
    color: theme.text,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 14,
    color: theme.textMuted,
    marginTop: 4,
  },
  actions: {
    flexDirection: "row",
    gap: 10,
    paddingHorizontal: 16,
    paddingBottom: 12,
  },
  actionBtn: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    backgroundColor: theme.sea,
    paddingVertical: 13,
    borderRadius: 12,
  },
  actionText: {
    color: theme.white,
    fontWeight: "700",
    fontSize: 14,
  },
  actionBtnSecondary: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    backgroundColor: theme.white,
    borderWidth: 1.5,
    borderColor: theme.sea,
    paddingVertical: 13,
    borderRadius: 12,
  },
  actionTextSecondary: {
    color: theme.sea,
    fontWeight: "700",
    fontSize: 14,
  },
  grid: {
    paddingHorizontal: 16,
    paddingBottom: 32,
    flexDirection: "row",
    flexWrap: "wrap",
    gap: COL_GAP,
  },
  tile: {
    width: TILE,
    height: TILE,
    borderRadius: 14,
    overflow: "hidden",
    backgroundColor: theme.foam,
  },
  tileOverlay: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    padding: 10,
    backgroundColor: "rgba(11, 42, 74, 0.55)",
  },
  tileCaption: {
    color: theme.white,
    fontSize: 12,
    fontWeight: "600",
  },
  tileGuest: {
    color: "rgba(255,255,255,0.85)",
    fontSize: 11,
    marginTop: 2,
  },
  empty: {
    padding: 40,
    alignItems: "center",
  },
  emptyEmoji: {
    fontSize: 48,
    marginBottom: 8,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: "700",
    color: theme.text,
    marginBottom: 4,
  },
  emptySub: {
    fontSize: 14,
    color: theme.textMuted,
    textAlign: "center",
    lineHeight: 20,
  },
  modalRoot: {
    flex: 1,
    backgroundColor: "rgba(6,18,31,0.6)",
    justifyContent: "flex-end",
  },
  modalCard: {
    backgroundColor: theme.white,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    padding: 20,
    gap: 12,
    paddingBottom: 40,
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: "800",
    color: theme.text,
  },
  preview: {
    width: "100%",
    height: 220,
    borderRadius: 16,
    backgroundColor: theme.foam,
  },
  input: {
    backgroundColor: theme.bg,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    color: theme.text,
  },
  uploadBtn: {
    backgroundColor: theme.sea,
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: "center",
    marginTop: 4,
  },
  uploadBtnText: {
    color: theme.white,
    fontWeight: "700",
    fontSize: 15,
  },
});
