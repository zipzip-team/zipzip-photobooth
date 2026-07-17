# PhotoPrintBooth

MacBook local camera app for capture, filter selection, preview, and 100 x 148 mm printing.

## Run

```bash
./Scripts/build_app.sh
open .build/PhotoPrintBooth.app
```

The first launch should ask for camera permission.

## Print Size

Target paper size is **100 x 148 mm**.

- Portrait ratio: `100:148`
- Landscape ratio: `148:100`
- 300 dpi export target:
  - Portrait: `1181 x 1748 px`
  - Landscape: `1748 x 1181 px`

The app preview uses this same ratio, so the camera crop should match the print layout.

## Figma Filter Asset Guide

Send filters as overlay assets with transparent background.

- Recommended format: `PNG`
- Color profile: `sRGB`
- Portrait size: `1181 x 1748 px`
- Landscape size: `1748 x 1181 px`
- Filename example:
  - `filter_01_clean.png`
  - `filter_02_vintage.png`

If the filter is only a color/effect recipe rather than a frame overlay, send:

- A PNG preview from Figma
- The intended effect notes: brightness, contrast, saturation, blur, vignette, grain, color tint

## Current MVP Scope

- Camera preview
- Capture photo
- Filter selection
- Photo preview
- Print through macOS print panel
