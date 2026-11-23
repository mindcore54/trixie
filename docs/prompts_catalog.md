# Catálogo y Guía de Prompts Consistentes — *Trixie*

Este documento estandariza cómo generar ilustraciones de personajes y props para que mantengan coherencia visual y sean 100% compatibles con el script automático de transparencia (`tools/process_white_bg.py`).

> **Archivo de Prompts por Personaje:** Los prompts exactos ya aprobados de cada personaje (Concept Art, Retratos `16:9`, Medio Cuerpo `4:3` y archivo de Semi-Chibi) se guardan en [prompts_characters.md](file:///c:/Users/mindcore.dev/Projects/trixie/docs/prompts_characters.md).

## Reglas de Oro para Todo Prompt
1. **Fondo Blanco Puro (`#FFFFFF`) sin Sombra Proyectada ni Marco:**
   Siempre incluye al final:
   `isolated on a completely pure solid white #FFFFFF background, zero background scenery, no frame or border around the character, no floor cast shadow, closed dark outer silhouette contour`
2. **Contorno Cerrado Obligatorio:**
   El lineart exterior oscuro debe ser continuo y cerrado. Esto permite que `process_white_bg.py` elimine el fondo exterior con *flood-fill* desde los bordes sin perforar ojos blancos, dientes, brillos ni prendas blancas internas.
3. **3 Tipos de Imagen por Personaje (sin chibis ni múltiples tamaños de retrato):**
   - **Concept Art (`concept`)**: Solo hoja de referencia de diseño (frente, espalda, rostro, accesorios). **NO se usa como `fullbody` en el juego.**
   - **Retrato (`portrait` — Hoja `16:9`)**: Las 6 expresiones juntas en `16:9`, exportadas en un solo tamaño estándar (rostro y hombros).
   - **Medio Cuerpo (`halfbody` — 2 Hojas `4:3`, 3 por imagen)**: Ilustraciones verticales sin marco, divididas en **Hoja 1 Core Gameplay** (`normal`, `confiada`, `nerviosa_sudando`) y **Hoja 2 Secundarias** (`sonrojada_picante`, `hollin_derrota`, `sorprendida`) para asegurar consistencia en las 3 principales de partida.
   - **Full Size (`fullbody` — Vertical `9:16`)**: Ilustración de cuerpo completo **dedicada y pensada aparte** en `9:16` (pose de presentación/escena, nunca reciclada del Concept Art).
4. **Dirección Estética (Próximos Conceptos):** Estilo súper sexy con curvas marcadas y recursos de vestuario atrevido (escotes muy pronunciados, *underboob*, *sideboob*, transparencias) según la personalidad de cada personaje.

---

## Generador CLI Rápido
Usa [generate_prompts.py](file:///c:/Users/mindcore.dev/Projects/trixie/tools/generate_prompts.py) para imprimir prompts listos para copiar y pegar:

```bash
# 0. Concept Art (SOLO referencia de diseño)
python tools/generate_prompts.py --type concept --id trixie --archetype "playful curvy young fire witch with wavy chestnut hair and amber eyes" --outfit "dark purple off-shoulder corset witch dress, thigh-high stockings, tilted pointed hat"

# 1. Pack de Retratos (tamaño único, rostro y hombros)
python tools/generate_prompts.py --type portrait --id sylvi --archetype "gorgeous curvy female faun with curled ram horns, fluffy ears, glowing golden eyes and wavy blonde hair" --outfit "ornate low-cut woodland tavern bodice"

# 2. Pack de Medio Cuerpo (vertical, sin marco, para pantalla de juego)
python tools/generate_prompts.py --type halfbody --id sylvi --archetype "gorgeous curvy female faun with curled ram horns, fluffy ears, glowing golden eyes and wavy blonde hair" --outfit "ornate low-cut woodland tavern bodice"

# 3. Full Size dedicado (NO reutilizar Concept Art)
python tools/generate_prompts.py --type fullbody --id trixie --archetype "playful curvy young fire witch with wavy chestnut hair and amber eyes" --outfit "dark purple off-shoulder corset witch dress, thigh-high stockings, tilted pointed hat"

# 4. Props / Calderos / UI
python tools/generate_prompts.py --type prop --id cauldron --archetype "cast-iron alchemy cauldron with glowing purple runes"
```

---

## Plantillas Maestras de Referencia

### Plantilla 0 — Concept Art (Solo Referencia)
> Character design reference sheet titled `[NOMBRE] - Concept Art` of `[ARCHETYPE]`, wearing `[OUTFIT]`. Includes front full-body view, back full-body view, large expressive face close-up, and clear outfit/accessory callouts. 2D digital anime illustration in the bold charismatic style of Helltaker mixed with vibrant fantasy anime, crisp closed dark ink outlines, cel-shaded colors with subtle warm rim highlights, expressive appealing curvy anatomy, isolated on a completely pure solid white #FFFFFF background, zero background scenery, no frame or border around the character, no floor cast shadow, closed dark outer silhouette contour.

### Plantilla 1 — Retratos (Tamaño Único, Rostro y Hombros)
Usar los 6 sufijos para mapeo automático en Godot:
1. `*_portrait_normal.png`: `confident playful half-smile, relaxed alluring posture, bright expressive eyes`
2. `*_portrait_confiada.png`: `smug victorious grin, one hand on hip or winking playfully, sparkling aura`
3. `*_portrait_nerviosa_sudando.png`: `panicked wide eyes, anime sweat drops, flustered bitten lip, tense shoulders`
4. `*_portrait_sonrojada_picante.png`: `heavy rosy blush, teasing bedroom eyes, slight smirk, flirty dynamic pose`
5. `*_portrait_hollin_derrota.png`: `comical soot smudges on cheeks and clothes, messy disheveled hair, torn/askew hat or apron, dizzy spiral or shocked anime eyes, cute defeated pose`
6. `*_portrait_sorprendida.png`: `wide-eyed cute shock, raised hands or startled tilt, lively anime reaction`

### Plantilla 2 — Medio Cuerpo Vertical (Sin Marco)
> Vertical waist-to-mid-thigh-up 2D anime character illustration of `[ARCHETYPE]`, wearing `[OUTFIT]`. Tall vertical composition designed to stand freely on screen without any border or frame. Expression & body language: `[EMOCIÓN]`. Crisp closed dark ink outlines, cel-shaded colors with warm rim highlights, isolated on pure solid white #FFFFFF background, no floor cast shadow.

### Plantilla 3 — Full Size Dedicado (NO Concept Art)
> Dedicated full-body vertical 2D anime key illustration of `[ARCHETYPE]`, wearing `[OUTFIT]`. Intentional dynamic showcase pose from head to boots with strong personality, appeal, and lively silhouette (composed as finished in-game/menu illustration, NOT a neutral turnaround reference sheet). Isolated on pure solid white #FFFFFF background, no frame or border, no floor cast shadow.

### Plantilla 4 — Props de Alquimia y UI
> 2.5D slightly tilted top-down stylized fantasy alchemy asset: `[ITEM/UI DESCRIPTION]`. Hand-painted cozy-dark wooden/arcane aesthetic with crisp bold dark ink outline matching Helltaker, isolated on pure solid white #FFFFFF background, no floor cast shadow.

---

## Flujo Automático hacia Godot
1. Guarda las imágenes crudas generadas en `raw_assets/<personaje_o_tipo>/`.
2. Limpia el fondo blanco:
   ```bash
   python tools/process_white_bg.py raw_assets/trixie --category playable --id trixie --trim
   ```
3. Exporta a resolución 1:1 para Godot:
   ```bash
   python tools/export_character_sizes.py --id trixie --category playable --flip-portraits
   ```
