# AGENTS.md

Guía para agentes (y personas) que trabajan en **Fichitas**: un juego 3D educativo de fichas hecho con Godot, solo para Android. Leé esto antes de tocar el código.

## Idioma y trato

- Comunicación y comentarios en **español**.
- Mensajes de commit en **inglés**.
- Los nombres de código (variables, funciones, nodos) pueden estar en inglés o español, pero hay que seguir el criterio que ya use el archivo que se edita.
- El autor está aprendiendo inglés: si aparece vocabulario técnico en inglés, está bien, pero explicalo brevemente cuando no sea obvio.

## Stack

- **Godot 4.7.2**, GDScript.
- Renderizador **Compatibility**. No usar funciones que ese renderizador no soporte ni efectos pesados (iluminación global, reflejos en pantalla, sombras costosas, etc.).
- Plataforma: **Android**, orientación **vertical**. No se hace versión de escritorio.
- Entrada **táctil primero**: tocar, deslizar, zoom con dos dedos. **No se arrastran fichas**: en Asociación se toca una y luego su pareja.

## Concepto del juego

- Dos modos, elegibles en un paso aparte, después de elegir la materia y antes de entrar al tablero:
  - **Memoria**: fichas boca abajo, descubrir parejas.
  - **Asociación**: fichas visibles; se toca una y luego su pareja (sin arrastrar).
- Relaciones entre fichas: pregunta ↔ respuesta, imagen ↔ palabra, concepto ↔ definición, elemento ↔ símbolo.
- Niveles progresivos: cada nivel suma más parejas.
- Tablero: **siempre 2 columnas** (fichas grandes), con el mismo desplazamiento y zoom que Materias: vertical (el horizontal solo aparece al acercar), con inercia, empezando por la primera fila. Al empezar se ven `Board.FIT_ROWS` filas y la siguiente asoma para invitar a deslizar. Los niveles se dividen en **rondas** de como mucho `Levels.ROUND_PAIRS` (6) parejas, repartidas parejo (`Levels.round_sizes`: 14 -> 5+5+4); al terminar una ronda salen fichas nuevas, el contador sigue sumando (`matched_pairs` incluye las rondas hechas), el subtítulo muestra "Ronda 1/3" (sin el modo, por falta de ancho) y `won` se emite solo al terminar la última. `main` cuenta las parejas del nivel con `cur_pairs`, no con las fichas en pantalla.
- Al completar un nivel: solo avanzar. **Sin cronómetro ni estrellas.**
- Sonido: efectos simples (giro de ficha, toque, acierto, error). **Sin música** por ahora.

## Arquitectura visual: un solo mundo con estaciones

Todo ocurre sobre el **mismo suelo de cubos de colores**. No se cambia de pantalla 2D: la **cámara viaja** entre estaciones. El suelo (`FloorCubes`) se define en unidades del mundo (`X_MIN`/`X_MAX`/`Z_FAR`/`Z_NEAR`) y debe cubrir todo lo que ve la cámara, también en los extremos de paneo de las listas largas (materias y álbum), en pantallas muy altas y en ventanas apaisadas de escritorio (solo para desarrollo); `test_flow` lo comprueba. Si una mesa crece, hay que ampliar el suelo.

