# Hoja de Ruta — Recreación de Astroneer

Este documento describe **dónde estamos** (estado del intento actual: `escenas/test_2.tscn`),
**hacia dónde vamos** (qué significa "recrear Astroneer" en este proyecto) y **qué falta**
(fases de trabajo con tareas concretas). Es el documento vivo de referencia: se actualiza
al completar cada fase.

---

## 1. Visión: qué es "el juego terminado"

Astroneer, reducido a su bucle central:

> **Explorar → deformar terreno → minar recursos → gestionar oxígeno y energía →
> refinar y fabricar → construir base → investigar desbloqueos → vehículos →
> viajar a otros planetas → repetir a mayor escala.**

Definición de **vertical slice** (primer hito jugable real):

> Aterrizas en el planeta, cavas terreno con la herramienta, encuentras una veta de
> mineral y la extraes como item, la colocas en un slot de la mochila, fabricas un
> tether con la impresora de la mochila, el oxígeno te obliga a volver, guardas la
> partida y al cargar el planeta conserva tus ediciones.

Definición de **juego completo (single player)**: el bucle anterior + base con módulos
(fundición, investigación), energía solar/día-noche, un rover, 2–3 planetas distintos
y viaje entre ellos, muerte/respawn, menús y guardado completo.

**Fuera de alcance por ahora**: multiplayer cooperativo, tormentas, hazards de bioma,
customización de personaje, núcleos/gateways de planeta. (Ver §6, decisiones.)

---

## 2. Dónde estamos (2026-09-09, Fases 0 a 5 implementadas ~70%, pendientes de pulido)

### 2.1 Lo que YA funciona en `test_2` (el intento Astroneer)

| Sistema | Estado | Dónde |
|---|---|---|
| Planeta voxel procedural deformable + SQLite persistence | ✅ MVP (70%) | `scripts/planeta/planeta_cuerpo.gd` (VoxelLodTerrain + SQLite) |
| Gravedad esférica + alineación cuaterniónica de jugador | ✅ Funciona | `scripts/jugador/player.gd` |
| Movimiento WASD + salto + cámara 3ª persona (ratón libre) | ✅ Funciona | `player.gd` + `escenas/planeta/player.tscn` |
| Herramienta de terreno diegética (3 modos: Excavar/Rellenar/Aplanar + Canister volumétrico + retícula 3D) | ✅ Completo (100%) | `terrain_tool.gd` + `voxel_manager.gd` + `player.gd` |
| Proporcionalidad física y conservación de sedimento (V ∝ r³, Aplanar continuo con recolección y adaptativo) | ✅ Completo (100%) | `voxel_manager.gd` + `terrain_tool.gd` |
| Vetas de mineral y depósitos 3D con cristales deterministas | ✅ MVP (70%) | `ore_field.gd` + `ore_deposit_placer.gd` |
| Mochila diegética Astroneer (8 slots + barras O2/Power + Micro-Impresora 3D + cámara frontal [TAB]) | ✅ Completo (100%) | `slot.gd` + `mochila_impresora.gd` + `player.gd` |
| Catálogo holográfico 3D retráctil (marco superior interactivo [CATALOGO], persiana animada, 8 recetas) | ✅ Completo (100%) | `catalogo_holo.gd` + `catalogo_holo.tscn` + `player.gd` |
| Supervivencia: Oxígeno y energía con señales desacopladas | ✅ Funciona | `scripts/jugador/player_stats.gd` + `hud.gd` |
| Red de oxígeno encadenada (tethers con luz, cable visual 3D continuo y filamento vital a la mochila) | ✅ MVP (100%) | `oxygen_network.gd` + `tether.gd` + `player.gd` + `capsula.tscn` |
| Ciclo día/noche con sol rotatorio y recarga solar | ✅ Funciona | `scripts/sistema/day_night.gd` |
| Módulos de base actuales: Fundición (mena→lingote) y Cámara (bytes) [Próximo: Expansión de mesas] | 🔄 En expansión | `fundicion.gd` + `camara_investigacion.gd` + `modulo_base.gd` |
| Red de energía de base (batería + paneles solares con tecla P) | ✅ Funciona | `base_core.gd` + `panel_solar.tscn` |
| Cables de energía de base (interconexión amarilla de paneles y módulos con la cápsula/núcleo) | ✅ MVP (100%) | `panel_solar.gd` + `modulo_base.gd` + `base_core.gd` |
| Vehículo terrestre (Rover 4x4, batería, 4 slots de carga, O2) | ✅ MVP (70%) | `scripts/vehiculo/rover.gd` + `rover.tscn` |
| Sistema Solar (3 mundos: Terra, Árido con titanio, Hielo con criolita) | ✅ MVP (70%) | `planeta_cuerpo.tscn` en `test_2.tscn` |
| Lanzadera espacial estilo No Man's Sky (6-DOF, boost, auto-aterrizaje E) | ✅ MVP (70%) | `scripts/vehiculo/shuttle.gd` + `hud_nave.tscn` |
| Mapa estelar y saltos orbitales con tecla M montado | ✅ Funciona | `menu_viaje.tscn` + `menu_viaje.gd` |
| Consola de desarrollo (tecla `) y guardado por 3 slots (Escape) | ✅ Funciona | `consola.tscn` + `guardado.gd` + `game_state.gd` |
| Onboarding inicial y Baliza de Rescate (muerte, recuperación de mochila, veta semilla de cobre) | ✅ MVP (100%) | `death_beacon.gd` + `hud.gd` + `player.gd` + `capsula.gd` |
| Gateways monumentales (superficie con pilar 300m y núcleos colosales de 32m con altar) | ✅ Completo (100%) | `gateway_chamber.tscn` + `gateway_engine.tscn` + `planeta_cuerpo.gd` |
| Red de teletransporte interplanetario holográfico (selección superficie/núcleo entre mundos) | ✅ Completo (100%) | `menu_teleport.gd` + `menu_teleport.tscn` |
| Gravedad esférica consistente y adherencia activa a pendientes (floor snap 0.8m, 65° máx) | ✅ Completo (100%) | `scripts/jugador/player.gd` |
| Tormentas dinámicas de viento + empuje físico con alertas HUD | ✅ Completo (100%) | `sistema_tormentas.gd` + `tormenta_viento.tscn` |
| Modificadores (Augments) de Terrain Tool (ciclo [G]: Estándar, Amplio, Precisión, Impulso) | ✅ Completo (100%) | `terrain_tool.gd` + `terrain_tool.tscn` |
| Flora peligrosa alienígena (drenaje de O2 y desprendimiento de muestras al desenterrar) | ✅ MVP (100%) | `flora_peligrosa.gd` + `flora_peligrosa.tscn` |


### 2.2 Material reciclable ya presente en el proyecto

| Asset/Sistema (hoy fuera del test_2) | Sirve para |
|---|---|
| `addons/gevp` + `scripts/maquinas/vehicle_base.gd` | Base del rover (Fase 4) |
| `scripts/items/ItemData.gd`, monedas, `prosesador.gd`, `vender.gd` | Esqueleto de datos de recursos y economía de crafteo (Fase 1/3) |
| `scripts/sistema/saveload.gd` + `save_file.gd` + `loading_screen` | Guardado/carga (Fase 6; requiere refactor, ver 2.3) |
| `addons/Stylized-Smoke`, `Godot-Water-Ripple`, `godot-shaders-main` | Partículas de excavación, efectos |
| `addons/grappling_hook_3d` | Idea futura de augment de la herramienta de terreno (opcional) |
| `demo_arcade.tscn` (grúas, bulldozer, cargadora) | **Otro juego**. Mantener congelado como sandbox; no es parte del Astroneer |

### 2.3 Deuda técnica y bugs conocidos del test_2

**Resueltos en F0 (2026-08-16):**

- [x] `toggle_inventory_mode()` roto (doble negación) — TAB ahora alterna el modo y el zoom.
- [x] Código muerto tras `return` en `get_object_under_mouse()` — el `exclude` del jugador
      ya se aplica y no hay `print` de debug.
- [x] "Item en mano sigue al ratón" duplicado — unificado en `_process`.
- [x] Slots de la mochila no liberaban — `slot.gd` implementa `remove_item()` y el player
      recupera items clicando el slot.
- [x] Grupos rotos: slots no estaban en `"slots"` y los items small/heavy no estaban en
      `"items"` (no se podían agarrar). Areas hijas de los items desactivadas para raycast
      (se comían los clics destinados al cuerpo/slot).
- [x] Al abrir la mochila se ocultaba la mochila misma (tool_model mal cableado) — corregido.
- [x] Seed aleatoria en `planeta_01.gd` — ahora `@export var world_seed`.

**Aún abiertos (asignados a fases):**

- [x] ~~`VoxelStreamSQLite` sin ruta de BD~~ → **resuelto en F1**: stream configurado en
      `test_2.tscn` (`user://mundo_voxel.db`, `save_generator_output = false` para poder
      iterar el generador sin migrar bloques guardados).
