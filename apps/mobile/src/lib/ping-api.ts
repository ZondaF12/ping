import { getApiBaseUrl } from "./config";

export type BannerVariant = "info" | "success" | "error";

export async function postRegister(
    base: string,
    secret: string,
    expoPushToken: string,
): Promise<
    { ok: true; status: number } | { ok: false; status: number; body: string }
> {
    const registerUrl = `${base}/v1/register/${encodeURIComponent(secret)}`;
    if (__DEV__) console.log("[ping] register POST", registerUrl);
    const res = await fetch(registerUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ expoPushToken }),
    });
    if (__DEV__)
        console.log("[ping] register response", res.status, res.statusText);
    const body = await res.text();
    if (!res.ok) return { ok: false, status: res.status, body };
    return { ok: true, status: res.status };
}

export async function postWebhookNotify(
    base: string,
    secret: string,
    payload: {
        title?: string;
        subtitle?: string;
        message: string;
        url?: string;
        thread_id?: string;
    },
): Promise<{ ok: boolean; status: number; text: string }> {
    const url = `${base}/v1/${encodeURIComponent(secret)}`;
    const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
    const text = await res.text();
    return { ok: res.ok, status: res.status, text };
}

export { getApiBaseUrl };