- Estaciones: **menú**, **materias**, **modo**, **tablero**, **nivel completado** y **álbum de datos curiosos**.
- Las estaciones están en **fila horizontal** (álbum −35, menú −25, materias −15, modo −9, tablero 0, victoria +10) y la cámara se mueve en horizontal entre ellas. El tablero ancho (hasta ±5,5) no debe tocar la mesa del modo: si se mueve una estación, revisar el vuelo en pantalla ancha.
- El paso **modo** ("¿Cómo quieres jugar?") va entre materias y tablero: el jugador elige Memoria o Asociación recién cuando ya eligió qué practicar. El menú principal no cambia modos.
- El álbum de datos curiosos es una estación 3D como Materias, con fichas iguales a las del juego y la cámara moviéndose en vertical. La cámara debe estar algo más alejada que en otras estaciones.
- "Nivel completado" es una **estación 3D** a la derecha del tablero (una mesa con cabecera, miniaturas y un botón), a la que se llega solo moviendo la cámara.
- Materias son **varias mesas** (una por grupo), no una columna única; el usuario hace zoom y recorre la lista a mano, igual que en el tablero.
- La cámara **no rota libremente**: solo zoom y desplazamiento.
- El fondo de cubos va algo alejado, y el menú un poco más abajo, no pegado al logo.
- Suelo: **cubos de colores de distinta profundidad**, de **dos tamaños** (grandes de 2×2 y medianos) repartidos por bloques sin solaparse, en un solo `MultiMesh` de cajas simples de 12 triángulos (~5 200 instancias: pensado para móviles antiguos; no subirlo sin medir en un móvil modesto, `test_floor` falla por encima de 6 500). No hay cubos chicos, edificios con ventanas ni modo alternativo: se probó y se descartó. La altura de cada cubo (`FloorCubes._height_for`) es el grosor mínimo más un relieve **cercano** (`NEAR_RISE`, ya pegado a la mesa, porque en la vista casi cenital del tablero solo se ve esa franja) y uno **lejano** (`FAR_RISE`) que crece con la distancia a la mesa desde `RISE_START`; los más profundos se aclaran (`TALL_LIGHT`) para que la profundidad también se lea desde arriba. **Distancia a las mesas**: los cubos apoyan `SINK` más abajo que las mesas (`FloorCubes.GROUND_Y` es también la altura del plano lejano de `Board`) y los cercanos nunca llegan a la parte baja del marco (y = −0,325; `test_floor` lo comprueba). Las mesas proyectan su sombra sobre el suelo: el alcance de las sombras del sol sigue a la cámara (`Board.SHADOW_REACH` sumado a su distancia); con un límite fijo desaparecían al alejarse (niveles grandes, menú, materias). La niebla de profundidad empieza detrás de la mesa (distancia de la cámara + 4), así que apenas se nota en pantalla; el tono azulado de los cubos viene de `FloorCubes.FADE`.
- **Rendimiento en móvil** (solo con el tag `mobile`, el escritorio no cambia): sin MSAA, glow apagado, mapa de sombras de 2048, filtro de sombras suave muy bajo (`project.godot` y `Board`) y el 3D dibujado al 75 % de la resolución (`Board.MOBILE_SCALE_3D`, filtro bilineal; la interfaz 2D sigue nítida). Medido por software en el tablero (indicativo, no son fps de un móvil): MSAA 4× fue lo más caro por mucho (319 → 171 ms por cuadro al quitarlo), luego sombras y glow juntos, y el suelo de cubos pesó poco (~14 %). Antes de tocar el suelo por rendimiento, probar estos ajustes en el móvil.
- No agregar pantallas 2D ni paneles de UI que rompan esta lógica. Si hace falta algo de interfaz (botones de volver, avisos), debe tener la misma estética que las fichas. **La capa 2D no lleva títulos**: la barra superior solo tiene el botón de volver y todo texto que informa (menú principal, "¿Cómo quieres jugar?", título y nivel de la partida, álbum, victoria) es un rótulo plano sobre su mesa.

## Estilo visual (no romper)

- Educativo: colores vivos, aspecto de juguete de calidad.
- Fichas cuadradas de esquinas redondeadas, como pines esmaltados, con bisel metálico fino en ambas caras.
- Filo dorado, placas color crema, marco azul del tablero.
- La iluminación debe ser suave. Una versión anterior se veía con la luz exagerada, así que ante la duda, bajarla.
- Todo elemento nuevo (menú, botón de volver, modo, materias, nivel completado, álbum) debe parecer parte del mismo juego.
- Lo que se toca y lo que no se ven distinto: **lo tocable es una loseta dorada con relieve** (`Plaque` en 3D, `_enamel_tile` en 2D); **lo que solo informa va plano**, sin filo dorado ni grosor (`FlatLabel` pintado sobre la mesa; en 2D no hay equivalente porque no debe haber títulos). Un rótulo nuevo que no se toca no debe parecer un botón.
- Los iconos de menús y materias son PNG a color de `assets/emoji/` (Noto Emoji); `UiTheme.icon()` los prefiere a los SVG de línea del mismo nombre.
- El fondo de cubos se mezcla con la niebla del tablero (`FloorCubes.FADE`) y se aclara cerca de cada mesa: la mesa, las fichas y el texto mandan. Si un color de fondo compite con una loseta, bajar el fondo, no subir la loseta.

## Experiencia de uso (UX)