- [ ] `SaveManager` hardcodea rutas de `ArcadeDemo` (`get_node("/root/ArcadeDemo/...")`):
      inusable desde el test_2 sin refactor → **F6**.
- [x] ~~Generación del planeta en test_2 aclarada~~ → **decidido en F1**: el generador es
      el grafo estático `planeta_01.tres` (solo SDF). Las vetas de mineral viven FUERA
      del grafo, en `OreField` (ver hallazgos §2.4). **Post-verificación del autor**:
      la rama de montañas del grafo estaba desconectada (planeta esfera lisa) →
      reconectada `[9→10]`: superficie ahora varía r=244..272. Las "cuevas" (nodo 11)
      siguen desconectadas → decidir en F2+ si se quieren de verdad.

### 2.3.2 Bugs persistentes conocidos (2026-09-20) — Abiertos

- [ ] **🔴 Lanzamiento Orbital (Velocity Inheritance al salir de vehículo o teletransportarse)**
  - **Síntoma**: Al bajar de la lanzadera tras un vuelo interplanetario, al cambiar de planeta
    o al teletransportarse via `MenuTeleport` / `gateway_engine` / `gateway_chamber`, el jugador
    sale disparado a órbita como si fuera un asteroide. Ocurre intermitentemente y puede tener
    un retardo de varios segundos antes de manifestarse.
  - **Causa probable**: La lanzadera es un `CharacterBody3D` con velocidad dinámica alta. Al
    teletransportar, `set_deferred("velocity", Vector3.ZERO)` se aplica en el siguiente frame
    pero el motor de física ya integró la velocidad residual del vehículo ese mismo tick. Los 3
    physics frames de congelamiento no siempre son suficientes cuando hay `await` de por medio.
  - **Archivos implicados**: `player.gd` (`_salir_vehiculo`), `menu_teleport.gd` (`_viajar_a`),
    `gateway_engine.gd` (`_retornar_a_superficie`), `gateway_chamber.gd` (`_teletransportar_a_nucleo`).
  - **Impacto**: Alto — impide probar correctamente el juego tras cambios de planeta.
  - **Pendiente F8**: padding de 6-8 frames de congelamiento, clamp hard de velocidad radial
    post-teleport y `move_and_slide()` inmediato dentro del bloque freezeado.

- [ ] **🟡 Glitch Visual "Todo se vuelve Hielo" (Atmosphere Shader Bleed)**
  - **Síntoma**: Durante unos segundos tras un teletransporte o cambio de planeta, el shader de
    cielo adopta los colores gélidos del planeta Hielo. Se normaliza solo. Inofensivo.
  - **Causa probable**: `day_night.gd` hace lerp de la atmósfera hacia el planeta más cercano a
    la cámara. Al teletransportar, la cámara cruza brevemente por una posición equidistante entre
    Terra y el Hielo y el shader interpola hacia los colores glaciales antes de estabilizarse.
  - **Archivos implicados**: `scripts/sistema/day_night.gd` (`_actualizar_cielo_y_atmosfera`).
  - **Impacto**: Bajo (cosmético, no bloquea gameplay).
  - **Pendiente F8**: snap inmediato de parámetros de cielo al teletransportarse (sin lerp).

### 2.3.1 Bugs encontrados en la verificación del autor (2026-08-21, resueltos)

- **Excavación muerta (2ª causa)**: `voxel_tool.raycast()` del addon no funciona en esta
  versión (devuelve vacío siempre → el clic no hacía nada, silencioso). El patrón
  probado del proyecto es **raycast de FÍSICA** (`PhysicsRayQueryParameters3D`, como el
  arcade con su `RayCast3D`): el collider del terreno ES el propio nodo `VoxelLodTerrain`.
  `voxel_manager._modify_voxel` ahora usa raycast de física. Verificado headless
  end-to-end: SDF en el punto de impacto pasó de −1.39 (sólido) a +3.40 (aire).
  Nota: no hay que "activar" ninguna herramienta — clic izq. excava, clic der. rellena.
- **Excavación muerta (1ª causa) + planeta entero color cobre**: el export `terrain_node`
  del VoxelManager estaba sin cablear en `test_2.tscn` (perdido en una reorganización).
  Sin él: el input de excavar se ignoraba Y la textura de vetas nunca se aplicaba al
  material → el sampler3D del shader quedaba sin asignar (Godot lo muestrea blanco)
  → `ore.r > 0.55` en todas partes → todo cobre. Arreglo: cableado explícito en la
  escena + fallback defensivo en `voxel_manager._ready()` (busca un VoxelLodTerrain
  hermano) + `push_warning` si falta.
- **Terreno tipo espuma**: al reconectar las montañas, el grafo quedó con los ruidos
  intercambiados (el nodo de montañas recibía el ruido de período 0.2 ×40 = espuma
  gigante; el editor re-guardó el `.tres` con esa asignación). Recalibrado:
  montañas = ruido período **280**, 3 octavas, ×40 (picos/valles prolongados);
  rugosidad = período **90** ×3 (ondulación sutil). Verificado: superficie 230-282.
- **Excavaciones accidentales al agarrar items**: ahora la herramienta de terreno se
  ACTIVA/DESACTIVA con **E** o **R** (`is_tool_active` del player, off por defecto) —
  sin ella el clic izquierdo solo agarra. Ver también §5.
- **Vetas invisibles (minado sí funcionaba)**: la textura 32³ (celdas de 32 unidades)
  no podía resolver vetas de longitud de onda ~25 → aliasing, no se veía nada.
  Arreglado: vetas con longitudes de onda **90/100/130** (depósitos grandes estilo
  Astroneer), textura **64³** (16 u/celda, genera en ~80 ms), threshold de minado
  0.70 (un poco más generoso que el visual ≈0.755). Consistencia minado↔visual: 91%.
- **Vetas SIGUEN sin verse en el editor → depósitos 3D** (idea del autor, 2026-08-21):
  el sampler3D del shader no renderiza en el editor real (headless no reproducible;
  se deja el código por si se retoma). Solución definitiva: **depósitos de cristal**
  (`ore_deposit.tscn` + `ore_deposit_placer.gd`) — ~217 grupos de prismas emissive
  clavados en la superficie en las ubicaciones aproximadas de las vetas (sondeo a
  20/55/95 u de profundidad). La superficie se calcula analíticamente muestreando
  los mismos ruidos ZN del generador (`ZN_FastNoiseLite.get_noise_3d()` funciona
  desde GDScript) → determinista. Se rompen al excavar cerca y sueltan su mena.
  *Limitación: los rotos reaparecen tras reiniciar (no persisten) → junto al save de F6.*
- **Depósitos flotando (2ª ronda)**: el grafo del generador **compila los ruidos con
  las seeds por defecto al deserializar el `.tres`**; mutar `noise.seed` en `_ready`
  no cambia el terreno ya compilado (sí al objeto que leen otros scripts) → la
  superficie analítica y la real usaban patrones distintos (dif. media 15.6 u,
  195/229 flotando). Arreglado eliminando la mutación (lección documentada en
  `planeta_01.gd` y §2.4): dif. media 0.7 u, **2/217 flotando**, y los cristales
  se hunden 0.5 u para "brotar" del terreno.

### 2.4 Hallazgos técnicos de zylann.voxel (verificados empíricamente, F1)

Guardar como referencia — condicionan diseño futuro:

1. **La API `VoxelGeneratorGraph.create_node()` NO existe** en la versión del addon del
   proyecto. El grafo solo se construye vía la propiedad `graph_data` (Dictionary con
   `nodes`, `connections` — igual que se serializa en el `.tres`). El `planeta_01.gd`
   original del autor usaba la API vieja: era código muerto.
2. **Nodo Select del grafo**: puertos 0=`a`, 1=`b`, 2=`t`. Semántica: `t < threshold → a`,
   si no `b`. (Verificado con probe + docs oficiales.)
3. **`OutputType` es para el mesher BLOCKY**, no para Transvoxel: el canal TYPE guarda
   datos (se puede leer con `VoxelTool.get_voxel`) pero el mesher smooth **NO lo hornea
   como vertex COLOR** → el shader no puede leer el tipo desde COLOR. Por eso las vetas
   visuales usan Texture3D muestreada por posición, no canales del voxel.
4. **`VoxelTool`**: `channel` es propiedad (no argumento de `get_voxel`); el raycast
   devuelve posición en coords de voxel. Pintar COLOR funciona; el SDF se lee como bits
   float32 reinterpretados a int. **`voxel_tool.raycast()` no funciona** en esta versión
   (siempre vacío) — para apuntar al terreno usar raycast de física; el collider del
   terreno es el propio nodo `VoxelLodTerrain`.
5. **Cache de clases globales**: al añadir un script con `class_name` hay que abrir el
   editor (o correr `godot --headless -e --quit-after N`) para regenerar
   `.godot/global_script_class_cache.cfg` — si no, el juego en runtime no encuentra la
   clase y falla el parse de quien la referencia.
