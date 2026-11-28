# Pipeline de SFX y Voces con ElevenLabs — *Trixie (Love Potion Tour)*

> **Propósito:** Guía técnica y operativa reutilizable (manual + especificación de skill) para diseñar, presupuestar, generar, post-procesar e integrar efectos de sonido (SFX), ambientes y *voice barks* en **Godot 4.7** usando **ElevenLabs (Plan Starter)** sin desperdiciar créditos.

---

## 1. Contexto de Cuenta, Presupuesto y Alcance Sonoro

### 1.1 Suscripción Activa (Plan Starter)
* **Plan:** Suscripción directa a **ElevenLabs Starter** (**30,000 créditos/mes**).
* **Licencia y Acceso:** Incluye **licencia comercial** y acceso completo a la API consumiendo de la misma bolsa mensual de `30,000` créditos.
* **Nota estratégica para Steam (`roadmap.md` §5.3):** Aunque el plan Starter otorga licencia comercial plena, ten presente que la encuesta de publicación de **Steam** exige declarar contenido pre-generado con IA si en la build comercial final permanecen voces o SFX generados por IA (independientemente de que todo el arte visual se redibuje 100% a mano en Krita). Esta guía sirve tanto para **prototipado/Demo ágil** como para producción final si se decide declarar audio asistido o usarlo de referencia (*temp track*) antes de grabar voces definitivas.

### 1.2 Filosofía de Audio en *Trixie* (100% *Voice Barks* Independientes del Guion)
El bucle táctico de *Love Potion Tour* (olas rápidas de `2–5` clientas, caldero de clics/mezclas y lectura ágil) **no dobla diálogos extensos ni lee textos del guion**:
1. **SFX táctiles con identidad alquímica:** Golpes y grietas de orbes (`3 -> 2 -> 1`), fusiones elementales, purga segura (`❌`), llenado y corcho del matraz, lanzamiento de Cartas Hechizo, familiares y ambientes por parada del Mapa.
2. **Voces = 100% Expresiones No Verbales (*Non-Verbal Barks*) en Fonética Japonesa (`0.4s–1.8s`):** **Cero palabras ni frases habladas.** Únicamente sonidos expresivos puros (sorpresa *"ええぇっ！？"*, risitas *"えへへっ♪"*, enojo/puchero *"むぅ〜っ！"* , pánico *"あわわっ！"*, suspiros, tos de hollín *"けほっ…うぅ…"*) escritos en kana japonés dentro de `tools/audio_manifest.json` para aprovechar la expresividad *seiyuu*.
3. **Desacoplamiento total del texto escrito (estilo *Zelda*):** Como ningún personaje pronuncia palabras reales, jamás choca con lo que diga el cuadro de texto en pantalla, nunca se lee ni parsea ningún banco de diálogos y sirve universalmente en cualquier idioma (`ES / EN / JP`).

---

## 2. Puntos de Parada Obligatorios (*Human-in-the-Loop*)

> [!IMPORTANT]
> **Regla estricta para Antigravity:** El agente **NO puede escuchar audio**. Queda terminantemente prohibido ejecutar lotes de generación o tomar decisiones estéticas de voz sin detenerse primero en estos **5 puntos de control** con el desarrollador:

1. **Selección y mapeo de voces (`voice_id`):**
   * Antes de generar cualquier *bark* de un personaje (`trixie`, `sylvi`, `velvet`, `seraphina`, `mona`, `roxy`, `lyra`, `nyxara`, `morrigan`, `goblin_boss`), pedir al desarrollador que audicione o cree la voz en la web de ElevenLabs (preferiblemente con **Voice Design**) y entregue el par `character_id -> voice_id`.
2. **Clicks y UI ultra básicos (CC0 / Procedural vs. ElevenLabs):**
   * Antes de gastar créditos en micro-sonidos genéricos (hover de botones, ticks de texto, clics secos de menú), consultar al desarrollador si prefiere cubrirlos con un pack **CC0** (ej. *Kenney.nl*) o mantener la síntesis ligera actual en [AudioJuiceManager.gd](../scripts/autoloads/AudioJuiceManager.gd), reservando ElevenLabs para SFX alquímicos con identidad propia y voces.
3. **Grabaciones base para *Speech-to-Speech* (STS):**
   * Si un *bark* anime/coqueto requiere una cadencia, pausa o entonación muy específica que el TTS no clava al primer o segundo intento, **detener los reintentos por texto** y pedir al desarrollador un audio crudo actuado por él en `raw_assets/voices/<character_id>/`.
4. **Aprobación previa de presupuesto (`--dry-run`):**
   * Antes de disparar cualquier lote contra la API, mostrar una tabla resumen con: **cantidad de archivos**, desglose por flujo (`SFX` / `TTS` / `STS`), **costo estimado en créditos** y porcentaje del cupo mensual (`30,000`), esperando confirmación explícita.
