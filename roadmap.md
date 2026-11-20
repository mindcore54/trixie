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
  * **Siguiente Foco Inmediato:** Que el desarrollador abra el proyecto en Godot (`F5`), juegue 1–2 turnos del Vertical Slice y marque qué siente lento, incómodo o mejorable para iterar al vuelo (Hito 1.6).

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
- [ ] **1.6 Validación de Playtest (Hito Crítico):**
  - [ ] Probar manualmente con el desarrollador (F5 en Godot) y ajustar tiempos de cocción/paciencia/sensación de clics hasta que el bucle envicie antes de ilustrar el arte definitivo.

---

## Fase 2: Motor Roguelite, Familiares y Escalada Incremental
- [ ] **2.1 Gestión de Días 1–8 + Modo Infinito:**
  - [ ] Crear `RunManager.gd` y tabla de oleadas (`WaveScheduleData`) con escalado de frecuencia y complejidad de pedidos.
  - [ ] Implementar Jefes de Turno (Día 3 *Seraphina VIP*, Día 6 *Hora Pico del Sabbat*, Día 8 *Archidemonio*).
- [ ] **2.2 Sistema de Familiares Autónomos:**
  - [ ] Implementar los 4 familiares iniciales (`Michi Alado`, `Diablillo Carmesí`, `Murciélago Sombrío`, `Mandrágora Cantora`) con IA de estado simple y animaciones flotantes.
- [ ] **2.3 Catálogo Completo de 12 Reliquias y Sinergias:**
  - [ ] Crear los 12 archivos `.tres` en `res://data/upgrades/` y conectar los hooks de evento (`espejo_duplicador`, `corazon_fenix`, `mortero_sismico`, etc.).
  - [ ] Implementar tienda intermedia entre días (Reroll de cartas y Reparación de corazones).

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
