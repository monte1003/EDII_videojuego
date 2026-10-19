# EDII_juego

Juego 3D en Godot **4.7.2** (Forward+) para Estructura de Datos II. Código y comentarios en inglés; textos de UI en español.
Rutas del ejecutable y del proyecto: ver `CLAUDE.local.md` (`$GODOT`, `$PROJECT`).

## Estructura
- `scenes/{menus,characters,levels,ui}` y `scripts/` con las mismas carpetas, más `autoload/`, `data_structures/`, `player/`. `resources/characters/*.tres` (`CharacterData`) y `assets/`.
- Escena principal: `res://scenes/menus/main_menu.tscn`. Único nivel: `scenes/levels/test_world.tscn`.
- Autoloads: `GameState`, `CustomCursor`, `ScreenFlow`, `ColorFilter`, `UiSound`.
- `ScreenFlow` navega con un árbol (`ScreenTree`); las pantallas nuevas se registran en `ScreenFlow._ready()`.
- Estructuras propias: `AVLTree`, `ScreenTree` en `scripts/data_structures/`.
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
