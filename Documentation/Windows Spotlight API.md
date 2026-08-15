# Windows Spotlight API Reference

#### 🤖 Generated with Claude

Reverse-engineered from Windows 11's `IrisService.dll` and `DesktopSpotlight.dll`
(in `MicrosoftWindows.Client.CBS`) and `Microsoft.Windows.ContentDeliveryManager`.

## Endpoints

### 1. Desktop Spotlight (IrisService)

```
GET https://fd.api.iris.microsoft.com/v4/api/selection
```

| Param       | Example      | Description                                          |
|-------------|--------------|------------------------------------------------------|
| `placement` | `88000820`   | Surface ID. `88000820` = desktop wallpaper            |
| `bcnt`      | `4`          | Batch count — number of creatives returned            |
| `country`   | `NZ`         | ISO country code for regional content targeting       |
| `locale`    | `en-NZ`      | BCP-47 locale tag                                     |
| `fmt`       | `json`       | Response format                                       |

- Renderer: `CDMLite`
- Surface: `DesktopSpotlightSurface`
- Package: `MicrosoftWindows.Client.CBS_cw5n1h2txyewy`
- Binary: `IrisService.dll` (endpoint), `DesktopSpotlight.dll` (UI + response schema)

### 2. Lock Screen Spotlight (ContentDeliveryManager)

```
GET https://arc.msn.com/v3/Delivery/Placement
```

| Param         | Example              | Description                                    |
|---------------|----------------------|------------------------------------------------|
| `pid`         | `338387`             | Placement ID. `338387` = lock screen            |
| `fmt`         | `json`               | Response format                                 |
| `ua`          | `WindowsShellClient` | User agent identifier                           |
| `cdm`         | `1`                  | ContentDeliveryManager flag                     |
| `disphorzres` | `1920`               | Display horizontal resolution                   |
| `dispvertres` | `1080`               | Display vertical resolution                     |
| `lo`          | `80217`              | Location identifier                             |
| `pl`          | `en-NZ`              | Primary language                                |
| `lc`          | `en-NZ`              | Locale                                          |
| `ctry`        | `NZ`                 | Country code                                    |
| `rafb`        | `0`                  | Unknown flag (always 0 in observed traffic)     |

- Renderer: `CDM`
- Surface: `LockScreen` / `LockScreenHotSpots`
- Package: `Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy`

### 3. Telemetry (not content-serving)

| Endpoint                                                | Method | Purpose                              |
|---------------------------------------------------------|--------|--------------------------------------|
| `https://ris.api.iris.microsoft.com/v1/a/{ACTION}`      | GET    | Impression/click/hover/like/dislike  |
| `https://arc.msn.com/v3/Delivery/Events/Impression`     | POST   | Impression reporting with telemetry  |

## Response Format

Both endpoints return the same outer envelope:

```json
{
  "batchrsp": {
    "ver": "1.0",
    "items": [
      { "item": "<JSON string — must be parsed separately>" }
    ],
    "refreshtime": "2026-08-21T02:52:23"
  }
}
```

Each `item` value is a **JSON-encoded string** (not an object). Parse it a second time to get the creative payload.

### Desktop Spotlight Creative (CDMLite)

```json
{
  "f": "raf",
  "v": "1.0",
  "rdr": [{ "c": "CDMLite", "u": "DesktopSpotlightSurface" }],
  "ad": {
    "landscapeImage": {
      "asset": "https://res.public.onecdn.static.microsoft/creativeservice/{uuid}_{name}_3840x2160.jpg"
    },
    "portraitImage": {
      "asset": "https://res.public.onecdn.static.microsoft/creativeservice/{uuid}_{name}_1080x1920.jpg"
    },
    "iconLabel": "Learn about this picture",
    "iconHoverText": "Location Name\r\n© Photographer / Agency\r\nRight-click to learn more",
    "title": "Short headline",
    "description": "Full paragraph description...",
    "copyright": "© Photographer / Agency",
    "ctaText": "Learn more",
    "ctaUri": "microsoft-edge:https://www.bing.com/spotlight?spotlightid=DS_{Id}&q=...",
    "relatedContent": [
      { "glyph": "", "label": "Ask Copilot", "actionUri": "microsoft-edge:https://copilot.microsoft.com/..." },
      { "glyph": "", "label": "See more photos", "actionUri": "..." },
      { "glyph": "", "label": "Related topic", "actionUri": "..." },
      { "glyph": "", "label": "Explore region", "actionUri": "..." }
    ],
    "relatedHotspots": [
      { "glyph": "", "label": "Hotspot description text", "actionUri": "..." }
    ],
    "entityId": "128000000005500309"
  },
  "tracking": {
    "baseUri": "https://ris.api.iris.microsoft.com/v1/a/{ACTION}?PG=...&UNID=88000820&CID=...&..."
  },
  "prm": {
    "_id": "128000000005500309",
    "_imp": "https://arc.msn.com/v3/Delivery/Events/Impression?...",
    "_flight": ""
  }
}
```

