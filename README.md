# Fichitas — prototipo en Godot 4.7.2

Juego educativo 3D de fichas (memoria y asociación). Port a Godot en curso.

Solo vertical: la ventana de pruebas en el PC es de 540×960 (proporción de celular) y en Android la orientación está fijada a vertical.

## Abrir y probar
1. Godot 4.7.2 → *Importar* → `project.godot`. La primera vez importa los recursos (unos segundos).
2. **F5** para ejecutar. En el menú elige **Memoria** o **Asociación** y pulsa *Elegir materia* o *Recorrido general*.
   - Memoria: toca una ficha para girarla; se descubren de dos en dos.
   - Asociación: todas visibles; toca dos fichas o arrastra una sobre su pareja.
   - Rueda o pellizco: zoom. Arrastrar el fondo: mover. **Atrás** (o el botón Atrás de Android) vuelve a la pantalla anterior.

## Android
Ajustes del editor → *Export → Android*: ruta del JDK (17 o 21, según la documentación de 4.7) y del SDK. Luego *Proyecto → Exportar → Añadir… → Android* y ejecuta en tu dispositivo con la depuración inalámbrica (el icono de Android de la esquina superior derecha).

Desde la terminal (el preset ya está creado y firmado con el keystore de depuración que Godot genera solo):
```
godot --headless --path . --export-debug "Android" ./fichas-del-saber.apk
adb install -r fichas-del-saber.apk
```
Es un APK de depuración, solo `arm64-v8a`. Para publicar hace falta un keystore de release (y, si hacen falta móviles de 32 bits o emuladores, activar `armeabi-v7a` / `x86_64` en el preset).

## Ajustar la luz
En `scripts/board.gd` están `LIGHT_ENERGY`, `FILL_ENERGY`, `AMBIENT_ENERGY`, `SKY_ENERGY` y `CLEARCOAT`; el color de fondo y de la niebla lo da `FOG_COLOR`, y el del suelo entre los cubos, `_ground_edge()`. Con el juego en ejecución desde el editor, las flechas ↑ ↓ del teclado suben o bajan la luz principal y la ambiental; la consola muestra los valores para copiarlos.

## Qué incluye
- Renderizador **Compatibility** (OpenGL): funciona en móviles y en equipos antiguos sin Vulkan.
- Ficha: losa dorada con bisel (malla procedural), hueco oscurecido alrededor de la cara, cara con la imagen y dorso con emblema azul, reflejos de estudio, sombra proyectada, destello al emparejar y halo del resaltado con la silueta de la ficha; las pendientes flotan sobre la losa y las resueltas se hunden en ella y quedan un poco translúcidas.
- Escena: luz principal con sombras que caen hacia abajo + luz de relleno, brillo (glow) muy suave, niebla de profundidad, suelo de cubos de colores (`scripts/floor_cubes.gd`, un solo `MultiMesh`) y tablero con marco barnizado y losa de puntos. No hay SSAO: el renderizador Compatibility no lo soporta.
- Entrada unificada táctil + ratón (`scripts/board.gd`), cámara casi cenital sin rotación durante el juego. El menú es una vista lejana e inclinada del suelo de cubos; al jugar, la cámara baja hasta el tablero (`Board.view` y `fly_to()`).
- Dos modos de juego, menú, **pantalla de materias** con niveles propios (de 3 parejas hasta el tamaño del paquete) y **recorrido general** de 20 niveles. Las materias de pago se muestran bloqueadas (`"premium": true` en `pack.json`).
- **Progreso en JSON** (`user://progress.json`): nivel, nivel por materia, dominio por pareja, calendario de repaso, sonido y vibración.
- **Repaso espaciado:** cada nivel mezcla parejas pendientes (máximo 60 %, las más atrasadas primero), nuevas y el resto. La pantalla de materias muestra cuántas parejas esperan y una tarjeta **Repaso** (con ≥3 pendientes) que reúne hasta 10 de todas las materias en una sola sesión.
- **Dominio al completar:** miniaturas grandes y adaptativas de las parejas del nivel (la cuadrícula y la tarjeta crecen según cuántas haya) con su planta (brote, dos hojas, árbol) y contorno verde en las que mejoraron.
- **Audio y vibración:** efectos de giro, acierto, error y final sintetizados en memoria (`scripts/audio.gd`, sin archivos), vibración suave solo en móvil y ajustes en el menú.
- Interfaz con fuentes **Fredoka SemiBold** y **Lilita One** (licencia OFL, en `fonts/`), pieles de botón con relieve, iconos dibujados (flecha, candado, destellos, plantas), logotipo y patrón de fondo **generados por código** en `scripts/ui_theme.gd` (sin archivos de imagen añadidos).
- Paquetes JSON en `packs/` (mismo formato que la versión web). Imágenes provisionales en PNG.

## Aún no está
Álbum con datos curiosos, paquetes externos y carga de imágenes de usuario. El modo oscuro se retiró.

## Pruebas (sin pantalla)
```
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/test_game.gd     # tablero, memoria y asociación
godot --headless --path . --script res://tests/test_flow.gd     # menús, niveles, materias y guardado
godot --headless --path . --script res://tests/test_review.gd   # repaso, sesión Repaso, miniaturas y sonidos
```