5. **Control de Calidad auditivo (QA) con Reproductor Inline en el Chat:**
   * Tras generar cualquier lote (voces o SFX), el agente **debe generar e incrustar un mini reproductor HTML interactivo inline** (usando la skill `generative_ui` + `<agent-embed>`, con comparador `v01 / v02 / v03...` cuando haya versiones previas) para que el desarrollador escuche los clips al instante dentro del chat e indique cuáles pasan a `approved`, cuáles a `regen_requested` y cuáles vuelven a una versión anterior (`--restore`).

### 2.1 Playbook Rápido: Nuevo Personaje (*"Ya creé la voz de X, genera los barks"*)
Cuando el desarrollador diga que ya creó la voz de un personaje en ElevenLabs y pida sus *barks*, ejecutar este flujo exacto sin preguntar pasos intermedios innecesarios:
1. **Detectar `voice_id` (`0` créditos):** ejecutar `python tools/generate_audio.py --list-voices` y registrar su `voice_id` bajo `voices.<char_id>` en `tools/audio_manifest.json`.
2. **Medir saldo inicial (`0` créditos):** ejecutar `python tools/generate_audio.py --credits`.
3. **Añadir los *barks* al manifiesto:**
   * **Brujas (`playable`):** `6` emociones (`normal`, `confiada`, `nerviosa_sudando`, `sonrojada_picante`, `hollin_derrota`, `sorprendida`).
   * **Clientas/Jefas (`customers`):** `3` emociones core (`normal`, `sonrojada_picante`, `impaciente`).
   * **Reglas de texto:** 1 sola expresión no verbal corta en kana japonés por clip (cero palabras, sin lectura del guion, terminación vocal abierta `〜` o `!` sin corte glotal `っ` brusco si es risa/suspiro suave).
   * *Presupuesto:* si es un pack grande o SFX (`> 100` créditos) o el usuario no pidió generar de inmediato, mostrar `--dry-run` y esperar confirmación; si pidió explícitamente generar el pack estándar de un personaje (`< 100` créditos), proceder directo.
4. **Generar, recortar y reimportar:** ejecutar `python tools/generate_audio.py --character <char_id>` y reimportar con el binario local de Godot (`<godot_exe> --headless --import`) *(en Godot no hace falta editar scripts: `AudioJuiceManager.gd` e `IntroCutscene.gd` detectan automáticamente `res://assets/audio/voices/<playable|customers>/<id>/vo_<id>_<emo>_01.wav`)*.
5. **Entregar reproductor QA inline + reporte de créditos:** ejecutar `python tools/generate_audio.py --credits`, reportar **gasto real de la tanda + saldo restante**, e incrustar el widget HTML inline (`generative_ui` + `<agent-embed>`) para que los escuche y apruebe al momento.

---

## 3. Estructura de Carpetas, Formatos Godot 4.7 y Nomenclatura

### 3.1 Árbol de Directorios en el Repositorio
Se aprovecha que `raw_assets/*` ya está excluido tanto de Git ([.gitignore](../.gitignore)) como del importador de Godot (`raw_assets/.gdignore`):

```text
raw_assets/
├── voices/                        # Grabaciones crudas del desarrollador (.wav, .mp3, .m4a, .aac) para STS
│   ├── trixie/                    # Ej: trixie_hollin_01.m4a, trixie_giggle_01.wav
│   └── mona/                      # Ej: mona_hmph_01.m4a
├── audio_api_raw/                 # Caché temporal de última descarga mp3_44100_128 antes de ffmpeg
└── audio_history/                 # Historial versionado por ID (v01, v02...) para rollback sin coste API
    └── <item_id>/                 # v01.mp3, v01.wav, v01.json (prompt/texto y duración)

assets/audio/                      # Assets finales procesados e importados por Godot (res://assets/audio/)
├── bgm/                           # Música adaptativa por parada/intensidad (.ogg)
├── ambience/                      # Loops ambientales por parada (res://assets/audio/ambience/*.ogg)
├── sfx/
│   ├── ui/                        # Botones madera, pergaminos, mapa, árbol, galería (.wav)
│   ├── cauldron/                  # Golpes 3->2->1, grietas, mezclas, purga ❌, explosión, matraz (.wav)
│   ├── spells/                    # Cartas Hechizo activas (Vórtice, Tinte, Purga Total, Hielo) (.wav)
│   ├── familiars/                 # Michi Alado, Diablillo Purgador, Murciélago Alquimista (.wav)
│   └── events/                    # Llegada clienta, paciencia baja, afinidad ❤, victoria/derrota ola (.wav)
└── voices/
    ├── playable/
    │   ├── trixie/                # vo_trixie_<emocion>_<nn>.wav
    │   ├── lyra/
    │   ├── nyxara/
    │   └── morrigan/
    └── customers/
        ├── sylvi/                 # vo_sylvi_<emocion>_<nn>.wav
        ├── velvet/
        ├── seraphina/
        ├── mona/
        ├── roxy/
        └── goblin_boss/

tools/
├── generate_audio.py              # CLI de generación, historial y post-procesado ffmpeg
└── audio_manifest.json            # Fuente única de verdad (fuera de res://data/; no se empaqueta en el juego)
```