### Lock Screen Creative (CDM / LockScreenHotSpots)

```json
{
  "f": "raf",
  "v": "1.0",
  "rdr": [{ "c": "CDMLite", "u": "LockScreenHotSpots" }],
  "ad": {
    "image_fullscreen_001_landscape": { "t": "img", "w": "1920", "h": "1080", "u": "https://...1920x1080.jpg" },
    "image_fullscreen_001_portrait":  { "t": "img", "w": "1080", "h": "1920", "u": "https://...1080x1920.jpg" },
    "image_fullscreen_002_landscape": { "...": "empty.jpg placeholder for other aspect ratios" },
    "title_text":     { "t": "txt", "tx": "Location Name" },
    "copyright_text": { "t": "txt", "tx": "© Photographer / Agency" },
    "hs1_title_text":          { "t": "txt", "tx": "Hotspot 1 headline" },
    "hs1_cta_text":            { "t": "txt", "tx": "Call to action text" },
    "hs1_destination_url":     { "t": "url", "u": "microsoft-edge:https://..." },
    "hs1_x_coordinate_001_landscape": { "t": "txt", "tx": "72" },
    "hs1_y_coordinate_001_landscape": { "t": "txt", "tx": "72" },
    "hs2_title_text":          { "t": "txt", "tx": "Hotspot 2 headline" },
    "hs2_destination_url":     { "t": "url", "u": "microsoft-edge:https://..." },
    "title_destination_url":   { "t": "url", "u": "microsoft-edge:https://www.bing.com/images/search?q=..." },
    "options": { "t": "txt", "tx": "4" }
  },
  "prm": {
    "_id": "WW_128000000005976089_EN-NZ",
    "rotationPeriod": 82800,
    "requiresNetwork": 0,
    "startTime": "2026-04-28T17:15:39",
    "expireTime": "2027-04-01T07:00:00",
    "feedback_enabled": 1,
    "_imp": "https://arc.msn.com/v3/Delivery/Events/Impression?..."
  }
}
```

## Image CDN

Both APIs serve images from the same CDN (Akamai-backed, no auth required):

```
https://res.public.onecdn.static.microsoft/creativeservice/{uuid}_{descriptive_name}.jpg
```

- Desktop images: 3840x2160 (landscape), 1080x1920 (portrait)
- Lock screen images: 1920x1080 (landscape), 1080x1920 (portrait)
- Cache header: `max-age=630720000` (~20 years)

## Local Cache Locations

### Desktop Spotlight
- **Registry**: `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Creatives`
- **Images**: `%LOCALAPPDATA%\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\LocalCache\Microsoft\IrisService\{batchId}\{imageId}.jpg`

### Lock Screen Spotlight
- **Creatives JSON**: `%LOCALAPPDATA%\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\ContentManagementSDK\Creatives\338387\`
- **Cached images**: `%LOCALAPPDATA%\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets\`

## Spotlight ID Prefixes

- `DS_` — Desktop Spotlight (e.g. `DS_IncahuasiBolivia`)
- No prefix — Lock Screen (e.g. `MobiusArchCalifornia`)

## Other Known Placement IDs

| ID         | Surface                          |
|------------|----------------------------------|
| `88000820` | Desktop wallpaper (Spotlight)    |
| `338387`   | Lock screen (Spotlight)          |
| `338389`   | Start menu suggestions           |
| `310091`   | General content delivery         |
| `88000045` | Unknown (returns EmptyCreative)  |
| `202914`   | Unknown (returns EmptyCreative)  |
