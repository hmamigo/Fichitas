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

Todo ocurre sobre el **mismo suelo de cubos de colores**. No se cambia de pantalla 2D: la **cámara viaja** entre estaciones. El suelo (`FloorCubes`) se define en unidades del mundo (`X_MIN`/`X_MAX`/`Z_FAR`/`Z_NEAR`) y debe cubrir todo lo que ve la cámara, también en los extremos de paneo de las listas largas (materias y álbum) y en pantallas apaisadas; `test_flow` lo comprueba. Si una mesa crece, hay que ampliar el suelo.

- Estaciones: **menú**, **materias**, **modo**, **tablero**, **nivel completado** y **álbum de datos curiosos**.
- Menú, materias, modo y tablero están en **fila horizontal**, y la cámara se mueve en horizontal entre ellos.
- El paso **modo** ("¿Cómo quieres jugar?") va entre materias y tablero: el jugador elige Memoria o Asociación recién cuando ya eligió qué practicar. El menú principal no cambia modos.
- El álbum de datos curiosos es una estación 3D como Materias, con fichas iguales a las del juego y la cámara moviéndose en vertical. La cámara debe estar algo más alejada que en otras estaciones.
- "Nivel completado" es una **loseta 3D real** en el piso, a la que se llega solo moviendo la cámara.
- En Materias el usuario hace zoom y recorre las fichas a mano, igual que en el tablero.
- La cámara **no rota libremente**: solo zoom y desplazamiento.
- El fondo de cubos va algo alejado, y el menú un poco más abajo, no pegado al logo.
- No agregar pantallas 2D ni paneles de UI que rompan esta lógica. Si hace falta algo de interfaz (botones de volver, avisos), debe tener la misma estética que las fichas. **La capa 2D no lleva títulos**: la barra superior solo tiene el botón de volver y todo texto que informa (menú principal, "¿Cómo quieres jugar?", título y nivel de la partida, álbum, victoria) es un rótulo plano sobre su mesa.

## Estilo visual (no romper)

- Educativo: colores vivos, aspecto de juguete de calidad.
- Fichas cuadradas de esquinas redondeadas, como pines esmaltados, con bisel metálico fino en ambas caras.
- Filo dorado, placas color crema, marco azul del tablero.
- La iluminación debe ser suave. Una versión anterior se veía con la luz exagerada, así que ante la duda, bajarla.
- Todo elemento nuevo (menú, botones superiores, modo, materias, nivel completado, álbum) debe parecer parte del mismo juego.
- Lo que se toca y lo que no se ven distinto: **lo tocable es una loseta dorada con relieve** (`Plaque` en 3D, `_enamel_tile` en 2D); **lo que solo informa va plano**, sin filo dorado ni grosor (`FlatLabel` pintado sobre la mesa; en 2D no hay equivalente porque no debe haber títulos). Un rótulo nuevo que no se toca no debe parecer un botón.
- Los iconos de menús y materias son PNG a color de `assets/emoji/` (Noto Emoji); `UiTheme.icon()` los prefiere a los SVG de línea del mismo nombre.

## Flujo de pantallas y estados

`main.gd` guarda un único estado (`enum S`) y lo recorre así:

| Estado | Estación / capa | Qué se ve | Se llega desde |
|---|---|---|---|
| `MENU` | `StationMenu` (x = -25) | Logo y pastilla con Sonido/Vibración (2D) y, en la mesa, el rótulo "Menú principal" y tres losetas (Jugar, Recorrido general, Álbum). | Arranque, "Atrás". |
| `SUBJECTS` | `StationSubjects` (x = -15) | Una mesa por grupo (Para todos, Peques, Exploradores, Nerds, Más), cada una con su rótulo plano arriba y el marco de su color; las losetas son las materias, Recorrido general y Repaso. | Jugar, "Atrás" desde modo/juego. |
| `MODE` | `StationMode` (x = -9) | "¿Cómo quieres jugar?" con Memoria y Asociación. | Tocar materia, recorrido general o repaso. |
| `GAME` | Tablero (x = 0) | Fichas y barra de juego. | Tocar una loseta de modo o "Siguiente nivel". |
| `WIN` | `StationWin` (x = +10) | Mesa de nivel completado. | Al emparejar todo. |
| `ALBUM` | `StationAlbum` (x = -35) | Secciones por materia, parejas dominadas y dato curioso. | Loseta Álbum. |