6. **Texturas 3D en GDScript**: `ImageTexture3D.create()` NO es estático (instanciar y
   chequear el `Error` que devuelve); se construyen con array de Images 2D (una por
   slice Z). `Image.create_from_data` 2D solo acepta 5 args. Además el sampler3D del
   shader no llegó a renderizar en el editor real — los depósitos 3D reemplazaron
   ese enfoque.
7. **El generador compila al deserializar**: los recursos `ZN_FastNoiseLite` del grafo
   se hornean con sus seeds por defecto. Mutar `noise.seed` en runtime NO cambia el
   terreno generado (sí el objeto en memoria). Para seeds por planeta: escribirlas en
   el `.tres` o construir+compilar el grafo por código. `ZN_FastNoiseLite.get_noise_3d()`
   SÍ sirve para replicar la superficie analíticamente (difiere <1 u del terreno real).

---

### 2.3.2 Avances Recientes y Pulido de Mochila / Terreno (2026-09-09 al 2026-09-11)

- **Mochila Diegética Totalmente Operativa**:
  - Eliminado el desacople caótico de piezas: la mochila permanece sólida en la espalda del astronauta.
  - Cámara de inventario (`[TAB]`): encuadre nítido frontal hacia la espalda (`spring_length = 2.0`, `Y = 0.35`) con cálculo de ángulo exacto `atan2(espalda.x, espalda.z)` sin giros de 180° indeseados.
  - 8 ranuras (`Slot1`–`Slot8`) reposicionadas a los costados para no quedar tapadas por el chasis.
  - Barras volumétricas de O2 (azul/cian) y Energía (amarillo) en la espina central.
  - Micro-impresora 3D diegética integrada con display holográfico, navegación de recetas `<`, `>` y botón `[IMPRIMIR]`.
- **TerrainTool Enfundable y Retícula 3D**:
  - Enfundado/desenfundado físico en el lateral derecho de la mochila con tecla `[E]`.
  - 3 modos de operación diegéticos (0: EXCAVAR en naranja, 1: RELLENAR en verde, 2: APLANAR en cian) alternables con `[R]` o `[H]`.
  - Canister físico de vidrio con nivel de llenado visible de sedimento (0% a 100%) y display holográfico.
  - Retícula circular 3D (`TorusMesh`) proyectada en el suelo orientada automáticamente a la normal del terreno y con color reactivo al modo.
- **Perfeccionamiento y Estabilidad de Modo Aplanar (Flatten)**:
  - **Activación Continua (Hold-to-Flatten)**: Se mantiene presionado el botón izquierdo para aplanar áreas extensas de forma fluida.
  - **Alineación con la Gravedad Esférica del Planeta**: El plano de allanado se fija a partir de la normal física del punto de contacto (`hit.normal`), permitiendo aplanar en cualquier punto o ladera de los planetas esféricos.
  - **Proyección Rayo-Plano Estable**: Se reemplazó el raycast continuo de suelo por la proyección matemática del rayo de la cámara sobre el plano de referencia capturado en el primer frame, eliminando la deriva o pérdida de nivel.
  - **Protección de Determinante de Base**: Se añadió guardia `abs(basis.determinant()) > 0.0001` antes de invertir bases para blindar el código frente a singularidades numéricas del voxel engine.
- **Conservación de Volumen y Proporcionalidad Física de Sedimento**:
  - **Fórmula Cúbica ($V \propto r^3$)**: El sedimento extraído y depositado se calcula estrictamente en función del volumen de la esfera (`_calcular_sedimento_por_radio(radio)`), donde un radio base de 4.0 m equivale a 10.0 unidades (10% del canister).
  - **Conservación 1:1**: 1 m³ excavado equivale exactamente a 1 m³ depositado.
  - **Relleno Adaptativo**: Si resta menos sedimento que el de una esfera completa, se deposita una esfera de radio reducido proporcional al volumen disponible en vez de bloquearse.
  - **Recolección en Aplanar**: El paso `MODE_REMOVE` ahora añade sedimento al canister en tiempo real cuando raspa montículos por encima del plano; `MODE_ADD` consume sedimento cuando rellena cavidades bajo el plano. No hay transferencias en suelo ya nivelado.
- **Catálogo Holográfico Retráctil (`CatalogoHolo`)**:
  - Marco superior interactivo `[ CATALOGO ]` visible en todo momento como pestaña/botón en la mochila.
  - Al hacer clic, despliega la pantalla holográfica mediante animación de persiana (`Tween` en escala Y).
  - Árbol de 8 recetas desbloqueables con Bytes en tiempo real sin pausas de pantalla.
- **Limpieza de Sintaxis y Encoding**:
  - Eliminación de comentarios `#` en archivos `.tscn` (los comentarios de hash provocaban fallos críticos de parseo en el motor de Godot).
  - Anotaciones estáticas completas en GDScript y eliminación de warnings por parámetros no utilizados (`_delta`).
  - Todo el proyecto verificado en codificación UTF-8 sin BOM (`[101, 120, 116, 101]` en `.gd`, `[91, 103, 100, 95]` en `.tscn`).

---

## 3. Mapa de brechas: Astroneer vs. hoy (Evaluación ~70% MVP vs Pulido 100%)

| Sistema de Astroneer | Estado Funcional (~70% MVP) | Qué falta para el 100% (Pulido F6) | Fase |
|---|---|---|---|
| Herramienta de terreno | ✅ Cavar y añadir esférico SDF funcional | Modos aplanar/suavizar, UI selector de modos, audio y partículas de excavación | F1/F6 |
| Recursos incrustados | ✅ Vetas deterministas + depósitos 3D de cristales | Variedad de modelos por tipo de mena, partículas al fracturarse | F1/F6 |
| Minado y dropeo a mochila | ✅ Minar suelta item físico y encaja en slots | Sonido de recogida/colocación en mochila, animación de dropeo | F1/F6 |
| Persistencia de terreno y seed | ✅ SQLite guarda ediciones por planeta y slot | Persistencia de items sueltos dropeados en el suelo | F1/F6 |
| Oxígeno, tethers y supervivencia | ✅ Red de O2 con cápsula, tethers T y respawn | Cables visuales (lines/ropes) entre tethers, fade negro al morir | F2/F6 |
| Energía y día/noche | ✅ Sol rotatorio, paneles solares P y consumo O2/herramienta | Indicador visual de panel siguiendo al sol, batería 3D en base | F2/F6 |
| Módulos de base y fabricación | ✅ Fundición funcional, cámara de bytes, menú F | Conexiones de energía por cable/plataforma libre, animación fundición | F3/F6 |
| Investigación y progresión | ✅ Piedras moradas → bytes → catálogo de recetas | Más recetas y artefactos variados por bioma | F3/F6 |
| Vehículo planetario (Rover) | ✅ Conducción 4x4 esférica, batería, 4 slots de carga | Ajuste fino de suspensión en baches, sonido de motor/freno | F4/F6 |
| Múltiples planetas y biomas | ✅ 3 planetas (Terra, Árido, Hielo) con minerales propios | Atmósfera/niebla personalizada por planeta, skybox espacial | F5/F6 |
| Vuelo espacial (Lanzadera) | ✅ Estilo No Man's Sky: 6-DOF, boost, auto-aterrizaje E, HUD | Efectos de sonido de motor/impulso, reentrada con fricción de aire | F5/F6 |
| HUD, menús y opciones | ✅ HUD O2/energía/bytes, menú viaje M, slots Escape | Menú principal de inicio, opciones de vídeo/audio sobre `config.cfg` | F2/F6 |
| Guardado completo de partida | ✅ 3 slots JSON + DBs SQLite por planeta + GameState | Desacoplar definitivamente autoload `SaveManager` de arcade | F6 |
| Audio, música y feedback | ⚠️ Básico (sonidos heredados en vehículos) | Pasada global de efectos sonoros y partículas (Stylized-Smoke) | F6 |


---

## 4. Fases

Regla de avance: cada fase termina con algo **ejecutable y jugable** desde `test_2.tscn`.
No se empieza una fase sin cerrar los checkboxes de la anterior (salvo ítems marcados *opcional*).

### Fase 0 — Estabilizar test_2 *(corto: días)* — ✅ COMPLETADA 2026-08-16

Objetivo: cero bugs conocidos, mundo reproducible, base de código limpia para crecer.

- [x] Arreglar `toggle_inventory_mode()` (doble negación) — TAB alterna y hace zoom a la mochila.
- [x] Limpiar `get_object_under_mouse()`: código muerto fuera, `exclude` del jugador aplicado, sin `print`.
- [x] Unificar el "item en mano" en un solo lugar (solo `_process`).
- [x] `remove_item()` en `slot.gd` + flujo completo: agarrar de slot → slot libre → volver
      a colocar. Además se repararon los grupos (`"items"`/`"slots"`) y se desactivaron las
      Areas hijas de los items que interceptaban los clics (detalles en §2.3).
- [x] `@export var world_seed` en `planeta_01.gd`. Aclarado: test_2 genera con
      `planeta_01.tres` estático (ya determinista); el script es la variante por código.
