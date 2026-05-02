# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Screengrabber** — a lightweight macOS screenshot and annotation tool optimized for creating documentation and web-friendly assets. Spec in `md/🧩 PROJEKTBESKRIVNING.md` (Swedish).

- **Platform:** macOS, Apple Silicon, Sonoma+
- **Language:** Swift (SwiftUI/AppKit mix — developer's choice)
- **Status:** Pre-alpha, no source code yet as of 2026-04-20

## Build & Run

No Xcode project exists yet. When one is created, standard commands will be:

```bash
xcodebuild -scheme Screengrabber -configuration Debug build
xcodebuild -scheme Screengrabber -configuration Debug test
```

## Architecture Decisions (developer has full freedom)

The spec intentionally leaves these open:

- SwiftUI vs AppKit vs hybrid UI
- AVIF library choice (libavif, FFmpeg, or other)
- Project/module structure
- Rendering technique for the annotation canvas
- Caching strategy

## Core Features (from spec)

### Screenshot Capture
- Global hotkey `⌘+⇧+S` (verify no system conflict)
- Drag-to-select region → immediately opens editor
- Delayed capture (2 / 5 / 10 sec): freeze the screen as an overlay so open menus stay visible, then capture
- Multi-monitor support
- Use `CGWindowListCreateImage` or `CGDisplayCreateImage`; fix coordinate system so image is not flipped

### Editor Tools
1. **Pen** — freehand; Shift = straight line in 45° increments
2. **Highlighter** — transparent color; Shift = straight line
3. **Shapes** — rectangle, circle, arrow; Shift = perfect square/circle; optional fill (color + opacity)
4. **Shape library** — built-in icons (arrows, checkmark, cross, info, warning); user can add PNG/SVG
5. **Text** — font, size, bold/italic/underline, text color, background color + opacity, auto-padding, rounded corners
6. **Step markers** — numbered circles 1–10, white text on red background
7. **Highlight box** — transparent-filled rectangle for section emphasis
8. **Blur/Pixelate** — Gaussian blur or block pixelation over a drag-selected area
9. **Zoom bubble** — magnifying glass overlay for a selected region
10. **Smart arrow** — curved, adjustable path; Shift = straight

Other: Undo/Redo, canvas zoom 25–400%, drag-to-reposition annotations, copy to clipboard (WebP/PNG/AVIF), dark/light theme.

### Floating Menu UI
- **No image captured:** small floating panel — New, Save, Delay picker
- **Image captured:** toolbar expands with all tool buttons

### Save
- Formats: **WebP** (default), AVIF, PNG
- Default filename: `Screenshot-YYYYMMDD-HHMMSS.webp`
- "Save" and "Save As…" dialogs
- AVIF requires an external library (libavif or FFmpeg)

### New Image Flow
- If unsaved changes → prompt to save → clear editor
- If already saved → clear editor immediately

## Roadmap

| Version | Scope |
|---------|-------|
| v0.1 | Screenshot capture, pen, text, PNG/WebP save |
| v0.2 | Shapes, highlight box, blur/pixelate |
| v0.3 | AVIF export, zoom bubble, step markers |
| v1.0 | Shape library, smart arrow, clipboard export, stability |
