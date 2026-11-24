# GDD — *Trixie: Roguelite de Tienda de Pociones*

> **Versión:** 1.0 (Diseño Base Completo)  
> **Motor:** Godot 4.7 (`1920x1080`, `canvas_items`)  
> **Referencia Visual Aprobada:** [stash/imagen3.jpeg](stash/imagen3.jpeg)

---

## 1. Visión de Alto Nivel y Pilares

### 1.1 Concepto Central
*Trixie* es un **roguelite incremental de gestión alquímica en 2.5D vista superior inclinada**, que fusiona la adrenalina táctil de encadenar órdenes por clic de **Cake Mania / Diner Dash**, la escalada de automatización rota de **PlateUp! / Vampire Survivors**, y el gancho estético atrevido, cómico y carismático de **Helltaker**.

Partidas intensas de **10 a 15 minutos** donde empiezas preparando cada poción a mano en una cocina humilde y terminas comandando un aquelarre automatizado con familiares volando, calderos en reacción en cadena, multiplicadores de propinas absurdos y clientas encantadas soltando líneas picantes.

### 1.2 Los 4 Pilares Innegociables
1. **Control Cero Fricción (Cola de Clics):** Todo el movimiento y trabajo ocurre mediante clic izquierdo encadenado (hasta 6 acciones en cola) + clic derecho para habilidad especial. Esto libera la vista del jugador para mirar lo que vende el juego: las reacciones de los retratos y los diálogos.
2. **Contraste Viral (De Artesanal a Máquina Rota):**
   * *Minutos 1–3:* Puro *Cake Mania* táctil y sudor frío.
   * *Minutos 4–8:* Aparecen los primeros Familiares y Reliquias que cubren estaciones.
   * *Minutos 9–15:* Sinergias rotas donde una entrega dispara burbujas en cadena y limpia la fila entera en explosiones de oro.
3. **Escaparate de Carisma Anime *Stream-Friendly*:** Sprites semi-chibi (~3 cabezas de altura) en cocina para animar rápido con fluidez, combinados con retratos 2D grandes y súper expresivos (busto reactivo de tu bruja + retrato de clienta en grande), en tono *ecchi* elegante y sugerente (apto para Twitch/YouTube/TikTok).
4. **Cero Relleno Narrativo:** Diálogos de 1 o 2 líneas afiladas con chispa sobre pergamino gastado; nunca muros de texto que interrumpan el estado de flujo.

---

## 2. Layout de Pantalla y HUD (Basado en `imagen3.jpeg`)

```text
+-----------------------------------------------------------------------+
| [Reloj 02:55] [Oro: 230] | [♥ ♥ ♥ Estabilidad]    [DÍA 3] [Reliquias] |
| +---------------+                                                     |
| | BUSTO BRUJA   |     [Estante Ingredientes]   [Mesa Embotellado]     |
| | (Reactivo)    |                                                     |
| +---------------+   (Calderos x3)    [Familiar]       | Mostrador |   |
|                                                       | y Fila    |   |
|      [Cajas + Mortero]      <-- Cocina 2.5D -->       | Clientas  |   |
|                                                       | (Bubbles) |   |
|                                               +-------------------+   |
|  (ESPACIO LIBRE DE BOTONES Q/W/E)             | RETRATO 2D GRANDE |   |
|                                               |   DE LA CLIENTA   |   |
|                             [Pergamino Chipped: "¡Algo fuerte...!"]   |
+-----------------------------------------------------------------------+
```