- **Sonido y vibración al tocar**: toda loseta de una estación emite `sfx("tap")`, que suena y vibra corto. `Board` repite la señal de cada estación (`_relay_sfx`) y `main` la reproduce. Al agregar una estación, conectá su señal `sfx` a `Board._relay_sfx`.
- **Las listas recuerdan dónde estabas**: Materias y Álbum guardan desplazamiento y zoom al cambiar de estación (`Board._view_mem`) y los restauran al volver; la primera visita empieza por arriba. El valor guardado se recorta solo con los límites de la mesa, así que nunca queda fuera.
- **Aviso de desplazamiento**: la primera vez que se abre una lista larga, `main._show_pan_hint()` muestra "Deslizá para recorrer y usá dos dedos para acercar." y lo recuerda en `Progress.data["hint"]`.
- **El tablero se limpia al llegar**: `Board._arrive()` retira las fichas recién al terminar el vuelo (si la estación destino no es la partida), así el mundo no se vacía antes de que la cámara se vaya. No hay que llamar `board.stop()` al salir de una estación.
- **Contador de parejas**: la franja del título del tablero muestra "Nivel 2 · Memoria · 1 de 3". Se actualiza una vez por pareja (`Board.set_progress` + `FlatLabel.update`), no en cada frame.
- **Álbum legible**: las dos fichas de una pareja van juntas y entre parejas hay más aire (`PAIR_GAP`). Tocar una pareja no dominada avisa en qué materia jugarla.
- **Victoria con muchas parejas**: entran hasta 12 miniaturas (`main.WIN_DOMS`) y el resto se resume en una ficha "+N". El alto de la cuadrícula se mide con las fichas dibujadas, no con el total.
- **Menú sin ruido**: el lema va plano con halo (nunca en una pastilla, que parecería un botón) y no hay pie 2D. La capa 2D del menú solo lleva el logo, el título y la pastilla de Sonido/Vibración.

## Flujo de pantallas y estados

`main.gd` guarda un único estado (`enum S`) y lo recorre así:

| Estado | Estación / capa | Qué se ve | Se llega desde |
|---|---|---|---|
| `MENU` | `StationMenu` (x = -25) | Logo, lema plano y pastilla con Sonido/Vibración (2D) y, en la mesa, el rótulo "Menú principal" y tres losetas (Jugar, Recorrido general, Álbum). | Arranque, "Atrás". |
| `SUBJECTS` | `StationSubjects` (x = -15) | Una mesa por grupo (Para todos, Peques, Exploradores, Nerds, Más), cada una con su rótulo plano arriba y el marco de su color; las losetas son las materias, Recorrido general y Repaso. Recuerda desplazamiento y zoom. | Jugar, "Atrás" desde modo/juego. |
| `MODE` | `StationMode` (x = -9) | Rótulo "¿Cómo quieres jugar?" (con la sesión) y las losetas Memoria y Asociación. | Tocar materia, recorrido general o repaso. |
| `GAME` | Tablero (x = 0) | Fichas sobre su mesa, con el título de la partida (materia, nivel y modo) y el avance "N de M" en una franja plana arriba; la capa 2D solo tiene "Atrás". | Tocar una loseta de modo o "Siguiente nivel". |
| `WIN` | `StationWin` (x = +10) | Cabecera con trofeo y miniaturas de las parejas (planas; hasta 12 y "+N") y la loseta "Siguiente nivel". | Al emparejar todo. |
| `ALBUM` | `StationAlbum` (x = -35) | Rótulo "Álbum" y una sección por materia con sus parejas (las dos fichas juntas) y dato curioso. Recuerda desplazamiento y zoom. | Loseta Álbum. |

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
{"packs": ["mat", "qui", "fis", "ing", "bio", "geo", "ast", "inf", "ani", "contar", "colores", "formas"]}
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
- `category`: `peques`, `exploradores` o `nerds` (opcional; sin ella, o con otra, cae en `exploradores`). Agrupa las materias en la pantalla de materias (una cabecera por categoría) y en el álbum. Las categorías, su orden, nombre, icono y colores (`color` del rótulo, `ink` del texto y `frame` del marco de su mesa) están en `Packs.CATEGORIES`: para renombrar una basta cambiar su `name`. Peques = sin leer, solo imágenes (Animales, Contar, Colores, Formas); Exploradores = lo básico (Matemáticas, Inglés, Geografía, Astronomía); Nerds = a fondo (Química, Física, Biología, Informática). Las materias de Peques llevan `unlock` 99, así que no entran en el recorrido general (sí en el Repaso).
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
| `board.gd` | El mundo 3D: cámara, entorno, suelo, entrada táctil, fichas y reglas de los dos modos. Emite `won`, `pair_done` y `sfx` (repite el de las estaciones). Guarda las estaciones, el encuadre (pose, paneo, huecos del suelo), el avance de la partida y dónde quedó cada lista. |
| `station_menu.gd` | Mesa del menú: rótulo "Menú principal" y las losetas Jugar, Recorrido general y Álbum. |
| `station_subjects.gd` | Mesas de materias por grupo, con recorrido general y repaso. |
| `flat_label.gd` | Rótulo plano 3D (no se toca) pintado sobre la mesa; su contenido lo dibuja `Cards.label`. `FlatLabel.make()` lo crea ya horneado y `update()` cambia el contenido sin parpadeo (doble búfer). |
| `station_mode.gd` | Paso "¿Cómo quieres jugar?": rótulo con la sesión y las losetas Memoria y Asociación. |
| `station_win.gd` | Mesa de nivel completado: cabecera y miniaturas planas y la loseta de seguir. |
| `station_album.gd` | Mesa del álbum: rótulo, secciones por materia (cabeceras planas) y parejas en fichas. |
| `album_tile.gd` | Ficha del álbum (boca arriba si la pareja está dominada). |
| `plaque.gd` | Loseta genérica del mundo: cara horneada, pulsación y animación de entrada. |
| `tile_look.gd` | Piezas visuales compartidas: metal dorado, dorso con emblema y mesas con marco. |
| `tile_mesh.gd` | Mallas procedurales: losa redondeada con bisel y caras planas. |
| `pick3d.gd` | Toques sobre piezas planas: rayo desde la cámara contra el plano de la mesa. |
| `face_tex.gd` | Hornea controles 2D a textura para usarlos como cara de una loseta. |
| `cards.gd` | Caras 2D que se hornean a textura: losetas (`subject`, `action`, `win_button`) y rótulos planos (`label`, `win_header`, `win_doms`, incluida la ficha "+N" de la victoria). |
| `ui.gd` | Capas 2D: botones de volver y dato curioso, sin títulos. Solo dibuja y emite señales. |
| `ui_theme.gd` | Tema de interfaz: relieve, fuentes, iconos (a color de `assets/emoji/` o SVG de línea) y logo. |
| `audio.gd` | Efectos de sonido sintetizados en memoria. |
| `progress.gd` | Guardado JSON en `user://`: nivel, dominio, calendario de repaso y ajustes (incluido `hint`, el aviso de desplazamiento ya visto). |
| `levels.gd` | Tamaños de nivel, selección de parejas y repaso espaciado. |
| `packs.gd` | Carga los paquetes oficiales y los externos, y define las categorías (`CATEGORIES`). |
| `pack_import.gd` | Importa `.zip` externos con validación estricta. |
| `cam_view.gd` | Geometría de la vista: qué entra en pantalla y a qué distancia. |
| `floor_cubes.gd` | Suelo de cubos de colores, dos tamaños y distinta profundidad, en un solo `MultiMesh` de cajas simples. |

