# roadmap.md — Memoria Viva del Proyecto (*Trixie*)

> **ESTADO DEL DOCUMENTO:** Este archivo es la **memoria viva y el punto de contacto directo** entre **Antigravity** y el **Desarrollador**.  
> **Rama Activa:** `proto/incremental` · **Motor:** Godot `4.7.2` (`1920×1080`)  
> **Regla Operativa:** Antigravity actualiza este archivo tras cada sesión o hito: marcando tareas completadas (`[x]`), registrando decisiones críticas de diseño, reportando bloqueos reales y definiendo los siguientes pasos para lanzar el juego en **Steam**.

---

## Snapshot del Proyecto Actual (`proto/incremental`)

* **Género y Alcance:** **Incremental Táctico 2D de Alquimia Itinerante** (campaña cerrada de **3–5 horas** con final y logros al 100%, **cero autoclicker**): **Trixie** es una bruja vendedora ambulante que recorre el reino cargando su caldero a cuestas (tropezándose a menudo) a través de un **Mapa de Viaje bifurcado**, atendiendo **Olas de Clientas con Manías y Química de Colores**, lanzando **Hechizos Activos**, reclutando a otras brujas (`Lyra`, `Nyxara`, `Morrigan`) en paradas clave del camino y desbloqueando la **Galería de Cinemáticas Secretas** (matriz `Bruja × Clienta`).
* **Estrategia Comercial (Steam PC):**
  * **Plataforma objetivo:** **Steam** (`$100` Steam Direct, precio objetivo de compra impulsiva **`$4.99–$6.99`**), validando tracción con Demo jugable en **Steam Next Fest** (meta orientativa: `3.000–5.000+` *wishlists*). Descartado móvil como primer lanzamiento; *itch.io* solo como campo de pruebas gratuito si hiciera falta.
  * **Regla Cero IA Pública:** La IA se usa únicamente como referencia interna y prototipado veloz. **Todo el arte visible en Steam, cápsulas, tráiler, clips y build pública será 100% redibujado a mano en Krita** (conservando `.kra` y timelapses).
* **Estándar Visual Vigente (0 chibis 2.5D):**
  * **3 tipos de ilustración por personaje** (definidos en [prompts_catalog.md](docs/prompts_catalog.md) y [prompts_characters.md](docs/prompts_characters.md)):
    1. **Medio Cuerpo (`halfbody` — vertical sin marco):** Protagonistas con **2 hojas `16:9` / 6 expresiones** mirando `>>` (`normal`, `confiada`, `nerviosa_sudando`, `sonrojada_picante`, `hollin_derrota`, `sorprendida`); Clientas con **1 hoja `16:9` Core / 3 expresiones** mirando `<<` (`normal`, `sonrojada_picante`, `impaciente`).
    2. **Retrato (`portrait` — tamaño único `420×420`):** Rostro y hombros para diálogos/iconos.
    3. **Full Size (`fullbody` — vertical `9:16`):** Ilustración dedicada de cuerpo completo (nunca recorte del Concept Art).
  * **Diseño *Stream-Friendly* con Identidad Única:** Estética anime *ecchi* elegante sin desnudez ni explícito, asignando **una sola firma reveladora protagonista por chica** en lugar de mezclar todas las aberturas a la vez (ej. Trixie = corsé asimétrico + media; Sylvi = mega escote vertical tipo corsé hasta el abdomen + *micro-hotpants* con cadenas bohemias).
  * **Regla de Ahorro de Tokens en Placeholders:** Reutilizar gráficos existentes sin coste extra y usar **formas simples ("huevos"/cápsulas de colores)** para cualquier gráfico temporal que luego se dibuje en Krita.

---

## Siguiente Foco Inmediato

1. **Prototipar el bucle táctico "Vendedora Ambulante" en `proto/incremental` (Zona 1 jugable):**
   - Sustituir el timer pasivo de `25s` por **Olas de Clientas**, un **Mapa de Viaje bifurcado** entre paradas (rutas de Hechizos Activos vs. rutas de mayor riesgo/spawn/Esencia, con el nodo final de reclutamiento de **Lyra**) y **3 Hechizos Activos** (`Q/W/E`) en el caldero para comprobar en playtest que el ritmo engancha de verdad.
2. **Vestir el Tablero Central estilo [imagen4.jpeg](stash/imagen4.jpeg) (Bloque A):**
   - Ya integrados: **caldero parcheado (`cauldron_main.png`) + fuego difuso por shader (`cauldron_fire_glow.gdshader`)**, **Fondos Nivel 1 y 2 (`bg_01_castillo.jpg`, `bg_02_pueblo.jpg` con `stage_bg_depth.gdshader`)**, **tubo/matraz vertical (`flask_empty.png` + `flask_liquid_mask.png`, `flask_liquid.gdshader`)**, **8 orbes alquímicos + grietas biseladas 3D (`assets/props/items/orbs/*.png`)** y **pergamino de diálogo (`dialog_bg.png` + sombra gaussiana y entrada *ease-out* desde abajo-izquierda en partida e intro)**; faltan fondos por parada restantes (`3–5`) y el shader de caldo animado en el caldero.
3. **Completar el elenco visual de Brujas viajeras (`Lyra`, `Nyxara`, `Morrigan`) — 5/5 Clientas ya integradas:**
   - Repetir el flujo afinado con Sylvi: conversación rápida con 1 firma sexy protagonista -> Concept Art -> 1 hoja `16:9` Core de Medio Cuerpo mirando `<<` (o `>>` para brujas) -> integración automática en Godot.