### 3.2 Formato Óptimo en Godot 4.7 (Post-Procesado `MP3 -> WAV` con Latencia Cero)
La API en plan Starter entrega como tope **`mp3_44100_128`**. Nunca importamos ese MP3 crudo directo en Godot para sonidos reactivos porque el codificador MP3 añade *padding* de silencio al inicio (~20–26 ms) y ElevenLabs suele dejar colas de silencio residual al final, retrasando el impacto visual en pantalla:

| Tipo de Asset | Formato Final en `res://` | Especificación `ffmpeg` | Motivo en Godot 4.7 |
| :--- | :--- | :--- | :--- |
| **SFX y *Voice Barks*** (`0.4s–3.5s`: orbes, purga, UI, hechizos, reacciones por emoción) | **`.wav`** (`AudioStreamWAV`) | `PCM 16-bit, 44100 Hz, mono` + **`silenceremove` inicial y final** | **Latencia `0 ms`** al hacer clic o cambiar retrato/emoción, y cero coste de decodificación CPU en combos polifónicos. |
| **Ambientes largos en Loop (`loop: true`)** (`6s–12s`) | **`.ogg`** (`AudioStreamOggVorbis`) | `Vorbis -q:a 5, 44100 Hz, estéreo` | Peso reducido en disco y *loop* continuo sin saltos en `AudioStreamOggVorbis`. |

### 3.3 Convención de Nombres (`snake_case` estricto)
* **SFX:** `sfx_<subcarpeta>_<accion>[_<variante>].wav`
  * Ejemplos: `sfx_cauldron_orb_crack_01.wav`, `sfx_cauldron_orb_merge.wav`, `sfx_cauldron_purge_clean.wav`, `sfx_ui_scroll_open.wav`, `sfx_spell_vortex_cast.wav`.
* **Ambientes:** `amb_<stop_id>_loop.ogg`
  * Ejemplos: `amb_cauldron_simmer_loop.ogg`, `amb_castillo_dusk_loop.ogg`, `amb_bosque_goblins_loop.ogg`, `amb_arroyo_balsa_loop.ogg`.
* **Voice Barks de Brujas** (mapeados por personaje + emoción de `halfbody`: `normal`, `confiada`, `nerviosa_sudando`, `sonrojada_picante`, `hollin_derrota`, `sorprendida`):
  * `vo_<witch_id>_<emocion>_<01..03>.wav`
  * Ejemplos: `vo_trixie_hollin_derrota_01.wav`, `vo_trixie_sonrojada_picante_01.wav`, `vo_trixie_confiada_01.wav`.
* **Voice Barks de Clientas** (mapeados por personaje + emoción de `halfbody`: `normal`, `sonrojada_picante`, `impaciente`, más etiquetas puntuales como `saludo` o `satisfecha` definidas directo en el manifiesto):
  * `vo_<customer_id>_<emocion>_<01..02>.wav`
  * Ejemplos: `vo_mona_impaciente_01.wav`, `vo_velvet_sonrojada_picante_01.wav`, `vo_roxy_normal_01.wav`.

### 3.4 Integración con Buses de Godot, `AudioJuiceManager.gd` y Reglas de Reproducción
Al pasar del prototipo 100% sintetizado a audio mixto, evolucionar [AudioJuiceManager.gd](../scripts/autoloads/AudioJuiceManager.gd) y [GameSettings.gd](../scripts/autoloads/GameSettings.gd) con `default_bus_layout.tres` en 4 buses bajo `Master`:
* `Music` (BGM adaptativa), `Ambience` (fondos en loop), `SFX` (caldero + UI, con `pitch_scale = randf_range(0.94, 1.06)` en impactos normales y escalado pentatónico en rachas) y `Voice` (un único `AudioStreamPlayer` por lado del escenario — izquierda Bruja / derecha Clienta — para que un nuevo *bark* corte limpiamente al anterior sin pisarse).
* **Reglas estrictas de reproducción de *Voice Barks*:**
  1. **Sin repetición consecutiva en cinemáticas ([IntroCutscene.gd](../scripts/ui/IntroCutscene.gd)):** si dos líneas seguidas del mismo hablante comparten la misma emoción normalizada, **no** se vuelve a disparar el audio.
  2. **Silencio vocal durante el gameplay activo ([MainGame.gd](../scripts/core/MainGame.gd)):** en partida, los *barks* suenan **únicamente al inicio de un diálogo formal** (ej. apertura del pergamino de cierre); nunca durante los golpes del caldero ni en reacciones efímeras para no distraer ni tapar los SFX táctiles.

---

## 4. Opciones de Integración con ElevenLabs

### Opción A — API Key + Script Local en Lote en Python *(Recomendada para Producción)*
Dado que todo el pipeline de herramientas del repositorio ([process_white_bg.py](../tools/process_white_bg.py), [slice_sprite_sheet.py](../tools/slice_sprite_sheet.py), [export_character_sizes.py](../tools/export_character_sizes.py), [generate_prompts.py](../tools/generate_prompts.py)) está escrito en **Python 3.10+** y el entorno ya cuenta con **`ffmpeg`** en `PATH`, el flujo estándar de producción se centraliza en un script CLI declarativo (`tools/generate_audio.py`) leyendo `tools/audio_manifest.json`.

