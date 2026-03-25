/**
 * JetBrains Mono — embedded via expo-font config plugin (iOS/Android dev & production builds).
 * @see https://docs.expo.dev/develop/user-interface/fonts/
 */
export const Fonts = {
    mono: "JetBrainsMono-Regular",
    monoSemiBold: "JetBrainsMono-SemiBold",
} as const;

/**
 * Subset of light/dark palette (muscle-memory-rn style) for Ping’s single screen.
 */
export const Colors = {
    light: {
        text: "#11181C",
        background: "#fff",
        success: "#0a6b2f",
        error: "#b00020",
        info: "#333",
        muted: "#888",
        label: "#333",
        hint: "#666",
        warningBg: "#fff8e8",
        warningText: "#8a5a00",
        logLabel: "#555",
        logBody: "#333",
    },
    dark: {
        text: "#ECEDEE",
        background: "#151718",
        success: "#4ade80",
        error: "#f87171",
        info: "#ECEDEE",
        muted: "#888",
        label: "#ECEDEE",
        hint: "#9BA1A6",
        warningBg: "#3d3000",
        warningText: "#fcd34d",
        logLabel: "#9BA1A6",
        logBody: "#ECEDEE",
    },
} as const;

export type ColorSchemeName = keyof typeof Colors;