### Reglas Estrictas de HUD
* **Arriba a la Izquierda:** Reloj del turno actual, Oro acumulado en la *run*, **Corazones de Estabilidad del Caldero** (3 base) y el **Busto Enmarcado Reactivo** de la bruja elegida. El marco cambia de color/vibración según peligro y el retrato reacciona en tiempo real a 6 estados (`normal`, `confiada`, `nerviosa_sudando`, `sonrojada_picante`, `hollin_derrota`, `cutin_habilidad`).
* **Centro (80%+ de la pantalla):** Cocina 2.5D transitable sin mesas de comedor. Todas las estaciones tienen siluetas claras e iconos flotantes de progreso.
* **Arriba a la Derecha:** Indicador de Día / Oleada, barra de progreso del turno o medidor de combos, y mini-iconos de las Reliquias/Familiares activos.
* **Abajo a la Derecha (Zona Sacrosanta de Personajes):** **SIN botones de atajo Q/W/E**. Espacio limpio reservado exclusivamente para el **Retrato 2D Anime grande de la clienta actual** (al llegar, al ser atendida o al activarse diálogo de afinidad), con la **franja de diálogo de pergamino viejo con bordes gastados/rotos (*chipped*)** justo debajo.

---

## 3. Bucle Jugable y Mecánica Exacta de Pociones

### 3.1 Controles
| Input | Acción | Detalle de UX |
| :--- | :--- | :--- |
| **Clic Izquierdo en Estación / Clienta** | Mover / Pre-encolar siguiente clic | Solo acepta estaciones interactivas o clientas (nunca suelo vacío). Mientras la bruja va hacia un destino (`1`), puedes hacer clic en el **siguiente punto** (`2`) para encadenarlo al instante sin acumular colas largas ni confusas. |
| **Clic Derecho (o Barra Espaciadora)** | **Habilidad Especial (*Cut-in*)** | Detona la activa única de la bruja en cualquier momento sin interrumpir su posicionamiento, disparando un banner *cut-in* anime de 0.6s con *hitstop*. |
| **Clic Central / `Q` / `Esc`** | Cancelar siguiente clic / Pausa | `Clic central` o `Q` cancela la acción actual y el clic en espera. |

### 3.2 Flujo de Creación de una Poción (4 Estaciones)
Para que el juego sea táctil al principio sin volverse tedioso en el *late-game*, el flujo sigue una cadena de **4 estaciones físicas**:

1. **Estación de Ingredientes (y Mortero):**
   * Tres ingredientes base codificados por color y forma (daltonismo-friendly):
     * **Rojo — Hierba Ignis** (Hojas carmesí vibrantes)
     * **Azul — Cristal Cryo** (Gemas prismáticas azules)
     * **Verde — Savia Silvestre** (Brotes esmeralda luminosos)
   * *Inventario en mano:* La bruja tiene **2 manos/ranuras de carga base** (ampliable con reliquias). Puede llevar ingredientes o pociones terminadas mezclando libremente, o soltar ingredientes directo en un caldero.
   * *Mortero (Recetas de 2 Colores — Obligatorio):* Las pociones simples (`Rojo`, `Azul`, `Verde`) van directo al caldero. Las pociones combinadas (**Amarillo** = `Rojo + Verde`, **Morado** = `Rojo + Azul`, **Turquesa** = `Azul + Verde`) **requieren** llevar los 2 colores al **Mortero** (juntos en mano o de 1 en 1), donde se fusionan en un único círculo del color combinado listo para echarlo al caldero.
2. **Los Calderos Alquímicos (2 iniciales, hasta 3–4 mediante mejoras):**
   * Al hacer clic en un caldero llevando ingredientes, los deposita dentro. Cuando coinciden con una receta válida (1 a 3 ingredientes), **el caldero comienza a hervir automáticamente** (`3.5s` base).
   * **Mecánica de Riesgo y "¡CALIENTE!":**
     * **Revolver (Opcional / Pro-Skill):** Si el jugador hace clic de nuevo en un caldero hirviendo (o mantiene presionado 0.6s), la bruja remueve con el cucharón acelerando la cocción un **+60%** y activando el estado **`¡CALIENTE!`** (`x1.5` propina si se entrega antes de enfriarse).
     * **Peligro de Desbordamiento (*Overboil*):** Una vez lista la poción, el caldero entra en ventana de gracia (`4.0s` base, visible como anillo ámbar -> rojo parpadeante). Si nadie la recoge a tiempo, **¡EXPLOTA!**
     * **Consecuencia de Explosión:** Se pierde la mezcla, el caldero queda aturdido `2.5s`, pierdes **1 Corazón de Estabilidad**, y el busto de la bruja cambia instantáneamente a `hollin_derrota` durante `2.0s` con nubes de humo cómicas.
   * **Errores de Mezcla:** Si echas un ingrediente incompatible con una receta posible, el caldero chisporrotea humo morado y devuelve el ingrediente al vacío (en modo normal no quita corazón, solo tiempo, para no castigar clics frenéticos por error; en *Pactos Malditos* sí puede dañar).
