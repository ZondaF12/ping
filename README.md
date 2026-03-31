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

| Variable            | Purpose                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `MONGODB_URI`       | Mongo connection string                                                                                                                    |
| `SECRET_SALT`       | Server-only salt for HMAC digest of URL secrets (use a long random value in production)                                                    |
| `PORT`              | HTTP port (default `3000`)                                                                                                                 |
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

## Host the API on Railway

Deploy the **Nest service from the monorepo root** (not `apps/api` alone), so `@ping/shared` installs and builds correctly.

1. In [Railway](https://railway.com), **New project** → **Deploy from GitHub** → select this repo.
2. **Root directory:** leave as the **repository root** (`/`). Do **not** point the service only at `apps/api`.
3. Add **MongoDB** (Railway’s template) **or** use [MongoDB Atlas](https://www.mongodb.com/atlas). You need a single connection string the API can reach.
4. On the **API** service → **Variables**, set:
    - **`MONGODB_URI`** — e.g. paste the Mongo URL from Railway’s Mongo service (`MONGO_URL` / `DATABASE_PRIVATE_URL`, etc.), or your Atlas SRV string. Our code reads `MONGODB_URI` (see `app.module.ts`).
    - **`SECRET_SALT`** — long random secret; **do not change** after users have registered or their webhook URLs will stop matching stored digests.
    - **`EXPO_ACCESS_TOKEN`** — only if you enabled Expo’s [push access token](https://docs.expo.dev/push-notifications/sending-notifications/#additional-security).
    - **`PORT`** — Railway sets this automatically; Nest uses `process.env.PORT` and does not need you to set it unless you override.
5. **Build command** (service **Settings → Build**), for example:

    ```bash
    corepack enable && corepack prepare pnpm@10.33.0 --activate && pnpm install && pnpm --filter @ping/shared build && pnpm --filter @ping/api build
    ```

6. **Start command:** Railpack looks for a root **`start`** script in `package.json`. This repo defines `"start": "pnpm --filter @ping/api start:prod"`, so you usually **do not** need a custom start command. If your platform still asks for one, use:

    ```bash
    pnpm --filter @ping/api start:prod
    ```

7. **Networking:** generate a **public domain** for the service (HTTPS). Smoke-test `GET https://YOUR_DOMAIN/health` → `{"ok":true}`.
8. **Phone / `.env`:** set `EXPO_PUBLIC_API_URL=https://YOUR_DOMAIN` (no trailing slash, **no `:3000`** on Railway—HTTPS is on the default port; `:3000` is only for local dev like `http://192.168.x.x:3000`). Restart Metro/reload the dev build, then **Re-register device** so tokens are stored against the hosted API.

Outbound HTTPS to Expo’s push servers (`exp.host`) must be allowed (default on Railway).

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

Optional **`thread_id`** (string, max 256 characters) groups notifications in Notification Center on iOS: the server sets Apple’s `aps["thread-id"]` to this value. Omit it for the default ungrouped behavior. You can also pass `thread_id` on **GET** notify URLs as a query parameter (same as other fields).

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

| Environment       | What to expect                                                                                                                                                                                                                                                                                                                         |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Expo Go**       | `expo-notifications` is **not fully supported** in Expo Go. On **Android**, **remote (push) notifications were removed from Expo Go in SDK 53**—use a [**development build**](https://docs.expo.dev/develop/development-builds/introduction/) (or a production build) instead. See [expo.fyi/dev-client](https://expo.fyi/dev-client). |
| **iOS Simulator** | Obtaining a push token **may not work reliably** on recent iOS simulators (Apple / Expo warn about this). **Use a physical iPhone** to confirm register + delivery end-to-end.                                                                                                                                                         |

For standalone / EAS builds, configure an EAS project and set `expo.extra.eas.projectId` when you need a fixed project id for push tokens (see [Expo push setup](https://docs.expo.dev/push-notifications/push-notifications-setup/)).

### EAS Build (development client)

This repo uses **pnpm workspaces**. The root [`.npmrc`](.npmrc) sets `node-linker=hoisted` so Expo’s native tooling (`expo-modules-autolinking`, `@expo/prebuild-config`, etc.) resolves consistently. After cloning, run `pnpm install` from the repo root.

If `eas build` fails with **“expo-modules-autolinking … incompatible with @expo/prebuild-config”**:

1. From the **repository root**: `pnpm install` (with the committed `.npmrc`).
2. Use a current CLI: `npx eas-cli@latest build --profile development --platform ios` (or `npm i -g eas-cli@latest`).
3. From `apps/mobile`, sanity-check: `pnpm exec expo prebuild --platform ios` (optional; `ios/` is gitignored).

## Scripts (root)

| Script        | Description                          |
| ------------- | ------------------------------------ |
| `pnpm api`    | Run API in watch mode                |
| `pnpm mobile` | Start Expo dev server                |
| `pnpm build`  | Build shared + API; typecheck mobile |
