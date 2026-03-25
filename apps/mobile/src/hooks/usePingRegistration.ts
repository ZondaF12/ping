import { useCallback, useState } from "react";
import { getApiBaseUrl } from "@/lib/config";
import { registerForExpoPushTokenAsync } from "@/lib/notifications";
import { postRegister, postWebhookNotify } from "@/lib/ping-api";

export type Banner = {
    text: string;
    variant: "info" | "success" | "error";
};

export function usePingRegistration() {
    const [apiBase, setApiBase] = useState(getApiBaseUrl());
    const [banner, setBanner] = useState<Banner | null>(null);
    const [busy, setBusy] = useState(false);
    const [registerLog, setRegisterLog] = useState<string | null>(null);

    const registerWithApi = useCallback(
        async (
            s: string,
            onProgress?: (b: Banner) => void,
        ): Promise<
            { ok: true; base: string } | { ok: false; banner: Banner }
        > => {
            const base = getApiBaseUrl();
            setApiBase(base);
            onProgress?.({
                variant: "info",
                text: "Register: getting Expo push token…",
            });
            const expoPushToken = await registerForExpoPushTokenAsync();
            if (!expoPushToken) {
                const b: Banner = {
                    variant: "error",
                    text: "No Expo push token (allow notifications in Settings, use a dev build or Expo Go, and ensure push is configured). The register request was not sent.",
                };
                setRegisterLog(
                    `${new Date().toLocaleTimeString()}: register not sent (no push token)`,
                );
                return { ok: false, banner: b };
            }
            const registerUrl = `${base}/v1/register/${encodeURIComponent(s)}`;
            onProgress?.({
                variant: "info",
                text: `Register: sending POST to\n${registerUrl}`,
            });
            const result = await postRegister(base, s, expoPushToken);
            if (!result.ok) {
                setRegisterLog(
                    `${new Date().toLocaleTimeString()}: POST register → HTTP ${result.status}`,
                );
                return {
                    ok: false,
                    banner: {
                        variant: "error",
                        text: `Register failed: ${result.status} ${result.body}`,
                    },
                };
            }
            setRegisterLog(
                `${new Date().toLocaleTimeString()}: POST register → HTTP ${result.status} (saved token ${expoPushToken.slice(0, 24)}…)`,
            );
            return { ok: true, base };
        },
        [],
    );

    const registerDevice = useCallback(
        async (s: string) => {
            setBusy(true);
            try {
                const result = await registerWithApi(s, setBanner);
                if (!result.ok) {
                    setBanner(result.banner);
                    return;
                }
                setBanner({
                    variant: "success",
                    text: "Register complete: API responded OK and stored your push token.",
                });
            } finally {
                setBusy(false);
            }
        },
        [registerWithApi],
    );

    const sendTest = useCallback(
        async (secret: string) => {
            setBusy(true);
            setBanner(null);
            try {
                const reg = await registerWithApi(secret, setBanner);
                if (!reg.ok) {
                    setBanner(reg.banner);
                    return;
                }
                const { base } = reg;
                const res = await postWebhookNotify(base, secret, {
                    title: "Ping test",
                    subtitle: "From the app",
                    message: "If you see this, the webhook works.",
                    url: "https://expo.dev",
                });
                if (!res.ok) {
                    setBanner({
                        variant: "error",
                        text: `Send failed: ${res.status} ${res.text}`,
                    });
                } else {
                    setBanner({
                        variant: "success",
                        text: `Sent (${res.status}). ${res.text}`,
                    });
                }
            } finally {
                setBusy(false);
            }
        },
        [registerWithApi],
    );

    return {
        apiBase,
        banner,
        setBanner,
        busy,
        registerLog,
        registerDevice,
        sendTest,
    };
}