3. **Mesa de Embotellado y Vitrina (Expositor de 2 Huecos):**
   * Recoger del caldero entrega un *Frasco Caliente Sin Sellar* que requiere sellar en la Mesa de Embotellado (`0.42s`).
   * **Vitrina (2 espacios clicables individualmente):** Permite guardar hasta **2 pociones embotelladas** eligiendo exactamente en qué hueco poner o cuál de las 2 recoger. Al llegar una clienta, ojea la vitrina un instante (`0.85s` con globito `. . .`) antes de mostrar su pedido: si ve una poción disponible en vitrina la pide de entrada con un diálogo especial; **una vez revelado su globito de pedido, jamás lo cambia**.
4. **Mostrador de Entrega y Fila de Clientas:**
   * Espacio máximo en fila: **5 clientas visibles** esperando ante el mostrador (el punto 6 provoca colapso).
   * Al hacer clic sobre una clienta llevando su poción pedida, la bruja entrega el frasco, salta el combo (`+1`), suenan monedas, aparece la clienta en grande abajo a la derecha con una línea reactiva en el pergamino, y la barra de paciencia de las demás recibe un micro-respiro (`+0.5s`) si la entrega tuvo bono `¡CALIENTE!`.

### 3.3 Fórmulas de Combo y Puntuación
* **Multiplicador de Combo:** Cada entrega exitosa dentro de una ventana de `7.0s` desde la anterior suma `+1` al combo (`x1.0` base, `+0.1x` por cada stack hasta `x3.0x` base, o ilimitado con reliquias).
* **Valor de Venta:**
  $$\text{Oro} = \text{ValorBaseReceta} \times \text{BonoCaliente} \times \text{MultCombo} \times \text{GenerosidadClienta}$$

---

## 4. Sistema Roguelite e Incremental Completo

### 4.1 Estructura de la Partida (*Run* de 12–15 Minutos)
Una partida completa estándar dura **8 Días (Oleadas)** de **75 a 90 segundos** cada uno (~12 min efectivos contando selecciones), más un modo **Hora Extra Infinita (Endless Sabbat)** opcional tras vencer al Día 8 para romper récords virales.

| Día | Duración | Tasa de Llegada | Complejidad de Recetas | Evento / Hito |
| :---: | :---: | :--- | :--- | :--- |
| **Día 1** | 65s | Lenta (cada 9s) | 1 ingrediente (Rojo/Azul/Verde) | Tutorial orgánico; al cerrar -> Draft 1 |
| **Día 2** | 75s | Media (cada 7.5s) | 2 ingredientes (Púrpura, Turquesa, Ámbar) | Primeras propinas por combo |
| **Día 3** | 80s | Media-Alta (cada 6.5s) | Introduce **Mortero** | **JEFE DE TURNO 1:** *Seraphina la Inquisidora* (pide 2 pociones seguidas, menos paciencia, oro x3) |
| **Día 4** | 80s | Alta (cada 5.5s) | 2–3 ingredientes | Desbloquea ranura de Reliquia Rara / Familiar |
| **Día 5** | 85s | Alta (cada 4.8s) | Múltiples pedidos simultáneos | Posible Maldición de Turno (+velocidad, calderos calientan x1.5) |
| **Día 6** | 90s | Frenética (cada 4.0s) | Recetas de 3 ingredientes + Mortero | **EVENTO:** *Hora Pico del Sabbat* (llegan clientas en parejas) |
| **Día 7** | 90s | Caos Controlado (cada 3.3s) | Todo el recetario activo | Se ponen a prueba las sinergias de automatización |
| **Día 8** | 95s | Clímax (cada 2.8s) | Pedidos dobles y VIPs | **JEFE FINAL DEL TURNO:** *Visita de la Archidemonio / Ronda Dorada* |