## Pruebas

No se usa GUT: cada archivo de `tests/` es un `SceneTree` que corre sin ventana y termina con código 0 si todo pasa (imprime `Resultado: TODO OK`). Ejecutar todas después de cada cambio:

```bash
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/test_game.gd
godot --headless --path . --script res://tests/test_rounds.gd
godot --headless --path . --script res://tests/test_flow.gd
godot --headless --path . --script res://tests/test_review.gd
godot --headless --path . --script res://tests/test_packs.gd
godot --headless --path . --script res://tests/test_floor.gd
```

| Prueba | Qué cubre |
|---|---|
| `run_tests` | Malla de ficha y carga de los 12 paquetes oficiales. |
| `test_game` | Reglas del tablero: parejas (por toque), victoria, chispas y nivel de 24 parejas (4 rondas de 6). |
| `test_rounds` | Reparto en rondas (`Levels.round_sizes`), 2 columnas, límites de desplazamiento vertical, paso entre rondas con el contador acumulado y `won` una sola vez. |
| `test_flow` | Flujo completo: menú → materias → modo → tablero → victoria → álbum, encuadre de cámara, cobertura del suelo en los extremos de las listas, contador de parejas, memoria de la posición de las listas y guardado. |
| `test_review` | Repaso espaciado, calendario, sesión de repaso y sonidos. |
| `test_packs` | Importación de paquetes externos: validación, imágenes, reemplazo y borrado. |
| `test_floor` | Suelo de cubos: presupuesto de instancias, solo cubos medianos y grandes, relieve ya pegado a la mesa sin tocarla, cubos más profundos lejos, distancia vertical y plano lejano. En headless Godot no guarda las transformaciones del `MultiMesh`, así que la prueba lee los datos propios del suelo (`_cells`, `_heights`); el aspecto se revisa con capturas. |

- Al agregar un script con `class_name`, ejecutar una vez `godot --headless --path . --import` para actualizar la caché de clases (`.godot/global_script_class_cache.cfg`); si no, Godot falla con "Could not resolve external class member".
- `tests/_shot.gd` guarda capturas en `/tmp/opencode/m_*.png` y necesita pantalla (`DISPLAY`), así que no corre en headless. No es una prueba.
- En Android: exportar con el preset **Android**, instalar con `adb install -r <apk>` y mirar los errores con `adb logcat -s godot`. La depuración usa ADB inalámbrico.
