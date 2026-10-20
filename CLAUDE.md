# EDII_juego

Juego 3D en Godot **4.7.2** (Forward+) para Estructura de Datos II. Código y comentarios en inglés; textos de UI en español.
Rutas del ejecutable y del proyecto: ver `CLAUDE.local.md` (`$GODOT`, `$PROJECT`).

## Estructura
- `scenes/{menus,characters,levels,ui}` y `scripts/` con las mismas carpetas, más `autoload/`, `data_structures/`, `player/`. `resources/characters/*.tres` (`CharacterData`) y `assets/`.
- Escena principal: `res://scenes/menus/main_menu.tscn`. Niveles: `scenes/levels/test_world.tscn` (tutorial) y `scenes/levels/level_01.tscn` (nivel 1, detalles en `docs/nivel_01.md`).
- Flujo: menú → selección de personaje → tutorial (`test_world`) → "Ir al nivel 1" → `level_01`. En `ScreenFlow` el árbol es `character_select → test_world → level_01`.
- Autoloads: `GameState`, `CustomCursor`, `ScreenFlow`, `ColorFilter`, `UiSound`.
- `ScreenFlow` navega con un árbol (`ScreenTree`); las pantallas nuevas se registran en `ScreenFlow._ready()`.
- Estructuras propias en `scripts/data_structures/`: `AVLTree`, `ScreenTree`, `WeightedGraph` (listas de adyacencia + Dijkstra) y `MinHeap`. No usar `AStar3D` ni `NavigationServer` para los bots.
- Bots: `scripts/bots/` (`ChaserBot` con la IA, `BotAppearance` recurso de apariencia, `BotVisual` primitivas provisionales); recursos en `resources/bots/`. El nivel 1 lo arman `Level01Layout` (tabla única de vértices/puentes/costos), `Level01World`, `PlayerLocator`, `LevelHud`, `LevelHelp` (ayuda para jugador casual, se abre al inicio, con F1, con el botón "?" o desde la pausa) y `GraphDebugView`.
- Menú **Test** (botón TEST arriba a la derecha del menú principal → pantalla `test_games`, `scenes/menus/test_menu.tscn`, reutiliza `options_menu.gd`): muestra un botón por cada hijo de `test_games` en `ScreenFlow`. Los juegos de prueba nuevos se registran ahí con `tree.add_screen(&"test_games", id, título, ruta)`.
- Minijuego `scenes/levels/multiplayer_game1.tscn` (pantalla `multiplayer_game1`, hija de `test_games`): calle sobre el eje X con aceras; autos (bloques) y peatones (cápsulas) avanzan hacia +X y aceleran durante la ronda; el jugador (`StreetRunner`, modelo a escala 1.4) solo se mueve en Z (W/S) y salta (ESPACIO, decorativo: el choque ignora la altura). Cada choque lo empuja hacia la línea FIN y hacia un lado; la invulnerabilidad dura mínimo 1.2 s y sigue mientras toque un obstáculo. Máximo 2 autos en paralelo; un tanque (1 %, `tank_chance`) ocupa dos carriles y cuenta como dos autos. Los peatones solo salen en la mitad de arriba o de abajo de cada acera (`Lane.slot_offset`). Pierde al cruzar FIN; gana al aguantar 60 s (la calle se congela, la cámara se acerca de frente y luego sale el panel). Scripts: `multiplayer_game1.gd` (reglas, todo exportado), `street_runner.gd`, `street_obstacle.gd`, `street_world.gd`, `street_hud.gd`.
- Acciones nuevas del Input Map: `interact` (E), `toggle_debug` (F3), `demo_route` (F4), `help` (F1). Los PDF explicativos están en `docs/`.
- Personajes: fire, lightning, plant, water (escena + `.tres` cada uno).
- `scripts/level_logic/` y `scripts/network/` existen vacíos (no versionados por git).

## Convenciones GDScript (observadas)
- Tabs, tipado estático (`: float`, `-> void`), `class_name` + `extends` arriba, `_privado` con guion bajo.
- `@export` y `@onready` con tipo; señales con parámetros tipados; `StringName` (`&"id"`) para ids de pantalla.
- Comentarios con `#Texto` (sin espacio), cortos y explicando el porqué.
- `push_error("Clase: mensaje")` para errores.

## Comandos (verificados con Godot 4.7.2)
Siempre con `timeout` y `--headless`:
```bash
timeout 180 "$GODOT" --headless --path "$PROJECT" --import                  # importar recursos
timeout 60  "$GODOT" --headless --path "$PROJECT" --quit-after 60           # carga escena principal + autoloads
timeout 60  "$GODOT" --headless --path "$PROJECT" --scene res://scenes/levels/test_world.tscn --quit-after 60
timeout 60  "$GODOT" --headless --path "$PROJECT" --check-only --script res://scripts/player/player.gd   # parseo de un script
timeout 60  "$GODOT" --path "$PROJECT" --scene <escena>                     # ejecutar con ventana (el usuario prueba)
```
- Buscar `ERROR`/`SCRIPT ERROR`/`Parse Error` en la salida. El aviso "ObjectDB instances were leaked" ya aparece en el estado base; ignorarlo.
```bash
timeout 60  "$GODOT" --headless --path "$PROJECT" --script res://scripts/tests/graph_check.gd   # grafo y Dijkstra (sale con 0 si todo pasa)
timeout 60  "$GODOT" --headless --path "$PROJECT" --scene res://scenes/levels/level_01.tscn --quit-after 120
```
- `--script` con `--check-only` no ve los autoloads: los errores de `GameState`/`ScreenFlow` ahí son falsos; comprobar cargando la escena.
- Estas comprobaciones solo prueban que carga y parsea, **no** la jugabilidad, la cámara, las animaciones ni el input.

## Reglas de edición
- Preservar referencias, UID (`.uid`, `uid://` en `.tscn`/`.tres`), señales y rutas de nodos (`$Ruta`, `@onready`, `NodePath`). Si se renombra o mueve algo, buscar y actualizar todas sus referencias.
- No editar a mano `.godot/` (caché, ignorada por git).
- Preferir editar archivos de texto `.tscn`/`.tres` con cambios mínimos; no reformatear.

## Git
- Antes de trabajar: `git status`. Al terminar: `git diff`. Preservar cambios ajenos a la tarea.
- No hacer pull, reset, merge, rebase, push ni cambiar de rama, ni commit, salvo petición expresa.

## Forma de trabajo
- Leer solo los archivos necesarios. Respuestas breves. Sin subagentes salvo que se pidan.
- Al terminar: qué cambió, qué se comprobó y qué debo probar manualmente en Godot.