4. **Convertir la Galería en Cinemáticas Secretas (`Bruja × Clienta`) y adaptar la Intro:**
   - Evolucionar la Galería a mini-historias desbloqueables por pareja `(witch_id, customer_id)` y ajustar [intro_cutscene.json](data/dialogues/intro_cutscene.json) a la premisa de Trixie recorriendo el reino con su caldero ambulante.

---

## Fase 0: Cimientos, Arquitectura Godot 4.7 y Pipeline de Arte
- [x] Inicializar arquitectura base en Godot `4.7.2` con tipado estricto y autoloads ([EventBus.gd](scripts/autoloads/EventBus.gd), [AudioJuiceManager.gd](scripts/autoloads/AudioJuiceManager.gd), [GameSettings.gd](scripts/autoloads/GameSettings.gd), [SceneFader.gd](scripts/autoloads/SceneFader.gd)).
- [x] Crear Menú Principal ([MainMenu.gd](scripts/ui/MainMenu.gd)) con splash art, logo con halo mágico (`logo_magic_halo.gdshader`) y Cinemática de Intro ([IntroCutscene.gd](scripts/ui/IntroCutscene.gd) + [intro_cutscene.json](data/dialogues/intro_cutscene.json)).
- [x] Construir pipeline automatizado de transparencia y escala 1:1 sin perforar blancos internos:
  - [x] [process_white_bg.py](tools/process_white_bg.py) (flood-fill exterior + *defringe* con `--self-test`).
  - [x] [slice_sprite_sheet.py](tools/slice_sprite_sheet.py) con corte por componentes conexos, `--alpha-sheet` directo y `--white-sheet --clean-pockets` para huecos cerrados entre brazos, pelo y cuernos.
  - [x] [export_character_sizes.py](tools/export_character_sizes.py) con pre-escalado Lanczos 1:1 y escala uniforme en lienzo de `560px` (`--only halfbody`).
  - [x] Estandarizar generador y archivo maestro de prompts ([generate_prompts.py](tools/generate_prompts.py), [prompts_catalog.md](docs/prompts_catalog.md), [prompts_characters.md](docs/prompts_characters.md)).

---

## Fase 1: Bucle Base del Incremental Táctico 2D (`proto/incremental`)
- [x] **1.1 Caldero Táctico de Golpes y Mezcla Alquímica ([MainGame.gd](scripts/core/MainGame.gd)):**
  - [x] Arranque lento y legible (6 orbes iniciales, pasar el cursor no extrae nada, golpes solo al soltar clic o mantener con mejora).
  - [x] **Clic Izquierdo (`3 -> 2 -> 1` golpes):** agrieta y rompe orbes progresivamente; mejora temprana (*Toque Continuo*) desbloquea mantener presionado para golpear en ráfaga.
  - [x] **Levantar y Soltar sobre otro orbe:** pasa por encima sin chocar para mezclar colores primarios (`🔥+🍃 -> ☀️ Solar`, `🔥+🌙 -> 🔮 Estelar`, `🌙+🍃 -> 💧 Bruma`) o concentrar iguales en `x2/x3` sin riesgo de romperlo al agarrar.
  - [x] **Clic Derecho (clic o mantener):** purga orbes negativos (`❌`) o libera espacio de forma segura sin dañar el tubo ni cortar el combo.
- [x] **1.2 Química de Colores Viva (Puros + Mezclas) + Frenesí Escarlata:**
  - [x] Tabla de afinidades por clienta con colores puros (Sylvi) y mezclados (Velvet, Seraphina, Mona, Roxy) + spawner inteligente que garantiza los ingredientes base.
  - [x] Tubo vertical de poción (`0–100%`), combos con audio pentatónico, Pociones Críticas y **Frenesí Escarlata** (`[Espacio]` / botón rojo) transmutando todos los `❌` al color Afín y rompiendo de 1 golpe con `2x` producción.
- [x] **1.3 Árbol de Mejoras Base (`17 Nodos · 4 Ramas`, [GameCatalog.gd](scripts/core/GameCatalog.gd)):**
  - [x] Ramas funcionales: **Golpes y Toque Continuo** (`3 -> 2 -> 1` golpes, velocidad y Purga Recicladora), **Caldero y Reacciones** (*Chispa*, *Bomba*, *Estrella*), **Familiares Inteligentes y Tiempo** (*Michi Alado*, *Diablillo Purgador*, *Murciélago Alquimista*) y **Clientas y Victoria** (*Elixir Supremo*).
- [x] **1.4 Escenarios Laterales Sin Marcos y Primer Dúo en Vivo:**
  - [x] Integrado medio cuerpo completo `6/6` de **Trixie** a la izquierda (`>>`, animación procedural por emoción + aura dinámica en [CharacterArt.gd](scripts/ui/CharacterArt.gd)).
  - [x] Integrado medio cuerpo Core `3/3` de **Sylvi** a la derecha (`<<`, dock compacto, 3 reacciones en partida + Galería/Visor).
  - [x] Suite headless [smoke_test_slice.gd](tools/smoke_test_slice.gd) verificando química, purga, cadenas, Frenesí, compras y reacciones de Trixie + Sylvi (`INCREMENTAL SMOKE RESULT: PASS`).

---

