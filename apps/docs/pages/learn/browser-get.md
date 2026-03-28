---
title: GET in the browser
description: Trigger a notification from the address bar
---

# GET in the browser

**GET** uses query parameters instead of a JSON body. **`message`** is required.

Paste a URL like this into the browser (replace placeholders and encode spaces as `%20`):

```
https://ping-production-9dc3.up.railway.app/v1/YOUR_SECRET?message=Hello%20from%20the%20browser&title=Quick%20test
```

The page will show a JSON response such as `{"success":true}`. This is handy for quick checks when your client cannot send POST bodies.

**Note:** The hosted Ping API is HTTPS. If you point a browser at a **local** API served only at `http://localhost`, an HTTPS page (including this docs site when deployed) may block the request (mixed content); use [cURL](/learn/curl) or a tunnel in that case.
