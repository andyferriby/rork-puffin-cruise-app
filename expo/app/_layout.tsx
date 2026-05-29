import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Stack, router } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import React, { useEffect } from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { registerForPushNotifications } from "@/lib/notifications";
import { ONBOARDING_KEY } from "@/app/onboarding";

SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 30,
      retry: 1,
    },
  },
});

function RootLayoutNav() {
  return (
    <Stack screenOptions={{ headerBackTitle: "Back" }}>
      <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      <Stack.Screen name="onboarding" options={{ headerShown: false }} />
      <Stack.Screen name="arrival-guide" options={{ presentation: "modal", title: "Arrival Guide" }} />
      <Stack.Screen
        name="book/[cruiseId]"
        options={{ presentation: "modal", title: "Book Cruise" }}
      />
    </Stack>
  );
}

export default function RootLayout() {
  useEffect(() => {
    const prepare = async (): Promise<void> => {
      const hasSeenOnboarding = await AsyncStorage.getItem(ONBOARDING_KEY);
      await SplashScreen.hideAsync();
      try {
        const token = await registerForPushNotifications();
        if (token) console.log("[app] push token registered", token.slice(0, 12) + "...");
        else console.log("[app] push token not available (simulator or permission denied)");
      } catch (err) {
        console.error("[app] push registration failed", err);
      }
      if (!hasSeenOnboarding) {
        router.replace("/onboarding");
      }
    };
    prepare();
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <StatusBar style="auto" />
        <RootLayoutNav />
      </GestureHandlerRootView>
    </QueryClientProvider>
  );
}