**Configuración de seguridad obligatoria antes del primer uso:**
1. **Crear API Key restringida en el Dashboard de ElevenLabs:**
   * Activar **únicamente** permisos para:
     * `Sound Effects`
     * `Text to Speech`
     * `Speech to Speech`
   * Configurar un **tope mensual de créditos (*Credit Limit*)** en la propia API Key (ej. `5,000` o `10,000` créditos por iteración) para impedir cualquier gasto accidental por bucle.
2. **Variables de entorno locales (`.env`):**
   * Añadir `.env` a [.gitignore](../.gitignore) **antes** de crear el archivo (nunca commitear claves).
   * Crear `.env` en la raíz del proyecto:
     ```env
     ELEVENLABS_API_KEY=sk_tu_clave_restringida_aqui
     ```
3. **Dependencias Python locales (en `.venv`):**
   ```bash
   pip install elevenlabs python-dotenv
   ```

### Opción B — Servidor MCP Oficial / Skill Oficial *(Prototipado Rápido)*
Para pruebas exploratorias puntuales desde el agente (ej. tantear 1 o 2 prompts acústicos de orbe antes de redactar un lote en el manifiesto):
* **MCP Oficial alojado:** Conectar `https://api.elevenlabs.io/v1/mcp` mediante OAuth.
* **Skill Oficial de SFX:**
  ```bash
  npx skills add elevenlabs/skills --skill sound-effects
  ```
* **Regla de higiene:** Cualquier sonido generado mediante MCP/Skill que se apruebe para quedarse en el juego debe registrarse igualmente en `tools/audio_manifest.json` con estado `approved` y pasar por el recorte de silencio + conversión a `.wav` con `ffmpeg` hacia `res://assets/audio/`.

---

## 5. Capacidades por API y Reglas de Costo en Créditos

| Flujo | Endpoint / Método SDK | Modelo Obligatorio | Costo en Starter | Uso en *Trixie* |
| :--- | :--- | :--- | :--- | :--- |
| **SFX puntuales** | `POST /v1/sound-generation` | `eleven_text_to_sound_v3` | **40 créd./seg** (manual) vs **200 créd.** (auto) | Orbes, caldero, purga, matraz, hechizos, familiares, UI especial. |
| **SFX en Loop** | `POST /v1/sound-generation` (`loop: true`) | `eleven_text_to_sound_v2` | **40 créd./seg** (manual) | Hervor constante del caldero y ambientes de paradas (`6s–12s`). |
| **Texto a Voz (TTS)** | `POST /v1/text-to-speech/{voice_id}` | `eleven_v4` / `eleven_turbo_v4` *(según ID vigente de API v4)* | **1 créd./carácter** | *Voice barks* autónomos: exclamaciones, risas, suspiros y micro-frases (`1–4` palabras). |
| **Voice Changer (STS)** | `POST /v1/speech-to-speech/{voice_id}` | Modelo STS oficial vigente | **~1,000 créd./min** (~17 créd./seg) | *Barks* actuados por el desarrollador con timing anime exacto. |

### 5.1 Efectos de Sonido — Sound Effects (`POST /v1/sound-generation`)
* **Solo desde texto:** Este endpoint genera audio **exclusivamente a partir de descripciones en texto**. No convierte grabaciones caseras de objetos o golpes en SFX.
* **Modelo explícito:** Enviar siempre `model_id="eleven_text_to_sound_v3"`, ya que el valor por defecto de la API sigue siendo `v2`.
* **Excepción obligatoria para Loops:** Cuando el manifiesto indique `"loop": true` (ambientes o burbujeo continuo del caldero), cambiar automáticamente a `model_id="eleven_text_to_sound_v2"`, porque el modo loop nativo depende actualmente de `v2`.
* **Regla de Oro de Ahorro (`duration_seconds` obligatorio):**
  * Sin duración explícita, ElevenLabs cobra **200 créditos fijos** por clip.
  * Enviando `duration_seconds` manual cobra **40 créditos por segundo**:
    * Golpe / grieta de orbe (`0.8s`) = **32 créditos** (ahorro del **84%**).
    * Purga / corcho / fusión (`1.2s`) = **48 créditos** (ahorro del **76%**).
    * Carta Hechizo (`2.5s`) = **100 créditos** (ahorro del **50%**).
* **Redacción de prompts SFX:** Redactar siempre en **inglés acústico concreto**, pidiendo sonido seco y sin música de fondo (ej. *"Crisp magical glass orb cracking, bright crystalline transient, subtle arcane chime, dry close-mic studio game SFX, no reverb tail, no music"*).

