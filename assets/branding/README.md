# Brand assets

Official Octo Cluster logos and icons. MIT-licensed project assets — see [LICENSE](../../LICENSE).

## Files

| File | Variant | Use when |
|------|---------|----------|
| [`logo-primary.png`](./logo-primary.png) | Primary logo (refurbished, with wordmark) | Docs headers, presentations, social banners |
| [`app-icon.png`](./app-icon.png) | App icon (rounded square, 1024×1024) | Desktop/mobile app icons, PWA manifest |
| [`favicon.png`](./favicon.png) | Favicon (simplified mark, ring border) | Browser tabs, small UI chrome |
| [`github-avatar.png`](./github-avatar.png) | GitHub avatar (512×512 circle) | GitHub org/repo profile image |
| [`logo-system-overview.png`](./logo-system-overview.png) | Reference sheet (A–D) | Design reference only — not for production embed |

## Usage

- Prefer **PNG** sources from this folder; do not upscale raster assets.
- Keep aspect ratio; do not stretch or recolor without a design pass.
- For README embed: `![Octo Cluster](./assets/branding/logo-primary.png)` (resize via HTML width if needed).

## Validation

```powershell
Get-ChildItem assets/branding/*.png | Select-Object Name, Length
```

Expect five PNG files plus this README.

## Limitations

- Raster only (no SVG in repo yet). ponytail: add `logo-primary.svg` when a vector export exists.
- `logo-system-overview.png` is a composite reference — use the individual files above in products.

## Related

- Brand overview: [`logo-system-overview.png`](./logo-system-overview.png)
- [THIRD_PARTY.md](../../THIRD_PARTY.md) — original Octo Cluster assets
