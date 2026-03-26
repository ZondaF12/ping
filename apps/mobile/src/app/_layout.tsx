import { useEffect } from "react";
import { DarkTheme, ThemeProvider } from "@react-navigation/native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { getLastNotificationResponse } from "expo-notifications";
import { Product } from "@/constants/theme";
import {
    openUrlFromNotificationResponse,
    subscribeToNotificationResponses,
} from "@/lib/notifications";
import { PingRegistrationProvider } from "@/providers/ping-registration-provider";

const navigationTheme = {
    ...DarkTheme,
    colors: {
        ...DarkTheme.colors,
        background: Product.canvas,
        card: Product.canvas,
    },
};

export default function RootLayout() {
    const bg = Product.canvas;

    useEffect(() => {
        const last = getLastNotificationResponse();
        if (last) openUrlFromNotificationResponse(last);

        const sub = subscribeToNotificationResponses((response) => {
            openUrlFromNotificationResponse(response);
        });
        return () => sub.remove();
    }, []);

    return (
        <GestureHandlerRootView style={{ flex: 1, backgroundColor: bg }}>
            <PingRegistrationProvider>
                <ThemeProvider value={navigationTheme}>
                    <Stack
                        screenOptions={{
                            headerShown: false,
                            contentStyle: { backgroundColor: bg },
                        }}
                    >
                        <Stack.Screen
                            name="index"
                            options={{
                                title: "",
                                headerShown: false,
                                headerStyle: {
                                    backgroundColor: Product.canvas,
                                },
                                headerTintColor: Product.text,
                                headerShadowVisible: false,
                            }}
                        />
                    </Stack>
                </ThemeProvider>
            </PingRegistrationProvider>
            <StatusBar style="light" />
        </GestureHandlerRootView>
    );
}