### 5.2 *Voice Barks* desde Texto — Text-to-Speech (Eleven v4 / v4 Turbo)
* **100% interjecciones no verbales definidas en el manifiesto (cero palabras, cero lectura del guion):** Ningún personaje pronuncia palabras ni frases reales; solo sonidos expresivos asociados a `character` y `emotion` en `tools/audio_manifest.json`. **Prohibido meter diálogo hablado o leer archivos de texto del juego.**
* **Regla de Brevedad (1 sola expresión por *bark*, `~0.5s–1.1s`):** Cada clip debe contener **una única onomatopeya corta** (ej. `えへっ♪`, `ふふんっ！`, `あわわっ！`, `うふっ♪`, `ええぇっ！？`). **Evitar apilar** etiqueta de risa + risa larga en kana o dos expresiones seguidas (como `[giggles] えへへっ♪` o `あわわっ…むぅ〜っ！`), porque `eleven_v4` interpreta doble reacción y estira el clip a `> 1.5s`.
* **Costo ultrabajo:** A **1 crédito por carácter**, una expresión simple consume apenas **4 a 16 créditos**.
* **Etiquetas de actuación inline (Eleven v4):** Usarlas solo cuando no dupliquen la expresión (p. ej. `[coughs]` antes de tos de humo, o un toque puntual en suspiros).
  * Brujas / Trixie: `[excited]`, `[nervously]`, `[sighs]`, `[gasps]`, `[coughs]`.
  * Clientas: `[whispers]`, `[sarcastically]` (Velvet / Mona), `[playfully]` (Sylvi), `[softly]` (Seraphina), `[fiercely]` (Roxy).

### 5.3 *Voice Barks* desde Grabaciones — Speech-to-Speech (`POST /v1/speech-to-speech/{voice_id}`)
* **Cuándo usarlo:** Cuando una reacción cómica o *ecchi* elegante (un *"¡Hmph!"* indignado de Mona, el *"¡Puf...!"* mareado de Trixie con hollín, un rugido juguetón *"¡Auuu!"* de Roxy o una risa seductora de Velvet) requiere un ritmo, pausa e intención anime que el texto plano no captura.
* **Flujo operativo:**
  1. El desarrollador graba su actuación con el micrófono o el móvil (admite hasta 5 minutos por clip; para *barks* bastan clips de `1.5s–4s`, equivalentes a **~25–70 créditos**) y la deja en `raw_assets/voices/<character_id>/`.
  2. Activar limpieza de ruido (`remove_background_noise=True`) si se grabó desde celular o habitación sin tratar.
  3. **Compatibilidad de formatos de entrada:** Preferir `.wav` o `.mp3`. Si el archivo en `raw_assets/voices/` está en **`.m4a` o `.aac`** (grabadora nativa de teléfono), el script **convierte automáticamente a `.mp3` con `ffmpeg`** en un archivo temporal antes de enviarlo al endpoint STS.
* **Límite estricto de uso:** STS sirve **exclusivamente para actuación vocal humana**. Nunca enviar ruidos de objetos, palmas o soplidos no vocales esperando generar Foley/SFX.

### 5.4 Herramientas Complementarias Disponibles en API
* **Voice Design:** Permite sintetizar voces originales desde cero describiendo edad, timbre y carácter. **Es la opción recomendada para el elenco de *Trixie*** (ver §6.3).
* **Voice Isolator:** Disponible vía API si alguna grabación casera para STS tuviese ruido ambiente severo que la limpieza estándar de STS no baste para aislar.

---

## 6. Limitaciones del Plan Starter y Post-Procesado `ffmpeg`

### 6.1 Concurrencia y Protección contra HTTP `429`
* El plan Starter admite un máximo de **3 peticiones simultáneas** en modelos principales (`6` en modelos Flash).
* **Regla de implementación:** Todo script en lote debe ejecutar **de forma secuencial (`concurrency = 1` por defecto, máximo `2` workers)** con una pausa corta (`0.25s–0.5s`) entre llamadas y reintento con *exponential backoff* (`2s -> 4s -> 8s`) únicamente ante errores `429` o `5xx` (nunca reintentar en bucle errores `400`/`401`/`422`).

### 6.2 Formato Máximo de Salida API y Recorte de Silencio (`MP3 -> WAV`)
* **Tope en Starter:** Pedir siempre `output_format="mp3_44100_128"` (`44.1 kHz / 128 kbps`).
* **Prohibido en código:** Nunca solicitar `mp3_44100_192` ni `pcm_44100` / WAV directo a la API (devolverá error de suscripción).
* **Recorte obligatorio de silencio inicial y final (`silenceremove`):**
  * Todo MP3 devuelto por ElevenLabs trae *padding* de codificación al principio y cola muerta al final (especialmente cuando pedimos `duration_seconds: 1.2` y el impacto dura `0.65s`).
  * Antes de escribir el `.wav` final en `res://assets/audio/`, `tools/generate_audio.py` **debe limpiar automáticamente tanto la cabeza como la cola de silencio** invirtiendo la onda (`silenceremove -> areverse -> silenceremove -> areverse`) con un margen mínimo (`start_silence=0.005` / `0.015`) para preservar el ataque consonántico o transiente sin comerse el inicio del sonido y lograr **disparo de latencia cero en Godot**:

