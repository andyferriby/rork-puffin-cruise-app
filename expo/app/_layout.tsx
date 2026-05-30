import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Stack, router } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import React, { useEffect } from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { OneSignal } from "react-native-onesignal";
import { ONBOARDING_KEY } from "@/app/onboarding";
import { initOneSignal } from "@/lib/notifications";

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

      // Initialize OneSignal for push notifications
      initOneSignal();

      if (!hasSeenOnboarding) {
        router.replace("/onboarding");
      }
    };
    prepare();
  }, []);

  // Handle notification taps — navigate to tickets tab
  useEffect(() => {
    OneSignal.Notifications.addEventListener("click", () => {
      router.replace("/(tabs)/tickets");
    });
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
