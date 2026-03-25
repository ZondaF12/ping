import { useEffect } from "react";
import {
    ActivityIndicator,
    Button,
    ScrollView,
    StyleSheet,
    Text,
    useColorScheme,
    View,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { PushEnvironmentNote } from "@/components/push-environment-note";
import { RegisterLogSection } from "@/components/register-log-section";
import { StatusBanner } from "@/components/status-banner";
import { WebhookUrlSection } from "@/components/webhook-url-section";
import { Colors } from "@/constants/theme";
import { usePingRegistration } from "@/hooks/usePingRegistration";
import { useWebhookSecret } from "@/hooks/useWebhookSecret";

export default function HomeScreen() {
    const scheme = useColorScheme() === "dark" ? "dark" : "light";
    const c = Colors[scheme];
    const { secret, loadError } = useWebhookSecret();
    const {
        apiBase,
        banner,
        busy,
        registerLog,
        registerDevice,
        sendTest,
    } = usePingRegistration();

    const webhookUrl =
        secret && apiBase ? `${apiBase}/v1/${encodeURIComponent(secret)}` : "";

    useEffect(() => {
        if (!secret) return;
        void registerDevice(secret);
    }, [secret, registerDevice]);

    if (!secret) {
        return (
            <View style={[styles.centered, { backgroundColor: c.background }]}>
                {loadError ? null : <ActivityIndicator size="large" />}
                <Text
                    style={[
                        styles.muted,
                        { color: loadError ? c.error : c.muted },
                        loadError && styles.loadErrorText,
                    ]}
                >
                    {loadError
                        ? `Startup failed: ${loadError}`
                        : "Preparing…"}
                </Text>
                <StatusBar style="auto" />
            </View>
        );
    }

    return (
        <ScrollView
            contentContainerStyle={[
                styles.container,
                { backgroundColor: c.background },
            ]}
        >
            <Text style={[styles.title, { color: c.text }]}>Ping</Text>
            <WebhookUrlSection webhookUrl={webhookUrl} scheme={scheme} />
            <PushEnvironmentNote />
            <View style={styles.actions}>
                <Button
                    title={busy ? "Working…" : "Re-register device"}
                    onPress={() => registerDevice(secret)}
                    disabled={busy}
                />
                <View style={styles.gap} />
                <Button
                    title="Send test notification"
                    onPress={() => void sendTest(secret)}
                    disabled={busy}
                />
            </View>
            {busy ? <ActivityIndicator style={styles.spinner} /> : null}
            {banner ? <StatusBanner banner={banner} scheme={scheme} /> : null}
            {registerLog ? (
                <RegisterLogSection registerLog={registerLog} scheme={scheme} />
            ) : null}
            {__DEV__ ? (
                <Text style={[styles.devHint, { color: c.muted }]}>
                    Dev: watch Metro logs for [ping] register POST / response
                    lines.
                </Text>
            ) : null}
            <StatusBar style="auto" />
        </ScrollView>
    );
}

const styles = StyleSheet.create({
    container: {
        padding: 24,
        paddingTop: 56,
    },
    centered: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
    },
    title: {
        fontSize: 28,
        fontWeight: "700",
        marginBottom: 20,
    },
    actions: {
        marginTop: 24,
    },
    gap: { height: 12 },
    spinner: { marginTop: 16 },
    muted: { marginTop: 8 },
    loadErrorText: {
        textAlign: "center",
        paddingHorizontal: 24,
    },
    devHint: {
        marginTop: 12,
        fontSize: 11,
        fontStyle: "italic",
    },
});