- [x] **Cámara (decisión)**: se mantiene el esquema actual — ratón libre para apuntar/clicar
      (como Astroneer), rotación arrastrando con botón central, zoom con rueda. Revisar de
      nuevo en F1 cuando la herramienta de terreno tenga UI de modos (candidato: cámara que
      sigue automáticamente detrás del jugador cuando corre).

### Fase 1 — Recursos y persistencia *(el corazón)* — ✅ COMPLETADA 2026-08-21

Objetivo: el vertical slice de minería. "Cavo, encuentro mineral, lo recojo, apago el
juego y sigue ahí."

- [x] **Vetas de mineral** — implementadas como `OreField` (`scripts/planeta/ore_field.gd`),
      NO en el grafo voxel (ver §2.4 por qué). Distribución por profundidad radial:
      cobre -5..-40, hierro -40..-80, litio <-80 (medido: ~1.3%/1.5%/2.5% del volumen).
- [x] **Visuales de vetas**: el shader del planeta muestrea una `Texture3D` (32³) generada
      desde los mismos ruidos de `OreField` → lo que se ve es lo que se mina. Colores:
      cobre, hierro gris, litio blanco-azulado; suelo verde en superficie, roca naranja
      por debajo.
- [x] **Minado con recompensa**: al excavar sobre veta, `voxel_manager` spawnea el item
      (`ore_copper/iron/lithium.tscn`, grupo `small_items` → cabe en la mochila) con
      cooldown de 0.25 s.
- [x] **Catálogo de recursos**: `RecursoData.gd` (id, nombre, color, escena) + 3 `.tres`
      en `recursos/`, conectados al VoxelManager en `test_2.tscn`.
- [x] **Persistencia de terreno**: `VoxelStreamSQLite` en `user://mundo_voxel.db`.
      Los agujeros/rellenos sobreviven entre sesiones. *(Los items dropeados aún no se
      guardan — eso va con el refactor de SaveManager en F6.)*
- [x] **Seed reproducible**: `Global.world_seed` (default 20260816); `planeta_01.gd`
      la inyecta en los ruidos del generador; `OreField` deriva sus seeds de la misma.
- [ ] *Opcional pendiente*: contador de suelo recogido (material para centrífuga, F3+).

**Verificación pendiente del autor (en editor con F5)**: ver vetas al excavar profundo,
dropear mineral al picar sobre veta, cerrar/reabrir y encontrar los agujeros persistidos.

### Fase 2 — Supervivencia: oxígeno, tethers, energía, día/noche *(conceptualizada 2026-08-21)*

Objetivo: riesgo y ritmo. El jugador ya no puede vagar infinito; hay que planificar.

#### Concepto (qué debe SENTIRSE)
- Aterrizas con una cápsula que da oxígeno en un radio cercano. Te alejas, el O2 baja.
- Colocas tethers para extender la "línea de vida" y llegar más lejos / más profundo.
- Excavar consume energía; la energía solo se recarga de día (panel de mochila v1).
- La noche llega (~10 min por ciclo) y cambia la luz — el momento de volver a casa.
- Morir por O2 → respawn en la cápsula; los items que llevas quedan donde caíste.

#### Arquitectura (datos separados de nodos — disciplina multiplayer §6.2)
1. **`scripts/jugador/player_stats.gd`** (RefCounted, propiedad del player):
   `oxygen`, `oxygen_max`, `power`, `power_max` + señales `oxygen_changed`,
   `power_changed`. Métodos `consume_power(a)`, `replenish_oxygen(rate)`.
   El HUD escucha las señales; nadie más toca los valores directamente.
2. **Red de oxígeno** (`scripts/sistema/oxygen_network.gd`, nodo en test_2):
   lista de fuentes (cápsula radio ~15, cada tether radio ~10) y
   `is_oxygenated(pos) -> bool` (distancia a la fuente más cercana).
   El player pregunta por frame: dentro → recarga, fuera → drena.
3. **Tether** (`escenas/planeta/tether.tscn`): poste fino + esfera de luz +
   `Area3D` fuente de O2 + línea visual (cable) al tether anterior o cápsula.
   v1 de colocación: tecla **T** lo planta a los pies del jugador si quedan
   (empiezas con 10; fabricarlos será la impresora de F3).
4. **HUD** (`escenas/hud.tscn`, CanvasLayer): barras de O2 (azul) y energía
   (amarillo) + contador de tethers. v1 = barras 2D simples; el anillo-alrededor-
   del-jugador estilo Astroneer es pulido de F6.
5. **Muerte/respawn**: `oxygen <= 0` → fade a negro → item en mano se suelta donde
   mueres (los de la mochila se quedan) → respawn en cápsula con todo lleno.
6. **Energía de la herramienta**: excavar cuesta ~2 por clic; sin energía la
   herramienta no actúa (feedback: barra parpadea). Recarga 1/s de día, 0 de noche.
7. **Día/noche** (`scripts/sistema/day_night.gd`): rota el `DirectionalLight3D`
   sobre un eje, ciclo ~600 s, expone `is_day()` y el ángulo; atenúa el ambiente
   de noche (Environment). El sol visual ya existe (ProceduralSky).
8. **Cápsula de aterrizaje** (`escenas/planeta/capsula.tscn`): StaticBody + Area
   de O2 + Marker3D de respawn + lucecita. Se coloca junto al spawn del player
   (posición determinista por seed).

#### ✅ IMPLEMENTADA 2026-08-21 (verificada headless end-to-end) — F2

- [x] `scripts/jugador/player_stats.gd` — O2/energía con señales (datos puros).
- [x] `escenas/hud.tscn` + `hud.gd` — barras O2 (azul) / energía (amarillo).
- [x] `scripts/sistema/oxygen_network.gd` — fuentes por nodo; `is_oxygenated()`.
- [x] `escenas/planeta/capsula.tscn` — auto-colocación sobre terreno real,
      radio O2 15, `respawn_point` + luz.
- [x] `escenas/planeta/tether.tscn` — radio O2 10.
- [x] Muerte por O2 → suelta item en mano → respawn en cápsula → reset.
- [x] Excavar cuesta 2 de energía; recarga 1/s solo de día.
- [x] `scripts/sistema/day_night.gd` — sol rotando, día 350 s / noche 250 s.
- [x] Inputs `press_t`/`press_p` en `project.godot`.

**Pulido F2 pendiente** (F6): cable visual entre tethers, fade al morir,
parpadeo de "sin energía" en HUD, balance fino.

**Hecha cuando** (§7): muero sin O2 lejos de la cápsula; con 5 tethers cruzo un
valle y sobrevivo; excavo hasta quedarme sin energía; la noche para la recarga
y la veo oscurecer.

### Fase 3 — Base, fabricación e investigación *(conceptualizada 2026-08-21)*

Objetivo: el bucle completo de progresión en un solo planeta:
**explorar → minar → fundir → investigar → desbloquear → fabricar → llegar más lejos**.

#### Concepto (qué debe SENTIRSE)
- La cápsula llega con una mini-base pegada: **fundición** y **cámara de investigación**
  (base semilla, como el inicio de Astroneer). Todo lo demás se fabrica y se coloca.
- Picas cobre → lo pones en la fundición → sale un **lingote** (con energía de la base).
- Explorando con tethers encuentras **piedras de investigación** moradas y brillantes →
  la cámara las convierte en **bytes**.
- Los bytes desbloquean recetas: panel solar, tanque de O2, batería, más tethers.
- Fabricas desde la mochila (**F**) con los materiales que llevas encima.
- Colocas paneles solares (**P**) junto a la base → de día hay energía para fundir
  e investigigar más rápido → el bucle se acelera solo.

#### Arquitectura (reusa lo existente; datos separados de nodos)
1. **`RecetaData`** (`scripts/items/receta_data.gd`, Resource `.tres` por receta):
   `id`, `nombre`, `inputs` (dict recurso→cantidad), `salida` (item+cantidad ó
   efecto), `coste_bytes`, `colocable`. Catálogo de recetas = array en escena.
2. **`BaseCore`** (nodo en test_2, grupo `base_core`): pool de energía de la base.
   `bateria` (arranca 50), fuentes registrables (cápsula +0.5/s siempre,
   panel solar +1/s de día — consulta `day_night`), y `consumir(cantidad) -> bool`
   para los módulos. v1 = pool único; redes por plataforma van en F4+.
3. **Fundición** (`escenas/planeta/fundicion.tscn`, colocada junto a la cápsula):
  StaticBody + **2 slots reutilizando `slot.tscn`** (entrada mena / salida lingote)
  + barra de progreso 3D. Con mena en entrada y energía: 20 s a 2/s → lingote en
  salida. Interacción = agarrar/soltar de siempre (cero curva de aprendizaje).
4. **Cámara de investigación** (`camara_investigacion.tscn`): 1 slot + energía →
   25 s → piedra consumida + bytes al catálogo.
