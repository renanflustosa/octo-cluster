# Brand assets

Official Octo Cluster logos and icons. MIT-licensed project assets — see [LICENSE](../../LICENSE).

## Files

| File | Variant | Dimensions | Use when |
|------|---------|------------|----------|
| [`logo-primary.png`](./logo-primary.png) | Primary symbol (detailed, **no wordmark**; circular light background, transparent outside) | 1024×1024 | Docs headers, README hero, presentations |
| [`app-icon.png`](./app-icon.png) | App icon (rounded square) | 565×565 | Desktop/mobile app icons, PWA manifest |
| [`favicon.png`](./favicon.png) | Favicon (simplified mark) | 256×256 | Browser tabs, small UI chrome |
| [`github-avatar.png`](./github-avatar.png) | GitHub avatar (circle) | 415×415 | GitHub org/repo profile image |
| [`wallpaper-dark.png`](./wallpaper-dark.png) | Desktop wallpaper (2560×1440, navy) | 2560×1440 | Personal desktop background — not for embed |
| [`logo-system-overview.png`](./logo-system-overview.png) | Reference sheet (3 variants) | 1254×1254 | Design reference only — not for production embed |

## Usage

- Prefer **PNG** sources from this folder; do not upscale raster assets.
- Keep aspect ratio; do not stretch or recolor without a design pass.
- For README embed: `width` must be ≤ native width of `logo-primary.png` (downscale only). Square canvas with circular light disc — transparent corners integrate with GitHub dark mode.

## Validation

```powershell
Get-ChildItem assets/branding/*.png | Select-Object Name, Length
```

Expect six PNG files plus this README.

## Limitations

- Raster only (no SVG in repo yet). ponytail: add `logo-primary.svg` when a vector export exists.
- `logo-primary.png` is symbol-only; wordmark no longer bundled.
- `app-icon`, `github-avatar`, and `favicon` are cropped from `logo-system-overview.png` at native resolution (no upscale). Re-export individual files when standalone HQ versions exist.
- `wallpaper-dark.png` unchanged — no HQ export in source batch.

## Related

- Brand overview: [`logo-system-overview.png`](./logo-system-overview.png)
- [THIRD_PARTY.md](../../THIRD_PARTY.md) — original Octo Cluster assets