### 4.2 Condiciones de Derrota (Tensión Real)
1. **Colapso de Fila (Saturación):** Si hay 5 clientas esperando en la barra y entra una 6ª sin hueco tras `3.0s` de alerta roja (`¡COLA LLENA!`), la tienda se desborda y termina la *run*.
2. **Catástrofe del Caldero (0/3 Corazones):** Cada explosión de caldero o cada clienta que se marcha furiosa con `0%` de paciencia resta **1 Corazón de Estabilidad**. Al llegar a 0, explota la cocina y aparece la **Ilustración Especial de Derrota (`hollin_derrota`)** con la bruja cubierta de hollín y ropa desarreglada, entregando la Esencia Arcana ganada para meta-progresión.

### 4.3 Catálogo Inicial de Familiares (Automatización Viva)
Los familiares ocupan espacio físico en la cocina y hacen visible el paso de manual a automático:
1. **Michi Alado (Familiar de Caldero):** Se posa junto a un caldero. Remueve automáticamente cuando empieza a hervir (`+40%` velocidad) y **detiene el contador de explosión** manteniéndolo listo sin quemarse.
2. **Diablillo Carmesí (Familiar Recolector):** Coge ingredientes de las cajas y rellena cualquier caldero vacío que tenga una receta coincidente con la primera clienta de la fila.
3. **Murciélago Sombrío (Familiar Mensajero):** Toma frascos recién salidos del caldero, los sella automáticamente al vuelo en la mesa de embotellado y los entrega a la clienta correspondiente si la bruja está ocupada.
4. **Mandrágora Cantora (Familiar de Mostrador):** Baila junto a la caja registradora emitiendo esporas musicales que ralentizan la caída de paciencia de toda la fila un **35%** y añaden `+15%` de propina base.

### 4.4 Catálogo Inicial de Reliquias (12 iniciales) y Sinergias Rotas
Al cerrar cada día, el jugador elige **1 de 3 cartas** (con botón de *Reroll* gastando oro de la run):

| Reliquia | Rareza | Tag Sinergia | Efecto Concreto |
| :--- | :---: | :--- | :--- |
| **Botas de Tacón Arcano** | Común | `Velocidad` | `+35%` velocidad de movimiento y estela de chispas doradas. |
| **Bandeja de Tres Copas** | Común | `Carga` | `+1` ranura de carga en manos (permite llevar 3 ítems). |
| **Cucharón Turbo** | Común | `Caldero` | Cocción base `+30%` más rápida en todos los calderos. |
| **Corsé Magnético** | Rara | `Velocidad` | Al pasar a menos de 120px de la Mesa de Embotellado, sella el frasco automáticamente sin detenerte. |
| **Caldero Gemelo** | Rara | `Caldero` | Desbloquea un 3er Caldero (o clona 1 poción cada 4 entregas). |
| **Perfume de Feromonas** | Rara | `Encanto` | Las clientas empiezan con `+25%` de paciencia y sueltan `+1` punto extra de afinidad. |
| **Mortero Sísmico** | Rara | `Alquimia` | Machacar un ingrediente en el mortero emite una onda que avanza `25%` todos los calderos activos. |
| **Pacto de Hielo Seco** | Maldita | `Riesgo` | Los calderos hierven `2x` más rápido, pero el tiempo antes de explotar se reduce a la mitad (`2.0s`). |
| **Espejo Duplicador** | Épica | `Cadena` | Cada entrega con bono `¡CALIENTE!` genera un clon flotante que atiende gratis a la siguiente clienta en fila. |
| **Propina Exponencial** | Épica | `Encanto` | Elimina el tope `x3.0` de combo; cada 5 de combo aumenta el tamaño de las partículas de oro. |
| **Látigo de Capataz** | Épica | `Familiares` | Los familiares trabajan un `65%` más rápido durante 6s cada vez que usas tu Habilidad Especial (clic derecho). |
| **Corazón de Fénix** | Épica | `Riesgo` | Cuando un caldero explota, en lugar de perder un corazón, cocina instantáneamente todas las pociones en curso y rellena la paciencia de la fila. |

