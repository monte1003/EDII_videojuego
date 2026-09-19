# Guía de Diseño de Niveles: El Árbol AVL

Este documento explica cómo está configurada la lógica del primer nivel y cómo el **Diseñador de Niveles** debe armar la escena en la interfaz gráfica de Godot sin tocar el código.

## 📌 ¿Qué cambió en el código?
1. **Se eliminó la generación de plataformas por código:** Ahora el motor espera que las plataformas estén colocadas manualmente en la escena `first_level.tscn`.
2. **Sistema de Identificación (ID):** Se agregó una variable exportada (`node_id`) al script `platform.gd`. Esto crea un campo visible en el Inspector de Godot para enumerar cada plataforma.
3. **Escaneo Automático:** Al darle Play al juego, el script `test_world.gd` escanea la escena, busca todas las plataformas y las conecta internamente al Árbol AVL según el `node_id` que el diseñador les haya asignado.

---

## 🛠️ Instrucciones para el Diseñador de Niveles

Para que el árbol matemático funcione con las físicas 3D, es obligatorio tener **7 plataformas** en el nivel, cada una con su ID correcto. Sigue estos pasos:

### 1. Colocar las plataformas
- Abre la escena principal: `scenes/levels/first_level.tscn`.
- Arrastra el recurso de la plataforma (`assets/models/platform.tscn`) 7 veces hacia tu mundo 3D.
- Acomódalas libremente en el espacio para formar un árbol colgante de 3 niveles.

### 2. Asignar el ID (MUY IMPORTANTE)
Para que el código sepa quién es quién (quién es la raíz, quién es hijo de quién), debes enumerar las plataformas en Godot:

1. Haz clic sobre una plataforma en tu escena 3D.
2. Ve al **Inspector** (el panel de la derecha).
3. Bajo la sección *AVL Platform*, busca la propiedad **Node Id**.
4. Escribe el número correspondiente según este mapa:

```text
Nivel 1 (La Cima):
          [ Nodo 1 (Raíz) ]

Nivel 2 (Intermedio):
      [ Nodo 2 ]     [ Nodo 3 ]

Nivel 3 (La Base donde caen las cajas):
   [ Nodo 4 ] [ Nodo 5 ]   [ Nodo 6 ] [ Nodo 7 ]
```

*Nota: Asegúrate de no repetir números y de que vayan exactamente del 1 al 7. Si te falta uno, el árbol lógico no se conectará bien.*

### 3. Listo para jugar
¡Eso es todo! Solo con colocar las plataformas y ponerles su número en el Inspector, el Gestor (`test_world.gd`) se encargará de hacerlas rotar o inclinarse cuando el peso de las cajas las desestabilice.
