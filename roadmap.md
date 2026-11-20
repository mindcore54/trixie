# roadmap.md — Memoria Viva del Proyecto (*Trixie*)

> **ESTADO DEL DOCUMENTO:** Este archivo es la **memoria viva y el punto de contacto directo** entre **Antigravity** y el **Desarrollador**.  
> **Regla Operativa:** Antigravity tiene total libertad y obligación de actualizar este archivo tras cada sesión o hito: marcando tareas completadas (`[x]`), registrando decisiones críticas de diseño, reportando bloqueos reales y definiendo qué necesita del desarrollador para la siguiente fase.

---

## Bitácora de Decisiones y Estado Actual
* **2026-11-19 — Inicio de Proyecto:**
  * Leído respaldo completo `stash/chat01.txt` y revisadas las 3 maquetas visuales (`stash/imagen1..3.jpeg`).
  * **Layout aprobado (`imagen3.jpeg`):** Cocina 2.5D transitable ocupando la mayor parte de la pantalla; arriba-izquierda estadísticas + busto enmarcado reactivo de la bruja; abajo-derecha limpio (sin botones Q/W/E) para retrato grande 2D anime de clientas + pergamino viejo con bordes *chipped*.
  * **Control principal fijado:** Movimiento por clic izquierdo con **cola de acciones** + clic derecho para **Habilidad Especial con *cut-in***.
  * **Entorno verificado:** Godot `4.7.2.stable` conectado por MCP, 22 skills de Godot 4.x + `trixie-art-pipeline` instaladas en `.agents/skills/`, y script `tools/process_white_bg.py` validado contra perforación de blancos internos.
  * **Siguiente Foco Inmediato:** Construir el **Vertical Slice Jugable (Fase 1)** con placeholders geométricos/colores en Godot 4.7 para validar que encadenar clics, controlar calderos al borde de explotar y ver las reacciones del HUD realmente envicia antes de producir arte masivo.

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

- [ ] **1.1 Escenario de Cocina 2.5D y Navegación:**
  - [ ] Construir `KitchenArena.tscn` con distribución calcada a `imagen3.jpeg` (Estación de Ingredientes + Mortero abajo-izquierda, 2 Calderos centro-izquierda, Mesa Embotellado arriba-derecha, Mostrador + 5 slots de fila a la derecha).
  - [ ] Configurar `NavigationRegion2D` o rejilla de evasión limpia alrededor de muebles.
- [ ] **1.2 Bruja Controlable por Cola de Clics:**
  - [ ] Implementar `ActionQueueController.gd` (hasta 6 clics encadenados, dibujo de waypoints numerados `1..6` en el suelo, clic central/`Q` para limpiar cola).
  - [ ] Implementar `WitchController.gd` con 2 ranuras visuales de mano y rebote procedural al caminar (estilo *Helltaker* por código).
- [ ] **1.3 Ciclo Completo de Poción y Calderos:**
  - [ ] Crear 3 recursos de recetas iniciales (Rojo, Azul, Rojo+Azul) en `res://data/recipes/`.
  - [ ] Implementar `IngredientBin.gd`, `MortarStation.gd` (machacado rápido), `CauldronStation.gd` (cocción, clic para revolver `¡CALIENTE!`, ventana de *overboil* y explosión con pérdida de corazón) y `BottlingStation.gd`.
- [ ] **1.4 Fila de Clientas, HUD Reactivo y Pergamino:**
  - [ ] Implementar `CustomerQueueManager.gd` (barras de paciencia, colapso al 6º cliente, pago con multiplicador de combo).
  - [ ] Implementar `ReactiveBustHUD.tscn` arriba-izquierda (reloj, oro, corazones y marco del busto que cambia de color/estado al sudar o explotar).
  - [ ] Implementar `CustomerDialoguePanel.tscn` abajo-derecha (retrato temporal + pergamino *chipped* con frase corta al entregar).
- [ ] **1.5 Primer Draft Roguelite y Habilidad de Trixie:**
  - [ ] Implementar clic derecho (`Fiebre Escarlata`: termina calderos + `+60%` velocidad) con banner *cut-in* provisional.
  - [ ] Implementar modal al acabar el Día 1 eligiendo 1 de 3 mejoras: *Michi Alado (Familiar Caldero)*, *Botas Arcanas (+35% vel)* o *Corsé Magnético (Embotellado automático)*.
- [ ] **1.6 Validación de Playtest (Hito Crítico):**
  - [ ] Probar manualmente con el desarrollador y ajustar tiempos de cocción/paciencia hasta que el bucle de clics se sienta adictivo.

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
