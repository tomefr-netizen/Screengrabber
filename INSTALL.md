# Installera Screengrabber

Det här dokumentet beskriver hur någon annan kan installera och köra Screengrabber.

## Krav

- macOS på Apple Silicon
- Xcode installerat om appen ska byggas från källkod

## Alternativ 1: Installera färdig app

Om du har fått en färdig `Screengrabber.app`:

1. Dra `Screengrabber.app` till mappen `Program`.
2. Starta appen från `Program`.
3. Första gången kan macOS fråga om du verkligen vill öppna appen.
4. Ge appen de rättigheter den behöver om macOS ber om det.

Rättigheter som normalt behövs:
- skärminspelning/skärmfångning
- hjälpmedel eller liknande åtkomst för global snabbtangent, beroende på systemets säkerhetsinställningar

Om macOS blockerar appen:
1. Öppna `Systeminställningar > Integritet och säkerhet`
2. Leta upp blockeringen längst ned i säkerhetsvyn
3. Tillåt att appen öppnas

## Alternativ 2: Bygg från källkod i Xcode

1. Klona eller kopiera projektmappen.
2. Öppna `Screengrabber.xcodeproj` i Xcode.
3. Välj schemat `Screengrabber`.
4. Tryck `Run`.
5. Godkänn eventuella rättighetsförfrågningar från macOS.

## Bygga från terminalen

Du kan också bygga projektet utan att öppna Xcode:

```bash
xcodebuild -project Screengrabber.xcodeproj -scheme Screengrabber -configuration Debug build
```

Den byggda appen hamnar normalt i Xcodes `DerivedData`-mapp.

## Installera den byggda appen manuellt

Efter en lyckad build kan du kopiera appen till `Program`:

1. Leta upp `Screengrabber.app` i Xcodes byggutdata
2. Kopiera den till mappen `Program`

## Om skärmfångning inte fungerar

Kontrollera detta:

1. att appen har rättigheter för skärminspelning/skärmfångning
2. att appen får köras i bakgrunden om macOS frågar
3. att snabbtangenten inte krockar med något annat på systemet

Om rättigheter ändras efter första start kan det ibland hjälpa att:

1. stänga appen helt
2. starta om den
3. i vissa fall logga ut och in igen

## Uppdatera appen

För att uppdatera en redan installerad version:

1. avsluta appen
2. ersätt `Screengrabber.app` i mappen `Program` med den nya versionen
3. starta appen igen