## Fase 2: Profundidad Táctica, Campaña Itinerante (3–5h) y Caldero 2.5D
- [ ] **2.1 Olas de Clientas, Mapa de Viaje Bifurcado y Hechizos Activos (Núcleo Adictivo):**
  - [x] Sustituir el reloj pasivo de `25s` por **Olas por Cantidad de Clientas (`2–5`) + Paciencia Individual por Clienta** (`30.0s` base uniforme + `+4s` por nivel de *Reloj de Arena*, hook listo para variar por arquetipo en el futuro) con diálogo corto de cierre tras la ola y transición *fade* suave al Mapa; si se van demasiadas conservas toda la Esencia ganada — **cero permadeath**).
  - [x] Implementar **Mapa de Viaje por Zonas con Bifurcaciones** entre paradas ([WorldMap.tscn](scenes/meta/WorldMap.tscn), [WorldMap.gd](scripts/meta/WorldMap.gd), [GameState.gd](scripts/autoloads/GameState.gd) + `get_map_nodes()` en [GameCatalog.gd](scripts/core/GameCatalog.gd)): 6 nodos de campaña con bifurcación rejugable (*Sendero de Esporas* -> **Lyra** vs. *Arroyo en Balsa*), concentrando el **Árbol de Habilidades** y la **Galería** únicamente en el Mapa sin botones duplicados en partida.
  - [ ] Añadir **2–3 ranuras de Hechizos Activos** del caldero (`Q / W / E` o clic, cargables con combos — sin deriva a *deckbuilder*): ej. *Tinte Alquímico* (convierte todos los orbes al color Afín), *Vórtice* (agrupa Afines para mega-cadena), *Purga Total* (detona todos los `❌` en Esencia) y *Hielo Arcano* (congela la presión/reloj).
  - [ ] Añadir **manías mecánicas propias por clienta** además de su trío de color (ej. Velvet exigiendo cadenas `2+`; Seraphina corrompiendo orbes si no purgas; Mona premiando cadenas específicas; Roxy acelerando el caldero a cambio de doble propina) y expandir el Árbol Permanente (`~25–35` nodos) con 2–3 saltos claros de fantasía de poder.
  - [x] Añadir **tutoriales guiados por Trixie con tiempo pausado ("Just-In-Time")**: tutorial básico inicial (romper `3 clics`, purgar `❌` con Clic Der y resumen de paciencia/Frenesí con botón `¡ENTENDIDO!`), **tutorial de mezcla contextual** que solo salta cuando llega la primera clienta con pedido compuesto (`Velvet`), y guía obligatoria en el Mapa hacia el **Árbol de Habilidades** forzando la compra de **Toque Continuo**.
- [ ] **2.2 Perspectiva Ligera del Caldero y UI Estilo [imagen4.jpeg](stash/imagen4.jpeg):**
  - [x] Integrar el caldero central parcheado (`assets/props/stations/cauldron_main.png`) en vista casi cenital sobre caldo base neutro con apertura elíptica, escala sutil por profundidad `Y` y ordenamiento `Y-Sort` de orbes bajo el borde frontal.
  - [ ] Refinar el lateral derecho e izquierdo: tubo vertical conectado a matraz inferior, fila visual de corazones de afinidad (`❤`) bajo el tubo, ranuras de Hechizos Activos y botón circular de Frenesí integrado bajo la bruja activa.
- [ ] **2.3 Reclutamiento de Brujas Jugables en el Mapa (`Lyra`, `Nyxara`, `Morrigan`) y Matriz `Bruja × Clienta`:**
  - [ ] **Mecánica oficial de desbloqueo (Hitos del Mapa de Viaje):** las demás brujas no se compran en un menú frío ni llegan por días pasivos; Trixie **las conoce y recluta al superar los nodos clave / Olas Especiales de cada Zona del Mapa** (*Zona 1: Sendero del Bosque -> **Lyra***; *Zona 2: Mercado Nocturno -> **Nyxara***; *Zona 3: Gala Carmesí -> **Morrigan***), con rutas rejugables para recorrer en libertad sin bloquear ninguna.
  - [ ] **Árbol Permanente Compartido + Selector 1-Clic:** cambiar de bruja antes de entrar a un nodo nunca reinicia el progreso; cada bruja aporta una **Pasiva + Frenesí único** adaptado al incremental (`Trixie`: cadenas y transmutación `❌` -> Afín; `Lyra`: brotes extra de Afines y Frenesí que congela reloj/presión; `Nyxara`: Familiares más rápidos que suman Combo/Frenesí y Frenesí de rayos simultáneos; `Morrigan`: alto riesgo con Bombas extra y Frenesí de mega-detonación crítica).
  - [ ] Actualizar [WitchCharacterData.gd](scripts/resources/WitchCharacterData.gd) y `data/characters/*.tres` reemplazando los stats heredados del prototipo *Diner Dash* por las pasivas/Frenesíes del incremental, y conectar cada pareja `(witch_id, customer_id)` con su fila de historias en Galería (+ micro-bono global permanente por historia completada).

---