5. **`Catalogo`** (`scripts/sistema/catalogo.gd`, nodo con datos+señales —
   disciplina multiplayer): `bytes: int`, `desbloqueadas: Array[String]`,
   señales `bytes_changed` / `receta_desbloqueada`. Persistirá en F6.
6. **Piedras de investigación**: extender el colocador de depósitos — ~25 piedras
   moradas emissive sobre la superficie (deterministas por seed), recogibles como
   items (grupo `items`, no caben en slots → se llevan en la mano).
7. **Lingotes**: 3 items nuevos (ingot cobre/hierro/litio, `small_items`) + 3 `.tres`.
   En F3 son el "producto refinado"; F4 (vehículos) los consumirá.
8. **Menú de fabricación** (`escenas/ui/menu_fabricacion.tscn`, tecla **F**):
   lista de recetas con coste de materiales (resaltando lo que ya llevas),
   coste en bytes y botón *Fabricar*. Consume items de los slots de la mochila
   (nuevo helper `player.contar_items()`) → suma al inventario de colocables.
9. **Colocables generalizados**: refactor de `_place_tether` →
   `player.placeables = {"tether": N, "panel_solar": N}`; **T** sigue plantando
   tethers, **P** planta paneles solares (mismo raycast al suelo). El panel se
   registra en `BaseCore` como fuente; también extiende la red de O2 (radio 10,
   como un tether — simplificación útil).
10. **HUD**: añadir contador de bytes junto a las barras.

#### Orden de implementación (cada paso jugable)
1. Lingotes + `RecetaData` + `BaseCore` + fundición junto a cápsula → **fundir funciona**
2. Piedras de investigación + cámara + bytes en HUD → **investigar funciona**
3. Menú de fabricación con 2 recetas: *tethers ×5 ← 1 cobre* (gratuita) y
   *panel solar ← 2 cobre + 500 bytes* → **el bucle cierra**
4. Colocables con P + panel solar alimentando la base (y dando O2)
5. Recetas de mejora: *tanque O2* (+25 O2 máx, consumible) y *batería* (+25 energía máx)
6. Pulido: barras de progreso 3D en módulos, cables visuales, sonidos

#### Balance inicial (consts/data, afinar jugando)
Fundir 20 s drenando 2/s; investigar 25 s a 2/s; piedra = 300 bytes (~25 piedras
en el mundo); batería base 50, cápsula +0.5/s, panel +1/s de día; recetas: tethers
0 bytes, panel 500, tanque 600, batería 600; lingotes aún sin consumo (F4).

#### Riesgos / decisiones
- **Base fija vs plataformas libres**: v1 = módulos fijos junto a la cápsula; solo los
  paneles son colocables. Las plataformas conectables por cable se rediseñan en F4+
  cuando haya vehículos que las justifiquen.
- Muerte: se conserva la mochila (como ahora); solo se suelta lo de la mano.
- Las piedras en la mano al morir se sueltan donde caigas → recuperables.

**Hecha cuando**: fundo un lingote usando energía de un panel que yo coloqué, con
bytes ganados de una piedra que encontré explorando con tethers que fabriqué yo
mismo con cobre que miné. El bucle se sostiene sin intervención del dev.

#### ✅ IMPLEMENTADA 2026-08-21 (verificada headless end-to-end)

- [x] **Fundición** (`scripts/base/fundicion.gd` + `escenas/planeta/fundicion.tscn`):
      mena (slot entrada) → lingote (slot salida), 20 s drenando 2/s de la base.
      Se coloca sola a 4.5 u de la cápsula, alineada al up del planeta
      (`ModuloBase`). Verificado: cobre (id 2) → lingote id 12.
- [x] **Lingotes**: 3 items metálicos (`ingot_copper/iron/litio.tscn`, ids 12-14,
      `small_items`). F4 los consumirá.
- [x] **Cámara de investigación** (`camara_investigacion.tscn`): piedra → 300 bytes
      en 25 s a 2/s.
- [x] **Piedras de investigación**: ~15 moradas emissive sobre la superficie
      (colocadas por `ore_deposit_placer` en sitios sin depósito, deterministas),
      se llevan en la mano (no caben en slots).
- [x] **`Catalogo`** (`scripts/sistema/catalogo.gd`): bytes + desbloqueos con
      señales; "tethers" desbloqueada de serie.
- [x] **`BaseCore`** (`scripts/sistema/base_core.gd`): batería 50; cápsula +0.5/s
      siempre, panel solar +1/s de día; `consumir()` para módulos.
- [x] **Menú de fabricación** (`escenas/ui/menu_fabricacion.tscn`, tecla **F**):
      4 recetas .tres; consume materiales de la mochila (`contar/quitar_items`
      del player), gasta bytes solo el primer craft. Verificado craft + bloqueo
      por bytes insuficientes.
- [x] **Colocables generalizados**: `player.placeables` dict; **T** tethers,
      **P** paneles (input `press_p`).
- [x] **Panel solar**: fuente de base de día + fuente de O2 (radio 10).
- [x] **Mejoras**: tanque O2 (+25 máx) y batería (+25 máx) vía
      `stats.mejorar_o2_max/mejorar_power_max`.
- [x] HUD con tethers/paneles/bytes.
- Bugs del ciclo corregidos: `_fabricar` dependía de abrir el menú antes; la
  cápsula no alimentaba la base.

**Pulido F3 pendiente** (F6): cables visuales módulo↔panel, sonidos, barras 3D
más vistosas, balance fino de costes.

### Fase 4 — Vehículos *(conceptualizada 2026-08-21)*

Objetivo: el rover. Lo más difícil técnicamente del proyecto — y el momento en
que los **lingotes de F3** por fin se consumen.

#### Concepto (qué debe SENTIRSE)
- Fabricas un rover caro (lingotes + bytes), lo plantas junto a la base con **P**.
- Te subes (**V** cerca del rover), el jugador desaparece al volante y una cámara
  persecutora sigue el coche. Bajas con **V** y apareces al lado.
- Conduces valle arriba y colina abajo sobre el terreno deformable, alrededor de
  TODO el planeta — la gravedad siempre tira hacia el centro.
- La plataforma trasera tiene **4 slots de carga**: mena, lingotes y piedras viajan
  contigo (y con una piedra a bordo puedes traerla del otro lado del mundo).
- La batería del rover drena al conducir y se recarga aparcado junto a la base.
- El rover hace de "tether con ruedas" mientras conduces (radio O2 10) — la
  exploración lejana deja de depender de tender línea.

#### Arquitectura
1. **Campo de gravedad esférica** (`Area3D` en test_2, `gravity_point = true`,
   centro = CentroPlaneta, `space_override = REPLACE`, g ≈ 20):
   afecta a TODOS los `RigidBody3D` — arregla de paso un bug latente (los items
   dropeados lejos del polo caían en -Y mundial en vez de hacia el centro).
   El player (`CharacterBody3D`) no le afecta (usa su propia gravedad) ✓.
2. **Rover v1** (`escenas/vehiculo/rover.tscn`): `VehicleBody3D` **builtin** con 4
   `VehicleWheel3D` (NO gevp para v1: gevp es un framework arcade pensado en mundo
   plano; el builtin es más fácil de alinear a la esfera. gevp se revisa si el
   builtin se queda corto). Chasis bajo + 4 slots (`slot.tscn`) en la plataforma.
3. **Controlador esférico** (`scripts/vehiculo/rover.gd`):
   - Alineación: cada physics frame, torque/corrección angular para que el eje Y
     del rover siga el "up" planetario (equivalente físico del
     `align_up_with_planet` del player).
   - Conducción: WASD → engine_force/steering solo cuando `conductor` != null.
   - Batería propia (datos + señal, disciplina multiplayer): 100, drena 2/s
     conduciendo, recarga 10/s aparcado a <15 u de la cápsula; sin batería no anda.
   - Registra O2 (radio 10) como tether con ruedas.
4. **Entrar/salir**: player detecta rover cercano (grupo `vehiculos`, <3 u) con **V**
   → `Global.estado = 0` (¡la variable ya existía para el arcade!), player se
   reparenta/esconde, cámara persecutora del rover (SpringArm3D en el rover);
   al salir, player reaparece al lado del rover con `Global.estado = 1`.
   El input de movimiento se enruta según `Global.estado` (player ignora WASD
   cuando `estado == 0`).
5. **Cámara persecutora**: SpringArm3D hijo del rover, rotación con botón central
   (mismo esquema del player), zoom con rueda.
6. **Receta**: `receta_rover.tres` — 2 lingotes de cobre (id 12) + 1 lingote de
   hierro (id 13) + **1500 bytes**; colocable `rover` (tecla P).
   *Ojo: los inputs de receta usan recurso_id — los lingotes ya lo llevan (12-14).*

#### Orden de implementación (cada paso jugable)
1. **Area3D de gravedad** → items dropeados caen al centro en todo el planeta
   (verificar con un item lejos del polo).
2. **Rover estático colocado con P** (sin conducir): gravedad + alineación lo
   sientan bien aparcado en una ladera.
