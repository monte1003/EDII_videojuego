# RumbleNet (Party Game) — Entrega Final

**Asignatura:** Estructura de Datos II · **Universidad del Norte**
**Lenguaje / motor:** GDScript sobre Godot Engine 4 (3D low poly)
**Integrantes:** Axel Tornadow · Isaac Monterrosa Guzmán · Juan Diego Vizcaino · María

---

## 🎮 Descripción del juego

**RumbleNet** es un *party game* de 1 a 4 jugadores enfocado en el **uso saludable de las redes sociales**. Los jugadores esquivan y enfrentan distracciones digitales (notificaciones, trolls, tendencias, la presión de la selfie perfecta) en un entorno caótico y competitivo que fomenta la "desconexión" y los hábitos digitales responsables. No hay preguntas explícitas: el mensaje se transmite por la mecánica.

### Formato de una partida
- Una partida son **5 rondas** de 1.5 a 2 minutos: los **5 minijuegos, cada uno una vez, en orden aleatorio**.
- Minijuegos: **Carrera del feed**, **La calle**, **SocialDrop**, **Guerra de Tendencias** y **La Selfie Perfecta**. Cada uno tiene su mapa, obstáculos y sistema de puntos.
- Al final de cada ronda se muestra el resumen de posiciones; al terminar las 5 rondas se suman los puntos y se muestra una **animación de podio** con coronas de bronce, plata, oro y diamante.
- **Modos:** *Singleplayer* (contra bots, con resumen de rendimiento y mejores puntajes guardados) y *Multijugador local* en red LAN.

### Requerimientos del laboratorio
| Requerimiento | Cómo se cumple |
|---|---|
| Componente aleatorio y de habilidad | Orden de rondas y semillas aleatorias (árbol de decisión); obstáculos y eventos aleatorios; el resultado depende de la destreza del jugador. |
| Componente inclusivo | Menú de **Accesibilidad** con **filtros de daltonismo**, selección de personajes/skins, indicaciones visuales. |
| Árboles y grafos | Ver secciones de las entregas 1 y 2 (AVL, árbol de decisión, árbol de pantallas, grafo ponderado con Dijkstra, min-heap). |
| Multijugador local cliente-servidor con sockets | Ver sección de la entrega final (TCP + UDP, hilos). |
| Todo de forma gráfica | Interfaz y juego 3D completos en Godot. |
| Ayuda y usabilidad | Páginas de ayuda por minijuego, mensajes en juego, sonidos, podio y recompensas. |
| Confiabilidad | Los mensajes de red inválidos se descartan; desconexiones y entradas erróneas no cierran el juego. |

---

## 🌳 Primera entrega — Árboles e interfaz gráfica

Se implementaron **tres árboles**, cada uno resolviendo un problema concreto del juego. Código en `scripts/data_structures/` y `scripts/session/`.

### 1. Árbol AVL — ranking y podio (`scripts/data_structures/avl_tree.gd`)
- **Problema que resuelve:** mantener ordenados los puntajes de los jugadores para el resumen de cada ronda y el podio final.
- **Por qué un AVL:** un árbol binario de búsqueda **auto-balanceado**: inserta en `O(log n)` y nunca se degenera en una lista aunque los puntajes lleguen ya ordenados. Cada nodo guarda una **clave compuesta** (puntos → mejor ronda individual como desempate → id de jugador), de modo que **dos jugadores nunca comparten clave**. Se rebalancea con rotaciones simples y dobles (`left_rotate` / `right_rotate`, factor de balance en `get_balance`); el contador `rotations` permite mostrar el balanceo.
- **Cómo se recorre:** **recorrido inorden** (`get_inorder_array`) sobre la clave, que devuelve el ranking directamente; `places()` convierte el recorrido en posiciones 1.º, 2.º, 3.º, 4.º.
- **Uso:** `GameSession.ranking()` y `PodiumPlan.build()` / `podium_ceremony.gd` lo usan para ordenar la tabla y ubicar a los jugadores en el podio.

### 2. Árbol de decisión — armado de la partida (`scripts/session/decision_tree.gd`)
- **Problema que resuelve:** decidir qué minijuego se juega en cada una de las 5 rondas sin repetir ninguno.
- **Estructura:** cada **nivel** del árbol es una ronda y cada **hijo** es un minijuego que aún no se ha jugado en ese camino (`DecisionTree.build(pool, rounds)`). Una partida es un **camino raíz → hoja**.
- **Cómo se recorre:** `random_path()` desciende desde la raíz eligiendo al azar un hijo por nivel. `RoundPlanner` lo usa para generar el orden de la sesión; en multijugador el servidor lo calcula una sola vez y lo envía a todos.

### 3. Árbol general de pantallas — navegación (`scripts/data_structures/screen_tree.gd`, `scripts/autoload/screen_flow.gd`)
- **Problema que resuelve:** organizar el flujo de menús y escenas (Menú principal → Personajes → Sala → minijuegos → Resultados → Podio; Opciones → Controles/Gráficos/Accesibilidad).
- **Estructura:** árbol general (cada nodo con lista de hijos y referencia débil al padre). Soporta `find`, `path_to` (ruta raíz → pantalla, útil para el botón "atrás") y recorrido **preorden** (`preorder`).

---

## 🕸️ Segunda entrega — Grafos integrados al juego

