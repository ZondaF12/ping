import { StyleSheet, Text } from "react-native";
import { Colors } from "@/constants/theme";
import type { ColorSchemeName } from "@/constants/theme";

type Props = {
    registerLog: string;
    scheme: ColorSchemeName;
};

export function RegisterLogSection({ registerLog, scheme }: Props) {
    const c = Colors[scheme];
    return (
        <>
            <Text style={[styles.logLabel, { color: c.logLabel }]}>
                Last register activity
            </Text>
            <Text selectable style={[styles.logBody, { color: c.logBody }]}>
                {registerLog}
            </Text>
        </>
    );
}

const styles = StyleSheet.create({
    logLabel: {
        marginTop: 20,
        fontSize: 12,
        fontWeight: "600",
    },
    logBody: {
        marginTop: 6,
        fontSize: 11,
        fontFamily: "monospace",
    },
});