3. **Conducir**: entrar con V, WASD, salir con V — circuito alrededor de la base.
4. **Cámara persecutora** + pulido de conducción (velocidad, giro).
5. **Slots de carga + batería** del rover (drenaje/recarga en base).
6. **Receta en el menú** (lingotes + bytes) → el bucle F3→F4 cierra.

#### Números de balance (afinar jugando)
Motor ~90 N·m por rueda trasera, freno 2, velocidad punta ~12 m/s, dirección máx
0.5 rad; batería 100 (2/s conduciendo → ~50 s por carga, recarga 10/s en base);
receta: 2× lingote cobre + 1× lingote hierro + 1500 bytes.

#### Riesgos / decisiones
- **VehicleBody3D sobre mesh transvoxel**: las ruedas raycastean el collider del
  LOD actual — en cambios de LOD bajo el vehículo puede vibrar; mitigar con
  suspensión suave y velocidad limitada. Si chirría demasiado → probar gevp.
- **Caída por el mundo** en hoyos profundos: clamp de velocidad + respawn del
  rover si cae bajo radio 150.
- **Dropped items y el área de gravedad**: los items dormidos no despiertan solos
  (sleep) — al soltarlos desde la mano van despiertos ✓.
- Slots del rover + `contar_items` del player NO se mezclan (el player solo cuenta
  los suyos) — para fabricar desde el rover haría falta transferir items (fuera
  de alcance v1; se cogen con la mano igual que siempre).

**Hecha cuando**: conduzco un circuito completo alrededor del planeta sin caerme
ni volcar, con una piedra de investigación en la plataforma, y al volver a la
base el rover recarga mientras fundo el botín.

#### ✅ IMPLEMENTADA 2026-08-21 (verificada headless)

- [x] **Gravedad esférica** (`GravedadPlaneta` Area3D `gravity_point` REPLACE
      g=20, esfera r=620 en test_2): todos los RigidBody caen al centro —
      arregla los items dropeados lejos del polo. El player no se ve afectado.
- [x] **Rover** (`escenas/vehiculo/rover.tscn` + `scripts/vehiculo/rover.gd`):
      VehicleBody3D builtin, 4 ruedas (tracción trasera, dirección delantera),
      alineación al up del planeta por corrección angular, velocidad máx 12,
      freno automático sin acelerar y freno fuerte aparcado (se mantiene en
      cuestas: vel 1.1 tras soltarlo), rescate si cae bajo radio 150.
- [x] **Entrar/salir con V** (`press_v` en project.godot): sube a <4 u del
      rover, oculta al player (`Global.estado=0`, colisión off), cámara del
      rover activa; al bajar reaparece al lado. El input del player se apaga
      montado (salvo V); el O2/energía se siguen actualizando (el rover es
      fuente O2 r=10 = "tether con ruedas").
- [x] **Cámara persecutora** en el rover (botón central + rueda, como player).
- [x] **4 slots de carga** en la plataforma trasera (reusan slot.tscn).
- [x] **Batería**: 100, drena 2/s conduciendo, recarga 10/s aparcado a <15 u
      de la cápsula (verificado 70→80). Sin batería no acelera.
- [x] **Receta** `receta_rover.tres`: 2 lingotes cobre + 1 hierro + 1500 bytes
      (verificado: consume lingotes, desbloquea, suma rover colocable).
- [x] HUD con contador de rovers; P coloca panel si hay, si no rover.
- *Pendiente de ver en editor: agarre de ruedas en terreno LOD y pendientes
  fuertes (si patina → subir `wheel_friction_slip`); balance de conducción.*
- *No persiste entre sesiones (ni rovers ni nada fuera del terreno) → F6.*

### Fase 5 — Mundo completo: sistema solar y viaje *(conceptualizada 2026-08-22)*

Objetivo: más de un mundo con razón para viajar — **y la lanzadera para hacerlo**.

#### Concepto (qué debe SENTIRSE)
- Miras al cielo desde la base y hay OTRO planeta visible: el Árido y el Hielo.
- Fabricas la **lanzadera** (cara: lingotes + bytes + un recurso que ya tienes),
  subes con V y despegas — el mundo se hace grande de golpe.
- En el espacio se abre el **mapa de viaje**: eliges destino, fundido a negro,
  y apareces en órbita del planeta elegido; bajas volando y aterrizas donde
  quieras (la alineación del planeta te recoge al acercarte).
- Cada planeta tiene su paleta, sus montañas y sus **recursos exclusivos**
  (en casa no hay titanio; en el Hielo no hay cobre) → recetas nuevas que
  obligan a viajar. Sus piedras de investigación dan más bytes (más riesgo).
- La lanzadera es fuente de O2 mientras estás dentro (como el rover).
- Guardas en cualquier planeta y al cargar vuelves ahí, con cada mundo
  exactamente como lo dejaste (db por planeta y slot).

#### Arquitectura
1. **Refactor a sistema solar**: `test_2` pasa a instanciar 3 **cuerpos
   planetarios** (`escenas/planeta/planeta_cuerpo.tscn` + `planeta_cuerpo.gd`)
   en posiciones fijas (~4000 u entre sí). Cada cuerpo empaqueta: su
   `VoxelLodTerrain` (con su propio `.tres` de ruido — lección §2.4: los
   parámetros van horneados en el .tres, uno por planeta), su `Area3D` de
   gravedad, su `OreField`/colocador (recursos y bandas propios), su material
   (uniforms de color: suelo/roca/cielo tint) y su marcador del grupo
   `planetas`. La gravedad del player YA elige el más cercano (F0) ✓.
   La cápsula/base/spawn siguen solo en el planeta inicial.
2. **Planetas** (seeds derivadas de `Global.world_seed + índice`):
   - **Terra (inicio)**: como hoy — cobre/hierro/litio, verdes y valles.
   - **Árido**: período de montañas menor (picos agudos), paleta arena/óxido;
     exclusivo **Titanio** (id 5) + hierro abundante.
   - **Hielo**: relieve suave, paleta azul-blanca; exclusiva **Criolita**
     (id 6) + litio abundante; piedras de 600 bytes (300 en Terra).
3. **Lanzadera** (`escenas/vehiculo/shuttle.tscn` + `shuttle.gd`):
   colocable caro (receta: 4 lingote cobre + 2 hierro + 3000 bytes).
   Montas con V (mismo sistema del rover, grupo `vehiculos`).
   **Control directo** (sin física de vehículos): WASD impulso, Space/Ctrl
   sube/baja, botón central orienta cámara. Cerca de un planeta, un
   controlador suave la alinea al "up" local (prestado del patrón del rover);
   lejos, vuela libre 6-DOF. Velocidad tope ~40 (espacio) / 15 (cerca de
   superficie). Batería infinita v1 (el coste es fabricarla).
4. **Mapa de viaje**: al alejarse >1.5× el radio del planeta actual (o tecla
   M montado), UI con la lista de planetas (nombre + distancia + recursos);
   elegir destino = fundido (`Loading`) + colocación en órbita del destino
   (a 3× radio, cayendo hacia él). Aterrizaje manual volando.
5. **Recursos y recetas que obligan a viajar**: `RecursoData` + items para
   titanio/criolita (reusan patrón); recetas nuevas: *Tanque grande O2 (+50)*
   ← titanio; *Motor mejorado* (para F4-polish del rover) ← titanio+criolita;
   *Estación de carga* ← criolita. El `OreField` se parametriza por planeta
   (bandas/ids/umbral como datos del cuerpo planetario, no constantes globales).
6. **Guardado multi-planeta**: `slot_N_planeta_M.db` por planeta;
   `GameState` asigna las N rutas al cargar. Los colocados guardan posición
   mundial (los planetas son estáticos ✓ ya funciona). Player/bytes/placeables
   sin cambios. La posición del player ya implica el planeta.
7. **Cielo**: v1 un solo Environment; el espacio "se nota" por lejanía y el
   mapa. Estrellas/fog por planeta = pulido F6.

#### Orden de implementación (cada paso jugable)
1. **Andamiaje**: refactor a `planeta_cuerpo` (Terra idéntica a hoy) + segundo
   planeta de prueba vacío lejos → verificar gravedad/O2/colocador/console-tp
   por planeta sin romper F1-F4 (regresión completa).
2. **Biomas y recursos**: .tres y materiales de Árido/Hielo, OreField por
   planeta, recursos nuevos + recetas.
3. **Lanzadera de superficie**: volar/alinear/aterrizar en tu planeta.
4. **Mapa de viaje** + saltos entre planetas.
5. **Balance**: escasez cruzada, bytes por planeta, coste de la lanzadera.
6. **Save multi-planeta** + regresión de carga.

#### Riesgos / decisiones
- **Refactor grande sobre test_2** (el más delicado): hacerlo incremental,
   mantener grupos/nombres (`planetas`, `base_core`...) y correr el probe de
   regresión tras cada paso.
