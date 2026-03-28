| Field | Type | Notes |
| ----- | ---- | ----- |
| `message` | string | **Required.** Body of the notification (max 4000 chars). |
| `title` | string | Optional. First line of the alert (max 200 chars). |
| `subtitle` | string | Optional. Second line (max 300 chars). |
| `url` | string (URL) | Optional. Passed in push data so the app can open it when tapped. |
| `image_url` | string (URL) | Optional. Image attachment when supported. |
| `expiration_date` | string | Optional. ISO 8601 datetime with offset. If delivery is delayed, Apple may stop retrying after this time. |
| `interruption-level` | string | Optional. One of: `passive`, `active`, `time-sensitive`. |
| `filter-criteria` | string | Optional. Used with Focus filters on the device (max 256 chars). |
