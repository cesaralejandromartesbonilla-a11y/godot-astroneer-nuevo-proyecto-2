# Nuevo Proyecto 2 (Copy)

Juego 3D de construcción/minería hecho con **Godot 4.6 (Forward Plus)**: grúas, bulldozer,
monedas, terreno voxel, planetas y un gancho tipo grappling hook.

Este documento explica la **reorganización y limpieza completa** realizada el **2026-08-16**,
el estado actual del proyecto y lo que queda pendiente.

➡️ **Hoja de ruta del juego (objetivo: recrear Astroneer)**: ver [`ROADMAP.md`](ROADMAP.md).

---

## Escena principal y autoloads

| Elemento | Ruta |
|---|---|
| Escena principal (F5) | `escenas/test_2.tscn` (juego Astroneer) |
| Escena del arcade de máquinas (F6, sandbox congelado) | `escenas/demo_arcade.tscn` |
| Autoload `Global` | `scripts/sistema/global.gd` |
| Autoload `SaveManager` | `scripts/sistema/saveload.gd` (+ `save_file.gd` con `class_name SaveGame`) |
| Autoload `Loading` | `escenas/loading_screen.tscn` |
| Autoload `AeroUnits` | addon `godot_aerodynamic_physics` |

## Estructura actual

| Carpeta | Función |
|---|---|
| `escenas/` | **Todas las escenas del juego**: principal (`demo_arcade`), máquinas (grúa, bulldozer, monta carga, camión), monedas/minerales, y `planeta/` (sistema de planeta con items recogibles) |
| `scripts/` | Código organizado por sistema: `sistema/` (autoloads, guardado), `jugador/` (player, items recogibles, slots, gancho), `planeta/` (voxel), `maquinas/` (grúa, bulldozer, cargadora, zonas de carga, vehículo base), `items/` (datos de items, monedas, cajas, vender) |
| `recursos/` | Recursos sueltos (`car.tres`, `cubo.tres`, `pelota.tres`) |
| `vehicles/` | Scripts y sonidos del camión (usados por la escena principal) |
| `assets/` | Texturas del juego (voxel, hook) + `simple_fpsplayer/` (licencias del demo del que viene `ability_grab`) |
| `FBX_format/` | Kit de modelos FBX — `item-coin-bronze.fbx` + `Textures/colormap.png` en uso; **el resto se conserva para uso futuro** |
| `materials/`, `models/`, `textures/`, `shaders/` | Librerías de materiales, modelos y shaders **conservadas para uso futuro** (decisión del autor) |
| `addons/` | Librerías: `zylann.voxel` (terreno voxel), `gevp` (física vehicular + demos), `grappling_hook_3d` (gancho del player), `aircraft` + `godot_aerodynamic_physics` + `simplified_flightsim` (vuelo), `godot-shaders-main`, `example`, `Godot-Water-Ripple`, `Stylized-Smoke`, `assets` (player del gancho) |
| `_backup_eliminados_2026-08-16/` | **Archivo muerto** (ver abajo). Ignorada por Godot (`.gdignore`) |
| `_proximos_proyectos_2026-08-16/` | Escenas/scripts fuera de uso actual guardados como futuros proyectos (incluye la demo del grappling hook). Ignorada por Godot (`.gdignore`) |
| Raíz | Solo `project.godot`, `icon.svg`, `configs_default.cfg` (pareja runtime de `res://config.cfg`), `README.md`, `LICENSE`, `.gitignore` |

---

## Qué se hizo (2026-08-16)

### Fase 1 — Inspección
Se auditó el proyecto completo buscando addons sin uso, assets huérfanos, carpetas de demos
ajenas y archivos temporales. Todo lo encontrado se verificó cruzando referencias por
ruta (`res://`) **y** por `uid://`, incluidos usos dinámicos (`load()`/`preload()`) y clases
`class_name` sin referencia de ruta.

### Fase 2 — Limpieza con respaldo (`_backup_eliminados_2026-08-16/`, 118 MB)
Nada se borró directamente (el repo git estaba vacío): se movió a esta carpeta con `.gdignore`.

- `weeping-angel-godot/` (105 MB, demo ajena), `3d_graphics_settings/` (demo), `screenshots/`
- Addons: `health_hitbox_hurtbox`, `portals`, `tree_maps`, `massimo` (verificado 0 usos), `docs`, `ShaderSecretsHelper`
- `addons/assets/` parcial: texturas, `character-male-e.glb`, `mouse_lock.gd`, `camera_pivot.gd`
  (se conservó `player.gd`, que usa el player del juego)
- `vehicles/meshes/meshes.glb`
- Borrados definitivamente: 6 archivos `.tmp`, 2 `.bak.gd.uid` huérfanos, `.sconsign.dblite` (6 MB)

**No se eliminaron** `addons/example`, `Godot-Water-Ripple` y `Stylized-Smoke` aunque se
habían marcado como sin uso: la escena principal `demo_arcade.tscn` vive dentro de
`addons/gevp/` y **sí los usa** (agua, humo, visuales/sonidos de aviones).

### Fase 3 — Filtrado por uso real y renombrado
Se calculó la cadena completa de dependencias vivas desde `demo_arcade.tscn`, `test_2.tscn`
y los autoloads. Todo lo no alcanzable se movió a `_proximos_proyectos_2026-08-16/` (65 archivos):
`main.tscn` (demo de pelotas), `world.tscn`, `test.tscn`, `ecena_principal`, `ecena_test`,
`objects/` (salvo `ball.tscn`), `scripts/scene_objects/` (salvo `ball.gd`), 3 de los 6 "player",
escenas sueltas de grúa/tienda, etc.

Renombrados (espacios → `_`, carpetas por función):