- Elegir una materia, el recorrido general o el repaso **no** reparte fichas: `_prepare()` deja la sesión lista y `_go_mode()` viaja a `MODE`. La partida arranca recién en `_on_mode_chosen()`.
- "Siguiente nivel" (`_on_next()`) prepara el nivel siguiente y entra directo al tablero, sin volver a preguntar el modo.
- "Atrás" (`_on_back()`) desde `MODE` vuelve a `SUBJECTS` o `MENU` según `_mode_from`; desde `GAME`/`WIN` vuelve a materias o al menú según el origen; desde `ALBUM` cierra primero el dato curioso.
- Los modos nunca se eligen desde el menú principal.

## Paquetes de contenido

- Los paquetes de fichas son **JSON**. Hay paquetes incluidos en el juego y también se pueden cargar paquetes externos ("Cargar paquete", con el selector de archivos de Android).
- Las imágenes (símbolos, fórmulas, gráficas) las crea el autor y se usan como imagen, sin renderizar fórmulas dentro del juego.
- Pendiente: pulir los paquetes externos y la carga de imágenes del usuario.
- Cualquier cambio en el formato de los paquetes debe mantener compatibilidad con los existentes, o actualizarlos todos.

### Formato

`packs/index.json` es el índice de los paquetes oficiales y su orden:

```json
{"packs": ["mat", "qui", "fis", "ing", "bio", "geo", "ast", "inf", "ani"]}
```

Cada materia vive en `packs/<id>/pack.json`:

```json
{
  "format": 1,
  "id": "qui",
  "name": "Química",
  "unlock": 2,
  "category": "nerds",
  "pairs": [
    {"id": "01", "a": "01a.png", "b": "01b.png", "fact": "Au viene del latín «aurum»."}
  ]
}
```

- `format`: si está, debe ser `1`.
- `id`: minúsculas, números, `-` y `_`, hasta 32 caracteres; no puede repetir un id oficial.
- `unlock`: número de 1 a 99; indica desde qué nivel del recorrido general entra la materia. Un paquete externo sin `unlock` queda en 99 y solo se juega desde su propia materia.
- `category`: `peques`, `exploradores` o `nerds` (opcional; sin ella, o con otra, cae en `exploradores`). Agrupa las materias en la pantalla de materias (una cabecera por categoría) y en el álbum. Las categorías, su orden, nombre, icono y colores (`color` del rótulo, `ink` del texto y `frame` del marco de su mesa) están en `Packs.CATEGORIES`: para renombrar una basta cambiar su `name`. Peques = sin leer, solo imágenes (Animales, Contar); Exploradores = lo básico (Matemáticas, Inglés, Geografía, Astronomía); Nerds = a fondo (Química, Física, Biología, Informática). Las materias de Peques llevan `unlock` 99.
- `pairs`: entre 3 y 60 parejas. `a` y `b` son rutas relativas a imágenes PNG, JPG o WebP dentro del paquete. `id` de pareja es opcional (por omisión, el índice) y único dentro del paquete; `fact` es el dato curioso, opcional, hasta 300 caracteres.
- Imágenes: lado entre 32 y 4096 px. Al importar un paquete externo se decodifican y se guardan recodificadas como PNG de hasta 1024 px.
- Un `.zip` externo lleva `pack.json` en la raíz o dentro de una única carpeta de primer nivel. Límites: 50 MB y 600 archivos. Si el id ya existe, el paquete se reemplaza entero.

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

```
Fichitas/
├── scenes/            main.tscn: la única escena; el resto se arma por código
├── scripts/           mundo 3D, interfaz, contenido, progreso y utilidades
├── tests/             pruebas sin ventana y capturas
├── packs/             paquetes oficiales: index.json + una carpeta por materia
├── assets/            iconos (SVG de línea en icons/, PNG a color en emoji/), shaders del fondo y licencias de terceros
├── fonts/             Nunito y Baloo 2 (OFL), empaquetadas en el juego
├── addons/godot_ai/   plugin de editor y ayudante de depuración (MCP); no es jugabilidad
├── tools/             utilidades sueltas del autor
├── project.godot      Compatibility, 960×1707 vertical, escena principal
├── export_presets.cfg preset Android (no se versiona: puede llevar contraseñas)
├── icon.svg
├── AGENTS.md
└── README.md
```