```bash
# 1. Pre-conversión de grabación móvil (.m4a / .aac) -> .mp3 limpio para enviar a Speech-to-Speech
ffmpeg -y -i raw_assets/voices/mona/mona_hmph_01.m4a \
  -ac 1 -ar 44100 -c:a libmp3lame -b:a 192k raw_assets/audio_api_raw/tmp_sts_input.mp3

# 2. Post-procesado de SFX (MP3 -> WAV 16-bit mono sin silencio inicial ni cola residual = latencia 0 en Godot)
ffmpeg -y -i raw_assets/audio_api_raw/sfx_cauldron_orb_crack_01.mp3 \
  -af "silenceremove=start_periods=1:start_duration=0.002:start_threshold=-50dB:start_silence=0.004,areverse,silenceremove=start_periods=1:start_duration=0.01:start_threshold=-52dB:start_silence=0.015,areverse" \
  -ac 1 -ar 44100 -sample_fmt s16 assets/audio/sfx/cauldron/sfx_cauldron_orb_crack_01.wav

# 3. Post-procesado de Voice Bark (MP3 -> WAV 16-bit mono: inicio 0ms y cola suave sin cortar respiros/risas)
ffmpeg -y -i raw_assets/audio_api_raw/vo_velvet_sonrojada_picante_01.mp3 \
  -af "silenceremove=start_periods=1:start_duration=0.004:start_threshold=-50dB:start_silence=0.010,areverse,silenceremove=start_periods=1:start_duration=0.020:start_threshold=-58dB:start_silence=0.100,areverse" \
  -ac 1 -ar 44100 -sample_fmt s16 assets/audio/voices/customers/velvet/vo_velvet_sonrojada_picante_01.wav

# 4. Post-procesado de Ambiente en Loop (generado con v2 + loop:true): MP3 -> OGG Vorbis estéreo conservando bordes del loop
ffmpeg -y -i raw_assets/audio_api_raw/amb_cauldron_simmer_loop.mp3 \
  -ar 44100 -c:a libvorbis -q:a 5 assets/audio/ambience/amb_cauldron_simmer_loop.ogg
```
*(Nota para loops: NO aplicar `silenceremove` a ambientes generados con `loop: true` para no romper el cruce continuo generado por `eleven_text_to_sound_v2`).*

### 6.3 Moderación y Tono *Ecchi Stream-Friendly*
* El juego maneja coqueteo y reacciones `sonrojada_picante` estrictamente *stream-friendly* (cero contenido explícito en el juego base).
* Muchos actores reales en la *Voice Library* comunitaria activan filtros estrictos de moderación que bloquean falsos positivos ante suspiros, susurros o entonaciones sugerentes.
* **Regla:** Priorizar siempre **voces sintéticas diseñadas con Voice Design** en la cuenta del desarrollador antes que voces clonadas de personas reales de la librería pública.

### 6.4 Control de Estado, Historial Versionado y Rollback (`0` Créditos)
* Ningún script puede regenerar carpetas completas ni pisar un archivo existente sin respaldo previo.
* **Historial automático (`raw_assets/audio_history/<item_id>/`):** Cada generación (y cualquier toma existente previa mediante `--backup-current`) se archiva automáticamente como `v01`, `v02`, `v03`... guardando su `.mp3` crudo, `.wav`/`.ogg` procesado y `.json` con texto/prompt y duración. Esto permite probar variaciones nuevas y volver a cualquier toma anterior con `--restore <id> v01` a **coste `0` de API**.
* Cada ítem en `tools/audio_manifest.json` mantiene un campo `status`:
  * `draft`: Idea o prompt en borrador (ignorado al generar).
  * `pending`: Listo para presupuestar en `--dry-run` y generar por primera vez.
  * `generated`: Ya descargado, recortado y exportado a `res://assets/audio/`; **el script lo salta** mientras espera revisión de QA.
  * `approved`: Escuchado y validado por el desarrollador; **inmutable** salvo cambio manual de estado.
  * `regen_requested`: Marcado explícitamente tras QA para rehacer en el siguiente lote.

### 6.5 Reproductor Interactivo de QA Inline en el Chat (Portabilidad entre PCs)
* **Cómo funciona:** El reproductor HTML que aparece dentro del chat **es un artefacto temporal de esa conversación** (no se guarda ni se versiona en el repo de Git). Lo que sí viaja contigo a **cualquier otra PC y cualquier nueva conversación** es esta propia regla en `docs/sfx_voice.md`: al abrir el proyecto en otro equipo, Antigravity lee este documento y vuelve a construir automáticamente un widget HTML nuevo para ese lote.
* **Regla de implementación para Antigravity al presentar resultados de QA:**
  1. Usar la skill `generative_ui` (layout compacto `<= 400px` sin scroll, tokens semánticos `--card` / `--primary` / `--success`, Web Audio API + fallback HTML5).
  2. Leer los `.wav` recortados activos (`res://assets/audio/...`) y las tomas previas disponibles en `raw_assets/audio_history/<id>/`, transcodificarlos en memoria con `ffmpeg` a MP3 mono `64 kbps` en Base64 e incrustarlos con `<agent-embed>` para audición directa y comparación `v01` vs `v02` vs `v03` con un clic.
