import {
    ActivityIndicator,
    Pressable,
    StyleSheet,
    Text,
    View,
} from "react-native";
import Ionicons from "@expo/vector-icons/Ionicons";
import { Fonts, Product } from "@/constants/theme";
import { WEBHOOK_TEST_PAYLOAD } from "@/lib/build-webhook-curl";

type Props = {
    webhookUrl: string;
    onSendTest: () => void;
    busy: boolean;
};

export function WebhookCurlCard({ webhookUrl, onSendTest, busy }: Props) {
    const json = JSON.stringify(WEBHOOK_TEST_PAYLOAD);
    const h = JSON.stringify("Content-Type: application/json");

    return (
        <View style={styles.card}>
            <View style={styles.cardHeader}>
                <Text style={styles.bashLabel}>Bash</Text>
                <Pressable
                    onPress={onSendTest}
                    disabled={busy}
                    style={({ pressed }) => [
                        styles.sendBtn,
                        pressed && styles.sendBtnPressed,
                        busy && styles.sendBtnDisabled,
                    ]}
                    hitSlop={8}
                >
                    {busy ? (
                        <ActivityIndicator
                            size="small"
                            color={Product.accentPurple}
                        />
                    ) : (
                        <>
                            <Ionicons
                                name="send-outline"
                                size={16}
                                color={Product.accentPurple}
                                style={styles.sendIcon}
                            />
                            <Text style={styles.sendLabel}>Send test</Text>
                        </>
                    )}
                </Pressable>
            </View>
            <Text
                selectable
                style={[styles.snippet, { fontFamily: Fonts.mono }]}
            >
                <Text style={{ color: Product.codePlain }}>curl -X POST </Text>
                <Text style={{ color: Product.codeUrl }}>
                    {JSON.stringify(webhookUrl)}
                </Text>
                <Text style={{ color: Product.codePlain }}>
                    {` \\\n  -H ${h} \\\n  -d `}
                </Text>
                <Text style={{ color: Product.codeString }}>
                    {JSON.stringify(json)}
                </Text>
            </Text>
        </View>
    );
}

const styles = StyleSheet.create({
    card: {
        backgroundColor: Product.surfaceElevated,
        borderRadius: 16,
        borderWidth: 1,
        borderColor: Product.borderSubtle,
        padding: 16,
        marginTop: 8,
    },
    cardHeader: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        marginBottom: 12,
    },
    bashLabel: {
        color: Product.textMuted,
        fontSize: 13,
        fontWeight: "600",
    },
    sendBtn: {
        flexDirection: "row",
        alignItems: "center",
        paddingVertical: 6,
        paddingHorizontal: 10,
    },
    sendBtnPressed: {
        opacity: 0.7,
    },
    sendBtnDisabled: {
        opacity: 0.5,
    },
    sendIcon: {
        marginRight: 6,
    },
    sendLabel: {
        color: Product.accentPurple,
        fontSize: 14,
        fontWeight: "600",
    },
    snippet: {
        fontSize: 11,
        lineHeight: 17,
    },
});
