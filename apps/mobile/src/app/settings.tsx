import {
    ActivityIndicator,
    Pressable,
    StyleSheet,
    Text,
    View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import { useRouter } from "expo-router";
import Ionicons from "@expo/vector-icons/Ionicons";
import { PushEnvironmentNote } from "@/components/push-environment-note";
import { Product } from "@/constants/theme";
import { getApiBaseUrl } from "@/lib/config";
import { usePingRegistration } from "@/providers/ping-registration-provider";
import { useWebhookSecret } from "@/hooks/useWebhookSecret";

export default function SettingsScreen() {
    const router = useRouter();
    const { secret } = useWebhookSecret();
    const { registerDevice, busy } = usePingRegistration();

    return (
        <SafeAreaView
            style={[styles.safe, { backgroundColor: Product.canvas }]}
            edges={["top", "bottom"]}
        >
            <View style={styles.header}>
                <Pressable
                    onPress={() => router.back()}
                    style={styles.iconHit}
                    accessibilityRole="button"
                    accessibilityLabel="Back"
                >
                    <Ionicons
                        name="chevron-back"
                        size={26}
                        color={Product.text}
                    />
                </Pressable>
                <Text style={styles.title}>Settings</Text>
                <View style={styles.headerSpacer} />
            </View>

            <Text style={styles.sectionLabel}>API</Text>
            <Text style={styles.monoHint}>{getApiBaseUrl()}</Text>
            <Text style={styles.hint}>
                Override with EXPO_PUBLIC_API_URL for a remote host.
            </Text>

            <PushEnvironmentNote variant="product" />

            <Text style={[styles.sectionLabel, styles.sectionSpaced]}>
                Device
            </Text>
            {secret ? (
                <Pressable
                    onPress={() => void registerDevice(secret)}
                    disabled={busy}
                    style={({ pressed }) => [
                        styles.reregBtn,
                        pressed && styles.reregBtnPressed,
                        busy && styles.reregBtnDisabled,
                    ]}
                >
                    {busy ? (
                        <ActivityIndicator color={Product.canvas} />
                    ) : (
                        <Text style={styles.reregBtnText}>
                            Re-register device
                        </Text>
                    )}
                </Pressable>
            ) : (
                <Text style={styles.hint}>Preparing device…</Text>
            )}
            <StatusBar style="light" />
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    safe: {
        flex: 1,
        paddingHorizontal: 20,
    },
    header: {
        flexDirection: "row",
        alignItems: "center",
        marginBottom: 28,
    },
    headerSpacer: {
        width: 44,
    },
    iconHit: {
        width: 44,
        height: 44,
        alignItems: "center",
        justifyContent: "center",
    },
    title: {
        flex: 1,
        textAlign: "center",
        fontSize: 17,
        fontWeight: "600",
        color: Product.text,
    },
    sectionLabel: {
        fontSize: 13,
        fontWeight: "600",
        color: Product.textMuted,
        textTransform: "uppercase",
        letterSpacing: 0.5,
    },
    sectionSpaced: {
        marginTop: 28,
    },
    monoHint: {
        marginTop: 8,
        fontSize: 14,
        color: Product.text,
    },
    hint: {
        marginTop: 8,
        fontSize: 13,
        lineHeight: 18,
        color: Product.textMuted,
    },
    reregBtn: {
        marginTop: 12,
        backgroundColor: Product.accentPurple,
        paddingVertical: 14,
        borderRadius: 12,
        alignItems: "center",
    },
    reregBtnPressed: {
        opacity: 0.9,
    },
    reregBtnDisabled: {
        opacity: 0.6,
    },
    reregBtnText: {
        color: Product.canvas,
        fontSize: 16,
        fontWeight: "700",
    },
});