#### Sinergias Rotas (*Game-Breakers* para Clips Virales)
1. **Cadena de Montaje Arcana** (*Corsé Magnético + Mortero Sísmico + Espejo Duplicador*): No te detienes al embotellar; cada machacado acelera todos los calderos y cada entrega caliente clona otra poción en cadena.
2. **Ejército de Sabbat** (*Michi Alado + Diablillo Carmesí + Murciélago Sombrío + Látigo de Capataz*): La tienda funciona sola como una fábrica frenética mientras tú solo activas habilidades y cobras montañas de oro.
3. **Bomba de Fenix** (*Pacto de Hielo Seco + Corazón de Fénix*): Dejas explotar un caldero a propósito en hora pico para detonar una limpieza masiva de pantalla con lluvia de oro y efecto visual dramático.
4. **Harem Encantado** (*Perfume de Feromonas + Propina Exponencial + Mandrágora Cantora*): Multiplicadores de `x10+`, corazones rosados por toda la pantalla y clientas soltando diálogos picantes seguidos.

---

## 5. Elenco Inicial: Brujas Jugables y Clientas

### 5.1 Protagonistas Jugables (4 Arquetipos)

| Personaje | Arquetipo | Stats Base | Pasiva Única | Habilidad Activa (Clic Derecho + *Cut-in*) | Desbloqueo y Atuendos |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Trixie** | Bruja Clásica de Fuego y Caos | Vel: `1.0x`<br>Cocción: `1.0x`<br>Carga: `2`<br>Vidas: `3 ♥` | **Chispa Ardiente:** Las pociones que entrega siempre mantienen el bono `¡CALIENTE!` durante 4s extra. | **Fiebre Escarlata** (*CD: 16s*): Todos los calderos activos terminan su cocción al instante y el movimiento gana `+60%` durante 5s. | **Inicial.** Atuendos: *Clásico Corsé Púrpura*, *Delantal Casero Hollín*, *Gala del Sabbat*. |
| **Lyra** | Druida de la Floración Salvaje | Vel: `0.95x`<br>Cocción: `1.1x`<br>Carga: `3`<br>Vidas: `3 ♥` | **Cosecha Abundante:** Cada vez que recoge Savia Silvestre o Hierba Ignis, tiene `35%` de duplicar el ingrediente en mano. | **Enredaderas Calmantes** (*CD: 20s*): Congela la barra de paciencia de toda la fila durante 8s mientras florecen rosas alrededor del mostrador. | **150 Esencias.** Atuendos: *Túnica Hoja*, *Ninfa Primaveral*. |
| **Nyxara** | Chamán Espiritual y Domadora | Vel: `0.9x`<br>Cocción: `0.9x`<br>Carga: `2`<br>Vidas: `4 ♥` | **Vínculo Totémico:** Empieza la partida desde el Día 1 con **1 Familiar aleatorio** invocado y sus familiares actúan `+20%` más rápido. | **Posesión del Sabbat** (*CD: 22s*): Invoca 2 espíritus temporales durante 7s que replican tu última entrega y embotellan todo en mesa. | **300 Esencias.** Atuendos: *Plumas Nocturnas*, *Chamán de Luna Roja*. |
| **Morrigan** | Alquimista Oscura (Alto Riesgo) | Vel: `1.2x`<br>Cocción: `1.35x`<br>Carga: `2`<br>Vidas: `2 ♥` | **Sangre Volátil:** Gana `+40%` oro y velocidad, pero empieza con solo `2 ♥` de Estabilidad y los calderos sobrecalientan un `25%` antes. | **Transmutación Carmesí** (*CD: 18s*): Sacrifica el contenido de 1 caldero para convertir al instante el pedido de las 3 primeras clientas en Oro Doble. | **500 Esencias.** Atuendos: *Corsé Gótico Carmesí*, *Dama de Laboratorio*. |

