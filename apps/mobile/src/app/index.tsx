import { useEffect, useLayoutEffect } from "react";
import {
    ActivityIndicator,
    Linking,
    Pressable,
    ScrollView,
    Share,
    StyleSheet,
    Text,
    View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import { Stack, useNavigation, useRouter } from "expo-router";
import * as Clipboard from "expo-clipboard";
import Ionicons from "@expo/vector-icons/Ionicons";
import { PushEnvironmentNote } from "@/components/push-environment-note";
import { RegisterLogSection } from "@/components/register-log-section";
import { StatusBanner } from "@/components/status-banner";
import { WebhookCurlCard } from "@/components/webhook-curl-card";
import { DOCS_URL } from "@/constants/links";
import { Fonts, Product } from "@/constants/theme";
import { buildWebhookCurl } from "@/lib/build-webhook-curl";
import { getApiBaseUrl } from "@/lib/config";
import { usePingRegistration } from "@/providers/ping-registration-provider";
import { useWebhookSecret } from "@/hooks/useWebhookSecret";

export default function HomeScreen() {
    const router = useRouter();
    const navigation = useNavigation();
    const { secret, loadError } = useWebhookSecret();
    const { apiBase, banner, busy, registerLog, registerDevice, sendTest } =
        usePingRegistration();

    const webhookUrl =
        secret && apiBase ? `${apiBase}/v1/${encodeURIComponent(secret)}` : "";

    useEffect(() => {
        if (!secret) return;
        void registerDevice(secret);
    }, [secret, registerDevice]);

    useLayoutEffect(() => {
        if (!secret) {
            navigation.setOptions({ headerShown: false });
            return;
        }
        navigation.setOptions({
            headerShown: true,
            title: "",
            headerStyle: { backgroundColor: Product.canvas },
            headerTintColor: Product.text,
            headerShadowVisible: false,
        });
    }, [secret, navigation]);

    const onCopy = async () => {
        if (!webhookUrl) return;
        await Clipboard.setStringAsync(buildWebhookCurl(webhookUrl));
    };

    const onShare = async () => {
        if (!webhookUrl) return;
        await Share.share({ message: buildWebhookCurl(webhookUrl) });
    };

    if (!secret) {
        return (
            <SafeAreaView
                style={[styles.safe, { backgroundColor: Product.canvas }]}
                edges={["top", "bottom"]}
            >
                <View style={styles.centered}>
                    {loadError ? null : (
                        <ActivityIndicator
                            size="large"
                            color={Product.textMuted}
                        />
                    )}
                    <Text
                        style={[
                            styles.muted,
                            {
                                color: loadError
                                    ? Product.error
                                    : Product.textMuted,
                            },
                            loadError && styles.loadErrorText,
                        ]}
                    >
                        {loadError
                            ? `Startup failed: ${loadError}`
                            : "Preparing…"}
                    </Text>
                </View>
                <StatusBar style="light" />
            </SafeAreaView>
        );
    }

    return (
        <>
            <Stack.Toolbar placement="left">
                <Stack.Toolbar.Button
                    icon="clock.arrow.circlepath"
                    onPress={() => router.push("/history")}
                />
            </Stack.Toolbar>
            <Stack.Toolbar placement="right">
                <Stack.Toolbar.Button
                    icon="gearshape"
                    onPress={() => router.push("/settings")}
                />
            </Stack.Toolbar>
            <SafeAreaView
                style={[styles.safe, { backgroundColor: Product.canvas }]}
                edges={["bottom"]}
            >
                <ScrollView
                    contentContainerStyle={styles.scrollContent}
                    keyboardShouldPersistTaps="handled"
                >
                    <Text style={styles.heroTitle}>
                        <Text style={styles.heroTitlePlain}>Welcome to </Text>
                        <Text
                            style={[
                                styles.heroBrand,
                                { fontFamily: Fonts.monoSemiBold },
                            ]}
                        >
                            Ping
                        </Text>
                    </Text>
                    <Text style={styles.heroSubtitle}>
                        Make this device go ping by sending a notification with
                        the API call below.
                    </Text>

                    <WebhookCurlCard
                        webhookUrl={webhookUrl}
                        onSendTest={() => void sendTest(secret)}
                        busy={busy}
                    />

                    <View style={styles.ctaRow}>
                        <Pressable
                            onPress={() => void onCopy()}
                            disabled={busy}
                            style={({ pressed }) => [
                                styles.copyBtn,
                                pressed && styles.copyBtnPressed,
                            ]}
                        >
                            <Ionicons
                                name="copy-outline"
                                size={20}
                                color={Product.accentLimeText}
                                style={styles.ctaIcon}
                            />
                            <Text style={styles.copyBtnText}>Copy</Text>
                        </Pressable>
                        <Pressable
                            onPress={() => void onShare()}
                            disabled={busy}
                            style={({ pressed }) => [
                                styles.shareBtn,
                                pressed && styles.shareBtnPressed,
                            ]}
                        >
                            <Ionicons
                                name="share-outline"
                                size={20}
                                color={Product.whiteButtonText}
                                style={styles.ctaIcon}
                            />
                            <Text style={styles.shareBtnText}>Share</Text>
                        </Pressable>
                    </View>

                    <Text style={styles.apiHint}>
                        API: {getApiBaseUrl()} — set EXPO_PUBLIC_API_URL to
                        override.
                    </Text>

                    <PushEnvironmentNote variant="product" />
                    {busy ? (
                        <ActivityIndicator
                            style={styles.spinner}
                            color={Product.textMuted}
                        />
                    ) : null}
                    {banner ? (
                        <StatusBanner banner={banner} variant="product" />
                    ) : null}
                    {registerLog ? (
                        <RegisterLogSection
                            registerLog={registerLog}
                            variant="product"
                        />
                    ) : null}
                    {__DEV__ ? (
                        <Text style={styles.devHint}>
                            Dev: watch Metro for [ping] register lines.
                        </Text>
                    ) : null}

                    <Pressable
                        onPress={() => void Linking.openURL(DOCS_URL)}
                        style={styles.docsRow}
                    >
                        <Ionicons
                            name="document-text-outline"
                            size={18}
                            color={Product.textMuted}
                        />
                        <Text style={styles.docsLink}>Read docs</Text>
                    </Pressable>
                </ScrollView>
                <StatusBar style="light" />
            </SafeAreaView>
        </>
    );
}

const styles = StyleSheet.create({
    safe: {
        flex: 1,
    },
    scrollContent: {
        paddingHorizontal: 20,
        paddingTop: 8,
        paddingBottom: 32,
    },
    centered: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
    },
    heroTitle: {
        marginTop: 0,
        fontSize: 28,
        fontWeight: "700",
        color: Product.text,
    },
    heroTitlePlain: {
        color: Product.text,
    },
    heroBrand: {
        color: Product.accentPurple,
    },
    heroSubtitle: {
        marginTop: 12,
        fontSize: 15,
        lineHeight: 22,
        color: Product.textMuted,
    },
    ctaRow: {
        flexDirection: "row",
        marginTop: 20,
    },
    copyBtn: {
        flex: 1,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: Product.accentLime,
        paddingVertical: 16,
        borderRadius: 14,
        marginRight: 6,
    },
    copyBtnPressed: {
        opacity: 0.88,
    },
    copyBtnText: {
        color: Product.accentLimeText,
        fontSize: 16,
        fontWeight: "700",
    },
    shareBtn: {
        flex: 1,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: Product.text,
        paddingVertical: 16,
        borderRadius: 14,
        marginLeft: 6,
    },
    shareBtnPressed: {
        opacity: 0.88,
    },
    shareBtnText: {
        color: Product.whiteButtonText,
        fontSize: 16,
        fontWeight: "700",
    },
    ctaIcon: {
        marginRight: 8,
    },
    apiHint: {
        marginTop: 16,
        fontSize: 12,
        color: Product.textMuted,
    },
    spinner: {
        marginTop: 16,
    },
    muted: {
        marginTop: 8,
        fontSize: 15,
    },
    loadErrorText: {
        textAlign: "center",
        paddingHorizontal: 24,
    },
    devHint: {
        marginTop: 12,
        fontSize: 11,
        color: Product.textMuted,
        fontStyle: "italic",
    },
    docsRow: {
        flexDirection: "row",
        alignItems: "center",
        marginTop: 28,
    },
    docsLink: {
        marginLeft: 8,
        fontSize: 14,
        color: Product.textMuted,
        fontWeight: "500",
    },
});
