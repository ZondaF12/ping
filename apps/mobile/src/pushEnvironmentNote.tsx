import Constants from "expo-constants";
import * as Device from "expo-device";
import { Platform, StyleSheet, Text } from "react-native";

/**
 * Surfaces the same limitations Expo logs at runtime (Expo Go, simulator).
 */
export function PushEnvironmentNote() {
    const parts: string[] = [];

    if (Constants.appOwnership === "expo") {
        parts.push(
            "Expo Go: push is limited—in SDK 53+ Android remote push was removed from Expo Go, and iOS push is not fully supported. Use an EAS development build for production-like behavior.",
        );
    }

    if (!Device.isDevice) {
        parts.push(
            `Simulator (${Platform.OS}): obtaining an Expo push token may not work reliably (especially on newer iOS simulators). Use a physical device to verify register + notifications.`,
        );
    }

    if (parts.length === 0) return null;

    return <Text style={styles.text}>{parts.join("\n\n")}</Text>;
}

const styles = StyleSheet.create({
    text: {
        marginTop: 14,
        fontSize: 11,
        lineHeight: 16,
        color: "#8a5a00",
        backgroundColor: "#fff8e8",
        padding: 10,
        borderRadius: 8,
        overflow: "hidden",
    },
});