### 5.2 Elenco Inicial de Clientas y Sistema de Afinidad (Diálogos Picantes)
Cada clienta tiene un medidor persistente de **Afinidad (Niveles 1 a 3)** que sube al atenderla rápido o con bono `¡CALIENTE!`. Al subir de nivel o atender con alta racha, su retrato cambia a **`sonrojada_picante`** en la esquina inferior derecha y muestra frases atrevidas y divertidas en el pergamino *chipped*.

1. **Sylvi — La Fauno Fiestera** *(Referencia directa de `imagen3.jpeg`)*
   * *Personalidad:* Descarada, alegre, coqueta sin filtros, busca pociones energéticas y afrodisíacas para sus noches en el bosque.
   * *Paciencia:* Media (`28s`) | *Propinas:* `x1.2` | *Favorita:* Elixir Carmesí (`Rojo + Rojo`) / Filtro Estelar (`Rojo + Azul`).
   * *Frases en Pergamino:*
     * Llegada: *"¡Necesito algo bien fuerte para esta noche!"*
     * Afinidad Nv. 2 (`sonrojada`): *"¿Siempre sudas así detrás del mostrador, brujita, o es por verme?"*
     * Afinidad Nv. 3 (`sonrojada`): *"Si este brebaje funciona la mitad de bien que tu sonrisa, mañana vuelvo por el doble... y sin ropa tan pesada."*

2. **Velvet — La Súcubo Ejecutiva** *(Inspiración directa en el tono Helltaker)*
   * *Personalidad:* Elegante, dominante, impaciente pero generosísima si le das servicio VIP impecable.
   * *Paciencia:* Baja (`22s`) | *Propinas:* `x1.6` | *Favorita:* Concentrado Morado (`Mortero Azul + Rojo`).
   * *Frases en Pergamino:*
     * Llegada: *"Tengo una cita importante en diez minutos. Sorpréndeme, linda."*
     * Afinidad Nv. 2 (`sonrojada`): *"Me encanta verte correr por toda la cocina solo para complacerme."*
     * Afinidad Nv. 3 (`sonrojada`): *"Te perdono el retraso... si me dejas probar la próxima poción directo de tu cucharón."*

3. **Seraphina — La Paladín "Reprimida"** *(También actúa como Jefe VIP Día 3)*
   * *Personalidad:* Orgullosa, intenta aparentar moral estricta pero siempre compra pociones sospechosas "para investigar el mal" y se sonroja facilísimo.
   * *Paciencia:* Media-Baja (`24s`) | *Propinas:* `x1.4` | *Favorita:* Esencia Pura Verde (`Verde + Verde`).
   * *Frases en Pergamino:*
     * Llegada: *"E-es para un ritual de purificación... ¡no pienses cosas raras!"*
     * Afinidad Nv. 2 (`sonrojada`): *"¿Por qué esta poción huele a fresas y calor?! ¡Cielos, qué bochorno!"*
     * Afinidad Nv. 3 (`sonrojada`): *"N-no le digas a la Orden que vengo aquí a escondidas... ni cuánto me gusta mirarte."*

