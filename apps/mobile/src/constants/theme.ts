/**
 * JetBrains Mono — embedded via expo-font config plugin (iOS/Android dev & production builds).
 * @see https://docs.expo.dev/develop/user-interface/fonts/
 */
export const Fonts = {
    mono: "JetBrainsMono-Regular",
    monoSemiBold: "JetBrainsMono-SemiBold",
} as const;

/**
 * Dark product UI (brrr-style reference): near-black canvas, purple accent, lime CTA.
 */
export const Product = {
    canvas: "#000000",
    surface: "#141414",
    surfaceElevated: "#1C1C1E",
    text: "#FFFFFF",
    textMuted: "#A1A1AA",
    accentPurple: "#C4B5FD",
    accentLime: "#A3FF4D",
    accentLimeText: "#0A0A0A",
    codePlain: "#E4E4E7",
    codeUrl: "#C4B5FD",
    codeString: "#FDE68A",
    borderSubtle: "#27272A",
    success: "#86EFAC",
    error: "#FCA5A5",
    info: "#D4D4D8",
    warningBg: "#2A2510",
    warningText: "#FCD34D",
    logLabel: "#A1A1AA",
    logBody: "#D4D4D8",
    whiteButtonText: "#0A0A0A",
} as const;

export type ProductColors = typeof Product;

/**
 * Subset of light/dark palette for any legacy/system-variant usage.
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
