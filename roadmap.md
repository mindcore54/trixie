# roadmap.md — Memoria Viva del Proyecto (*Trixie*)

> **ESTADO DEL DOCUMENTO:** Este archivo es la **memoria viva y el punto de contacto directo** entre **Antigravity** y el **Desarrollador**.  
> **Regla Operativa:** Antigravity tiene total libertad y obligación de actualizar este archivo tras cada sesión o hito: marcando tareas completadas (`[x]`), registrando decisiones críticas de diseño, reportando bloqueos reales y definiendo qué necesita del desarrollador para la siguiente fase.

---

## Bitácora de Decisiones y Estado Actual
* **2026-11-19 — Vertical Slice Jugable (Fase 1) Implementado y Verificado:**
  * Documentada en `AGENTS.md` la filosofía de trabajo **"First Make It Happen"**: priorizar prototipos jugables rápidos y visibles para que el desarrollador los pruebe y corrija sobre la marcha.
  * Implementados y verificados los sistemas núcleo en Godot 4.7.2: `AudioJuiceManager.gd` (SFX pentatónicos procedurales, hitstop, screen shake), `GameCatalog.gd` + 21 archivos `.tres` en `res://data/` (4 brujas, 5 clientas, 6 recetas, 6 mejoras/familiares), `KitchenStation.gd`, `CustomerEntity.gd`, `FamiliarEntity.gd`, `WitchController.gd` (cola de hasta 6 clics), `KitchenHUD.gd` (busto reactivo 6 emociones, retrato grande abajo-derecha, pergamino *chipped*, *cut-in* y modal de draft) y `MainGame.gd`.
  * **Validación:** `--smoke-test` headless superado (`gold=66, combo=1, day=2, familiars=1, ability_ok=true`) y arranque de `Main.tscn` limpio sin errores.
  * **Control refinado (Post-Playtest):** Bloqueado clic en suelo vacío (solo estaciones y clientas válidas) y simplificada la cola a **1 clic en curso + 1 clic siguiente en buffer** (`MAX_NEXT_BUFFER = 1`) para eliminar sobrecarga visual manteniendo el encadenado fluido.
  * **Balance de timings iniciales (Post-Playtest):** Relajada la cadencia de llegada (`14s` inicial, `16.5s` intervalo Día 1), paciencia aumentada (`52–70s` con desgaste al `40%` en fila trasera), ventana de sobrecalentamiento ampliada a `16s` (alerta solo en el último 35%), Día 1 solo con recetas de 1 ingrediente, y eliminado el familiar automático de Nyxara al arranque para que el inicio manual sea 100% limpio.
  * **Pausa selectiva de timings + Pantalla Completa (`F11`):** Al abrir el modal de tarjetas/habilidades roguelite, todos los contadores (reloj, paciencia, cocción, sobrecalentamiento y movimiento) se pausan vía `EventBus.timers_paused`, mientras las animaciones visuales siguen vivas. Ajustado `stretch/aspect="keep"` para evitar cortes en monitores 1080p y añadido botón + tecla `F11` para pantalla completa.
  * **Corrección de mezclas y mortero:** Arreglado bug donde el mortero (`crushed_*`) impedía mezclar colores, y redefinido el rol obligatorio del **Mortero**: las pociones de 1 color van directo al caldero, mientras que las de 2 colores (`Rojo + Verde -> Círculo Amarillo`, `Rojo + Azul -> Morado`, `Azul + Verde -> Turquesa`) deben fusionarse primero en el Mortero (2 en mano o 1 a 1 en el cuenco) antes de entrar al caldero.
  * **Vitrina de 2 huecos + Tarjetas concisas:** Añadida la estación **Vitrina (2/2)** con selección individual por hueco (clic en poción = la agarras; clic en hueco vacío = colocas la última que tienes) y tarjetas roguelite acortadas.
  * **Decisión previa de pedido en clientas:** Las clientas muestran `. . .` un instante al llegar para ojear la Vitrina antes de decidir su pedido; si ya revelaron su globito de poción, **nunca cambian de opinión** a mitad de preparación.
  * **Playtest Completo (8 Días Superados — Hito 1.6 Validado):** El desarrollador completó una partida entera hasta el Día 8 validando que el bucle base es divertido. Puntos detectados para abordar en **Fase 2** (sin tocar código todavía):
    1. **Desbloqueo progresivo al inicio:** Que el **Mortero** y la **Vitrina** se desbloqueen más adelante (cuando el jugador ya domina el bucle de 1 color) para hacer la entrada mucho más suave.
    2. **Auditoría de cartas roguelite:** Revisar todas las cartas y nerfear/rebalancear efectos demasiado rotos (ej. *Espejo Duplicador* clonando pociones en Vitrina se siente demasiado fuerte).
    3. **Revisión de Familiares y NPCs:** Depurar por qué los familiares (como *Michi Alado*) se quedan pegados al caldero y añadir feedback visual/tutorial claro de qué hace cada uno.
    4. **Tutoriales cortos con diálogos** para explicar mecánicas (`¡CALIENTE!`, Mortero, Vitrina, Familiares).
    5. **Sistema de Niveles por XP de Entregas y Slots estilo *Vampire Survivors*:**
       * **Subida de nivel por XP (NO atada al reloj del día):** Cada poción entregada da XP base + bono según qué tan rápido se sirvió. Al llenar la barra de XP en cualquier momento, se pausan los timings y sale el Draft de cartas (permitiendo subir muchos niveles por partida).
       * Cada carta empieza con bonos pequeños incrementales (ej. Nv. 1 = `+5%` velocidad al caminar o cocinado) y sube de nivel al volver a salir (`Nv. 2`, `Nv. 3`...).
       * **Topes de build por partida:** máximo **1 Familiar**, **3 Reliquias Pasivas** (velocidad, cocinado, carga, etc.) y **3 Habilidades Activas** (con **botones clicables en UI** fuera de la esquina del retrato + **teclas `1/2/3` como atajo**, para soportar tanto 1 mano como 2 manos).
    6. **Fricción Manual -> Automatización (Stock/Almacén) y Alcance Inicial de Arte:**
       * Evaluar cajas de ingredientes con stock (paquetes de 10) recargables desde una zona de suministro/carreta **visible en pantalla** (sin perder de vista calderos ni clientas) que luego se automatiza con familiares.
       * Arrancar la producción visual con **1 brujita jugable (*Trixie*)** + clientas (primero placeholders IA y luego dibujo final en Krita); el resto de brujas vendrán después.
