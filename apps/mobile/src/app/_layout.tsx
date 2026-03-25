import { useEffect } from "react";
import { useColorScheme } from "react-native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { getLastNotificationResponse } from "expo-notifications";
import { Colors } from "@/constants/theme";
import {
    openUrlFromNotificationResponse,
    subscribeToNotificationResponses,
} from "@/lib/notifications";

export default function RootLayout() {
    const colorScheme = useColorScheme() === "dark" ? "dark" : "light";
    const bg = Colors[colorScheme].background;

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
            <Stack
                screenOptions={{
                    headerShown: false,
                    contentStyle: { backgroundColor: bg },
                }}
            />
            <StatusBar style="auto" />
        </GestureHandlerRootView>
    );
}