### Grafo ponderado dirigido + Dijkstra (`scripts/data_structures/weighted_graph.gd`)
- **Representación:** **listas de adyacencia** (`Edge` con destino, peso y estado `enabled`). Un puente de doble sentido se guarda como dos arcos, así cada sentido puede tener un costo distinto (`set_weights`) y existen caminos de un solo sentido.
- **Algoritmo:** **Dijkstra** propio (`shortest_path`, `costs_from`) con soporte para **vértices prohibidos** y **penalizaciones** por tráfico; devuelve un `PathResult` (ruta, costo, penalización).
- **Cola de prioridad:** **min-heap binario** propio (`scripts/data_structures/min_heap.gd`) con desempate por orden de inserción, para que Dijkstra sea determinista.
- **Dinámico:** las aristas se pueden habilitar/deshabilitar en vivo (puentes que se cierran, trampas) y un contador `version` avisa a los bots cuando deben recalcular su ruta.

### Dónde se usa en la mecánica
- **Carrera del feed** (`level_01_layout.gd`) y **Guerra de Tendencias** (`arena_layout.gd`): el mapa es un grafo de plazas y puentes con costos, atajos estrechos y sentidos únicos.
- **Bots perseguidores** (`scripts/bots/`): cada rol (emboscada, flanqueo, guardia…) elige un vértice objetivo y calcula la ruta con Dijkstra, esquivando vértices prohibidos y zonas con tráfico; recalculan cuando el grafo cambia.
- **La Selfie Perfecta** (`selfie_layout.gd`): el dron vuela entre fotos por la ruta de menor costo del grafo.
- **Depuración visual:** `graph_debug_view.gd` dibuja vértices, aristas y la ruta calculada sobre el nivel para poder ver el efecto de la estructura.

---

## 🌐 Entrega final — Multijugador local cliente-servidor con sockets

### Arquitectura de red
El juego usa un esquema **cliente-servidor** con **sockets**. Un computador **abre una sala** y actúa como **servidor** (y además juega); hasta **3 computadores más** (capacidad total: 4 jugadores) se conectan como **clientes**. Código en `scripts/net/`:

| Archivo | Responsabilidad |
|---|---|
| `net_room.gd` | Nodo central: rol (OFFLINE / HOST / CLIENT), sala, lobby, inicio de rondas, puntos. Hilos de aceptación y de anuncio (servidor) y de escucha (cliente). |
| `net_link.gd` | Una conexión **TCP** (`StreamPeerTCP`) con **su propio hilo**, con bandeja de entrada y de salida protegidas por `Mutex`. |
| `net_protocol.gd` | Protocolo: mensajes **JSON** con prefijo de longitud de 4 bytes (big endian), validación de tipo y tope de 64 KB. |
| `net_puppets.gd` | Representa en cada pantalla a los jugadores remotos ("marionetas") con el estado que llega por red. |

- **TCP, puerto 47820** — canal fiable de juego (`TCPServer` en el servidor, `StreamPeerTCP` en los clientes).
- **UDP broadcast, puerto 47821** — **descubrimiento de salas**: el servidor anuncia su sala cada segundo a `255.255.255.255` y los clientes escuchan y listan las salas encontradas, o se conectan escribiendo la IP.
- **Hilos (`Thread`) + `Mutex`:** los hilos solo mueven bytes entre el socket y colas; el hilo principal es el único que lee las colas y modifica el juego, de modo que la red nunca bloquea el renderizado ni genera condiciones de carrera.
- **Servidor autoritativo:** el servidor decide la sala, el orden de las rondas (árbol de decisión) y sus **semillas aleatorias** (todos ven el mismo mapa), cuándo arranca cada ronda (`loaded` → `go`, sincronizando a todos) y **reúne los puntos de todos** para calcular el ranking (AVL). Cada cliente mueve a su propio jugador y envía su estado (`st`, `hit`).
- **Mensajes del protocolo:** `hello`, `welcome`, `reject`, `room`, `ready`, `profile`, `start`, `loaded`, `go`, `st`, `hit`, `points`, `scores`, `advance`, `ping`, `pong`, `bye`.
- **Robustez:** `ping`/`pong` cada segundo y desconexión si un equipo calla más de 3 s; mensajes rotos, demasiado largos o de tipo desconocido se descartan sin afectar el juego; versión y nombre de juego se verifican al conectar.

### Red física utilizada
Para probar y presentar el modo multijugador se montó una **red de área local (LAN) cableada** con:
- **1 router** como punto central de la red (reparte direcciones IP por DHCP y conecta los equipos).
- **Cables Ethernet LAN (UTP)**, uno por equipo, conectando cada computador al router.
- **3 computadores** conectados a esa red: uno hace de **servidor** (abre la sala y también juega) y los otros dos se unen como **clientes**.

Al estar todos en la misma subred, el broadcast UDP permite que los clientes **encuentren la sala automáticamente**, y las partidas se juegan por TCP sin necesidad de Internet. No se requiere ninguna configuración adicional más que permitir el juego en el firewall de Windows para los puertos 47820 (TCP) y 47821 (UDP).

### Cómo jugar en red
1. Conectar los computadores al router con cables LAN.
2. En el equipo servidor (en la Sala): **Crear sala**.
3. En los otros equipos: **Unirse a una sala** (se listan las salas encontradas o se escribe la IP del anfitrión) y **Conectar**.
4. Cada jugador elige personaje y marca **listo**; el servidor inicia la partida y las 5 rondas se juegan sincronizadas, terminando con el podio.

---

## 🛠️ Cómo ejecutar
1. Instalar **Godot 4.x**.
2. Abrir `project.godot` desde el gestor de proyectos e iniciar la escena principal (F5), o importar y exportar el ejecutable.

## 📁 Estructura del repositorio
```
scripts/data_structures/  AVL, min-heap, grafo ponderado, árbol de pantallas
scripts/session/          árbol de decisión, planificador de rondas, catálogo de minijuegos
scripts/net/              sockets, protocolo, sala cliente-servidor
scripts/bots/             bots que usan Dijkstra sobre el grafo
scripts/levels/           minijuegos y diseño de niveles
scripts/menus/            menús, lobby, podio, accesibilidad
```
