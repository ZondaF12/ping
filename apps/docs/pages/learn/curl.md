---
title: Send with cURL
description: POST a JSON notification from the terminal
---

# Send with cURL

Minimal JSON (message only):

```bash
curl -X POST "https://ping-production-9dc3.up.railway.app/v1/YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello world"}'
```

With a title:

```bash
curl -X POST "https://ping-production-9dc3.up.railway.app/v1/YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"title":"Build finished","message":"Tests passed on main."}'
```

You should see a JSON response like `{"success":true}` when at least one device receives the push.

See the [Docs](/docs) page for every supported field.