## Fase 3: Elenco de 5 Clientas, Diálogos Picantes y Galería Secreta
- [ ] **3.1 Ilustraciones de Personajes (Prototipo Interno -> Base para Krita):**
  - [x] **Trixie** (Concept `v05` + Medio Cuerpo `6/6` integrado).
  - [ ] **Trixie — `fullbody` dedicado (`9:16`)** (Menú Principal / cierre de campaña).
  - [x] **Sylvi (Clienta #1 — Fauno Bohemia)** (Concept `v02` + Medio Cuerpo Core `3/3` integrado).
  - [x] **Velvet (Clienta #2 — Súcubo Ejecutiva)** (Concept Art + Hoja 1 Medio Cuerpo `3/3` mirando `<<` integrada en juego y Galería).
  - [x] **Seraphina (Clienta #3 — Paladín Celestial Dulce · Estilo Veraniego)** (Concept Art + Hoja 1 Medio Cuerpo `3/3` mirando `<<` integrada en juego y Galería).
  - [x] **Mona (Clienta #4 — Elfa Noble Tsundere × Polilla Lunar)** (Concept Art + Hoja 1 Medio Cuerpo `3/3` mirando `<<` integrada en juego y Galería).
  - [x] **Roxy (Clienta #5 — Cazadora Lupina de Fantasía)** (Concept Art + Hoja 1 Medio Cuerpo `3/3` mirando `<<` integrada en juego y Galería).
- [ ] **3.2 Banco JSON de Diálogos Picantes y Reactivos (`res://data/dialogues/`):**
  - [ ] Sacar los diálogos a JSON por personaje con triggers en vivo (llegada, cadena alta, orbe `❌` -> `impaciente`, Frenesí, Poción Crítica y afinidad Nv. 1–3) manteniendo 1–2 líneas ágiles que no frenen el gameplay.
  - [ ] Rehacer [intro_cutscene.json](data/dialogues/intro_cutscene.json) **sin Doña Remedios** (descartada) con la premisa de **Trixie vendedora ambulante** (arranque ágil con Trixie sola o pique directo con Mona, manteniendo el humor físico de sus tropiezos).
  - [ ] Seguir el arco de paradas, descansos y eventos de ruta definido en [story_campaign.md](docs/story_campaign.md) (Castillo -> Pueblo -> Bosque Tenebroso con **Jefa Goblin** + goblins y choza -> bifurcación Bosque/Brujita vs. Arroyo en balsa mágica con Sirenas -> caída por cascada -> Nuevo Pueblo).
- [ ] **3.3 Galería = Cinemáticas Secretas Desbloqueables (Matriz Bruja × Clienta):**
  - [ ] Reemplazar las tarjetas genéricas de la Galería por un **reproductor de mini-historias ilustradas** (escena visual-novel corta de 3–6 pantallas con expresiones + CG especial desbloqueada por afinidad).
  - [ ] Guionizar e integrar las primeras historias de **Trixie × las 5 Clientas** (ej. salida de bar + borrachera + motel con final feliz junto a **Sylvi**; más rutas específicas para Velvet, Seraphina, Mona y Roxy).
  - [ ] Dejar el sistema preparado por pares `(witch_id, customer_id)` para futuras rutas con otras brujitas (ej. la ruta de Sylvi + otra bruja enredadas con moteros).

---

## Fase 4: Game Juice Extremo, Audio Dinámico y Arte de Escenario
- [ ] **4.1 Audio Dinámico y SFX Táctiles:**
  - [ ] BGM adaptativa por intensidad (capa base tranquila de botica -> percusión/bajo en racha alta -> clímax en **Frenesí Escarlata**).
  - [ ] Refinar feedback sonoro de cadenas ascendentes, purga `❌`, puf cómico con hollín, desbloqueo de nodos del árbol y subida de afinidad.
- [ ] **4.2 Shaders, VFX y Sprites de Juego (0 formas genéricas en build final):**
  - [ ] Sustituir placeholders restantes de los **3 familiares voladores** (*Caldero, matraz vertical, los 8 orbes alquímicos con grietas 3D y el pergamino de diálogo ya integrados*).
  - [x] Mezcla cromática dinámica sincronizada en caldo del caldero y matraz vertical: arranca neutro con *fade* suave en cada nueva clienta y gira hacia el pigmento de cada orbe roto (sin volverse marrón al combinar 3+ tonos).
  - [ ] Añadir shader/sprite de caldo animado bajo el borde del caldero.
  - [ ] Añadir banner/efecto breve de *cut-in* al activar Frenesí Escarlata sin congelar el ritmo más de un instante, y partículas de humo sobre Trixie en `hollin_derrota`.
  - [ ] Pulir visualmente la pestaña **Árbol de Habilidades** (fondo estilo grimorio/mesa arcana, nodos ilustrados en vez de círculos planos y líneas energizadas).

---

## Fase 5: Persistencia, Redibujo Krita y Lanzamiento en Steam
- [ ] **5.1 Guardado Persistente (`SaveManager`), Localización y Logros:**
  - [ ] Guardar progreso completo en `user://save.json` (Esencia, nodos del árbol, rondas, récords, afinidades, historias de Galería desbloqueadas y ajustes).
  - [ ] Implementar traducción completa **`ES / EN`** (`TranslationServer`) antes de abrir página de Steam.
  - [ ] Configurar **Logros de Steam** alineados con el árbol, afinidades máximas e historias secretas al 100%.
  - [ ] Verificar opciones de accesibilidad (legibilidad clara de iconos/símbolos por orbe además del color, volumen y pantalla completa `F11`).
- [ ] **5.2 Redibujo 100% a Mano en Krita (Antes de Todo Lanzamiento Público):**
  - [ ] **Paso 1 — Trixie en Krita:** fija el estilo definitivo de trazo y color del juego (archivo `.kra` + timelapse útil para redes).
  - [ ] **Paso 2 — 5 Clientas en Krita:** medio cuerpo + retratos usando los concepts aprobados solo como referencia en monitor aparte.
  - [ ] **Paso 3 — Escenas CG de Galería y Cápsula de Steam en Krita.**
  - [ ] **Paso 4 — Caldero, Orbes, Familiares, HUD, Pergamino y Logo en Krita.**
- [ ] **5.3 Validación de Mercado, Steam Next Fest y Lanzamiento:**
  - [ ] Grabar **clip viral de 15s** ("Minuto 1 vs Minuto 45": extrayendo 6 orbes lentos a mano -> tormenta de rayos, bombas, familiares y reacciones picantes) ya con arte de Krita y publicar en X/Bluesky/Reddit/TikTok.
  - [ ] Abrir **página de Steam** (`$100` Steam Direct, cero mención de arte IA porque todo será redibujado a mano, precio `$4.99–$6.99`) y juntar *wishlists* (meta: `3.000–5.000+`).
  - [ ] Publicar **Demo gratuita** (ej. primeras rondas + Sylvi + Velvet + árbol inicial) para participar en un **Steam Next Fest**.
  - [ ] Lanzar versión `1.0` en Steam; solo si funciona comercialmente, evaluar expansión de brujas o port de pago único a Android/iOS.

---

## Bitácora de Decisiones Recientes (`proto/incremental`)

* **2026-11-22 — Pivote a Incremental Táctico 2D (Cero Autoclicker · Química de Colores):**
  * Tras evaluar el techo comercial en Steam (ver resumen en el archivo histórico al pie) y descartar la cocina 2.5D caminable tipo *Diner Dash*, se abrió la rama `proto/incremental` con un bucle de pantalla fija: **6 orbes grandes iniciales**, extracción por **clic o cadena del mismo color (+ ⭐/💣)**, **Clic Derecho** para purgar `❌` sin romper combo, **Química de Colores viva** por clienta, **Frenesí Escarlata**, **Árbol de 17 Nodos** y **Galería**.
* **2026-11-23 — Redefinición de Arte, Medio Cuerpo `6/6` de Trixie, Sylvi (`3/3`) y Galería de Historias:**
  * Eliminados los semi-chibis 2.5D y los 3 tamaños de retrato; cada personaje usa solo `portrait` único, `halfbody` vertical sin marco y `fullbody` dedicado `9:16`.
  * **Trixie completa en medio cuerpo (`>>`):** integradas **Hoja 1 Core** (`normal`, `confiada`, `nerviosa_sudando`) y **Hoja 2 Secundarias** (`sonrojada_picante`, `hollin_derrota`, `sorprendida` desde `trixie_halfbody_2-alpha.png` vía `--alpha-sheet`) con animación procedural por emoción y aura dinámica en [MainGame.gd](scripts/core/MainGame.gd) y [CharacterArt.gd](scripts/ui/CharacterArt.gd).
  * **Sylvi completa en medio cuerpo (`<<`):** diseñado y archivado su concept `sylvi_concept_v02.jpg` (fauno gitana/bohemia alta con mega escote vertical tipo corsé, *micro-hotpants* con cadenas, botas bajo la rodilla, sin cola y sonrisa seductora sin dientes), establecido el estándar de **1 sola hoja `16:9` (3 poses)** para clientas (`normal`, `sonrojada_picante`, `impaciente`), automatizada la limpieza de bolsillos blancos internos (`--clean-pockets`) e integrada en el escenario derecho compacto + Galería.
  * **Galerías = Cinemáticas Secretas (Matriz Bruja × Clienta):** las recompensas de afinidad serán mini-historias cómicas/picantes por pareja Bruja × Clienta (bar + borrachera + motel con final feliz con Sylvi; futuras rutas con otras brujas como el encuentro con moteros).
  * **Validación:** `smoke_test_slice.gd` headless superado (`INCREMENTAL SMOKE RESULT: PASS`) tras la integración de Trixie `6/6` y Sylvi `3/3`.
* **2026-11-23 — Premisa "Vendedora Ambulante", Mapa Bifurcado por Olas, Hechizos Activos y Desbloqueo de Brujitas en Ruta:**
  * Tras auditar `MainGame.gd`, `GameCatalog.gd` y `data/characters/*.tres`, se confirmó que `Lyra`, `Nyxara` y `Morrigan` solo conservaban stats heredados del prototipo *Diner Dash* sin mecánica de desbloqueo en `proto/incremental`, y se diagnosticó que el reloj pasivo de `25s` sin hechizos activos ni olas hacía el bucle inicial demasiado plano.
  * **Pivote de narrativa y macro-bucle:** Trixie pasa de dueña de tienda fija a **bruja vendedora ambulante** que recorre el reino cargando su caldero a cuestas (tropezándose a menudo). Esto unifica en un solo gancho el **Mapa de Viaje bifurcado** (decisiones entre Hechizos Activos, rutas volátiles de mayor riesgo/Esencia y paradas de afinidad), las **Olas de Clientas con Manías**, los **Hechizos Activos** en el caldero (ej. convertir todos los orbes a un color), el **Árbol Permanente sin permadeath**, el **reclutamiento de `Lyra`, `Nyxara` y `Morrigan` en nodos hito del mapa** y las mini-historias de carretera de la matriz `Bruja × Clienta`.
  * **Guardarraíl comercial y guion de ruta:** se fijó el formato como **Hechizos Activos** (sin deriva a *deckbuilder*), se **descartó a Doña Remedios**, se sumó una **Jefa Goblin** liderando el tramo del Bosque Tenebroso y quedó archivado el primer arco de viaje en [story_campaign.md](docs/story_campaign.md).
* **2026-11-23 — Reestructuración del Caldero: Levantar-Soltar para Mezclar Colores + Multi-Clic (`3 -> 2 -> 1`) + Toque Continuo:**
  * Reemplazado el trazo de cadenas del mismo color en [MainGame.gd](scripts/core/MainGame.gd) y [GameCatalog.gd](scripts/core/GameCatalog.gd) por **levantar orbes por encima del resto y soltarlos sobre otro** para combinar colores primarios (`🔥+🍃 -> ☀️ Solar`, `🔥+🌙 -> 🔮 Estelar`, `🌙+🍃 -> 💧 Bruma`) o concentrar iguales (`x2/x3`).
  * Implementado sistema de golpes por soltar clic quieto o mantener tras mejora temprana (**Toque Continuo** + **Fuerza Alquímica** `3 -> 2 -> 1` golpes) para evitar conflictos entre agarrar y romper; spawner inteligente para pedidos mezclados + purga continua con Clic Derecho.
  * **Validación:** parse-check GDScript y [smoke_test_slice.gd](tools/smoke_test_slice.gd) headless verificando 3 golpes para romper, mezcla de colores, concentración `x2`, cambio a pedido mixto de Velvet, Frenesí y compras de *Toque Continuo* / *Fuerza Alquímica* (`INCREMENTAL SMOKE RESULT: PASS`).
* **2026-11-24 — Escena del Mapa ([WorldMap.tscn](scenes/meta/WorldMap.tscn)), Olas por Cantidad de Clientas con Paciencia Individual y Tutoriales Pausados "Just-In-Time":**
  * Centralizado el progreso persistente en el autoload [GameState.gd](scripts/autoloads/GameState.gd) y definidos los 6 nodos del viaje en `GameCatalog.get_map_nodes()`.
  * Sustituido el reloj global de ronda en [MainGame.gd](scripts/core/MainGame.gd) por **olas por cantidad de clientas (`2–5`)** y **paciencia individual por clienta** (`30.0s` base uniforme + `+4s` por nivel de *Reloj de Arena*, con flag `USE_PER_CUSTOMER_PATIENCE` listo para variar por arquetipo a futuro); al agotarse la paciencia de una clienta se marcha molesta, reinicia el combo y entra la siguiente.
  * Eliminados los botones duplicados de Árbol y Galería del caldero; al terminar la ola aparece un **diálogo corto de cierre en pergamino** y ejecuta *fade* suave vía [SceneFader.gd](scripts/autoloads/SceneFader.gd) hacia [WorldMap.tscn](scenes/meta/WorldMap.tscn).
  * Implementados **tutoriales pausados contextuales**: el tutorial inicial explica romper (`3 clics`), purgar `❌` con Clic Der y paciencia/Frenesí con el tiempo 100% pausado; la mecánica de **mezclar colores** salta únicamente cuando llega la primera clienta que exige un color compuesto (`Velvet`). En el Mapa ([WorldMap.gd](scripts/meta/WorldMap.gd)), Trixie guía al **Árbol de Habilidades** y obliga a subir **Toque Continuo** antes de viajar a la Parada 2.
  * **Pedidos visuales y rediseño de Mona:** añadido globo visual de pedido sobre el tubo con receta gráfica de mezcla, tubo pre-teñido, tira visual de orbes en la ficha de la clienta y colores de pedido variados dinámicamente entre visitas; cambiado el arquetipo de **Mona** de "Bruja Rival" a **Elfa Noble Tsundere** y redactado el prompt de Concept Art de **Velvet (#2 — Súcubo Ejecutiva)** en [prompts_characters.md](docs/prompts_characters.md).

* **2026-11-24 — Pergamino Panorámico, Bocadillos Efímeros In-Game y Cierre de 1 Línea:**
  * Actualizado [dialog_bg.png](assets/ui/hud/dialog_bg.png) a formato panorámico **1386×300 px** con sombra gaussiana regenerada y entrada suave (`0.55s` fade-in de opacidad + aterrizaje `TRANS_EXPO` `0.72s`) en [IntroCutscene.gd](scripts/ui/IntroCutscene.gd) y [MainGame.gd](scripts/core/MainGame.gd).
  * Exportado [speech_bubble.png](assets/ui/hud/speech_bubble.png) (**480×233 px** + sombra) y sustituida la caja fija de clienta + banner morado de tutorial por **bocadillos de pergamino**: burbuja izquierda de **Trixie** (tutoriales breves pausados y reacciones efímeras) y burbuja derecha espejada para **clientas** al llegar, impacientarse o recibir su elixir.
  * Simplificado el cierre de cada parada en [GameCatalog.gd](scripts/core/GameCatalog.gd) y [MainGame.gd](scripts/core/MainGame.gd): la última clienta suelta su bocadillo normal, se oculta el HUD del caldero y **Trixie** remata con **1 sola línea** en `dialog_bg.png` antes de volver al Mapa.
* **2026-11-24 — Refactorización Modular (Fases 0 y 1 Completadas):**
  * **Fase 0 (Limpieza):** eliminados los 5 scripts sin uso del antiguo prototipo 2.5D de cocina (`KitchenHUD.gd`, `KitchenStation.gd`, `WitchController.gd`, `FamiliarEntity.gd`, `CustomerEntity.gd`, conservados en el historial de `main`).
  * **Fase 1 (Prefabs UI editables en Godot + Shader de sombra):** extraídos [DialogBox.tscn](scenes/ui/DialogBox.tscn) ([DialogBox.gd](scripts/ui/DialogBox.gd)) y [SpeechBubble.tscn](scenes/ui/SpeechBubble.tscn) ([SpeechBubble.gd](scripts/ui/SpeechBubble.gd)) con sombra dinámica por shader ([ui_drop_shadow.gdshader](shaders/ui_drop_shadow.gdshader), eliminando los PNG horneados de sombra) e integrados en [IntroCutscene.gd](scripts/ui/IntroCutscene.gd) y [MainGame.gd](scripts/core/MainGame.gd), bajando [MainGame.gd](scripts/core/MainGame.gd) de `3.310` a `3.064` líneas.
  * **Fase 2 (Pantallas simples visibles en el editor):** convertidas [MainMenu.tscn](scenes/ui/MainMenu.tscn) ([MainMenu.gd](scripts/ui/MainMenu.gd)) e [IntroCutscene.tscn](scenes/ui/IntroCutscene.tscn) ([IntroCutscene.gd](scripts/ui/IntroCutscene.gd)) en árboles de nodos reales con fondo, logo + shader, botones, modal de opciones, retrato de Trixie e instancia de [DialogBox.tscn](scenes/ui/DialogBox.tscn) editables directo en el viewport de Godot.
  * **Fase 3 (Escenario y HUD de `Main.tscn` editables + `StageHUD.gd`):** poblada [Main.tscn](scenes/main/Main.tscn) con todo el escenario (`StageBackground`, slots de `Trixie`/`Clienta`, `CauldronFireGlow`, `CauldronAnchor`, `PotionFlask`) y capa `UILayer` (`TopBar`, `FrenzyDock`, `CustomerHeaderCard`, `PatienceCard`, `ChemistryCard`, `TrixieBubble`, `CustomerBubble`, `ClosingOverlay` y `PauseOverlay`), extraído [StageHUD.gd](scripts/ui/StageHUD.gd) y conectado a [MainGame.gd](scripts/core/MainGame.gd) (sin tocar física de orbes ni oleadas).
  * **Fase 4 (Subsistemas satélite fuera de `MainGame.gd`):** extraídos [ChemistryRules.gd](scripts/core/ChemistryRules.gd), [PotionFlaskView.gd](scripts/core/PotionFlaskView.gd) (adjunto directo al nodo `PotionFlask` de [Main.tscn](scenes/main/Main.tscn)), [TutorialDirector.gd](scripts/core/TutorialDirector.gd) y [MainGameSmokeRunner.gd](tools/MainGameSmokeRunner.gd).
  * **Fase 5 (Tablero del caldero + oleadas + coordinador limpio):** extraídos [CauldronBoard.gd](scripts/core/CauldronBoard.gd) (adjunto directo al nodo `CauldronAnchor` de [Main.tscn](scenes/main/Main.tscn), de modo que mover el nodo en el editor mueve el tablero físico real) y [WaveDirector.gd](scripts/core/WaveDirector.gd), movido el respaldo de clientas a [CharacterArt.gd](scripts/ui/CharacterArt.gd) y actualizado [MainGameSmokeRunner.gd](tools/MainGameSmokeRunner.gd). Además, se podó todo el arte procedural muerto (Trixie, clientas y Doña Remedios) en [CharacterArt.gd](scripts/ui/CharacterArt.gd) (**549 → 244 líneas reales**, quedando solo carga/caché/animación de PNGs), dejando en blanco su hueco en [IntroCutscene.gd](scripts/ui/IntroCutscene.gd) hasta rehacer la intro. [MainGame.gd](scripts/core/MainGame.gd) queda reducido a coordinador de **972 líneas reales**.
  * **Fase 6 (Hub `WorldMap.tscn` editable + 3 sub-escenas por pestaña):** convertida [WorldMap.tscn](scenes/meta/WorldMap.tscn) en escena editable (`TopBar`, `TreeBadge`, `PauseOverlay`, `VictoryOverlay` e instancias de las 3 pestañas) y separado el monolito de [WorldMap.gd](scripts/meta/WorldMap.gd) (**1.325 → 318 líneas reales**) en sub-escenas independientes editables desde el editor: [MapTab.tscn](scenes/meta/MapTab.tscn) / [MapTab.gd](scripts/meta/MapTab.gd) (**258 líneas**, incluyendo el panel `WitchSlot` con Trixie `fullbody` y nombre a la izquierda como ancla para el futuro selector de bruja), [SkillTreeTab.tscn](scenes/meta/SkillTreeTab.tscn) / [SkillTreeTab.gd](scripts/meta/SkillTreeTab.gd) (**211 líneas**) y [GalleryTab.tscn](scenes/meta/GalleryTab.tscn) / [GalleryTab.gd](scripts/meta/GalleryTab.gd) (**314 líneas**). Reacomodados los nodos del mapa en [GameCatalog.gd](scripts/core/GameCatalog.gd) para despejar `WitchSlot`.
  * **Validación:** [MapTab.tscn](scenes/meta/MapTab.tscn), [SkillTreeTab.tscn](scenes/meta/SkillTreeTab.tscn), [GalleryTab.tscn](scenes/meta/GalleryTab.tscn), [WorldMap.tscn](scenes/meta/WorldMap.tscn) y [Main.tscn](scenes/main/Main.tscn) arrancan en headless (`exit 0`), `--import` registra las clases sin errores (`IMPORT:0`) y [smoke_test_slice.gd](tools/smoke_test_slice.gd) supera todos los checks (`INCREMENTAL SMOKE RESULT: PASS`, `SMOKE_EXIT:0`).
* **2026-11-25 — Respeto de `z_index` del Editor en `Main.tscn` al Ejecutar (`F6`):**
  * Separado el dibujado en tiempo de ejecución en [MainGame.gd](scripts/core/MainGame.gd), [CauldronBoard.gd](scripts/core/CauldronBoard.gd) y [PotionFlaskView.gd](scripts/core/PotionFlaskView.gd) para que `CauldronAnchor` (`z_index = 0`), `TrixieStageSlot` / `CustomerStageSlot` (`z_index = 1`), `PotionFlask` (`z_index = 2`, vidrio `z_index = 3`) y `PopupLayer` (`z_index = 5`) dibujen sobre su propio `CanvasItem` y respeten en vivo el orden configurado en el editor de Godot.
* **2026-11-25 — Re-exportación `thigh-up` de Trixie (`6/6`):**
  * Actualizados los prompts de medio cuerpo de Trixie a corte `thigh-up` en [prompts_characters.md](docs/prompts_characters.md) y re-exportados los 6 recortes HD desde `raw_assets/hd_cutouts/trixie/` con escala uniforme Lanczos (`560px` de ancho) en [halfbody/](assets/characters/playable/trixie/halfbody/).
* **2026-11-25 — Nodo Editable `OrderBubble` en `Main.tscn`:**
  * Convertida la burbuja de pedido (`PIDE`) en el nodo visible `OrderBubble` (`z_index = 3`) dentro de [Main.tscn](scenes/main/Main.tscn) con vista previa en editor y ranura `BackgroundTexture` para colocar un asset PNG personalizado sin tapar el orbe ni la receta en vivo ([MainGame.gd](scripts/core/MainGame.gd), [PotionFlaskView.gd](scripts/core/PotionFlaskView.gd)).
* **2026-11-25 — Re-exportación `thigh-up` de Sylvi (`3/3`):**
  * Actualizado el prompt de Sylvi a corte `thigh-up` en [prompts_characters.md](docs/prompts_characters.md) y re-exportados sus 3 recortes HD desde `raw_assets/hd_cutouts/sylvi/` con escala uniforme Lanczos (`560px` de ancho) en [halfbody/](assets/characters/customers/sylvi/halfbody/).
* **2026-11-25 — Tutorial Básico Directo en 2 Pasos (Sin Botón `¡LISTO!`):**
  * Eliminado `AckButton` de [SpeechBubble.tscn](scenes/ui/SpeechBubble.tscn) / [SpeechBubble.gd](scripts/ui/SpeechBubble.gd) y suprimido el paso resumen `BASIC_READY_SUMMARY` en [TutorialDirector.gd](scripts/core/TutorialDirector.gd) y [MainGame.gd](scripts/core/MainGame.gd); ahora el tutorial inicial cierra automáticamente en 2 pasos activos (`1/2` romper afín, `2/2` purgar `❌`).
* **2026-11-25 — Asset `asking_bubble.png` en `OrderBubble` y Limpieza de Fallbacks:**
  * Limpiado e integrado [asking_bubble.png](assets/ui/hud/asking_bubble.png) (`220×219`, sombra vía `ui_drop_shadow.gdshader`) en el prefab independiente [OrderBubble.tscn](scenes/ui/OrderBubble.tscn) / [OrderBubble.gd](scripts/ui/OrderBubble.gd) (nodos 100% editables `SingleOrderOrb` + `MixedOrderGroup`, instanciado en [Main.tscn](scenes/main/Main.tscn)) y eliminados los fallbacks muertos (`TUBE_RECT` en [PotionFlaskView.gd](scripts/core/PotionFlaskView.gd) y círculos/glifos de orbes en [CauldronBoard.gd](scripts/core/CauldronBoard.gd)).
* **2026-11-25 — Componentización Total de `Main.tscn` (Cero Fantasmas de Vista Previa):**
  * Separados en escenas independientes editables [PotionFlask.tscn](scenes/ui/PotionFlask.tscn) (con `PercentLabel` real), [WitchStageSlot.tscn](scenes/gameplay/WitchStageSlot.tscn) / [CustomerStageSlot.tscn](scenes/gameplay/CustomerStageSlot.tscn) (heredando de [CharacterStageSlot.gd](scripts/ui/CharacterStageSlot.gd) sobre `TextureRect` real), [CauldronBoard.tscn](scenes/gameplay/CauldronBoard.tscn) (con `FireGlow`, `CauldronSprite` real y `ComboBox`) y [ChemistryStrip.tscn](scenes/ui/ChemistryStrip.tscn) / [ChemistryStrip.gd](scripts/ui/ChemistryStrip.gd).

---

<details>
<summary><strong>Archivo Histórico (2026-11-19 a 2026-11-20 — Prototipo Diner Dash 2.5D &amp; Evaluación Comercial Pre-Pivote)</strong></summary>

* **2026-11-19 — Vertical Slice Cocina 2.5D (Fase 1 en `main`):** Se implementó el prototipo jugable de gestión de cocina por cola de clics hasta el Día 8 (`KitchenStation.gd`, `WitchController.gd`, `CustomerEntity.gd`, `FamiliarEntity.gd`, `KitchenHUD.gd`, Mortero obligatorio, Vitrina 2/2, Almacén separado con cajas `x20`, barra de XP y límites `1 Familiar / 3 Pasivas / 3 Activas`), además del splash del menú principal y la cinemática de intro.
* **2026-11-20 — Evaluación Comercial Honesta y Decisión de Pivote (`stash/chat02.txt`):**
  * Se detectó que el género *Diner Dash* en solitario tiene bajo techo en Steam, que el estrés de la cocina tapaba los retratos/diálogos (el verdadero producto) y duplicaba la carga de dibujo en Krita (escenario con perspectiva + muebles + chibis 2.5D).
  * Se evaluaron alternativas (*Roguelite de combos tipo Balatro/HuniePop* vs *Incremental corto 2D tipo Nodebuster/Digseum*) y plataformas (*Steam* vs *Android/iOS*), concluyendo apostar por **Incremental Corto 2D en Steam (`$4.99–$6.99`)** conservando íntegramente a Trixie, la temática de botica, las 5 clientas, los sistemas base de Godot y el foco total del arte en retratos/medio cuerpo/galería dibujados en Krita.

</details>
