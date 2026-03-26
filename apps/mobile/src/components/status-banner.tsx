import { StyleSheet, Text } from "react-native";
import type { Banner } from "@/hooks/usePingRegistration";
import { Colors, Product } from "@/constants/theme";
import type { ColorSchemeName } from "@/constants/theme";

type Props =
    | {
          banner: Banner;
          variant: "product";
      }
    | {
          banner: Banner;
          variant: "system";
          scheme: ColorSchemeName;
      };

export function StatusBanner(props: Props) {
    const c =
        props.variant === "product"
            ? {
                  error: Product.error,
                  success: Product.success,
                  info: Product.info,
              }
            : Colors[props.scheme];

    const { banner } = props;
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
