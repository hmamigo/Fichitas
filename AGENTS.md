# AGENTS.md

Guía para agentes (y personas) que trabajan en **Fichitas**: un juego 3D educativo de fichas hecho con Godot, solo para Android. Leé esto antes de tocar el código.

## Idioma y trato

- Comunicación, comentarios y mensajes de commit en **español**.
- Los nombres de código (variables, funciones, nodos) pueden estar en inglés o español, pero hay que seguir el criterio que ya use el archivo que se edita.
- El autor está aprendiendo inglés: si aparece vocabulario técnico en inglés, está bien, pero explicalo brevemente cuando no sea obvio.

## Stack

- **Godot 4.7.2**, GDScript.
- Renderizador **Compatibility**. No usar funciones que ese renderizador no soporte ni efectos pesados (iluminación global, reflejos en pantalla, sombras costosas, etc.).
- Plataforma: **Android**, orientación **vertical**. No se hace versión de escritorio.
- Entrada **táctil primero**: tocar, arrastrar, zoom con dos dedos.

## Concepto del juego

- Dos modos, elegibles en un paso aparte, después de elegir la materia y antes de entrar al tablero:
  - **Memoria**: fichas boca abajo, descubrir parejas.
  - **Asociación**: fichas visibles, seleccionar o arrastrar hasta su pareja.
- Relaciones entre fichas: pregunta ↔ respuesta, imagen ↔ palabra, concepto ↔ definición, elemento ↔ símbolo.
- Niveles progresivos: cada nivel suma más parejas.
- Tablero: cuadrícula adaptable, con filas y columnas calculadas según la cantidad de parejas.
- Al completar un nivel: solo avanzar. **Sin cronómetro ni estrellas.**
- Sonido: efectos simples (giro de ficha, acierto, error). **Sin música** por ahora.

## Arquitectura visual: un solo mundo con estaciones

Todo ocurre sobre el **mismo suelo de cubos de colores**. No se cambia de pantalla 2D: la **cámara viaja** entre estaciones.

- Estaciones: **menú**, **materias**, **modo**, **tablero**, **nivel completado** y **álbum de datos curiosos**.
- Menú, materias, modo y tablero están en **fila horizontal**, y la cámara se mueve en horizontal entre ellos.
- El paso **modo** ("¿Cómo quieres jugar?") va entre materias y tablero: el jugador elige Memoria o Asociación recién cuando ya eligió qué practicar. El menú principal no cambia modos.
- El álbum de datos curiosos es una estación 3D como Materias, con fichas iguales a las del juego y la cámara moviéndose en vertical. La cámara debe estar algo más alejada que en otras estaciones.
- "Nivel completado" es una **loseta 3D real** en el piso, a la que se llega solo moviendo la cámara.
- En Materias el usuario hace zoom y recorre las fichas a mano, igual que en el tablero.
- La cámara **no rota libremente**: solo zoom y desplazamiento.
- El fondo de cubos va algo alejado, y el menú un poco más abajo, no pegado al logo.
- No agregar pantallas 2D ni paneles de UI que rompan esta lógica. Si hace falta algo de interfaz (barra superior, botones), debe tener la misma estética que las fichas.

## Estilo visual (no romper)

- Educativo: colores vivos, aspecto de juguete de calidad.
- Fichas cuadradas de esquinas redondeadas, como pines esmaltados, con bisel metálico fino en ambas caras.
- Filo dorado, placas color crema, marco azul del tablero.
- La iluminación debe ser suave. Una versión anterior se veía con la luz exagerada, así que ante la duda, bajarla.
- Todo elemento nuevo (menú, barra superior, nivel completado, materias, álbum) debe parecer parte del mismo juego.

## Paquetes de contenido

- Los paquetes de fichas son **JSON**. Hay paquetes incluidos en el juego y también se pueden cargar paquetes externos ("Cargar paquete", con el selector de archivos de Android, que ya funciona).
- Las imágenes (símbolos, fórmulas, gráficas) las crea el autor y se usan como imagen, sin renderizar fórmulas dentro del juego.
- Pendiente: pulir los paquetes externos y la carga de imágenes del usuario.
- Cualquier cambio en el formato de los paquetes debe mantener compatibilidad con los existentes, o actualizarlos todos.

## Decisiones cerradas (no reintroducir sin que el autor lo pida)

- **No** hay materias premium, códigos de desbloqueo ni donaciones/café. Primero se termina el juego.
- **No** hay Play Billing ni servidor.
- **No** hay cronómetro, estrellas ni música.
- **No** hay versión de escritorio.
- El modo de juego **no** vuelve al menú principal: se elige en su propia estación antes de jugar.
- El juego se mantiene dentro del ecosistema de Google Play.

## Cómo trabajar

- Cambios pequeños y verificables. Después de cada cambio visual, el autor prueba en su móvil Android, así que explicá qué debería verse distinto.
- Cuidar el rendimiento en móviles modestos: pocas luces, pocas sombras, materiales simples, instanciar con `MultiMesh` cuando haya muchos cubos iguales.
- Mantener el código simple y legible. No agregar dependencias ni plugins sin motivo.
- No tocar la carpeta `.godot/` ni archivos generados.
- Antes de reorganizar escenas o scripts, explicar el plan.
- Para depurar en Android se usa ADB inalámbrico.

## Estructura del proyecto

TODO: pegar acá la salida de `tree -L 2` del repositorio (escenas, scripts, paquetes, recursos) y una línea por carpeta explicando qué contiene.

## Pruebas

TODO: indicar cómo se prueba (escena de prueba, GUT si se usa, exportación a Android).
