# Catálogo y Guía de Prompts Consistentes — *Trixie*

Este documento estandariza cómo generar ilustraciones, retratos, sprites semi-chibi 2.5D y elementos de UI para que mantengan coherencia visual con la referencia aprobada ([stash/imagen3.jpeg](file:///c:/Users/M1ndc0re53/Projects/trixie/stash/imagen3.jpeg)) y sean 100% compatibles con el script automático de transparencia (`tools/process_white_bg.py`).

## Reglas de Oro para Todo Prompt
1. **Fondo Blanco Puro (`#FFFFFF`) sin Sombra Proyectada:**
   Siempre incluye al final:
   `isolated on a completely pure solid white #FFFFFF background, zero background scenery, no floor cast shadow, closed dark outer silhouette contour`
2. **Contorno Cerrado Obligatorio:**
   El lineart exterior oscuro debe ser continuo y cerrado. Esto permite que `process_white_bg.py` elimine el fondo exterior con *flood-fill* desde los bordes sin perforar ojos blancos, dientes, brillos ni delantales/prendas blancas internas.
3. **Tono Visual (Helltaker + Fantasy Anime Ecchi Stream-Friendly):**
   Atractivo, curvas marcadas, silueta legible, humor picante y expresividad exagerada, **sin desnudez ni contenido explícito**.

---

## Generador CLI Rápido
Usa [generate_prompts.py](file:///c:/Users/M1ndc0re53/Projects/trixie/tools/generate_prompts.py) para imprimir prompts listos para copiar y pegar:

```bash
# 1. Concept Art de cuerpo completo
python tools/generate_prompts.py --type concept --id trixie --archetype "playful curvy young fire witch with wavy chestnut hair and amber eyes" --outfit "dark purple off-shoulder corset witch dress, thigh-high stockings, tilted pointed hat"

# 2. Pack de 6 expresiones (Busto HUD o Retrato Grande de Clienta)
python tools/generate_prompts.py --type portraits --id sylvi --archetype "gorgeous curvy female faun with curled ram horns, fluffy ears, glowing golden eyes and wavy blonde hair" --outfit "ornate low-cut woodland tavern bodice" --framing "waist-up large portrait"

# 3. Sprites 2.5D Semi-Chibi In-Game (~3 cabezas de altura)
python tools/generate_prompts.py --type chibi --id trixie --archetype "curvy young fire witch" --outfit "dark purple off-shoulder corset dress and pointed hat"

# 4. Props / Calderos / Pergamino Chipped UI
python tools/generate_prompts.py --type prop --id parchment_dialogue --archetype "horizontal old weathered parchment scroll banner with chipped torn edges and subtle warm ink stain"
```

---

## Plantillas Maestras de Referencia

### Plantilla A — Concept Art de Cuerpo Completo
> Full-body character design sheet of `[ARCHETYPE]`, wearing `[OUTFIT]`. Clean front-3/4 standing hero pose showing full silhouette, proportions, and outfit details clearly from head to boots. 2D digital anime illustration in the bold charismatic style of Helltaker mixed with vibrant fantasy anime, crisp closed dark ink outlines, cel-shaded colors with subtle warm rim highlights, expressive appealing curvy anatomy, stream-friendly suggestive ecchi aesthetic (no nudity, no NSFW explicit details), isolated on a completely pure solid white #FFFFFF background, zero background scenery, no floor cast shadow, closed dark outer silhouette contour.

### Plantilla B — Pack de 6 Retratos Reactivos (Busto HUD / Clientas)
Usar exactamente los 6 sufijos para mapeo automático en Godot (`WitchCharacterData` / `CustomerArchetypeData`):
1. `*_normal.png`: `confident playful half-smile, relaxed alluring posture, bright expressive eyes`
2. `*_confiada.png`: `smug victorious grin, one hand on hip or winking playfully, sparkling aura`
3. `*_nerviosa_sudando.png`: `panicked wide eyes, anime sweat drops, flustered bitten lip, tense shoulders`
4. `*_sonrojada_picante.png`: `heavy rosy blush, teasing bedroom eyes, slight smirk, flirty dynamic pose`
5. `*_hollin_derrota.png`: `comical soot smudges on cheeks and clothes, messy disheveled hair, torn/askew hat or apron, dizzy spiral or shocked anime eyes, cute defeated pose`
6. `*_cutin_habilidad.png`: `ultra-dynamic anime special-attack cut-in framing, dramatic wind in hair, glowing arcane energy, intense confident gaze`

### Plantilla C — Sprite In-Game Semi-Chibi 2.5D (~3 Cabezas)
> 2.5D top-down tilted 3/4 view game sprite of `[ARCHETYPE]` in stylized semi-chibi ~3-head-tall proportions, preserving attractive curvy waist and clear outfit silhouette, wearing `[OUTFIT]`. Pose: `[idle | move_a | move_b | action]`. Crisp bold dark outline readable at gameplay scale, isolated on pure solid white #FFFFFF background, no floor cast shadow.

### Plantilla D — Props de Cocina y UI (Pergamino *Chipped* / Botones / Frascos)
> 2.5D top-down tilted 3/4 view stylized fantasy alchemy asset: `[ITEM/UI DESCRIPTION]`. Hand-painted cozy-dark wooden/arcane aesthetic with crisp bold dark ink outline matching Helltaker and Cake Mania, isolated on pure solid white #FFFFFF background, no floor cast shadow.

---

## Flujo Automático hacia Godot
1. Guarda las imágenes crudas generadas en `raw_assets/<personaje_o_tipo>/`.
2. Ejecuta:
   ```bash
   python tools/process_white_bg.py raw_assets/trixie --category playable --id trixie --trim
   ```
3. Los PNGs transparentes quedan guardados directamente en `res://assets/characters/playable/trixie/`.