4. **Mona — La Bruja Rival Tsundere**
   * *Personalidad:* Competidora del barrio que viene a espiar tus recetas y finge que tus pociones no son gran cosa mientras repite cada noche.
   * *Paciencia:* Alta (`32s`) | *Propinas:* `x1.1` | *Favorita:* Tríada Arcana (`Rojo + Azul + Verde`).
   * *Frases en Pergamino:*
     * Llegada: *"Solo vine a comprobar lo lenta que eres. Hazme un filtro decente."*
     * Afinidad Nv. 2 (`sonrojada`): *"¡Hmph! No está nada mal... ¡pero no creas que me impresionaste, tonta!"*
     * Afinidad Nv. 3 (`sonrojada`): *"Oye... si algún día quieres cerrar temprano y comparar varitas, avísame. ¡S-solo por negocio!"*

5. **Roxy — La Cazadora Lupina**
   * *Personalidad:* Salvaje, enérgica, impulsiva, le encanta el riesgo y las pociones explosivas.
   * *Paciencia:* Alta (`30s`) | *Propinas:* `x1.25` | *Favorita:* Tónico Ignis Machacado (`Mortero Rojo + Verde`).
   * *Frases en Pergamino:*
     * Llegada: *"¡Dame algo que me haga rugir antes de que salga la luna!"*
     * Afinidad Nv. 2 (`sonrojada`): *"¡Guau! ¡Agitas ese caldero con una energía que me vuelve loca!"*
     * Afinidad Nv. 3 (`sonrojada`): *"Tienes mejor olor que cualquier presa del bosque... ¿me guardas un frasco especial?"*

---

## 6. Economía In-Run y Meta-Progresión

### 6.1 Oro In-Run (Temporal por Partida)
* Se gana entregando pociones, encadenando combos y sirviendo VIPs.
* Se gasta **durante la pausa entre días** en:
  * **Reroll de mejoras:** `35g` (escala `+20g` por uso en el mismo día).
  * **Reparar 1 Corazón de Estabilidad:** `120g` (disponible en tienda intermedia los días pares).
  * **Comprar un 2º/3º Caldero o Mejora de Estación directa** si aparece como oferta especial.

### 6.2 Esencias Arcanas (Moneda Persistente — Meta-Progresión)
Al ganar o perder una partida, el Oro acumulado y los Días sobrevividos se convierten en **Esencias Arcanas** que se gastan en la pantalla del **Aquelarre**:
1. **Reclutar Brujas Nuevas:** Lyra (`150`), Nyxara (`300`), Morrigan (`500`).
2. **Mejoras Permanentes Suaves (Meta-Árbol):**
   * *Estabilidad Reforzada:* `+1` Corazón inicial (Nv. max 1, caro).
   * *Suela Encantada:* `+5%` velocidad base por nivel (hasta `+15%`).
   * *Encanto de Mostrador:* `+8%` paciencia base de clientas por nivel.
   * *Suerte del Sabbat:* `+1` Reroll gratis al inicio de cada run.
3. **El Vestidor (Atuendos Desbloqueables):** Skins alternativas para cada bruja comprables con Esencias o desbloqueables al completar retos (*ej. "Gana el Día 8 sin perder ningún corazón"*). Cambian tanto el sprite semi-chibi como el busto reactivo y los *cut-ins*.
4. **La Galería:** Colección de ilustraciones a pantalla completa (Concept Art, Retratos *Helltaker-style* desbloqueados al subir afinidad con clientas, y las ilustraciones cómicas/picantes de derrota con hollín).

---

## 7. Dirección de Game Juice, Trucos Visuales y Audio

Para que el juego se sienta adictivo desde el segundo 1 y brille en clips cortos sin exigir miles de frames animados al artista:

1. **Animación Procedural sobre Sprites Cortos:**
   * Los sprites semi-chibi solo requieren **2–4 poses clave**. Godot aplica:
     * **Rebote rítmico tipo *Helltaker*** al caminar (compresión vertical `scale.y = 0.88` -> `1.08` sincronizada con los pasos).
     * **Inclinación lateral (`skew` / rotación ligera)** al girar hacia una estación.
     * **Polvo mágico en los pies** y anillo de destello en el suelo donde el jugador hace clic.
