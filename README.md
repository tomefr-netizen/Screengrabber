# Screengrabber

Screengrabber är en lättviktig macOS-app för att ta skärmbilder och annotera dem snabbt när du bygger manualer, guider och annan dokumentation.

Appen är byggd för ett enkelt arbetsflöde:
- ta en skärmbild med snabbtangent eller via menyikonen
- markera, rita, skriva och peka ut detaljer
- zooma och panorera utan att annotationer tappar position
- spara som `AVIF` eller `PNG`
- kopiera till urklipp när du vill jobba vidare direkt

## Funktioner

- Skärmfångning av valfritt område
- Fördröjd fångning
- Penna och överstrykningspenna
- Rektangel, ellips och pil
- Textverktyg
- Stegmarkörer
- Blur/pixelering
- Zoom-bubbla
- Symboler: `checkmark`, `kryss`, `info`, `varning`
- Flytta objekt med `⌘ + dra`
- Ändra storlek på befintliga objekt
- Canvas-zoom `25–400 %`
- Panorering med mus
- Export till `AVIF` och `PNG`
- Kopiera till urklipp

## Kortkommandon och interaktion

- `Ctrl + Shift + S`: starta skärmfångning
- `⌘ + scroll`: zooma canvas
- `Option + dra`: panorera
- `Mittenmus + dra`: panorera
- `⌘ + dra på objekt`: tillfälligt flyttläge
- `Esc`: avbryt skärmfångning

## Målgrupp

Screengrabber är främst byggd för att dokumentera appar och gränssnitt snabbt, utan att behöva hoppa mellan flera olika verktyg.

## Bygga projektet

Öppna `Screengrabber.xcodeproj` i Xcode och kör appen med schemat `Screengrabber`.

Du kan också bygga från terminalen:

```bash
xcodebuild -project Screengrabber.xcodeproj -scheme Screengrabber -configuration Debug build
```

## Installation

Se [INSTALL.md](/Volumes/home/VScode/Screengrabber/INSTALL.md) för installationsinstruktioner.
