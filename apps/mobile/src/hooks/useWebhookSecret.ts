import { useEffect, useState } from "react";
import * as Crypto from "expo-crypto";
import * as SecureStore from "expo-secure-store";

const SECRET_KEY = "webhook_secret_v1";

async function getOrCreateSecret(): Promise<string> {
    const existing = await SecureStore.getItemAsync(SECRET_KEY);
    if (existing) return existing;
    const bytes = await Crypto.getRandomBytesAsync(24);
    const secret = `ping_${Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")}`;
    await SecureStore.setItemAsync(SECRET_KEY, secret);
    return secret;
}

export function useWebhookSecret(): {
    secret: string | null;
    loadError: string | null;
} {
    const [secret, setSecret] = useState<string | null>(null);
    const [loadError, setLoadError] = useState<string | null>(null);

    useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const s = await getOrCreateSecret();
                if (!cancelled) setSecret(s);
            } catch (e) {
                if (!cancelled)
                    setLoadError(e instanceof Error ? e.message : String(e));
            }
        })();
        return () => {
            cancelled = true;
        };
    }, []);

    return { secret, loadError };
}
