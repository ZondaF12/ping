import * as Device from "expo-device";
import { isRunningInExpoGo } from "expo";
import { Platform, StyleSheet, Text } from "react-native";
import { Colors, Product } from "@/constants/theme";
import type { ColorSchemeName } from "@/constants/theme";

type Props =
    | { variant: "product" }
    | { variant: "system"; scheme: ColorSchemeName };

/**
 * Surfaces the same limitations Expo logs at runtime (Expo Go, simulator).
 */
export function PushEnvironmentNote(props: Props) {
    const c =
        props.variant === "product"
            ? {
                  warningText: Product.warningText,
                  warningBg: Product.warningBg,
              }
            : Colors[props.scheme];

    const parts: string[] = [];

    if (isRunningInExpoGo()) {
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

    return (
        <Text
            style={[
                styles.text,
                { color: c.warningText, backgroundColor: c.warningBg },
            ]}
        >
            {parts.join("\n\n")}
        </Text>
    );
}

const styles = StyleSheet.create({
    text: {
        marginTop: 14,
        fontSize: 11,
        lineHeight: 16,
        padding: 10,
        borderRadius: 8,
        overflow: "hidden",
    },
});
