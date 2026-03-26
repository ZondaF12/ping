/** Matches default body in usePingRegistration sendTest / postWebhookNotify. */
export const WEBHOOK_TEST_PAYLOAD = {
    title: "Ping test",
    subtitle: "From the app",
    message: "If you see this, the webhook works.",
    url: "https://expo.dev",
} as const;

/**
 * Copy-paste friendly curl for the notify webhook (shell-safe quoting).
 */
export function buildWebhookCurl(webhookUrl: string): string {
    const json = JSON.stringify(WEBHOOK_TEST_PAYLOAD);
    return `curl -X POST ${JSON.stringify(webhookUrl)} \\
  -H ${JSON.stringify("Content-Type: application/json")} \\
  -d ${JSON.stringify(json)}`;
}
