# Screenshot & Annotation Tool
Version: Alpha 0.00002  
Platform: macOS (Apple Silicon, Sonoma eller senare)  
Start: 2026‑04‑20

## 🎯 Syfte
En lätt och snabb macOS‑app för att:
- ta skärmbilder via kortkommando
- rita, markera och kommentera bilder
- spara i webbvänliga format (WebP, AVIF, PNG)
- skapa material till manualer, guider och PWA‑appar med låg bandbredd

Appen ska vara enkel, snabb och ha ett workflow optimerat för dokumentation.

---

# ⌨️ Kortkommando
Global hotkey för att starta skärmfångaren.

**Förslag:** `⌘ + ⇧ + S`  
(Claude får föreslå alternativ om det krockar med systemet.)

---

# 📸 Skärmfångning

## Funktioner
- Dra en rektangel över skärmen för att välja område
- Direkt efter fångst öppnas editorn
- Fördröjd fångning: 2, 5 och 10 sekunder
- Vid fördröjning ska skärmen “frysas” så att menyer inte stängs
- Stöd för flera skärmar
*klart*

## Tekniskt
- Använd `CGWindowListCreateImage` eller `CGDisplayCreateImage`
- Hantera koordinatsystem korrekt (ingen upp‑och‑ner‑bild)
- Vid fördröjning: ta snapshot av hela skärmen → visa som overlay → låt användaren markera på den

---

# 🖌️ Editor – Ritverktyg

## 1. Penna
- Frihand
- Shift = rak linje i 45° intervall
- Färg + tjocklek
*klar*

## 2. Överstrykningspenna
- Transparent färg
- Shift = rak linje
- Färg + opacitet + tjocklek

## 3. Figurer
- Rektangel
- Cirkel
- Pil
- Shift = perfekt kvadrat/cirkel
- Fyllning (valfri färg + transparens)
- Linjefärg + tjocklek

## 4. Figurbibliotek
- Inbyggda figurer: pilar, cirklar, rektanglar, checkmark, kryss, info‑ikon, varningstriangel
- Användaren kan lägga till egna PNG/SVG‑figurer
- Figurer kan skalas och roteras

## 5. Textverktyg
- Valfri font
- Storlek
- Fet/kursiv/understruken
- Textfärg
- Bakgrundsfärg (valfri + transparens)
- Auto‑padding och rundade hörn

## 6. Numrerade cirklar / stegmarkörer
- Autoformaterade cirklar med siffror (1–10)
- Standard: vit text på röd bakgrund
- Shift = perfekt cirkel

## 7. Highlight‑ruta
- Rektangel med transparent fyllning
- Perfekt för att markera sektioner

## 8. Blur / Pixelering
- Blur (Gaussian)
- Pixelate (blockig censur)
- Dra ut område som ska censureras

## 9. Zoom‑bubbla
- Förstoringsglas som förstorar ett valt område
- Justerbar zoomnivå

## 10. Smart‑pil
- Böjbar pil
- Justerbar kurvning
- Shift = rak pil

---

# 🧰 Övriga verktyg
- Undo/Redo
- Zoom (25–400 %)
- Dra‑och‑släpp av figurer
- Kopiera till urklipp (WebP, PNG, AVIF)
- Mörkt och ljust tema (ej aktuellt)

---

# 🪟 UI – Flytande meny

## När appen är inaktiv
En liten flytande meny med:
- Ny
- Spara
- Fördröjning (2, 5, 10 sek)

## När en bild är fångad
Menyrad + verktygspanel:
- Ny
- Spara
- Fördröjning
- Penna
- Överstrykningspenna
- Figurer
- Text
- Blur
- Zoom‑bubbla
- Stegmarkörer

---

# 💾 Spara funktion

## Format
- **WebP** (standard)
- **AVIF** (premiumformat, kräver libavif/FFmpeg)
- **PNG** (fallback)

## Spara‑dialog
- “Spara” → normal dialog
- “Spara som…” → välj namn, plats och format
- Standardfilnamn: `Screenshot-YYYYMMDD-HHMMSS.webp`

---

# 🔄 Ny bild
- Om nuvarande bild är osparad → fråga om användaren vill spara
- Om sparad → töm editor och börja om
- Editorfönstret ska rensas helt vid “Ny”

---

# 🧠 Implementation – frihet för utvecklaren
Claude får själv välja:
- bibliotek för AVIF
- struktur på projektet
- SwiftUI/AppKit‑mix
- optimeringar
- caching
- renderingsteknik

---

# 🗺️ Roadmap (förslag)
## v0.1
- Skärmfångning
- Penna
- Text
- Spara som PNG/WebP

## v0.2
- Figurer
- Highlight‑ruta
- Blur/pixelering

## v0.3
- AVIF‑export
- Zoom‑bubbla
- Stegmarkörer

## v1.0
- Figurbibliotek
- Smart‑pil
- Clipboard‑export
- Stabilitet och optimering


