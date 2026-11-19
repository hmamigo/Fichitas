# Fichitas

Juego 3D de fichas para aprender jugando. Las fichas parecen pines esmaltados sobre un suelo de cubos de colores, y la cámara viaja de una zona a otra del mismo mundo: menú, materias, modo, tablero, nivel completado y álbum.

Hecho con **Godot 4.7.2** (renderizador *Compatibility*) para **Android**, en vertical.

## Cómo se juega

Hay dos modos, que se eligen en un paso aparte justo antes de jugar (después de elegir la materia o el recorrido general):

- **Memoria**: las fichas están boca abajo y hay que descubrir las parejas.
- **Asociación**: las fichas están visibles y hay que unir cada una con su pareja, seleccionándola o arrastrándola.

Las parejas pueden ser de varios tipos: pregunta ↔ respuesta, imagen ↔ palabra, concepto ↔ definición, elemento ↔ símbolo.

Los niveles son progresivos: cada uno suma más parejas. Al completar un nivel no hay cronómetro ni estrellas; solo se avanza al siguiente. El tablero es una cuadrícula adaptable, con filas y columnas calculadas según la cantidad de parejas.

### Cómo empieza una partida

1. En el menú, tocar **Jugar** (o **Recorrido general**).
2. Elegir una materia (o el recorrido general).
3. Elegir **Memoria** o **Asociación** en el paso "¿Cómo quieres jugar?".
4. Jugar el nivel. Al completarlo, **Siguiente nivel** conserva el modo elegido.

El álbum de datos curiosos se abre como una loseta más del menú.

## Un solo mundo, varias estaciones

No hay pantallas 2D que se cambian. Todo ocurre sobre el mismo suelo de cubos de colores, y la cámara se mueve en horizontal entre estaciones:

| Estación | Qué es |
|---|---|
| **Menú** | Vista lejana, con el logo y una mesa "Menú principal" con las opciones: jugar, recorrido general y álbum. |
| **Materias** | Una mesa por grupo (Para todos, Peques, Exploradores, Nerds y Más), cada una con su color. Se hace zoom y se recorre a mano, igual que en el tablero. |
| **Modo** | Paso "¿Cómo quieres jugar?": dos losetas grandes, Memoria y Asociación. La partida empieza al tocar una. |
| **Tablero** | La partida, con su título (materia, nivel y modo) sobre la mesa. La cámara baja hasta la posición de juego. |
| **Nivel completado** | Una mesa a la derecha del tablero, con el trofeo, las parejas del nivel y el botón de seguir. |
| **Álbum de datos curiosos** | Fichas iguales a las del juego, con la cámara moviéndose en vertical. |

La cámara no rota libremente: solo hace zoom y se desplaza.

## Estilo visual

- Estilo educativo, con colores vivos y aspecto de juguete de calidad.
- Fichas cuadradas de esquinas redondeadas, como pines esmaltados, con bisel metálico fino en ambas caras.
- Filo dorado, placas color crema y marco azul en el tablero. Esta misma estética se usa en el menú, el paso de modo, las materias, "Nivel completado" y el álbum. Lo que se toca es una loseta dorada con relieve; los títulos y datos van planos sobre la mesa, y la barra superior solo lleva el botón de volver.
- Cada grupo de materias tiene su mesa con el marco de su color, y los iconos son a color.
- El suelo está hecho de cubos de tres tamaños; los altos quedan lejos de las mesas para que no compitan con ellas.

## Contenido

Las materias son colecciones temáticas: matemáticas, química, física, inglés, biología, geografía, astronomía e informática, y, para los más pequeños, Animales (cada animal con su comida) y Contar (cantidades y números), que se juegan sin leer. Las materias se agrupan en tres categorías: Peques, Exploradores y Nerds. Los símbolos, fórmulas y gráficas se incluyen como imágenes. Las materias de Peques no entran en el recorrido general: solo se juegan desde su propia materia.

Los paquetes de fichas son archivos JSON. Hay paquetes incluidos en el juego y también se pueden cargar paquetes externos desde el selector de archivos del celular ("Cargar paquete").

## Sonido

Efectos simples: giro de ficha, acierto y error. Por ahora no hay música.

## Requisitos para desarrollar

- Godot **4.7.2**
- Renderizador **Compatibility**
- Un dispositivo Android (o emulador) para probar el tacto, el rendimiento y el vuelo de cámara

## Ejecutar el proyecto

1. Clonar el repositorio:
   ```bash
   git clone https://github.com/hmamigo/Fichitas.git
   ```
2. Abrir la carpeta del proyecto con Godot 4.7.2.
3. Ejecutar la escena principal (F5), o exportar a Android para probar en el dispositivo.

## Pruebas

Pruebas automáticas sin ventana (terminan con código 0 si todo pasa e imprimen `Resultado: TODO OK`):

```bash
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/test_game.gd
godot --headless --path . --script res://tests/test_flow.gd
godot --headless --path . --script res://tests/test_review.gd
godot --headless --path . --script res://tests/test_packs.gd
```

`tests/_shot.gd` genera capturas en `/tmp/opencode/` para revisar el aspecto; necesita pantalla y no forma parte de las pruebas.

En Android, exportar con el preset **Android**, instalar con `adb install -r <apk>` y revisar los errores con `adb logcat -s godot`.

## Estado

En desarrollo. Lo que viene:

- Probar el rendimiento y el tacto en un celular real (el suelo tiene unos 9 000 cubos).
- Más materias para Peques (colores, formas, mamá y cría).
- Paquetes externos de fichas, con más pulido, y carga de imágenes del usuario.

Por ahora el juego no tiene materias premium, códigos de desbloqueo ni donaciones. Primero se termina el juego y se ve si gusta.

## Licencia

Todavía no hay una licencia definida para el código del juego: todos los derechos reservados por el autor.

Los recursos de terceros conservan sus licencias:

- Iconos de `assets/icons/`: @icons, licencia MIT (ver `assets/icons/LICENSE.txt`).
- Fuentes Nunito y Baloo 2: SIL Open Font License 1.1 (ver `fonts/LICENSE-*.txt`).
- Ilustraciones de `packs/ani/` y `packs/contar/` e iconos a color de `assets/emoji/`: Noto Emoji (Google), Apache License 2.0 (ver `packs/ani/LICENSE.txt`, `assets/emoji/LICENSE.txt` y los `LICENSE-Apache-2.0.txt` de cada carpeta).