### Scripts

| Archivo | Rol |
|---|---|
| `main.gd` | Orquesta estados, niveles, guardado y vuelos de cámara; conecta las señales. |
| `board.gd` | El mundo 3D: cámara, entorno, suelo, entrada táctil, fichas y reglas de los dos modos. Emite `won`, `pair_done` y `sfx`. Guarda las estaciones y el encuadre (pose, paneo, huecos del suelo). |
| `station_menu.gd` | Mesa del menú: Jugar, Recorrido general y Álbum. |
| `station_subjects.gd` | Mesas de materias por grupo, con recorrido general y repaso. |
| `flat_label.gd` | Rótulo plano 3D (no se toca) pintado sobre la mesa; contenido en `Cards.label`. |
| `station_mode.gd` | Paso "¿Cómo quieres jugar?": Memoria y Asociación. |
| `station_win.gd` | Mesa de nivel completado. |
| `station_album.gd` | Mesa del álbum: secciones por materia y parejas en fichas. |
| `album_tile.gd` | Ficha del álbum (boca arriba si la pareja está dominada). |
| `plaque.gd` | Loseta genérica del mundo: cara horneada, pulsación y animación de entrada. |
| `tile_look.gd` | Piezas visuales compartidas: metal dorado, dorso con emblema y mesas con marco. |
| `tile_mesh.gd` | Mallas procedurales: losa redondeada con bisel y caras planas. |
| `pick3d.gd` | Toques sobre piezas planas: rayo desde la cámara contra el plano de la mesa. |
| `face_tex.gd` | Hornea controles 2D a textura para usarlos como cara de una loseta. |
| `cards.gd` | Caras 2D de las losetas, dibujadas con el tema. |
| `ui.gd` | Capas 2D: botones de volver y dato curioso, sin títulos. Solo dibuja y emite señales. |
| `ui_theme.gd` | Tema de interfaz: relieve, fuentes, pieles de botón, iconos y logo. |
| `audio.gd` | Efectos de sonido sintetizados en memoria. |
| `progress.gd` | Guardado JSON en `user://`: nivel, dominio, calendario de repaso y ajustes. |
| `levels.gd` | Tamaños de nivel, selección de parejas y repaso espaciado. |
| `packs.gd` | Carga los paquetes oficiales y los externos. |
| `pack_import.gd` | Importa `.zip` externos con validación estricta. |
| `cam_view.gd` | Geometría de la vista: qué entra en pantalla y a qué distancia. |
| `floor_cubes.gd` | Suelo de cubos de colores en un solo `MultiMesh`. |

## Pruebas

No se usa GUT: cada archivo de `tests/` es un `SceneTree` que corre sin ventana y termina con código 0 si todo pasa (imprime `Resultado: TODO OK`). Ejecutar todas después de cada cambio:

```bash
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/test_game.gd
godot --headless --path . --script res://tests/test_flow.gd
godot --headless --path . --script res://tests/test_review.gd
godot --headless --path . --script res://tests/test_packs.gd
```

| Prueba | Qué cubre |
|---|---|
| `run_tests` | Malla de ficha y carga de los 9 paquetes oficiales. |
| `test_game` | Reglas del tablero: parejas, arrastre, victoria, chispas y nivel de 24 parejas. |
| `test_flow` | Flujo completo: menú → materias → modo → tablero → victoria → álbum, encuadre de cámara y guardado. |
| `test_review` | Repaso espaciado, calendario, sesión de repaso y sonidos. |
| `test_packs` | Importación de paquetes externos: validación, imágenes, reemplazo y borrado. |

- Al agregar un script con `class_name`, ejecutar una vez `godot --headless --path . --import` para actualizar la caché de clases (`.godot/global_script_class_cache.cfg`); si no, Godot falla con "Could not resolve external class member".
- `tests/_shot.gd` guarda capturas en `/tmp/opencode/m_*.png` y necesita pantalla (`DISPLAY`), así que no corre en headless. No es una prueba.
- En Android: exportar con el preset **Android**, instalar con `adb install -r <apk>` y mirar los errores con `adb logcat -s godot`. La depuración usa ADB inalámbrico.
