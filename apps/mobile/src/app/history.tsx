import { Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import { useRouter } from "expo-router";
import Ionicons from "@expo/vector-icons/Ionicons";
import { Product } from "@/constants/theme";

export default function HistoryScreen() {
    const router = useRouter();

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
                <Text style={styles.title}>History</Text>
                <View style={styles.headerSpacer} />
            </View>
            <Text style={styles.body}>Notification history coming soon.</Text>
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
        marginBottom: 24,
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
    body: {
        fontSize: 15,
        lineHeight: 22,
        color: Product.textMuted,
    },
});
