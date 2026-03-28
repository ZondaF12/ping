---
title: Webhook API
description: Send push notifications with your secret URL
---

# Webhook API

Your automation calls **Ping** with HTTP **GET** or **POST** against a URL that includes your secret. The Ping API forwards the alert to registered devices.

The hosted API is at **`https://ping-production-9dc3.up.railway.app`** (no trailing slash). Replace `YOUR_SECRET` with the secret from the app.

## URL shape

```
https://ping-production-9dc3.up.railway.app/v1/YOUR_SECRET
```

The last path segment is your secret. Anyone who knows the full URL can send notifications to your devices, so treat it like a password. If it is ever exposed, rotate it in the app.

## POST with JSON

`Content-Type: application/json`

The body is an object. **`message`** is required (non-empty string, up to 4000 characters). All other fields are optional.

{% partial file="field-table.md" /%}

### Plain text body

You may also send a **non-JSON** body: a raw string (for example `text/plain`). The entire body becomes the notification **message**. No title or other fields are set in that case.

## POST example

```bash
curl -X POST "https://ping-production-9dc3.up.railway.app/v1/YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello from curl","title":"Ping"}'
```

## GET (query parameters)

For quick tests, **GET** supports the same payload via query parameters. **`message`** is required; other fields are optional.

Supported query keys: `message`, `title`, `subtitle`, `url`, `image_url`, `expiration_date`, `interruption-level`, `filter-criteria`.

### GET example

```
https://ping-production-9dc3.up.railway.app/v1/YOUR_SECRET?message=Hello&title=Quick%20test
```

## Response

Both GET and POST return JSON:

```json
{ "success": true }
```

`success` is `true` only if at least one device accepted the notification. On validation failure or if no matching devices are available, the API still returns **200** with `success: false` (it does not expose whether a secret was invalid).

## Rate limiting

Notify routes are throttled (per secret route) to avoid abuse. If you hit the limit, wait a minute and retry.
