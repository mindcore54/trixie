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
    5. **Sistema de Reliquias por Niveles y Slots estilo *Vampire Survivors*:**
       * Cada carta empieza con bonos pequeños incrementales (ej. Nv. 1 = `+5%` velocidad al caminar o cocinado) y sube de nivel al volver a salir (`Nv. 2`, `Nv. 3`..., sumando `+5%` extra cada vez).
       * **Topes de build por partida:** máximo **1 Familiar**, **3 Reliquias Pasivas** (velocidad, cocinado, carga, etc.) y **3 Habilidades Activas por tecla** (ej. transformar poción, frenar caída de paciencia por unos segundos, acelerar calderos).
  * **Siguiente Foco Inmediato (Para retomar la próxima sesión):**
    1. Definir y diseñar las **3 Pasivas + 3 Activas (con niveles escalables)** y la estructura de **1 Familiar máximo**.
    2. Hacer desbloqueables el **Mortero** y la **Vitrina** tras superar los primeros pedidos.
    3. Depurar la IA/feedback visual de **Familiares** y armar los **tutoriales cortos** con diálogos.

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

## Fase 2: Motor Roguelite, Familiares y Escalada Incremental
- [ ] **2.1 Gestión de Días 1–8 + Modo Infinito + Progresión Suave:**
  - [ ] Hacer que **Mortero** y **Vitrina** sean desbloqueables progresivamente (no activos desde el minuto 0) para suavizar el arranque.
  - [ ] Crear `RunManager.gd` y tabla de oleadas (`WaveScheduleData`) con escalado de frecuencia y complejidad de pedidos.
  - [ ] Implementar Jefes de Turno (Día 3 *Seraphina VIP*, Día 6 *Hora Pico del Sabbat*, Día 8 *Archidemonio*).
- [ ] **2.2 Sistema de Familiares Autónomos y Depuración de NPCs:**
  - [ ] Revisar y depurar bugs de movimiento/estado donde los familiares se quedan pegados junto al caldero (ej. *Michi Alado*), y darles feedback visual claro de lo que hacen.
  - [ ] Implementar los 4 familiares iniciales (`Michi Alado`, `Diablillo Carmesí`, `Murciélago Sombrío`, `Mandrágora Cantora`) con IA limpia y animaciones flotantes.
- [ ] **2.3 Sistema de Niveles, Slots Límite (Vampire Survivors) y Catálogo de Reliquias:**
  - [ ] Implementar **niveles acumulables por carta** (ej. Nv. 1 `+5%` velocidad -> Nv. 2 `+10%`, etc. cuando vuelve a aparecer en el Draft).
  - [ ] Implementar **límite máximo de slots por partida:** **1 Familiar** + **3 Pasivas** + **3 Habilidades Activas** (activables por tecla, ej. transmutar una poción en otra o ralentizar la pérdida de paciencia unos segundos).
  - [ ] Auditar y rebalancear todas las cartas actuales junto al desarrollador (ajustar *Espejo Duplicador*, que resulta demasiado fuerte al clonar directo a la Vitrina).
  - [ ] Crear los archivos `.tres` definitivos en `res://data/upgrades/` y conectar los hooks de evento (`espejo_duplicador`, `corazon_fenix`, `mortero_sismico`, etc.).
  - [ ] Implementar tienda intermedia entre días (Reroll de cartas y Reparación de corazones).

- [ ] **2.4 Tutoriales Cortos con Diálogos (Onboarding Orgánico):**
  - [ ] Secuencia de diálogos cortos explicando paso a paso: 1 color al caldero, 2 colores al Mortero, revolver el caldero para el bono `¡CALIENTE!`, uso de la Vitrina y habilidad especial con clic derecho.

---

## Fase 3: Elenco Completo, Afinidad Picante e Integración de Arte Final
- [ ] **3.1 Integración de Arte de Trixie y Sylvi (Primer Pack Visual):**
  - [ ] Procesar dibujos de fondo blanco de **Trixie** (busto 6 emociones + semi-chibi + *cut-in*) y **Sylvi** (Fauno + 4 emociones) con `tools/process_white_bg.py`.
  - [ ] Reemplazar placeholders de cocina, calderos, ingredientes y pergamino *chipped*.
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
