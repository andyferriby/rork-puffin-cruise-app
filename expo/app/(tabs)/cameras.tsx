import { fetchCameras, type CamerasConfig } from "@/lib/cameras";
import { theme, radius, spacing } from "@/constants/theme";
import { useQuery } from "@tanstack/react-query";
import { Video } from "lucide-react-native";
import React, { useCallback, useState } from "react";
import {
  ActivityIndicator,
  Dimensions,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import YoutubePlayer from "react-native-youtube-iframe";

const SCREEN_WIDTH = Dimensions.get("window").width;
const PLAYER_WIDTH = SCREEN_WIDTH - spacing.xl * 2;
const PLAYER_HEIGHT = PLAYER_WIDTH * (9 / 16);

export default function CamerasScreen() {
  const insets = useSafeAreaInsets();
  const [playingId, setPlayingId] = useState<string | null>(null);

  const { data: cameras, isLoading } = useQuery({
    queryKey: ["cameras"],
    queryFn: fetchCameras,
    staleTime: 60_000,
  });

  const handleStateChange = useCallback(
    (videoId: string) => (state: string) => {
      if (state === "playing") setPlayingId(videoId);
      if (state === "paused" || state === "ended") setPlayingId(null);
    },
    [],
  );

  const videos = cameras?.videos?.filter((v) => v.id?.trim()) ?? [];

  return (
    <View style={[styles.root, { paddingTop: insets.top }]}>
      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: insets.bottom + spacing.xl },
        ]}
      >
        <View style={styles.header}>
          <Text style={styles.title}>Live Cameras</Text>
          <Text style={styles.subtitle}>Coquet Island live feed</Text>
        </View>

        {isLoading ? (
          <View style={styles.loadingWrap}>
            <ActivityIndicator color={theme.sea} size="large" />
            <Text style={styles.loadingText}>Loading streams…</Text>
          </View>
        ) : videos.length === 0 ? (
          <View style={styles.emptyWrap}>
            <Video size={40} color={theme.textMuted} />
            <Text style={styles.emptyTitle}>No live streams</Text>
            <Text style={styles.emptyText}>
              The crew hasn't configured any cameras yet. Check back later.
            </Text>
          </View>
        ) : (
          videos.map((video, i) => (
            <View key={`${video.id}-${i}`} style={styles.playerCard}>
              <View style={styles.playerLabel}>
                <View style={styles.liveDot} />
                <Text style={styles.playerLabelText}>{video.label}</Text>
              </View>
              <View style={styles.playerWrap}>
                <YoutubePlayer
                  height={PLAYER_HEIGHT}
                  width={PLAYER_WIDTH}
                  videoId={video.id}
                  play={playingId === video.id}
                  onChangeState={handleStateChange(video.id)}
                  webViewStyle={styles.webview}
                  initialPlayerParams={{
                    controls: true,
                    modestbranding: true,
                    rel: false,
                  }}
                />
                {playingId !== video.id && (
                  <Pressable
                    style={styles.playOverlay}
                    onPress={() => setPlayingId(video.id)}
                  >
                    <View style={styles.playBtn}>
                      <Video size={24} color={theme.white} />
                    </View>
                  </Pressable>
                )}
              </View>
            </View>
          ))
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: theme.bg,
  },
  scrollContent: {
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.md,
    gap: spacing.lg,
  },
  header: {
    gap: spacing.xs,
  },
  title: {
    fontSize: 28,
    fontWeight: "800",
    color: theme.text,
  },
  subtitle: {
    fontSize: 14,
    color: theme.textMuted,
  },
  loadingWrap: {
    alignItems: "center",
    paddingVertical: 80,
    gap: spacing.md,
  },
  loadingText: {
    color: theme.textMuted,
    fontSize: 14,
  },
  emptyWrap: {
    alignItems: "center",
    paddingVertical: 80,
    gap: spacing.md,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: theme.text,
  },
  emptyText: {
    fontSize: 14,
    color: theme.textMuted,
    textAlign: "center",
    lineHeight: 20,
  },
  playerCard: {
    backgroundColor: theme.white,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: theme.border,
    overflow: "hidden",
  },
  playerLabel: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    backgroundColor: theme.deep,
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: theme.coral,
  },
  playerLabelText: {
    fontSize: 14,
    fontWeight: "700",
    color: theme.white,
  },
  playerWrap: {
    width: PLAYER_WIDTH,
    height: PLAYER_HEIGHT,
    backgroundColor: theme.ink,
    alignSelf: "center",
    position: "relative",
  },
  webview: {
    opacity: 0.99,
  },
  playOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(0,0,0,0.35)",
  },
  playBtn: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: theme.coral,
    alignItems: "center",
    justifyContent: "center",
    paddingLeft: 4, // optical centre for play icon
  },
});
