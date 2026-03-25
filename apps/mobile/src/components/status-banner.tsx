import { StyleSheet, Text } from "react-native";
import type { Banner } from "@/hooks/usePingRegistration";
import { Colors } from "@/constants/theme";
import type { ColorSchemeName } from "@/constants/theme";

type Props = {
    banner: Banner;
    scheme: ColorSchemeName;
};

export function StatusBanner({ banner, scheme }: Props) {
    const c = Colors[scheme];
    return (
        <Text
            style={[
                styles.banner,
                banner.variant === "error" && { color: c.error },
                banner.variant === "success" && { color: c.success },
                banner.variant === "info" && { color: c.info },
            ]}
        >
            {banner.text}
        </Text>
    );
}

const styles = StyleSheet.create({
    banner: {
        marginTop: 16,
        fontSize: 14,
    },
});
