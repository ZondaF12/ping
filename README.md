# Ping

Monorepo for a minimal **webhook → push notification** flow: your automation calls `POST /v1/:secret` with JSON, and registered iOS devices get an Expo push.

## Layout

- `apps/api` — NestJS + Mongoose + [Expo push](https://docs.expo.dev/push-notifications/sending-notifications/)
- `apps/mobile` — Expo SDK 55 (iOS-focused); secret in SecureStore, digest + token on the server only
- `packages/shared` — Zod schemas for webhook and register bodies

## Prerequisites

- Node 20+, pnpm
- MongoDB (e.g. `docker compose up -d`)

## API environment

Copy `apps/api/.env.example` to `apps/api/.env` and adjust:

| Variable | Purpose |
| --- | --- |
| `MONGODB_URI` | Mongo connection string |
| `SECRET_SALT` | Server-only salt for HMAC digest of URL secrets (use a long random value in production) |
| `PORT` | HTTP port (default `3000`) |
| `EXPO_ACCESS_TOKEN` | Optional; required if you enable [Expo push security](https://docs.expo.dev/push-notifications/sending-notifications/#additional-security) |

The API does not persist notification bodies in the database; avoid logging full webhook payloads in production.

## Run the API

```bash
docker compose up -d
pnpm install
pnpm --filter @ping/shared build
pnpm --filter @ping/api start:dev
```

Health check: `GET http://127.0.0.1:3000/health`

## Register a device (from the app)

The mobile app calls:

```http
POST /v1/register/:secret
Content-Type: application/json

{"expoPushToken":"ExponentPushToken[...]"}
```

`:secret` is the raw webhook secret (only stored on the device). The API stores `HMAC-SHA256(secret, SECRET_SALT)` and the Expo token.

## Send a notification (automation / curl)

```bash
curl -X POST "http://127.0.0.1:3000/v1/YOUR_SECRET_HERE" \
  -H "Content-Type: application/json" \
  -d '{"title":"In stock","subtitle":"Example","message":"Widget is available again.","url":"https://example.com"}'
```

`message` is required. `title`, `subtitle`, and `url` are optional. `url` is passed in push `data` so the app can open it when the user taps the notification.

## Mobile app

```bash
cd apps/mobile
# Point at your machine from a device/simulator if needed:
# EXPO_PUBLIC_API_URL=http://192.168.x.x:3000 pnpm start
pnpm start
```

Then press `i` for iOS. Use **Send test notification** to hit your API with a sample payload.

**Physical iPhone:** `http://127.0.0.1:3000` or `http://localhost:3000` points at the **phone**, not your computer. Put your Mac’s **LAN IP** in `EXPO_PUBLIC_API_URL` (same Wi‑Fi as the phone), e.g. `http://192.168.1.42:3000`, or use a tunnel (ngrok, etc.) if the device is not on your LAN.

### Expo Go, simulator, and push tokens

Expo prints warnings in Metro for good reason:

| Environment | What to expect |
| --- | --- |
| **Expo Go** | `expo-notifications` is **not fully supported** in Expo Go. On **Android**, **remote (push) notifications were removed from Expo Go in SDK 53**—use a [**development build**](https://docs.expo.dev/develop/development-builds/introduction/) (or a production build) instead. See [expo.fyi/dev-client](https://expo.fyi/dev-client). |
| **iOS Simulator** | Obtaining a push token **may not work reliably** on recent iOS simulators (Apple / Expo warn about this). **Use a physical iPhone** to confirm register + delivery end-to-end. |

For standalone / EAS builds, configure an EAS project and set `expo.extra.eas.projectId` when you need a fixed project id for push tokens (see [Expo push setup](https://docs.expo.dev/push-notifications/push-notifications-setup/)).

### EAS Build (development client)

This repo uses **pnpm workspaces**. The root [`.npmrc`](.npmrc) sets `node-linker=hoisted` so Expo’s native tooling (`expo-modules-autolinking`, `@expo/prebuild-config`, etc.) resolves consistently. After cloning, run `pnpm install` from the repo root.

If `eas build` fails with **“expo-modules-autolinking … incompatible with @expo/prebuild-config”**:

1. From the **repository root**: `pnpm install` (with the committed `.npmrc`).
2. Use a current CLI: `npx eas-cli@latest build --profile development --platform ios` (or `npm i -g eas-cli@latest`).
3. From `apps/mobile`, sanity-check: `pnpm exec expo prebuild --platform ios` (optional; `ios/` is gitignored).

## Scripts (root)

| Script | Description |
| --- | --- |
| `pnpm api` | Run API in watch mode |
| `pnpm mobile` | Start Expo dev server |
| `pnpm build` | Build shared + API; typecheck mobile |
