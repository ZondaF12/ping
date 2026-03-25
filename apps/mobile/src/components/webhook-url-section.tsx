import { StyleSheet, Text } from "react-native";
import { getApiBaseUrl } from "@/lib/config";
import { Colors } from "@/constants/theme";
import type { ColorSchemeName } from "@/constants/theme";

type Props = {
    webhookUrl: string;
    scheme: ColorSchemeName;
};

export function WebhookUrlSection({ webhookUrl, scheme }: Props) {
    const c = Colors[scheme];
    return (
        <>
            <Text style={[styles.label, { color: c.label }]}>Webhook URL</Text>
            <Text selectable style={[styles.mono, { color: c.text }]}>
                {webhookUrl || "—"}
            </Text>
            <Text style={[styles.hint, { color: c.hint }]}>
                Set EXPO_PUBLIC_API_URL to your API host if not using the
                default ({getApiBaseUrl()}).
            </Text>
        </>
    );
}

const styles = StyleSheet.create({
    label: {
        fontSize: 14,
        fontWeight: "600",
        marginBottom: 6,
    },
    mono: {
        fontFamily: "monospace",
        fontSize: 12,
    },
    hint: {
        marginTop: 12,
        fontSize: 12,
    },
});