- **Rendimiento con 3 terrenos voxel**: solo generan alrededor de viewers
   (player/lanzadera) — pero vigilar memoria y hilos; opcional `default_view_distance` bajo en planetas lejanos.
- **Lanzadera sin física real**: control directo = robusto y barato; la
   sensación de vuelo la dan velocidad + alineación + cámara (suficiente v1).
- **EVA en espacio profundo**: NO soportado v1 (no sales de la lanzadera en
   tránsito; O2 infinito a bordo).
- **El rover pendiente** (ver §5): su pulido se retoma dentro de esta fase o
   antes, según prioridad del autor.

**Hecha cuando**: despego de Terra en mi lanzadera, viajo por el mapa al
Hielo, aterrizo, mino criolita (que en casa no existe), vuelvo, y fabrico el
tanque grande — y al cargar la partida sigo en el Hielo con ambos mundos
exactamente como los dejé.

#### ✅ IMPLEMENTADA 2026-08-22 (verificada headless)

- [x] **`planeta_cuerpo`** (`escenas/planeta/planeta_cuerpo.tscn` +
      `scripts/planeta/planeta_cuerpo.gd`): planeta empaquetado que construye
      por código terreno (con su `.tres`), Area3D de gravedad (centro local),
      OreField, depósitos/piedras y material con uniforms. Ruidos muestreados
      en LOCAL (lección F4). Grupos `cuerpos` + `planetas`.
- [x] **3 mundos en test_2**: Terra (0,0,0) como siempre; **Arido**
      (4000,0,0) — picos agudos (wl 120, ×55), paleta arena, titanio (id 5) +
      hierro profundo, piedras 450 b; **Hielo** (2000,0,3500) — suave (wl 400,
      ×25), paleta azul, criolita (id 6) + litio, piedras 600 b.
- [x] **Shader parametrizado** (`shaders/planeta.gdshader`): centro/radio/
      bounds/colores por uniforms; uvw relativo a cada planeta.
- [x] **OreField por planeta**: config {ore_id: banda+wl} (Terra default);
      minado exclusivo verificado (titanio en Arido sí, en Terra no).
- [x] **Excavadora universal** (voxel_manager): el raycast golpea cualquier
      terreno y su planeta responde `minar_en()`.
- [x] **Lanzadera estilo No Man's Sky** (`shuttle.tscn` + `shuttle.gd` + `hud_nave.tscn`):
      Vuelo 6-DOF suave y analógico. Pitch y Yaw directos con ratón (con inercia angular),
      Roll con teclas A/D y alabeo automático (banking) al virar. Acelerador progresivo W/S,
      modo Boost con Shift (FOV dinámico 75°→100° y estelas/fuego emissivo en motores).
      Aterrizaje automático asistido con tecla **E** a baja altura (la nave orienta sus alas
      con el planeta y se posa suavemente sin colisiones bruscas). Despegue vertical con W/Space.
      HUD de cabina con retícula de puntería, velocímetro digital, barra de Boost y alertas contextuales.
      Receta: 4 lingote cobre + 2 hierro + 3000 bytes; colocable con P (tercera prioridad).
- [x] **Mapa de viaje** (`menu_viaje.tscn`, tecla **M** montado en la
      lanzadera): lista planetas con distancia, salto con fundido (Loading) a
      órbita 2.2×radio. Verificado: dist exacta.
- [x] **Recetas nuevas**: Tanque grande O2 (+50, 2 titanio, 1000 b), Traje
      aislante (+50 energía, 2 criolita, 1000 b), Lanzadera.
- [x] **Guardado multi-planeta**: db `slot_N_pM.db` por planeta y slot;
      sesiones frescas usan `temp_pM.db` y al guardar se copian al slot
      (`asignar_db` con flush). Borrar slot limpia sus N dbs. Cámara del player
      y de la lanzadera con far 20000 (planetas a 4000+ visibles).
- [x] **Visibilidad interplanetaria completa (F5)**: Cada planeta cuenta con un
      globo impostor (`impostor_planeta.gdshader`) visible desde cualquier distancia
      con iluminación solar y halo Fresnel. Culling de cristales lejanos (`visibility_range_end`).
- [x] **Cielo espacial 360° y atmósferas dinámicas relativas**: Eliminado el suelo gris
      por defecto de ProceduralSky; shader de cielo en 360° con campo estelar continuo,
      sol/corona y gradiente atmosférico orientado a `planet_up` (Terra azul/cian,
      Árido ámbar/dorado, Hielo cobalto/blanco glacial).
- *Pendiente pulido (F6): niebla volumétrica, combustible de lanzadera, EVA.*

### Fase 6 — Pulido y cierre

- [x] **Refactor SaveManager**: quitadas rutas hardcodeadas de ArcadeDemo; save/load
      completo (terreno SQLite por planeta, módulos de base con rotación, inventario, posición, catálogo, desbloqueos) + autoguardado periódico de 5 min con notificación en HUD.
- [x] **Menú principal, pausa y opciones**: `menu_principal.tscn` como escena de entrada del juego, pausa (`menu_partida.tscn`) con regreso al menú, y panel de configuración gráfica/audio (ventana/pantalla completa/sin bordes, resolución 720p/900p/1080p, V-Sync, volumen master y calidad de LOD del terreno) persistido sobre `user://config.cfg` mediante `SaveManager`.
- [x] **Audio**: ambiente espacial continuo (drone cósmico estéreo + viento modulado en `AudioStreamWAV` procedural) y efectos de feedback en tiempo real (`AudioJuego` autoload) para excavar (estruendo grave), recoger items (ping agudo) y finalizar impresión (doble tono).
- [x] **Partículas de excavación**: ráfaga estilizada de polvo (`polvo_excavacion.tscn`) instanciada con orientación y autodestrucción en `voxel_manager.gd` durante el minado SDF.
- [x] **Rendimiento**: ajuste dinámico del `lod_distance` en `planeta_cuerpo.gd` según configuración del usuario (32m/48m/64m), culling por distancia con fade (`visibility_range_end`) en piedras y vetas minerales, y esferas impostoras procedurales para cuerpos distantes en el firmamento.
- [x] **Build y verificación**: arranque verificado desde `menu_principal.tscn`, proyecto libre de errores de compilación comprobado con Godot 4.6 mono headless.

### Fase 7 — Expansión Avanzada: Gateways, Núcleos, Tormentas y Augments ✅ (100% Completa)

- [x] **Cámaras de Portal Monumentales (Gateway Chambers)**: monolitos colosales de 30m de base con agujas de 26m en la superficie de cada planeta. Haz vertical de luz de 300m visible a kilómetros en todo momento. Demandan carga continua (35 unidades de energía). Al activarse abren la red de portales.
- [x] **Núcleos Planetarios Monumentales (Gateway Engines)**: estaciones geométricas colosales de 32m de diámetro en el centro geométrico de cada planeta (`radio = 0`) con agujas perimetrales y altar central. Despiertan al depositar el mineral nativo (Cuarzo en Terra, Titanio en Árido, Criolita en Hielo), otorgando 2500 bytes y teletransporte instantáneo.
- [x] **Red de Teletransporte Interplanetario Holográfica (`MenuTeleport`)**: interfaz de red que lista cámaras de superficie y núcleos despertados entre mundos, con salto instantáneo, fundido cinematográfico y posicionamiento perpendicular automático.
- [x] **Gravedad Esférica Consistente y Adherencia a Superficies**:
  - Caverna central de 80m en los núcleos con gravedad firme de 18.0 m/s² perpendicular a la plataforma y transición suave (`slerp`) entre 55m y 80m (cero saltos bruscos de 90°).
  - Adherencia continua al terreno voxel (`floor_snap_length = 0.8`, `floor_max_angle = 65°`, `floor_constant_speed = true` y `floor_stop_on_slope = true`). Fuerza downward activa contra el suelo (`-normal_suelo * 0.75 g`), proyección tangencial del movimiento en cuestas y asistencia de aterrizaje por raycast.
- [x] **Tormentas y Vendavales Dinámicos (`SistemaTormentas`)**: ciclos meteorológicos dinámicos (180 s calma / 40 s tormenta) con partículas de vendaval (`tormenta_viento.tscn`), empuje físico tangencial sobre el cuerpo del jugador y alertas HUD.
- [x] **Peligros Ambientales Iniciales (Flora Tóxica)**: especies alienígenas con bulbo pulsante (`flora_peligrosa.tscn`) que drenan oxígeno por esporas si el jugador se aproxima, y se neutralizan soltando muestras valiosas de investigación (`freeze = true`, sin interferencia de colisión física).
- [x] **Modificadores (Augments) de la Herramienta de Terreno**: ciclado interactivo con tecla `[G]` entre *Estándar*, *Amplio* (1.75x radio), *Precisión* (0.5x radio) e *Impulso* (2x velocidad con consumo de energía), con escalado reactivo de la retícula 3D y display holográfico en el mango.
- [x] **Correcciones de Estabilidad Crítica**:
  - Eliminado bucle de errores `det == 0` en `catalogo_holo.gd` (escala mínima `0.001` en folding).
  - Corregido constructor de color con 4 argumentos en `ore_cuarzo.tscn` para compatibilidad con la consola.