* **2026-11-20 — Barra de XP, Días de 5 Minutos y Pantalla de Builds Entre Días (Fase 2.1 / 2.3 parcial):**
  * **Skills de Godot instaladas:** Copiadas las 14 skills de Godot 4.7 en `.agents/skills/` y creada la skill propia `trixie-art-pipeline`.
  * **Barra de XP en tiempo real y subida de nivel de cartas:** Cada entrega otorga XP base + bono por rapidez (`patience_ratio`) y calor (`¡CALIENTE!`). Al llenar la barra de XP en pleno turno, los contadores se pausan, se abre el Draft para elegir una nueva habilidad o subir el nivel de una existente (`Nv. 1 -> Nv. 2 -> ...`), y se reanuda el mismo día sin saltar de jornada.
  * **Rebalanceo inicial para niveles:** Ajustadas las 6 cartas en `res://data/upgrades/*.tres` y `GameCatalog.gd` (`Botas de Tacón Arcano` +12%/nivel hasta Nv. 5, `Espejo Duplicador` 35%/65%/100% por nivel, familiares y `Corsé Magnético` hasta Nv. 3).
  * **Días de 5 minutos (`300s`) y fin del selector en cocina:** Eliminado el botón para cambiar de bruja en medio de la partida.
  * **Pantalla de Preparación / Builds Entre Días (`KitchenHUD.gd` + `MainGame.gd`):** Al terminar cada día (o usar el botón de prueba `Fin de Día / Builds (Test)`), se abre la nueva pantalla con la bruja a **cuerpo completo** a la izquierda (solo **Trixie** jugable; **Lyra**, **Nyxara** y **Morrigan** bloqueadas para desbloqueo por historia, no por oro) y a la derecha **6 mejoras de build comprables con oro** (*Botas Ligeras*, *Llama del Caldero*, *Acero Templado*, *Encanto Comercial*, *Reloj de Arena*, *Corazón de Fénix*) más el resumen de habilidades de XP que se conservan para el día siguiente.
  * **Límites de build (`1 Familiar / 3 Pasivas / 3 Activas`) + Botones de Activas (`1/2/3`):** Implementado `UpgradeKind.ACTIVE_SKILL`, 4 habilidades activas (`Destello de Ebullición`, `Perfume Hipnótico`, `Paso Astral`, `Alquimia Dorada`) y la pasiva `Mortero Sísmico` en `res://data/upgrades/` y `GameCatalog.gd`. El Draft filtra cartas nuevas al llenarse cada categoría (permitiendo seguir subiendo de nivel las ya equipadas), muestra el contador de slots en HUD/Draft y añade 3 botones clicables abajo al centro (`1/2/3`) sin tapar el retrato de clienta.
  * **Inicio garantizado con Trixie:** Corregido el orden alfabético de carga de `.tres` en `GameCatalog.get_witches()` y `_find_witch_index(&"trixie")` en `MainGame.gd`.
  * **Murciélago Mensajero + 2 Slots en Embotellado + Cierre de Tienda (`00:00`):**
    * **Embotellado con 2 huecos (`KitchenStation.gd` + `WitchController.gd`):** La mesa de Embotellado ahora almacena hasta 2 pociones ya embotelladas con selección individual por hueco (tanto para Trixie como para el Murciélago).
    * **IA del Murciélago Mensajero (`FamiliarEntity.gd`):** Recoge pociones listas del caldero sin embotellar (`raw:`), vuela obligatoriamente a Embotellado para sellarlas (`bot:`), prioriza recoger pociones pedidas desde **Vitrina** o **Embotellado**, y si carga una poción que nadie pide la suelta en Embotellado (o Vitrina como respaldo) en lugar de quedarse colgado. Añadido texto de estado sobre los familiares.
    * **Cierre de tienda al llegar a `00:00` (`MainGame.gd` + `KitchenHUD.gd`):** El reloj cambia a `CERRANDO`, se bloquea la llegada de nuevas clientas y la pantalla de Builds entre días se abre automáticamente al atender a la última clienta de la fila.
  * **Animación de sudor en familiares bloqueados, Stock de Ingredientes (Bodega x20 + Estante de Cajas) y Hora Pico:**
    * **Gota de sudor anime (`FamiliarEntity.gd`):** Cuando el Murciélago no tiene huecos libres o el Diablillo se queda sin stock en caja, tiembla y muestra una gota de sudor azul animada sin texto.
    * **Stock de ingredientes + Habitación de Almacén separada + Estante de Cajas (`KitchenStation.gd` + `WitchController.gd` + `MainGame.gd`):** Cada caja de ingrediente tiene `10/10` usos. En la pared izquierda de la cocina hay una **Puerta al Almacén** (`Almacén ◀`) que hace un paneo rápido de cámara (`0.22s`) a la habitación separada del **Almacén** con las 3 pilas infinitas de cajas pesadas `x20` (solo 1 caja a la vez con manos vacías, `-25%` velocidad al cargarla) y puerta de vuelta (`Cocina ▶`). Los sobrantes de caja se aparcan en el **Estante de Cajas (3 slots)** de la cocina y desaparecen en `0`.
    * **Hora Pico sutil (`MainGame.gd` + `KitchenHUD.gd`):** Sin banners ni textos ni oro extra; durante las dos ventanas de Hora Pico (`03:15–02:20` y `01:15–00:15`) solo cambia el color del reloj a rojo/naranja y se acelera la llegada de clientas.
  * **Estándar Oficial de Generación de Arte por Hojas (Documentado en `.agents/skills/trixie-art-pipeline/SKILL.md`):**
    1. **Concept Art (`<Nombre> - Concept Art`):** Lámina base sobre `#FFFFFF` con cuerpo completo **frontal y trasero**, **retrato grande** del rostro reflejando personalidad, todos los accesorios/detalles del atuendo y título `<Nombre> - Concept Art`. **Obligatorio pasarlo como referencia** en cada generación siguiente.
    2. **Hoja de Expresiones (`16:9`):** Todas las expresiones juntas en una sola imagen `16:9` sobre `#FFFFFF` usando el Concept Art de referencia para consistencia total.
    3. **Hoja de Semi-Chibi 2.5D (`4:3`):** 4 poses direccionales en cuadrícula `2×2` (1 en cada esquina) sobre `#FFFFFF` usando el Concept Art de referencia: **abajo**, **diagonal derecha abajo**, **arriba (de espaldas)** y **diagonal derecha arriba** (izquierda por *flip* horizontal en Godot).
  * **Menú Principal, Cinemática de Intro con Lore, Transiciones Fade y Tutorial Guiado (Fase 2.4):**
    * **Menú Principal ([MainMenu.tscn](file:///c:/Users/mindcore.dev/Projects/trixie/scenes/ui/MainMenu.tscn) + [MainMenu.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/ui/MainMenu.gd)):** Escena de entrada en `project.godot` con título, Trixie animada a cuerpo completo, botones **Iniciar Juego**, **Opciones** (volumen general, pantalla completa, activar/desactivar tutorial en `GameSettings.gd`) y **Salir**.
    * **Cinemática de Intro ([IntroCutscene.tscn](file:///c:/Users/mindcore.dev/Projects/trixie/scenes/ui/IntroCutscene.tscn) + [intro_cutscene.json](file:///c:/Users/mindcore.dev/Projects/trixie/data/dialogues/intro_cutscene.json)):** Diálogo visual-novel humorístico donde Trixie (ligeramente torpe pero decidida a tener la tienda más famosa del pueblo) le compra el local a **Doña Remedios**, con texto máquina de escribir, expresiones animadas (`CharacterArt.gd`), botón de saltar y transiciones **fade-in / fade-out a negro** (`SceneFader.gd`).
    * **Diálogos de Trixie a la izquierda + Tutorial Guiado (`KitchenHUD.gd` + `MainGame.gd`):** Trixie tiene su propio retrato y pergamino en la esquina **inferior izquierda** (opuesta a las clientas). En Día 1 guía paso a paso la primera poción (flecha dorada pulsante sobre cada estación y paciencia congelada en la 1ª clienta), y la primera vez que una caja llega a `0/10` explica paso a paso cómo ir al **Almacén**, traer una caja `x20`, rellenar y usar el **Estante de Cajas**.
  * **Arte Final de Trixie Integrado en Todo el Juego (Fase 3.1 — Pack Trixie):**
    * Creado [slice_sprite_sheet.py](file:///c:/Users/mindcore.dev/Projects/trixie/tools/slice_sprite_sheet.py) con extracción por **componentes conexos** + limpieza de fondo `#FFFFFF` (`process_white_bg.py`) y limpieza de bolsillos cerrados en el rizo del sombrero.
    * Generados e importados 11 PNGs transparentes en `res://assets/characters/playable/trixie/` (cuerpo completo `v05`, 6 expresiones de borde recto `v02`, 4 semi-chibis 2.5D verticales `v03`) y cableados en `data/characters/trixie.tres`, `WitchCharacterData.gd`, `CharacterArt.gd`, `IntroCutscene.gd`, `KitchenHUD.gd` y `WitchController.gd` (6 direcciones con *flip* horizontal + rebote *Helltaker*).
  * **Splash Art + Logo 3D Transparente con Halo Mágico en Menú Principal:**
    * Procesado `raw_assets/trixies_logo.jpg` a PNG transparente limpio (`res://assets/ui/menus/trixies_logo.png`) e integrado el splash art `res://assets/ui/menus/trixies_main_bg.jpg` como fondo a pantalla completa en [MainMenu.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/ui/MainMenu.gd) (listo para separar el personaje en DragonBones más adelante).
    * Añadido halo mágico pulsante y destello dorado en el logo mediante shader propio ([logo_magic_halo.gdshader](file:///c:/Users/mindcore.dev/Projects/trixie/shaders/logo_magic_halo.gdshader)) + anillos arcanos, partículas orbitando y flotación suave sobre la zona izquierda sin tapar a Trixie ni a los michis voladores.
  * **Estándar 1:1 Lanczos (Cero Reescalado en Godot) + Corrección de Orientación de Trixie:**
    * Creado [export_character_sizes.py](file:///c:/Users/mindcore.dev/Projects/trixie/tools/export_character_sizes.py) y documentado como estándar permanente en `.agents/skills/trixie-art-pipeline/SKILL.md`: respalda recortes HD en `raw_assets/hd_cutouts/` y exporta 1:1 con *Lanczos* retratos en **3 tamaños exactos** (`cutscene 590×510`, `dialogue 420×370`, `hud 140×140` **cuadrado con zoom cerrado al rostro** mirando a la **derecha**), chibis a **`216px`** (corregido espejo de `down_right`/`up_right` para que mire a la dirección real al caminar izquierda/derecha, ajustado a las proporciones del concept art) y cuerpo completo (`300×366`).
    * Rediseñada la esquina superior izquierda de [KitchenHUD.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/core/KitchenHUD.gd) siguiendo el concept art: cajas separadas para `[Tiempo] [Oro] [Vidas]`, debajo la **barra de XP**, debajo el **retrato cuadrado con zoom** de Trixie y los **diálogos/tutoriales saliendo en pergamino hacia su derecha** (eliminando el retrato duplicado abajo-izquierda que tapaba las cajas de ingredientes); botones de debug reubicados en una barrita compacta abajo-izquierda.
    * Eliminadas las líneas verticales de 1px del degradado izquierdo en [MainMenu.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/ui/MainMenu.gd) y pre-escalados 1:1 el logo (`560×350`) y el fondo (`1920×1080`).
  * **Fondo Base `v02` + Mostrador Separado con Profundidad 2.5D y Y-Sort (`kitchen_bg.jpg` + `kitchen_desk.png`):**
    * Exportado `raw_assets/kitchen_bg_v02.jpg` (`1920×1080` sin bandas negras) y el recorte transparente `raw_assets/kitchen_bg_v02-desk.png` recortado a su *bounding box* exacto (`214×550` en `Vector2(1170, 353)` -> `res://assets/backgrounds/kitchen_desk.png`).
    * Implementada jerarquía de capas 2.5D en [MainGame.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/core/MainGame.gd): clientas detrás del mostrador (`_customers_layer`, `y_sort_enabled`, `z=1`) entrando por la puerta soleada (`(1485, 355)`), mostrador independiente (`_desk_sprite`, `z=2`), cocina completa con Y-sort (`_kitchen_layer`, `y_sort_enabled`, `z=3`) donde Trixie pasa por delante y detrás de cada estación, familiares volando encima (`z=10`) y popups/flechas tutorial en capa superior (`_world_overlay`, `z=20`).
    * Recalibradas estaciones, borde inclinado de atención (`WitchController.get_counter_service_pos`) y arco clicable del **Almacén**.
    * Reorganizada la distribución definitiva de cocina: **Vitrina vertical** sobre el tramo superior del mostrador, **Cajas de Ingredientes** en la fila inferior izquierda, **Pallet de Cajas** a su derecha y **Basura** abajo-derecha junto a la caja registradora (despejando el centro de paso y evitando *misclicks* entre Embotellado y Vitrina).
  * **Arte Final de Estaciones 2.5D Integrado (`res://assets/props/stations/` 1:1 Lanczos):**
    * Creado [export_kitchen_stations.py](file:///c:/Users/mindcore.dev/Projects/trixie/tools/export_kitchen_stations.py) para recortar e importar en 1:1 los 10 PNGs transparentes de las 3 láminas HD (`kitchen_assets1.png`, `kitchen_assets2a.png`, `kitchen_assets2b.png`): Caldero vacío, Mortero, Embotellado, Vitrina vertical, Pallet de madera, Cubo de Basura abierto con reciclaje, mesa unificada intacta de 3 cajones (`station_bins_table_empty.png`) y las 3 pilas separadas de ingredientes (`station_ing_red/blue/green.png`).
    * Integrados en [KitchenStation.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/core/KitchenStation.gd) con líquido dinámico en el borde del caldero, fuego parpadeante, vaciado visual de ingredientes sobre la mesa común según stock (`0/10` vacía real), frascos esféricos sobre Vitrina/Embotellado y cajas en Pallet, más ajuste de colisiones/rutas en [MainGame.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/core/MainGame.gd), [WitchController.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/core/WitchController.gd) y [FamiliarEntity.gd](file:///c:/Users/mindcore.dev/Projects/trixie/scripts/core/FamiliarEntity.gd).
  * **Validación:** `--import`, `MainMenu.tscn`, `IntroCutscene.tscn` y `--smoke-test` headless superados (`SMOKE_EXIT=0`, `SMOKE RESULT: PASS`).
* **2026-11-20 — Evaluación Comercial Honesta (sin cambios de código):**
  * **Veredicto:** Puede ser rentable a escala modesta (nicho anime/ecchi en Steam, precio `$6.99–9.99`), **no** gracias a la mecánica Diner Dash (género casi muerto en PC), sino al carisma de las chicas + afinidad estilo *HuniePop/Helltaker*. Hoy eso que vende está al ~0% (solo Trixie tiene arte; clientas, afinidad, galería y diálogos picantes sin hacer).
  * **Riesgos detectados:** (1) *Scope creep* en logística (Almacén, cajas x20, stock, 2 slots, Vitrina, Mortero) en vez de en el gancho; (2) días de `300s` x 8 = runs de ~40 min, rompe la promesa roguelite de 10–15 min; (3) automatización viral (familiares) aún con bugs/no implementada; (4) arte final IA = riesgo alto con este público y obligación de declararlo en Steam; (5) cero validación de mercado (sin página de Steam ni wishlists).
  * **Recomendación:** Congelar sistemas nuevos; priorizar 5 clientas con arte final + afinidad + galería, runs cortas, clip "minuto 1 vs minuto 12", página de Steam cuanto antes y demo para Next Fest. Meta orientativa: ~7k+ wishlists antes de lanzar.
* **2026-11-22 — Pivote a Incremental Táctico 2D en `proto/incremental` (Cero Autoclicker · Química de Colores):**
  * **Feedback del playtest & mockup 16:9:** Se descartó el primer borrador de *hover/autoclicker* por sentirse vacío y pasivo. Tras validar un mockup 16:9 (*Caldero central con runas + Trixie con barra/botón Frenesí a la izquierda + Tubo vertical de poción y Clienta en grande a la derecha*), se rediseñó por completo la mecánica para darle lógica alquímica real y arranque limpio.
  * **Mecánica Táctica Implementada (`GameCatalog.gd` + `MainGame.gd`):**
    1. **Cero Autoclicker y Arranque Lento:** Pasar el cursor NO extrae nada. La Ronda 1 arranca con solo **6 orbes grandes y lentos** (`34px`, `12–24 px/s`). **Clic Izquierdo** extrae un orbe; **mantener y arrastrar** encadena orbes del mismo color (+ ⭐ Comodín / 💣 Bomba) con multiplicador exponencial (`2.4x`, `4.2x`, `6.5x...`); **Clic Derecho** purga orbes negativos (`❌`) sin dañar el tubo ni cortar el Combo.
    2. **Química de Colores por Clienta (`AFÍN` / `NEUTRO` / `RESTA`):** Cada una de las 5 clientas (`Sylvi`, `Velvet`, `Seraphina`, `Mona`, `Roxy`) tiene gustos propios que cambian en vivo al entrar la siguiente: el color **Afín** llena `+22%+` del Tubo Vertical, da `2x` Esencia y carga **Frenesí**; el **Neutro** aporta `+7%` y mantiene el Combo; el color que **Resta (`❌`)** baja `-18%` del tubo y reinicia el Combo a `0`.
    3. **Frenesí Escarlata + Árbol de 17 Nodos + Galería:** Al llegar al `100%` de Frenesí (`Espacio` o botón rojo bajo Trixie), todos los orbes `❌` del caldero se transmutan en **Afines** y se duplica la producción. El Árbol de 17 nodos escala la química, cadenas, bombas/estrellas, duración y familiares inteligentes (**Michi Alado** caza Afines, **Diablillo Purgador** expulsa `❌`, **Murciélago Alquimista** apoya el tubo).
  * **Validación:** `tools/smoke_test_slice.gd` actualizado verificando ausencia de autoclicker, arranque lento de 6 orbes, química `Afín / Neutro / Resta`, purga con clic derecho, completado de pedidos, Frenesí y compra de nodos.
* **2026-11-23 — Redefinición de Tipos de Arte, Galerías como Cinemáticas Secretas y Regla de Ahorro de Tokens:**
  * **Nuevos Tipos de Imágenes por Personaje (actualizados en `trixie-art-pipeline/SKILL.md`, `tools/generate_prompts.py`, `tools/export_character_sizes.py` y `docs/prompts_catalog.md`):**
    * Se eliminan los semi-chibis y los 3 tamaños de retrato (`cutscene/dialogue/hud`).
    * Cada personaje usa ahora **3 tipos de ilustración**:
      1. **Retrato (`portrait` — Hoja `16:9`)**: Un único tamaño estándar (rostro/hombros) con las 6 expresiones juntas.
      2. **Medio Cuerpo (`halfbody` — 2 Hojas `4:3`, 3 por imagen)**: Ilustraciones **verticales sin marco** divididas en **Hoja 1 Core Gameplay** (`normal`, `confiada`, `nerviosa_sudando`) para blindar la consistencia de estilo en las 3 más vistas en partida, y **Hoja 2 Secundarias** (`sonrojada_picante`, `hollin_derrota`, `sorprendida`).
      3. **Full Size (`fullbody` — Vertical `9:16`)**: Ilustración dedicada de cuerpo completo en `9:16`, más pensada para el juego — **no vale reutilizar ni recortar el Concept Art** (el Concept Art queda únicamente como hoja de referencia).
    * **Dirección estética para próximos conceptos:** Estilo súper sexy con opciones de vestuario atrevido (escotes muy pronunciados, *underboob*, *sideboob*, transparencias) para diferenciar a los próximos personajes.
  * **Layout Vertical Sin Marcos + Medio Cuerpo Core de Trixie Integrado (`MainGame.gd` + `CharacterArt.gd`):**
    * Procesada e integrada la **Hoja 1 Core (`16:9`)** de Trixie (`trixie_halfbody_normal`, `trixie_halfbody_confiada` y `trixie_halfbody_nerviosa_sudando`, todas mirando `>>` en `res://assets/characters/playable/trixie/halfbody/`).
    * Eliminados los marcos rectangulares alrededor de Trixie y de la clienta; Trixie ocupa ahora espacio vertical amplio y libre a la izquierda (`520×816`), y el dock de **Frenesí + diálogo** se compactó a `174px` solapado sobre su borde inferior (recuperando ~`230px` verticales para lucir a la brujita).
  * **Perspectiva Ligera del Caldero + Y-Sort (pendiente para futuro):** Se documenta el enfoque para dar una ligera inclinación hacia atrás al caldero (referencia `imagen4`), proyectando los orbes en elipse con escala por profundidad `Y` y Y-sort entre orbes/borde delantero del caldero.
  * **Galerías = Cinemáticas Secretas Desbloqueables (Matriz Bruja × Clienta):**
    * La Galería no son solo imágenes sueltas, sino **historias cortas y cómicas/picantes desbloqueables** de encuentros entre cada brujita jugable y cada clienta (cada par Brujita × Clienta tiene su propia mini-historia).
    * *Ejemplos documentados por el desarrollador:*
      - Una brujita se va al bar con **Sylvi**, terminan borrachas, acaban en un motel y tienen "final feliz".
      - Otra brujita con la misma **Sylvi** termina enredada con unos moteros, las agarran a ambas y les hacen... cosas (y a ellas les gusta).
  * **Regla de Placeholders / Ahorro de Tokens:** Reutilizar los gráficos que ya existen en el proyecto sin costo extra; para cualquier gráfico nuevo temporal que el desarrollador vaya a reemplazar luego, usar **formas simples ("huevos"/cápsulas de colores)** y **no gastar tokens generando gráficos complejos desechables**.
* **Siguiente Foco Inmediato:**
  1. **Playtest del nuevo bucle táctico en `proto/incremental`:** Comprobar en partida real si enlazar cadenas afines, purgar los `❌` y activar el Frenesí se siente lógico, entretenido y adictivo.
  2. **Discutir y aplicar el nuevo Layout vertical sin marcos** (para Retratos / Medio Cuerpo / Full Size) y, más adelante, la perspectiva ligera del caldero con Y-sort.
  3. **Ajuste de balance y *Game Juice*:** Calibrar tiempos de ronda (`25s`), multiplicadores de cadena y costes del árbol según tu feedback tras jugarlo.
  4. **Arte Final en Krita (0 chibis 2.5D):** Sustituir el caldero, los 5 iconos de orbe, el tubo vertical y las ilustraciones (`portrait`, `halfbody`, `fullbody` dedicado) + cinemáticas secretas de la Galería.

---

## Fase 0: Cimientos, Arquitectura y Pipeline de Arte
- [x] Leer historial completo de lluvia de ideas (`stash/chat01.txt`) y maquetas visuales.
- [x] Verificar conexión con MCP de Godot (`4.7.2.stable.official`).
- [x] Instalar skills de Godot 4.x en `.agents/skills/` y crear skill `trixie-art-pipeline`.
- [x] Inicializar estructura limpia del proyecto Godot (`project.godot`, carpetas `res://assets/`, `res://data/`, `res://scenes/`, `res://scripts/`, `res://tools/`).
- [x] Crear `EventBus.gd` y recursos tipados base (`WitchCharacterData`, `CustomerArchetypeData`, `PotionRecipeData`, `RogueliteUpgradeData`).
- [x] Verificar creación de escena raíz `scenes/main/Main.tscn` mediante MCP de Godot.
- [x] Crear script automatizado de fondo blanco a transparente (`tools/process_white_bg.py`) con *flood-fill* exterior + *defringe* (preserva ojos/dientes/ropa blanca) y pasar `--self-test`.
- [x] Crear generador y catálogo de prompts consistentes (`tools/generate_prompts.py` y `docs/prompts_catalog.md`).
- [x] Redactar `AGENTS.md`, `GDD.md` y `roadmap.md`.
- [x] Configurar `.gitignore` (ignorando `stash/`, `.godot/`, `.agents/` y `raw_assets/`) y subir primer commit a repositorio GitHub `trixie`.

---

## Fase 1: Vertical Slice Jugable (Validar Diversión Pura con Placeholders)
> **Meta:** Prototipo jugable de 1–2 días (3 minutos de juego real) usando siluetas temporales limpias para validar ritmo, cola de clics, tensión del caldero y legibilidad del HUD sin esperar arte definitivo.

- [x] **1.1 Escenario de Cocina 2.5D y Navegación:**
  - [x] Construir cocina en `Main.tscn` / `MainGame.gd` con distribución calcada a `imagen3.jpeg` (Estación de Ingredientes abajo-izquierda, Mortero, 2 Calderos centro-izquierda, Mesa Embotellado arriba-derecha, Mostrador + 5 slots de fila a la derecha).
  - [x] Movimiento limpio solo entre estaciones/clientas válidas con indicador de destino actual (`1`) y siguiente clic (`2`).
- [x] **1.2 Bruja Controlable por Clic + Siguiente Clic:**
  - [x] Implementar buffer de **1 siguiente clic** en `WitchController.gd` (destino activo + 1 próximo clic anticipado, sin colas largas confusas; clic central/`Q` para limpiar).
  - [x] Implementar `WitchController.gd` con 2 ranuras visuales de mano y rebote procedural al caminar (estilo *Helltaker* por código).
- [x] **1.3 Ciclo Completo de Poción y Calderos:**
  - [x] Crear los 6 recursos de recetas iniciales (Rojo, Azul, Verde, Rojo+Azul, Verde+Rojo, Concentrado Carmesí con Mortero) en `res://data/recipes/`.
  - [x] Implementar `KitchenStation.gd` (Cajas, Mortero, Calderos con cocción, revolver `¡CALIENTE!`, ventana de *overboil* y explosión con pérdida de corazón, Embotellado y Basura).
- [x] **1.4 Fila de Clientas, HUD Reactivo y Pergamino:**
  - [x] Implementar fila de hasta 5 clientas (`CustomerEntity.gd` + `MainGame.gd`) con barras de paciencia, colapso al 6º cliente, pago con multiplicador de combo y afinidad.
  - [x] Implementar busto reactivo arriba-izquierda (reloj, oro, corazones, 6 emociones en `KitchenHUD.gd` + selector rápido de las 4 brujas).
  - [x] Implementar panel abajo-derecha (retrato grande + pergamino *chipped* con diálogos y afinidad picante).
- [x] **1.5 Primer Draft Roguelite y Habilidad de Trixie:**
  - [x] Implementar clic derecho (`Fiebre Escarlata` / habilidades de las 4 brujas) con banner *cut-in* anime y audio procedural (`AudioJuiceManager.gd`).
  - [x] Implementar modal de Draft entre días eligiendo 1 de 3 mejoras (`Michi Alado`, `Diablillo Carmesí`, `Murciélago Mensajero`, `Botas Arcanas`, `Corsé Magnético`, `Espejo Duplicador`) + botón Reroll y atajo de prueba.
- [x] **1.6 Validación de Playtest (Hito Crítico):**
  - [x] Probar partida completa hasta el Día 8 con el desarrollador: bucle base validado como divertido tras ajustar cola, Mortero y Vitrina.

---

## Fase 2: Motor Roguelite por XP, Familiares y Escalada Incremental
- [x] **2.1 Barra de XP por Entregas y Días de 5 Minutos:**
  - [x] Implementar **Barra de XP** que sube al entregar pociones + bono por rapidez de entrega, disparando el modal de Draft cada vez que se llena (conservando el día en curso y las habilidades entre días).
  - [x] Alargar la duración de cada día a **5 minutos (`300s`)**, quitar el cambio de bruja en partida y crear la **Pantalla de Builds Entre Días** (brujita de cuerpo completo a la izquierda con desbloqueo por historia; mejoras de build con oro a la derecha).
  - [ ] Hacer que **Mortero** y **Vitrina** sean desbloqueables progresivamente (no activos desde el minuto 0) para suavizar el arranque.
  - [x] Implementar mecánica de stock en cajas de ingredientes (`10/10` por caja + Habitación separada de Almacén con cajas pesadas `x20` + Estante de Cajas de 3 slots en cocina) para potenciar el contraste entre inicio manual y automatización.
  - [x] Implementar Oleadas de **Hora Pico** visuales dentro de cada día de 5 minutos (cambio de color del reloj y llegada acelerada, sin texto ni oro extra).
- [ ] **2.2 Sistema de Familiares Autónomos y Depuración de NPCs:**
  - [ ] Revisar y depurar bugs de movimiento/estado donde los familiares se quedan pegados junto al caldero (ej. *Michi Alado*), y darles feedback visual claro de lo que hacen.
  - [ ] Implementar los 4 familiares iniciales (`Michi Alado`, `Diablillo Carmesí`, `Murciélago Sombrío`, `Mandrágora Cantora`) con IA limpia y animaciones flotantes.
- [x] **2.3 Sistema de Niveles, Slots Límite (Vampire Survivors) y Catálogo de Reliquias:**
  - [x] Implementar **niveles acumulables por carta** (ej. Nv. 1 `+12%` velocidad -> Nv. 2 `+24%`, *Espejo Duplicador* 35%/65%/100%, familiares y *Corsé Magnético* hasta Nv. 3).
  - [x] Implementar **límite máximo de slots por partida:** **1 Familiar** + **3 Pasivas** + **3 Habilidades Activas** (con **botones clicables en UI** abajo-centro sin tapar el retrato de clienta + **teclas `1/2/3`** de atajo).
  - [ ] Auditar y rebalancear el resto de cartas y añadir más variedad junto al desarrollador.
  - [x] Crear los archivos `.tres` iniciales en `res://data/upgrades/` (`mortero_sismico` + 4 habilidades activas) y conectar sus hooks de evento.
  - [x] Implementar pantalla/tienda intermedia entre días para mejorar builds con oro (y selección de brujita desbloqueada por historia).

- [x] **2.4 Tutoriales Cortos con Diálogos (Onboarding Orgánico):**
  - [x] Secuencia guiada con flecha dorada y diálogos de Trixie a la izquierda: primera poción (caja ➔ caldero ➔ revolver/recoger ➔ embotellado ➔ entregar) y tutorial reactivo de reposición al Almacén cuando se agota una caja (`0/10`).

---

## Fase 3: Elenco Completo, Afinidad Picante e Integración de Arte Final
- [ ] **3.1 Integración de Arte de Trixie y Sylvi (Primer Pack Visual):**
  - [x] Procesar e integrar **Trixie** (cuerpo completo `v05` + 6 expresiones sin marco `v02` + 4 semi-chibis 2.5D `v03`) en Menú Principal, Intro, HUD, Tutorial, Pantalla de Builds y Cocina.
  - [ ] Procesar e integrar **Doña Remedios** y **Sylvi** (Fauno + emociones + semi-chibi).
  - [~] Reemplazar placeholders de cocina, calderos, ingredientes y pergamino *chipped* (fondo `v02`, mostrador separado y 10 sprites de estaciones/ingredientes integrados; pendiente pergamino *chipped* y líquidos/fuego animados).
- [ ] **3.2 Tres Protagonistas Adicionales:**
  - [ ] Integrar **Lyra** (Druida), **Nyxara** (Chamán) y **Morrigan** (Alquimista Oscura) con sus pasivas y activas únicas.
- [ ] **3.3 Elenco de Clientas y Sistema de Afinidad:**
  - [ ] Integrar **Velvet** (Súcubo), **Seraphina** (Paladín), **Mona** (Bruja Rival) y **Roxy** (Cazadora Lupina).
  - [ ] Implementar banco JSON de diálogos picantes (`res://data/dialogues/`) desbloqueables por afinidad Nv. 1–3 y contexto (ej. racha caliente).

---

## Fase 4: Game Juice Extremo, Audio Dinámico y Shaders
- [ ] **4.1 Escalado Musical y SFX:**
  - [ ] Implementar escalado pentatónico en cada clic de la cola y pitch ascendente por combo de monedas.
  - [ ] Integrar BGM dinámica por intensidad (capa base tranquila -> capa percusión frenética al superar 3 clientas o combo x5).
- [ ] **4.2 VFX y Shaders Godot 4.7:**
  - [ ] Shader de contorno brillante / *flash* blanco de impacto al recoger pociones y explotar calderos.
  - [ ] Partículas mágicas de vapor arcoíris en calderos, estelas en pies al correr y lluvia de monedas/corazones.
  - [ ] Animación completa de *cut-in* estilo anime al activar clic derecho + pantalla de derrota cómica con hollín.
  - [ ] Diferenciar visualmente cuando una clienta se marcha enojada por paciencia agotada (parpadeo rojo/icono de enfado) frente a cuando se va satisfecha.

---

## Fase 5: Meta-Progresión, Pulido y Lanzamiento
- [ ] **5.1 Hub del Aquelarre y Guardado Persistente (`SaveManager`):**
  - [ ] Guardar Esencias Arcanas, desbloqueos de brujas, atuendos, niveles de afinidad con clientas y récords en `user://save.json` (o `.tres`).
- [ ] **5.2 Vestidor y Galería de Ilustraciones:**
  - [ ] Pantalla de selección de bruja y atuendo antes de iniciar la *run*.
  - [ ] Galería para admirar a pantalla completa los retratos y escenas de derrota desbloqueadas.
- [ ] **5.3 Balance Final y Kit de Clips Virales:**
  - [ ] Ajustar curva de recompensas para que un jugador medio vea sinergias rotas entre el minuto 7 y 11.
  - [ ] Grabar clips de contraste (Minuto 1 vs Minuto 12) para validar atractivo visual en redes.
