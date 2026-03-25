# Ping

Monorepo for a minimal **webhook → push notification** flow: your automation calls `POST /v1/:secret` with JSON, and registered iOS devices get an Expo push.

## Layout

- `apps/api` — NestJS + Mongoose + [Expo push](https://docs.expo.dev/push-notifications/sending-notifications/)
- `apps/mobile` — Expo SDK 55 (iOS-focused); secret in SecureStore, digest + token on the server only (similar idea to [brrr](https://brrr.now/how-it-works/))
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

For standalone / EAS builds, configure an EAS project and set `expo.extra.eas.projectId` when you need a fixed project id for push tokens (see [Expo push setup](https://docs.expo.dev/push-notifications/push-notifications-setup/)).

## Scripts (root)

| Script | Description |
| --- | --- |
| `pnpm api` | Run API in watch mode |
| `pnpm mobile` | Start Expo dev server |
| `pnpm build` | Build shared + API; typecheck mobile |