* **Qué viaja entre PCs por Git vs. qué queda local:**
  * **Viaja por Git (todas tus PCs):** `docs/sfx_voice.md`, `tools/generate_audio.py`, `tools/audio_manifest.json` y los `.wav`/`.ogg` activos en `res://assets/audio/`.
  * **Solo local en cada PC (ignorado por `.gitignore`):** `raw_assets/audio_history/`, `raw_assets/audio_api_raw/` y `.env` (si quieres conservar tomas descartadas entre equipos, copia `raw_assets/audio_history/` manualmente o sube las variantes elegidas como `_02.wav` dentro de `res://assets/audio/`).

---

## 7. Esquema del Manifiesto (`tools/audio_manifest.json`)

Cuando iniciemos la producción de audio, `tools/generate_audio.py` usará este esquema exacto (100% autónomo respecto a cualquier otro archivo de datos):

```json
{
  "meta": {
    "plan": "starter",
    "monthly_credit_pool": 30000,
    "api_output_format": "mp3_44100_128",
    "max_concurrency": 1
  },
  "voices": {
    "trixie": { "voice_id": "TzUMK6AZCcUynEtO5419", "source": "voice_design", "lang": "ja", "notes": "Brujita seiyuu 19a, aguda, pícara, chispeante y cómica" },
    "lyra": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Druida dulce y traviesa" },
    "nyxara": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Chamán misteriosa, serena y elegante" },
    "morrigan": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Alquimista oscura, intensa y confiada" },
    "sylvi": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Fauno bohemia fiestera, cálida y pícara" },
    "velvet": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Súcubo sofisticada, registro grave onee-san seductor" },
    "seraphina": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Dama relajada, suave, melodiosa y veraniega" },
    "mona": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Elfa noble ojou-sama tsundere, altiva pero nerviosa al sonrojarse" },
    "roxy": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Cazadora lupina genki/feroz, directa y enérgica" },
    "goblin_boss": { "voice_id": "PENDING_USER_VOICE_ID", "source": "voice_design", "lang": "ja", "notes": "Jefa goblin mandona, carismática y cómica" }
  },
  "items": [
    {
      "id": "sfx_cauldron_orb_crack_01",
      "type": "sfx",
      "model_id": "eleven_text_to_sound_v3",
      "prompt": "Crisp enchanted glass alchemy orb cracking slightly, bright crystal tap transient, dry close-mic game SFX, no music, no long tail",
      "duration_seconds": 0.7,
      "loop": false,
      "target_path": "res://assets/audio/sfx/cauldron/sfx_cauldron_orb_crack_01.wav",
      "post_process": "wav_sfx_trim",
      "estimated_credits": 28,
      "status": "draft"
    },
    {
      "id": "amb_cauldron_simmer_loop",
      "type": "sfx",
      "model_id": "eleven_text_to_sound_v2",
      "prompt": "Cozy magical potion cauldron gently simmering and bubbling with thick glowing liquid, subtle warm fire crackle underneath, seamless ambient loop, no music",
      "duration_seconds": 8.0,
      "loop": true,
      "target_path": "res://assets/audio/ambience/amb_cauldron_simmer_loop.ogg",
      "post_process": "ogg_loop_keep_edges",
      "estimated_credits": 320,
      "status": "draft"
    },
    {
      "id": "vo_velvet_sonrojada_picante_01",
      "type": "tts",
      "character": "velvet",
      "emotion": "sonrojada_picante",
      "model_id": "eleven_v4",
      "text": "[chuckles] うふふっ…んふ♪",
      "target_path": "res://assets/audio/voices/customers/velvet/vo_velvet_sonrojada_picante_01.wav",
      "post_process": "wav_bark_trim",
      "estimated_credits": 19,
      "status": "draft"
    },
    {
      "id": "vo_trixie_hollin_derrota_01",
      "type": "sts",
      "character": "trixie",
      "emotion": "hollin_derrota",
      "source_audio": "raw_assets/voices/trixie/trixie_hollin_01.m4a",
      "remove_background_noise": true,
      "target_path": "res://assets/audio/voices/playable/trixie/vo_trixie_hollin_derrota_01.wav",
      "post_process": "wav_bark_trim",
      "estimated_duration_sec": 2.2,
      "estimated_credits": 38,
      "status": "draft"
    }
  ]
}
```

### Comandos Estándar que Soporta `tools/generate_audio.py`
```bash
# 0. Consultar saldo real de créditos y listar voice_id guardados por nombre (0 créditos)
python tools/generate_audio.py --credits
python tools/generate_audio.py --list-voices

# 1. Calcular costo exacto de todos los ítems 'pending' o 'regen_requested' SIN llamar a la API
python tools/generate_audio.py --dry-run

# 2. Generar únicamente un ítem, personaje o categoría tras aprobación
python tools/generate_audio.py --id sfx_cauldron_orb_crack_01
python tools/generate_audio.py --character sylvi
python tools/generate_audio.py --type sfx --only-pending

# 3. Marcar ítems escuchados como aprobados (quedan protegidos contra sobrescritura)
python tools/generate_audio.py --approve sfx_cauldron_orb_crack_01 vo_trixie_hollin_derrota_01

# 4. Consultar historial de versiones guardadas y restaurar una toma anterior (0 créditos)
python tools/generate_audio.py --history
python tools/generate_audio.py --restore vo_trixie_sonrojada_picante_01 v05
```