---

### Fase 8 — Ecosistemas Vivos, Biodiversidad Hostil y Rediseños Estéticos *(En Progreso — Bloques 1, 2 y 3 Implementados)*

Objetivo: transformar los mundos en **ecosistemas vivos, orgánicos y desafiantes**, poblando los biomas con árboles y vegetación autóctona destructible, expandiendo los peligros ambientales con nuevas variedades de plantas hostiles activas (proyectiles, gas tóxico y minas subterráneas), implementando botánica alienígena con semillas, y reconstruyendo la interfaz de teletransporte en una proyección holográfica 3D diegética.

#### 1. Árboles y Vegetación Alienígena Procedural por Bioma ✅
- [x] **Clase base `ArbolAlienigena`**: Anclaje al terreno mediante raycast, verificación post-meshing voxel y mecanismo de derribo al excavar raíces con la Herramienta de Terreno.
- [x] **Terra (Flora Fungiforme y Arbórea)**: `arbol_terra.tscn` / `arbol_terra.gd` — Árboles hongo con tronco cónico y sombrero con bioluminiscencia esmeralda.
- [x] **Árido (Flora Xerófila)**: `arbol_arido.tscn` / `arbol_arido.gd` — Megacactus columnares ramificados con resplandor cálido ocre/naranja.
- [x] **Hielo (Dendritas y Glaciares Vegetales)**: `arbol_hielo.tscn` / `arbol_hielo.gd` — Agujas de hielo cristalinas y ramificadas, translúcidas con reflejos cian.
- [x] **Materia Orgánica (Nuevo Recurso ID 24)**: `recurso_organico.tres` y `ore_organico.tscn` generado al derribar árboles, integrado en catálogo y comando `give` de consola.
- [x] **Distribución procedimental**: 1 de cada 5 sitios libres en `planeta_cuerpo.gd` genera árboles según el bioma del planeta.

#### 2. Variedad de Plantas Hostiles y Peligros Activos ✅
- [x] **Catapulta de Espinas (Flora Spitter)**: `flora_spitter.tscn` / `flora_spitter.gd` — Rastrea al jugador en 14m, orienta su cañón biológico y dispara proyectiles `proyectil_espina.tscn` que dañan oxígeno y generan retroceso. Desenterrable con la Herramienta de Terreno (+400 Bytes).
- [x] **Emisora de Niebla Tóxica (Flora Gas)**: `flora_gas.tscn` / `flora_gas.gd` — Libera densas nubes de esporas asfixiantes en un radio de 6.5m con consumo acelerado de oxígeno (26 O2/s). Desenterrable (+420 Bytes + Materia Orgánica).
- [x] **Bulbo Volátil Subterráneo (Flora Mina / Popping Pod)**: `flora_mina.tscn` / `flora_mina.gd` — Proximidad <3.8m detona cuenta atrás inestable de 1.4s antes de estallar en onda de choque. Desactivable excavando raíces (+500 Bytes).
- [x] **Peligros iniciales balanceados**: En Terra se ubican muestras de cada especie hostil junto a la base inicial (sitios 4, 7 y 11) y en todos los planetas 1 de cada 8 sitios.

#### 3. Rediseños y Refinamiento Estético
- [x] **Mitigación del glitch de cielo/atmósfera Hielo**: `snap_atmosfera()` y detección de saltos de cámara en `day_night.gd` eliminan el sangrado transitorio de color glacial durante teletransportes y viajes.
- [x] **Mitigación del bug orbital**: Clamp de seguridad post-`move_and_slide()` en `player.gd`, extensión de 6 frames de congelamiento físico y sincronización atómica de `up_direction` y centro gravitacional.
- [x] **Shader de Viento y Follaje**: `shaders/follaje_viento.gdshader` con oscilación orgánica de vértices por viento y pulso bioluminiscente.
- [ ] **Reconstrucción Holográfica 3D de la Red de Portales (`MenuTeleport`)**: Proyección holográfica diegética con orbes planetarios en 3D giratorios en tiempo real.
- [ ] **Domesticación y Botánica (Semillas Alienígenas)**: Cultivo pasivo en la base.

---

## 5. Estado Actual del Proyecto y Futuras Expansiones

Con la finalización de las **Fases 0 a 7**, el proyecto **Nuevo Proyecto II** cuenta con una base jugable completa:
1. **Generación Planetaria Voxel Esférica**: Múltiples mundos en el mismo espacio 3D, LOD Transvoxel dinámico, gravedad orientada con adherencia activa a pendientes y transiciones suaves en núcleos.
2. **Minería y Terreno Físico**: Excavación, relleno y aplanado adaptativo SDF con balance estricto de masa de sedimento en Canisters volumétricos y 4 Augments interactivos en la Terrain Tool.
3. **Mochila Diegética & Fabricación**: Inventario sin menús 2D flotantes, catálogo holográfico retráctil y micro-impresora integrada.
4. **Industrialización Modular**: Fundición/Horno, Centrifugadora de Sedimento, Plataformas con ranuras (`slot.tscn`), e Impresoras 3D en 3 tamaños (Pequeña, Mediana, Grande) con Ghost Blueprints.
5. **Redes de Supervivencia y Logística**: Tethers de oxígeno/energía, paneles solares con ciclo día/noche, rovers terrestres y lanzadera espacial con despegue orbital.
6. **Endgame Galáctico**: Cámaras de Portal monumentales en superficie y Motores en los núcleos de los planetas con haz de 300m, red de teletransporte interplanetario, tormentas de viento y flora hostil.
7. **Sistema de Partidas y Configuración**: Menú principal, selector de 3 slots persistentes con SQLite para voxels, autoguardado periódico cada 5 min y menú de opciones de pantalla, resolución, V-Sync, volumen y LOD.

La **Fase 8** llevará el juego al siguiente nivel de inmersión y riqueza de contenido, convirtiendo los planetas en biomas vivos con bosques, peligros reactivos variados y rediseños holográficos de última generación.

---

1. **Verificar F5 en el editor**: El juego arranca desde `menu_principal.tscn` (o F6 en `test_2.tscn` para testing directo).
2. Recordatorios técnicos:
   - Guardar archivos en **UTF-8 sin BOM** (`.gd`: `[101, 120, 116, 101]`, `.tscn`: `[91, 103, 100, 95]`).
   - Nunca incluir líneas con comentarios `#` en archivos `.tscn`.
   - Mantener tipado estático fuerte en GDScript para compatibilidad con el compilador.

## 6. Decisiones de arquitectura (registro)

1. **¿`test_2` pasa a ser el juego?** ✅ **Decidido 2026-08-16**: sí. `test_2.tscn` es la
   escena principal (F5). `demo_arcade.tscn` queda como sandbox congelado de máquinas
   (accesible por F6); se reciclará de él lo que se pueda (vehículos, sonido).
2. **¿Multiplayer alguna vez?** ✅ **Decidido 2026-08-21**: sí, "si en algún momento se
   añadirá" — es objetivo futuro declarado. Consecuencia: el estado del juego debe vivir
   separado de los nodos. `OreField` y `RecursoData` ya cumplen (lógica/datos puros);
   mantener esta disciplina en F2+ (ej.: oxígeno como dato del player, no solo UI).
3. **Estética**: mantener el shading procedural low-poly por color (línea actual del
   shader) — es coherente con Astroneer y evita dependencia de texturas.
4. **VoxelStreamSQLite vs diffs propios**: usar SQLite (ya integrado en zylann) salvo que
   falle en la práctica; no inventar formato propio antes de necesitarlo.

## 7. Criterios de "hecho" por fase (resumen ejecutable)

| Fase | Se considera hecha cuando... |
|---|---|
| F0 | Sin bugs de §2.3; TAB, slots y gravedad funcionan idénticos en cada sesión con mismo seed |
| F1 | Puedo cavar una veta, obtener el mineral, cerrar, reabrir y ver el agujero persistido (los items dropeados se guardarán en F6) |
| F2 | Muero sin oxígeno lejos de base; con tethers sobrevivo; la noche detiene la energía solar |
| F3 | Fundo mena → imprimo un panel con bytes de investigación → mi base crece sin intervención del dev |
| F4 | Conduzco un rover por el planeta con carga, sin caerme del mundo, colina arriba |
| F5 | Viajo planeta A→B, quedan mis dos bases, y hay un recurso que solo existe en B |
| F6 | Un jugador nuevo juega 30 min sin instrucciones y sin ver un error, con save/load |
| F7 | Activada la red monumental de monolitos y núcleos en los 3 mundos, teletransporte interplanetario, adherencia física a pendientes y augments en la Terrain Tool |
| F8 | Planetas poblados con bosques y vegetación única por bioma, 3 variedades de plantas hostiles activas, recolección de semillas/orgánicos, y rediseño holográfico 3D de portales |
