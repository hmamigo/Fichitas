# Fichitas

Juego 3D de fichas para aprender jugando. Las fichas parecen pines esmaltados sobre un suelo de cubos de colores, y la cámara viaja de una zona a otra del mismo mundo: menú, materias, tablero y álbum.

Hecho con **Godot 4.7.2** (renderizador *Compatibility*) para **Android**, en vertical.

## Cómo se juega

Hay dos modos, que se eligen en un paso aparte justo antes de jugar (después de elegir la materia o el recorrido general):

- **Memoria**: las fichas están boca abajo y hay que descubrir las parejas.
- **Asociación**: las fichas están visibles y hay que unir cada una con su pareja, seleccionándola o arrastrándola.

Las parejas pueden ser de varios tipos: pregunta ↔ respuesta, imagen ↔ palabra, concepto ↔ definición, elemento ↔ símbolo.

Los niveles son progresivos: cada uno suma más parejas. Al completar un nivel no hay cronómetro ni estrellas; solo se avanza al siguiente. El tablero es una cuadrícula adaptable, con filas y columnas calculadas según la cantidad de parejas.

## Un solo mundo, varias estaciones

No hay pantallas 2D que se cambian. Todo ocurre sobre el mismo suelo de cubos de colores, y la cámara se mueve en horizontal entre estaciones:

| Estación | Qué es |
|---|---|
| **Menú** | Vista lejana, con el logo y las opciones: jugar, recorrido general y álbum. |
| **Materias** | Fichas de cada materia. Se hace zoom y se recorren a mano, igual que en el tablero. |
| **Modo** | Paso "¿Cómo quieres jugar?": dos losetas grandes, Memoria y Asociación. La partida empieza al tocar una. |
| **Tablero** | La partida. La cámara baja hasta la posición de juego. |
| **Nivel completado** | Una loseta 3D real en el piso, a la que se llega moviendo la cámara. |
| **Álbum de datos curiosos** | Fichas iguales a las del juego, con la cámara moviéndose en vertical. |

La cámara no rota libremente: solo hace zoom y se desplaza.

## Estilo visual

- Estilo educativo, con colores vivos y aspecto de juguete de calidad.
- Fichas cuadradas de esquinas redondeadas, como pines esmaltados, con bisel metálico fino en ambas caras.
- Filo dorado, placas color crema y marco azul en el tablero. Esta misma estética se usa en el menú, la barra superior, las materias y "Nivel completado".

## Contenido

Las materias son colecciones temáticas (matemáticas, química, física, inglés, biología, historia, etc.). Los símbolos, fórmulas y gráficas se incluyen como imágenes.

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

## Estado

En desarrollo. Lo que viene:

- Paquetes externos de fichas, con más pulido.
- Carga de imágenes del usuario.

Por ahora el juego no tiene materias premium, códigos de desbloqueo ni donaciones. Primero se termina el juego y se ve si gusta.

## Licencia

TODO: indicar la licencia del proyecto.