---

## 8. Mapa de Eventos del Proyecto Priorizados para Audio

Para planificar lotes pequeños y de alto impacto en dopamina dentro del presupuesto de `30,000` créditos:

1. **Lote 1 — Caldero Táctico y Matraz (`MainGame.gd` / `CauldronBoard.gd` / `PotionFlaskView.gd`) — Prioridad Máxima:**
   * Levantar orbe (`orb_lifted`), golpe/grieta progresiva (`2–3` variaciones cortas de `0.6s–0.8s`), estallido de orbe afín, fusión alquímica (`🔥+🍃`, concentración `x2/x3`), potenciación Estrella (`⭐`), detonación Bomba (`💣`), purga limpia con Clic Derecho (`❌`), fallo con hollín (`backfire_severe`), burbujeo al inyectar pigmento y corcho/destello de poción completada al `100%` (+ variante Crítica).
   * *Costo orientativo del lote completo (~15 SFX `.wav` recortados):* **~700 – 950 créditos**.
2. **Lote 2 — *Voice Barks* por Emoción: Trixie + las 5 Clientas Actuales (`Sylvi`, `Velvet`, `Seraphina`, `Mona`, `Roxy`):**
   * **Trixie** (`6` emociones × `2` *barks* cortos = `12` clips `.wav`): `normal`, `confiada`, `nerviosa_sudando`, `sonrojada_picante`, `hollin_derrota`, `sorprendida`.
   * **5 Clientas** (`3` emociones core `normal`, `sonrojada_picante`, `impaciente` × `2` *barks* = `30` clips `.wav`).
   * *Costo orientativo del lote completo (~42 clips vía TTS/STS):* **~1,200 – 1,900 créditos**.
3. **Lote 3 — Cartas Hechizo, Familiares y Eventos de Ola (`WaveDirector.gd` / `StageHUD.gd`):**
   * Despliegue y clímax de Cartas Hechizo (*Tinte Alquímico*, *Vórtice*, *Purga Total*, *Hielo Arcano*), intervenciones de los 3 familiares (*Michi Alado*, *Diablillo Purgador*, *Murciélago Alquimista*), aviso de paciencia crítica en `timer_vial`, sello de botella en `WaveProgressDock` y subida de nivel de afinidad (`❤`).
   * *Costo orientativo (~14 SFX `.wav`):* **~800 – 1,200 créditos**.
4. **Lote 4 — UI de Madera/Pergamino, Mapa, Intro y Ambientes en Loop (`v2`):**
   * *Nota:* Evaluar primero usar **CC0 (Kenney)** o el sintetizador actual de `AudioJuiceManager.gd` para clics básicos y texto, reservando ElevenLabs para pergaminos (`dialog_bg`, `pause_scroll_bg`), explosión cómica de la Feria (`IntroCutscene.gd`) y `4–6` ambientes en loop `.ogg` (`8s` c/u = `320` créditos por ambiente).
   * *Costo orientativo (~6 loops + 6 SFX UI/cinemática):* **~2,200 – 2,600 créditos**.

> **Total estimado para sonorizar todo el Vertical Slice + Campaña base:** **~4,900 a 6,650 créditos** (~16%–22% de un solo mes del plan Starter, dejando amplio margen para iteraciones de QA, nuevas brujas `Lyra`/`Nyxara`/`Morrigan` y escenas de Galería).

---

## 9. Checklist Rápido antes de Ejecutar Cualquier Generación

- [ ] ¿`.env` está listado en `.gitignore` y la API Key tiene permisos restringidos + tope de créditos en ElevenLabs?
- [ ] ¿Ya consulté al desarrollador si los clicks/ticks genéricos de UI irán con CC0/procedural antes de presupuestarlos?
- [ ] Si hay *voice barks* en el lote: ¿están definidos 100% en `tools/audio_manifest.json` por personaje y emoción (sin tocar ningún banco de diálogos) y ya tengo el `voice_id` elegido por el desarrollador?
- [ ] Si algún *bark* requiere timing anime difícil: ¿pedí primero el audio crudo en `raw_assets/voices/<char_id>/` para usar STS en vez de quemar intentos en TTS?
- [ ] ¿Todos los SFX puntuales usan `eleven_text_to_sound_v3` con `duration_seconds` explícito y todos los `loop: true` usan `eleven_text_to_sound_v2`?
- [ ] ¿El formato solicitado a la API es `mp3_44100_128` con concurrencia `1` (máx. `2`) y el post-procesado de SFX/*barks* exporta a `.wav` aplicando `silenceremove` inicial y final?
- [ ] ¿Ejecuté `--dry-run`, mostré al desarrollador la tabla de archivos + créditos estimados y recibí su aprobación explícita?
