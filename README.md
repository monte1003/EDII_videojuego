# Proyecto: Disconnect (Party Game)
**Asignatura:** Estructura de Datos II
**Universidad del Norte**

---

## 🎮 Descripción del Juego
**"Disconnect"** es un juego multijugador local (1 a 4 jugadores) tipo *party game* enfocado en la concientización del uso saludable de las redes sociales. El objetivo es divertirse en un entorno caótico y competitivo mientras los jugadores enfrentan obstáculos que simulan distracciones digitales, trolls, y notificaciones, fomentando la "desconexión" y los hábitos saludables.

### Características Principales:
- **Formato por Partidas:** Cada partida consta de 4 rondas rápidas de 1.5 a 2 minutos.
- **Variedad por Ronda:** Cada ronda ofrece un mapa diferente, modalidad, obstáculos, diseño único y un sistema de puntos independiente.
- **Modos de Juego:**
  - **Singleplayer:** Permite jugar en solitario contra el entorno o bots. Al final, se guarda un resumen del rendimiento y efectividad del jugador.
  - **Multiplayer:** Competencia local entre amigos. Al final de cada ronda se muestra un resumen de las posiciones y puntos actuales. Al concluir las 4 rondas, se realiza una sumatoria total y se muestra una **animación de podio** celebrando las posiciones finales.
- **Estilo Visual:** 3D Low Poly para garantizar un excelente rendimiento (incluso en hardware de bajos recursos) sin perder el estilo caótico, colorido y divertido.

---

## 🌳 Primera Entrega: Aplicación de Árboles

De acuerdo con los lineamientos del **Laboratorio**, se debe evidenciar la implementación de estructuras de datos no lineales, específicamente los **Árboles**, y justificar su uso en la lógica del juego.

### 1. Sistema de Posiciones y Podio (Árbol Binario de Búsqueda / AVL)
- **Problema que resuelve:** Durante el juego, y en especial al final de cada ronda y de la partida, es necesario mantener los puntajes de los jugadores organizados para actualizar las posiciones, generar el resumen y ubicar a los jugadores en el podio final.
- **Por qué se eligió esta variante:** Utilizar un **Árbol Binario de Búsqueda (ABB)** o un **Árbol AVL (Balanceado)** permite insertar los puntajes de manera dinámica y mantenerlos ordenados de forma eficiente (complejidad $O(\log n)$). A diferencia de un arreglo simple, el árbol permite una gestión dinámica ideal si se planea incluir historiales de puntajes o tablas de clasificación (Leaderboards) más grandes.
- **Cómo se recorre:** Para mostrar las posiciones finales en el podio, se realiza un **recorrido Inorden (In-order)**. Este recorrido visita el subárbol izquierdo, luego la raíz, y finalmente el subárbol derecho, lo que devuelve los puntajes estructurados de menor a mayor (o mayor a menor, según la lógica de inserción), entregando el ranking de posiciones de forma directa.

### 2. Generación de Rondas y Mapas (Árbol de Decisión o Árbol General)
- **Problema que resuelve:** El juego requiere estructurar 4 rondas distintas combinando mapas, modalidades y obstáculos de forma aleatoria pero coherente, asegurando que las rondas tengan una progresión o no repitan los mismos componentes.
- **Por qué se eligió esta variante:** Un árbol permite modelar los posibles caminos o combinaciones que puede tomar una partida. Cada nivel del árbol puede representar una ronda, y los nodos hijos las combinaciones de mapa y modalidad disponibles.
- **Cómo se recorre:** Mediante un recorrido desde la raíz hasta una hoja, seleccionando nodos aleatorios en cada nivel, se construye dinámicamente la estructura completa de la partida antes de iniciar.

---

## 🛠️ Tecnologías y Motor
- **Motor:** Godot Engine (El repositorio actual contiene archivos `.godot`). 
