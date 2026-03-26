import { StyleSheet, Text } from "react-native";
import { Colors, Fonts, Product } from "@/constants/theme";
import type { ColorSchemeName } from "@/constants/theme";

type Props =
    | { registerLog: string; variant: "product" }
    | { registerLog: string; variant: "system"; scheme: ColorSchemeName };

export function RegisterLogSection(props: Props) {
    const c =
        props.variant === "product"
            ? { logLabel: Product.logLabel, logBody: Product.logBody }
            : Colors[props.scheme];

    return (
        <>
            <Text style={[styles.logLabel, { color: c.logLabel }]}>
                Last register activity
            </Text>
            <Text selectable style={[styles.logBody, { color: c.logBody }]}>
                {props.registerLog}
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
        fontFamily: Fonts.mono,
    },
});