| Antes | Ahora |
|---|---|
| `ecenas 2/` | `ecenas_planeta/` |
| `FBX format/` | `FBX_format/` |
| `ecenas/test 2.tscn` | `ecenas/test_2.tscn` |
| `ecenas/bull dozer.tscn` | `ecenas/bull_dozer.tscn` |
| `ecenas/monta carga.tscn` | `ecenas/monta_carga.tscn` |
| `ecenas/grua de construccion.tscn` | `ecenas/grua_de_construccion.tscn` |
| `ecenas/test coin_3d.tscn` | `ecenas/test_coin_3d.tscn` |
| `test coin.gd` | `test_coin.gd` |
| 14 shaders de `shaders/` con espacios | p. ej. `frosted_glass.gdshader`, `Water_Shader2.gdshader` |

Todas las referencias `res://` del proyecto (escenas, scripts, recursos, `.import`) se
actualizaron en consecuencia.

### Fase 4 — Correcciones post-renombreado
El editor de Godot estuvo abierto durante los renombrados, lo que causó errores puntuales:

1. Pestañas del editor con contenido viejo escribieron rutas `res://ecenas 2/...` al crear
   `ecenas/player.tscn` y `ecenas/planeta_01.tscn` → corregidas (se les añadió el `uid` que les faltaba).
2. `colormap.png` cambió de uid al re-importarse (`tp067sn8yc3g` → `bv03a70j5sewe`) →
   actualizado en `auto.tscn`, `demo_arcade.tscn`, `bull_dozer.tscn` y `monta_carga.tscn`.
3. Se borró un `vehicles/impact.wav.import` huérfano (su `.wav` no existía).

### Fase 5 — Corrección del anidamiento del addon de vuelo
`addons/addons/simplified_flightsim/` (doble carpeta, producto de una instalación con el zip
descomprimido entero) se movió a su ruta estándar **`addons/simplified_flightsim/`**, con
`project.godot`, `demo_arcade.tscn` y `Example1_Simple.tscn` actualizados. Esto además
reparó ~20 referencias internas del propio addon, que apuntaban a la ruta estándar y antes
quedaban rotas. Se regeneró el registro de uids (`.godot/uid_cache.bin`) y el índice de
búsqueda rápida del editor, ambos obsoletos tras los renombrados.

### Fase 6 — Reorganización grande
Reestructuración completa del proyecto (editor cerrado, todo con `mv` y actualización de
referencias por `sed`, verificando rutas y uids):

- **El juego salió de `addons/gevp/`**: `demo_arcade.tscn` (escena principal) y `arcade_car.tscn`
  pasaron a `escenas/`; `Cargadora.gd`, `zona_de_carga.gd`, `ZonaCargaMultiple.gd`,
  `dynamic_entities.gd`, `vehicle_base.gd`, `button_5.gd`, `changecamera.gd`, `node_3d.gd`
  pasaron a `scripts/maquinas/`. `gevp` quedó como librería pura (los archivos compartidos con
  sus demos — `track`, `engine_sound`, `smoke_effect`, `vehicle_controller` — se quedaron dentro).
- **Typo corregido y escenas consolidadas**: `ecenas/` → `escenas/`; `ecenas_planeta/` →
  `escenas/planeta/`; `auto.tscn`, `player.tscn` y `ball.tscn` (de `objects/`) pasaron a `escenas/`.
- **Scripts raíz organizados por sistema** en `scripts/{sistema,jugador,planeta,maquinas,items}`.
- **Recursos**: `car/cubo/pelota.tres` → `recursos/`; `water.gdshader` → `shaders/`;
  imágenes del hook → `assets/`.
- **Addon del gancho**: `grappling-hook-3d-main/addons/grappling_hook_3d` → `addons/grappling_hook_3d`;
  el resto del repo descargado → `_proximos_proyectos_2026-08-16/grappling-hook-demo/`.
- `project.godot` actualizado (`run/main_scene` y los 3 autoloads de rutas cambiadas) y
  `.godot/uid_cache.bin` regenerado.

**Lección**: cerrar el editor antes de cualquier operación de archivos del proyecto.

---

## Advertencias conocidas (inofensivas, preexistentes)

- `bulldozer.gd:53` — la variable local `brake` tapa una propiedad de `VehicleBody3D` (shadowing). Solo estilo, no rompe nada.
- `VoxelStreamSQLite: The database path hasn't been set` — un nodo de stream voxel sin base de datos configurada en la escena del planeta.
- `tile.tres` (Water-Ripple): "Height mapping is not supported on triplanar materials" — configuración del material del addon.
- Si al arrancar aparecen avisos `ext_resource, invalid UID ... using text path instead` de shaders: es el registro de uids (`.godot/uid_cache.bin`) desactualizado por los renombrados. Se corrige cerrando Godot y borrando `.godot/uid_cache.bin` (se regenera solo). Los recursos cargan igual por ruta de texto.

## Pendiente

Nada pendiente de la reorganización (completada el 2026-08-16). Posibles mejoras futuras:
renombrar `hook_availible.png` → `hook_available.png` y revisar typos históricos en nombres
de código (`coin_bornze`, `prosesador`, `terrarin`) si algún día molestan — requieren sed de
referencias igual que los movimientos ya hechos.

Las librerías `shaders/`, `models/`, `materials/` y `FBX_format/` **se conservan completas
para uso futuro** (decisión del autor, 2026-08-16).

## Restaurar algo del archivo

```bash
# Ejemplo: devolver el addon massimo
mv _backup_eliminados_2026-08-16/addons/massimo addons/
```

La carpeta `_backup_eliminados_2026-08-16/` se puede borrar cuando se confirme que nada
falta (libera ~118 MB). `_proximos_proyectos_2026-08-16/` es material para futuros juegos:
conviene mantenerla.
