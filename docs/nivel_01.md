# Nivel 1: Escapa del feed

## Cómo se juega
- Entrada normal: menú → Jugar → personaje → tutorial → **Ir al nivel 1**. Para pruebas, también se abre `scenes/levels/level_01.tscn` con F6.
- Llegar a la plataforma **M** antes de 120 s y con 3 intentos. Los bots salen 5 s después de la cuenta regresiva.
- Controles (tomados del Input Map): WASD, ESPACIO, mouse, **E** interactuar en las estaciones, **F3** grafo de depuración, **F4** demostración de Dijkstra, **Esc** pausa.
- Estaciones: **E** Bloquear (cierra el puente E-H a los bots 6 s, recarga 15 s), **F** Silenciar (radio de detección 18 → 6 durante 8 s, recarga 20 s), **D** Pausa digital (protección hasta 3 s dentro del refugio, recarga 20 s). **H** es el checkpoint. Reaparecer da 2 s de protección.

## Grafo
- `scripts/data_structures/weighted_graph.gd`: listas de adyacencia, `add_vertex`, `add_edge`, `neighbors`, `set_edge_enabled` (ambos sentidos), `shortest_path` (Dijkstra con `min_heap.gd`) que devuelve `found`, `path`, `cost` y `reason` cuando no hay camino. No contiene nodos ni posiciones.
- `scripts/levels/level_01_layout.gd`: única tabla de vértices, posiciones y puentes. El grafo y el escenario físico salen de la misma tabla, así que cada arista es un puente real.
- **Peso** = costo de cruzar el puente, aproximadamente la distancia entre centros / 7 m (2 = puente corto, 3 = largo). Ambos sentidos cuestan igual.
- Los bots nunca planifican hacia **M** (`BOT_FORBIDDEN`). Los saltos del jugador no son aristas.
- Decisión: el mapa del "documento de diseño formal" que la guía dice que prevalece no estaba disponible. Se usaron las conexiones de la lámina 1 de la guía, el texto (J-M, I-M, sin H-M) y los costos de la lámina 5: B→J cuesta 6 por B-E-H-J y 11 por B-E-D-G-J con E-H bloqueada. Los demás pesos son valores propios editables en `EDGES`.
- Decisión: `Nivel 1.pdf` (en la carpeta del curso) describe un minijuego distinto (AVL de cajas); la guía y el enunciado de esta tarea piden el nivel de grafos, que es lo implementado.

## Bots
- `ChaserBot` (IA compartida) planifica con Dijkstra y camina con física. Para cruzar de u a v va primero a una "compuerta" dentro de u, luego (comprometido) por el puente hasta una compuerta dentro de v. Una vez comprometido, termina el cruce aunque el puente se bloquee.
- La plataforma del jugador viene de sensores `Area3D` (`PlayerLocator`), no de distancias. En el aire se conserva el último lugar válido. Si el jugador está en un puente abierto, el bot apunta al extremo que lo obliga a cruzarlo; si está bloqueado, espera en el extremo más cercano.
- Sin detección (jugador fuera del radio) el bot recuerda el último destino, y tras `lose_time` patrulla vecinos.
- Empujón: aviso ❗ de 0.7 s, impulso moderado, enfriamiento y protección tras el golpe.
- Apariencias: `resources/bots/{trol,spam,bulo,espejo}.tres`. Para usar un modelo final, asignar `model_scene` en el `.tres`; la IA no cambia.

## Evidencia académica
- **F3** muestra ids de vértices, puentes abiertos (verde) y bloqueados (rojo, con costo) y la ruta de cada bot con su color, destino, costo y "SIN CAMINO" cuando corresponde. Se dibuja desde el mismo `WeightedGraph` que usa la IA.
- **F4** lanza la demostración reproducible: un bot en B va a J (ruta B-E-H-J, costo 6); se bloquea E-H y la ruta pasa a B-E-D-G-J (costo 11).
- Árbol de navegación: `ScreenFlow` guarda las pantallas en un `ScreenTree` (raíz `main_menu`, hijo `character_select`, hijo `test_world`, hijo `level_01`). El nivel 1 es un nodo de ese árbol, y el rastro "Menú principal › Personajes › Partida › Nivel 1" sale de `path_to`. Esto es la estructura de datos propia; la jerarquía de nodos de Godot no lo es.

## Pruebas
- `godot --headless --path . --script res://scripts/tests/graph_check.gd` verifica costos 6 y 11, bloqueo y reactivación, caso sin camino y la cola de prioridad.
