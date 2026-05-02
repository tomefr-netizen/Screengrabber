

# 📸 Skärmfångning

---

# 🖌️ Editor – Ritverktyg


## 4. Figurbibliotek
- Inbyggda figurer: checkmark, kryss, info‑ikon, varningstriangel
- Användaren kan lägga till egna PNG/SVG‑figurer
- Figurer kan skalas och roteras

## 5. Textverktyg
- Bakgrundsfärg (valfri + transparens)
- Auto‑padding och rundade hörn


## 9. Zoom‑bubbla
- Förstoringsglas som förstorar ett valt område
- Justerbar zoomnivå

## 10. Smart‑pil
- Böjbar pil
- Justerbar kurvning
- Shift = rak pil

---

# 🧰 Övriga verktyg
- Zoom (25–400 %)
- Kopiera till urklipp (PNG, AVIF)

---

# 🪟 UI – Flytande meny

## När appen är inaktiv
En liten flytande meny med:
- Ny
Ny finns, men fungerar inte



# 🗺️ Roadmap (förslag)


## Funktionsmissar. 
1. Budget besparande åtgärd. Lås fönsterstorleken istället.
När ett fönster ändrar storlek, så behåller vi aspect-ratio = bra. Men objekten som vi ritat flyter dock omkring på den visuella bilden. I den sparade bilden ändras inte zoom och därmed inte heller objektens placering (bra), det är bara en visnings feature som vi inte vill ha. Det blir ett problem när användaren flyttar objekten till visuellt "rätt" plats och dom flyttas till fel plats i den sparade bilden.
Jag tror att det här kan påverka skalning och flyttning av objekt, så vi kanske behöver ordna det här först?
Vi kan göra det i kombination med att kunna zooma in hela bilden (25-400%), se Övriga verktyg.

2. Jag såg nu att bilden sparas uppochner och spegelvänt, se bild3.avif

3. Glädjande nyhet. Jag har trott att vårt tangentbordskommando är CMD+Shift+S, det har inte fungerat. Men nu ser jag att det är Control+Shift+S och det fungerar, en sak till att släppa.

## v0.3.2
Budget besparande åtgärd, rationaliseras bort helt.
- Alla figurer kan skalas och roteras
- Låst figurers possition mot bakgrunden när fönster ändrar storlek.

## v.0.4
- Lås fönsterstorleken, tillåt inte att fönstret ändrar storlek. Minimera, återställ och stäng är ok. Detta för att spara token.
- Använd escape (eller annan Mac tangent) för att avbryta en fångning, just nu måste vi fånga en bild när vi klickat på Kameraikonen, eller tryckt CTRL+Shift+S
- Spara bilderna åt rätt håll, nu sparas dom spegelvända och uppochner, lite Leonardo Davinchi krypto

## v0.5
- Figurbibliotek
- Smart‑pil <- Tveksam till den här nu
- Clipboard‑export
- Stabilitet och optimering