2. **Escalado Musical por Clic y Combo (Clave de Dopamina):**
   * Cada clic encadenado en la cola de acciones (`1`, `2`, `3`, `4`, `5`, `6`) reproduce un sonido de campanilla cristalina subiendo una nota en una escala pentatónica mayor.
   * Cada entrega consecutiva sube sutilmente el *pitch* del tintineo de monedas y añade capas rítmicas de percusión a la música de fondo (BGM adaptativa estilo *Vitality* / electro-swing brujeril).
3. **Impacto Visual y *Hitstop*:**
   * **Entrega Perfecta / `¡CALIENTE!`:** Micro *hitstop* de `0.04s`, pop-up flotante con rebote (`+120g ¡CALIENTE!`), explosión de corazones/estrellas y destello en el retrato de la clienta.
   * **Habilidad Especial (Clic Derecho):** Oscurecimiento de fondo `0.45s`, barra diagonal anime atravesando la pantalla con el arte `cutin_habilidad`, texto estilizado y onda expansiva de partículas.
   * **Explosión de Caldero:** *Screen shake* direccional, nube densa de humo caricaturesco, flash en los corazones del HUD y cambio brusco del busto de la bruja a `hollin_derrota` temblando.

---

## 8. Arquitectura Técnica en Godot 4.7 y Pipeline de Assets

### 8.1 Árbol de Carpetas
```text
res://
├── assets/
│   ├── audio/ (bgm/, sfx/)
│   ├── characters/ (playable/, customers/, familiars/)
│   ├── props/ (stations/, items/)
│   ├── ui/ (hud/, buttons/, menus/)
│   └── vfx/
├── data/ (characters/, customers/, dialogues/, familiars/, recipes/, upgrades/)
├── docs/ (prompts_catalog.md)
├── raw_assets/ (carpeta staging para imágenes crudas con fondo #FFFFFF; ignorada por Git salvo .gitkeep)
├── scenes/ (main/, entities/, stations/, ui/, meta/)
├── scripts/ (autoloads/, core/, resources/)
└── tools/ (process_white_bg.py, generate_prompts.py)
```

### 8.2 Nodos Clave de Gameplay
* `Main.tscn`: Contenedor raíz (`KitchenWorld` + `HudCanvasLayer` + `CutInOverlay` + `DraftModal`).
* `ActionQueueController` (`scripts/core/`): Mantiene la cola de acciones (`Array[ActionTask]`), dibuja los waypoints y mueve al `WitchController` usando `NavigationAgent2D` o evasión limpia de obstáculos.
* `StationBase` -> `IngredientBin`, `MortarStation`, `CauldronStation`, `BottlingStation`, `ServiceCounter`: Estaciones interactivas por área de clic y señales tipadas hacia `EventBus`.
* `ReactiveBustHUD` + `CustomerDialoguePanel`: Escuchan `EventBus.witch_emotion_changed` y `EventBus.customer_dialogue_requested` para hacer *tween* de entrada estilo novela visual sobre el pergamino *chipped*.

### 8.3 Pipeline Automatizado de Arte (`#FFFFFF` -> PNG Transparente)
1. El desarrollador genera las imágenes usando las plantillas de [docs/prompts_catalog.md](docs/prompts_catalog.md) sobre **fondo blanco puro (`#FFFFFF`)**.
2. Las guarda en `raw_assets/` y Antigravity ejecuta:
   `python tools/process_white_bg.py raw_assets/<carpeta> --category <playable|customers|...> --id <nombre> --trim`
3. El script ejecuta *flood-fill* 4-conectado desde el perímetro + descontaminación de bordes (*defringe*) para eliminar halos blancos **sin tocar ningún píxel blanco interno** (ojos, dientes, brillos o delantales), exportando directamente a `res://assets/`.
