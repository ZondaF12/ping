---
title: JSON body
description: Optional fields for rich notifications
---

# JSON body

Use `Content-Type: application/json` and an object body. **`message`** is required; everything else is optional.

Example with several fields:

```json
{
  "title": "Coffee machine",
  "subtitle": "Kitchen",
  "message": "The brew cycle finished.",
  "url": "https://example.com/status",
  "interruption-level": "active"
}
```

Field names match the [Docs](/docs) reference exactly (including hyphenated keys like `interruption-level`).

If you send **plain text** instead of JSON (for example a raw string body), that string becomes the **message** and no optional fields are set.
