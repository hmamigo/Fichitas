# Fichitas — AGENTS.md (versión Godot)

## Decisiones de esta versión
- Motor: **Godot 4.7.2**, GDScript, renderizador **Compatibility** (móviles y equipos sin Vulkan).
- Escena construida por código (`scripts/main.gd`); mallas procedurales en `scripts/tile_mesh.gd`; paquetes en `scripts/packs.gd`; tema de interfaz en `scripts/ui_theme.gd`.
- Entrada: táctil y ratón unificados; se ignoran los eventos de ratón emulados desde el táctil (`device == DEVICE_ID_EMULATION`).
- Fuentes: Fredoka SemiBold (texto) y Lilita One (títulos), OFL, empaquetadas.
- Pruebas sin pantalla en `tests/` (`run_tests`, `test_game`, `test_flow`, `test_review`; ver README.md); ejecutarlas tras cada cambio.
- Arquitectura: `board.gd` (escena 3D, entrada y reglas de los modos; emite `won`, `pair_done` y `sfx`), `ui.gd` (pantallas; solo dibuja y emite señales), `main.gd` (orquesta menús, niveles, sonido, tema y guardado), `levels.gd` (selección de parejas con repaso y niveles), `progress.gd` (JSON), `packs.gd`, `ui_theme.gd`, `tile_mesh.gd`, `audio.gd` (efectos sintetizados).
- Estado: hecho = tablero, modos memoria y asociación, menú, materias con niveles propios, recorrido general (20 niveles), materias de pago bloqueadas, progreso JSON con dominio y repaso espaciado (usado en la selección y en la sesión "Repaso"), miniaturas de dominio al completar, audio y vibración con ajustes, modo oscuro.
- Aspecto: `ui_theme.gd` genera por código todo lo visual de la interfaz (pieles de botón con relieve y degradado, iconos de flecha/candado/destellos, logotipo, patrón de fondo, degradados) y expone `sdf()` para dibujar formas con antialiasing; `board.gd` usa ese `sdf()` para las texturas de la ficha. Sin archivos de imagen nuevos en la interfaz. Escena 3D: luz principal con sombras + relleno, SSAO, glow muy suave, suelo con degradado radial que se reajusta con la cámara (`_layout`), marco barnizado y losa de puntos; la ficha tiene hueco oscurecido (bisel), dorso con emblema y destello en anillo al emparejar (`TileMesh.ring`).
- Tipografía: los tamaños viven en `UiTheme` (`T_HERO` 96, `T_WIN` 64, `T_HEAD` 56, `T_NAME` 40, `T_BODY` 36, `T_SMALL` 30, `T_TINY` 28). El lienzo lógico mide 960 de ancho, así que `T_BODY` se lee como ~15 sp en un celular; no bajarlo sin probar en el móvil, y los títulos grandes no crecen porque se saldrían de la tarjeta.
- Repaso y dominio (Godot): `Progress.is_due/is_new/due_date` leen `sr`; `Levels.choose()` limita las pendientes al 60 % del nivel (`DUE_SHARE`), las más atrasadas primero, y completa con nuevas y el resto. `Levels.due_pairs/due_count` alimentan la tarjeta "Repaso" (≥3 pendientes, hasta 10, una sola sesión) y la línea de cada materia. Al completar se muestran miniaturas con planta dibujada (`UiTheme.icon_plant`: brote de dos hojas / dos hojas / árbol) y contorno en las que mejoraron.
- Nivel completado (tamaños): en `ui.gd`, `WIN_PAD` 34, `WIN_MIN_W` 660, `WIN_MAX_W` 860, `DOM_MAX` 148 y `DOM_SEP` 10. `_fill_doms()` elige la cuadrícula con `_dom_columns()` (3-6 columnas, máximo 5 filas, minimizando huecos y maximizando el lado), `_dom_side()` limita la miniatura por el ancho y la tarjeta ajusta su ancho al de la cuadrícula. Cada miniatura es imagen cuadrada + fila de 34 px con la planta (`_dom_tile(d, side)`). Con 24 parejas ocupa 5×5 y entra en el lienzo de 1707 de alto; si se suben las filas, revisar que no se salga. El brote de la etapa 0 debe tener dos hojas: con una sola se leía como una «f».
- Contrato de la pantalla de victoria: `ui.show_win(title, msg, button, doms)`; cada `doms[i]` es `{tex, stage, up}`. `main._doms()` lo arma con `Progress.pair_stage(id)` y `up = stage > stage_before[id]`; `stage_before` se llena en `_start()` antes de jugar. La sesión de repaso usa la misma pantalla.
- Audio y vibración: `audio.gd` sintetiza giro, acierto, error y final en `AudioStreamWAV` (sin archivos); el tablero emite `sfx(name)` y `main.gd` lo reproduce y vibra (solo en móvil). Interruptores "Sonido", "Vibración" (oculto si no hay móvil) y "Oscuro" en el menú; se guardan en `prog.sound/vib/theme`. Los efectos están probados sin pantalla; falta confirmar volumen y vibración en un móvil real.
- Modo oscuro: `UiTheme.apply(dark)` reescribe la paleta (`static var`), `GameUI.rebuild()` reconstruye las pantallas y `Board.apply_theme()` ajusta suelo, marco, losa, luces y cielo. No hay detección automática del sistema en 4.7.2; se guarda como `theme: "light"|"dark"`.
- Pendiente de portar: álbum con datos curiosos, chispas, paquetes externos, carga de imágenes de usuario.
- Evitar emojis en la interfaz de Godot (la fuente no los incluye y en Android dependen del sistema); usar iconos dibujados.
- Antes de dar por terminado un cambio: `--import` y las cuatro pruebas de `tests/`.

---

## Reglas y diseño (heredados de la versión web)


Juego educativo 3D de fichas en HTML5 (Three.js r128). El jugador practica conocimientos emparejando fichas de colecciones temáticas. Plataformas objetivo: PC (Windows/Linux, mouse) y Android (táctil), con controles adaptativos.

## Reglas que no se deben romper

- **Sin cronómetro, sin estrellas, sin puntuación, sin presión de tiempo.** No añadirlos sin que se pidan.
- Al completar un nivel solo se avanza al siguiente.
- La mecánica **no depende de ninguna temática**. Las temáticas son datos (paquetes).
- **Todo el contenido de las fichas son imágenes** creadas por el autor (texto, símbolos, fórmulas y gráficas incluidos). Las fichas solo muestran una textura; no se renderiza texto ni fórmulas en tiempo de ejecución.
- Audio: solo efectos simples (giro, acierto, error). Sin música por ahora.
- Cámara casi cenital fija, con zoom y paneo, **sin rotación**.

## Modos (mismo tablero, fichas y datos; cambian las reglas)

- **Memoria:** fichas boca abajo; se descubren de dos en dos; si forman pareja quedan resueltas.
- **Asociación:** todas visibles; se selecciona o se arrastra una ficha hasta su pareja.

## Estilo visual

Educativo: tablero claro, colores vivos, aspecto de juguete de calidad. Fichas cuadradas redondeadas tipo pin esmaltado: losa baja con bisel metálico fino en ambas caras, reflejos y cara plana con la imagen. El giro es de 180° y muestra cara y dorso.

## Tablero

Cuadrícula adaptable: filas y columnas se calculan según las parejas del nivel y la forma de la pantalla (apaisada en PC, vertical en celular). Se recalcula al redimensionar.

## Progresión

20 niveles (`PAIRS`: 3, 4, 5, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16, 16, 18, 18, 20, 20, 24 parejas). Cada paquete tiene un campo `unlock` (nivel desde el que entra al conjunto). Los 8 paquetes oficiales (matemáticas, química, física, inglés, biología, geografía, astronomía e informática) entran de uno en uno en los niveles 1 a 8. Cada nivel incluye al menos una pareja del paquete más reciente. El progreso se guarda como JSON en `localStorage` (`fichas.progress`).

## Paquetes de contenido (JSON)

Mismo formato para oficiales y externos:

```json
{
  "format": 1,
  "id": "historia",
  "name": "Historia",
  "unlock": 2,
  "colors": ["#ffd1a1", "#ffe9d2"],
  "fg": "#5a2d00",
  "pairs": [
    { "a": "img/historia/1492.png", "b": "img/historia/america.png" }
  ]
}
```

- `a` y `b` son las dos fichas de la pareja. Pueden ser rutas de imagen (`./`, `/`, `http(s):`, `data:`) o texto. Si es texto se genera un SVG provisional (para pruebas).
- `colors`/`fg` solo afectan a los SVG provisionales.
- Mínimo 3 parejas completas por paquete.
- Campos opcionales: `icon` (emoji de la materia) y `premium: true` (materia de pago: aparece bloqueada con candado hasta que su `id` esté en `prog.owned`; mientras tanto no entra en el recorrido general).
- Los oficiales viven en `OFFICIAL` (dentro del HTML) y pasan por el mismo `registerPack()` que los externos. Los externos se cargan desde el menú ("Cargar paquete (.json)") y se guardan en `localStorage` (`fichas.packs`).
- Ampliar o vender paquetes nuevos = añadir JSON; no se toca la mecánica.

## Estructura del código (un solo HTML)

1. Contenido: `DATA`, `OFFICIAL`, `registerPack()`, `pick(n)`.
2. Progreso (JSON) y audio sintetizado (WebAudio).
3. Escena: renderer, luces, geometría de ficha (`mkTile`), tablero.
4. Tweens propios (`tw`, `flipT`, `shake`).
5. Juego: `layout()`, `start()`, `tapMem()`, `tapAssoc()`, `drop()`, `good()`, `win()`.
6. Entrada: punteros (mouse y táctil), pellizco, rueda.
7. Menús y bucle de render.

## Materias y modo oscuro

- **Pantalla "Elige una materia"** (menú → Elegir materia): tarjeta "Recorrido general" (progresión mixta de siempre) y una tarjeta por materia. Cada materia tiene sus propios niveles (de 3 parejas hasta el tamaño del paquete) y su progreso en `prog.subj[id]`. Sin puntuación ni tiempo; al terminar solo se avanza al siguiente nivel.
- **Materias de pago:** un paquete con `premium: true` se muestra bloqueado (🔒 "De pago"). Aún no hay compra: al tocarlo solo se informa. Para integrar una tienda, añadir el `id` a `prog.owned` tras la compra. `COMING` define tarjetas "Próximamente" sin paquete.
- **Modo oscuro:** automático según el sistema (`prog.theme: "auto"`) y alternable con el botón ☀️/🌙 (guarda `light`/`dark`). Afecta a la interfaz (variables CSS) y a la escena 3D (`TH`: luces, tablero, marco, reflejos).

## Sensación de juego (sin presión)

- Principio: que dé ganas de volver por flujo, dominio y curiosidad. **No usar** rachas diarias que se pierden, vidas, temporizadores, recompensas aleatorias ni notificaciones de culpa.
- Aciertos seguidos: el tono sube por una escala pentatónica (`RUN`); un fallo lo reinicia. No hay puntos ni textos.
- Vibración suave en Android (`navigator.vibrate`) al girar, acertar y fallar.
- Ajustes: interruptores de sonido y vibración en el menú (`prog.sound`, `prog.vib`; el de vibración solo aparece si el dispositivo la soporta) y botón rápido 🔊/🔇 siempre visible junto al de tema.
- Al completar un nivel: onda de saltos en las fichas, chispas y arpegio antes de la pantalla de nivel completado.

## Dominio por pareja (sin puntuación)

- Cada pareja guarda cuántas veces se resolvió **sin error** (`prog.mp[idPareja]`). 0 → 🌱 nueva · 1-2 → 🌿 aprendiendo · 3 o más → 🌳 dominada. Fallar nunca resta: solo hace que esa vez no cuente.
- Qué es un error: en asociación, emparejar mal la ficha que se elige o arrastra primero; en memoria, descubrir otra ficha cuando la pareja de la primera ya se había visto antes (explorar fichas nuevas no cuenta como error).
- Se muestra en la pantalla de nivel completado (miniaturas de las parejas con su estado; las que mejoraron llevan un contorno) y en cada materia ("🌳 5/8 dominadas").
- El id de pareja es `idPaquete:idPareja`. Si un paquete reordena sus parejas, conviene darles un `id` propio en `pack.json` (`{"id":"oro","a":...,"b":...}`) para no perder el dominio.
- "Reiniciar progreso" también borra el dominio.

## Repaso espaciado

- Sistema de cajas (Leitner) por pareja en `prog.sr[idPareja] = {b: caja 0-5, d: fecha de repaso}`. Intervalos: 0, 1, 3, 7, 16 y 35 días (`DAYS`). Resolver sin error sube una caja; con error baja una (si baja a la caja 0, vuelve a estar pendiente de inmediato). Es solo programación: no se muestra como puntuación.
- `choose()` arma cada nivel mezclando pendientes (máximo 60 % del nivel, las más atrasadas primero), parejas nuevas y, si falta, el resto. Se usa en el recorrido general y en cada materia.
- **Repaso:** tarjeta en la pantalla de materias que reúne hasta 10 parejas pendientes de todas las materias abiertas (necesita al menos 3). Es una sesión de un solo nivel; al terminar vuelve a materias.
- Las tarjetas de materia muestran cuántas parejas hay para repasar (🔁).
- Sin notificaciones ni rachas diarias: el repaso espera al jugador.
- "Reiniciar progreso" también borra el calendario de repaso.

## Álbum

- Menú → 📖 Álbum: por materia, una cuadrícula con las miniaturas de todas las parejas. Las dominadas (🌳) se ven en color y, al tocarlas, muestran ambas fichas y su dato curioso; las demás aparecen en gris con su planta y no se pueden abrir.
- Dato curioso: campo opcional `fact` (texto) en cada pareja de `pack.json` (`{"a":..,"b":..,"fact":"..."}`). En `DATA` es el tercer elemento de cada fila. Se muestra con `textContent` (no interpreta HTML).
- La pantalla de nivel completado indica cuántas parejas nuevas entraron al álbum (📖 +n).
- Solo se listan materias abiertas (las de pago bloqueadas no aparecen).

## Android (Capacitor)

- App contenedora con Capacitor 8 (`webDir: www`, esquema `https`). El flujo está en README.md. Antes del primer `android:setup` hay que cambiar `appId`.
- El juego detecta pantallas táctiles (`MOB`) y baja el tamaño del mapa de sombras y la resolución de render.
- Botón Atrás (plugin `@capacitor/app`): cierra el detalle del álbum, vuelve de álbum/materias/nivel completado al menú, de la partida a materias o menú, y solo sale desde el menú.
- Permisos: la plantilla trae INTERNET; el script añade VIBRATE. No se usa red.
- Verificado: generación y sincronización del proyecto, permisos e iconos. Sin verificar: compilación y ejecución en dispositivo.

## Estructura del proyecto

```
www/index.html, www/lib/three.min.js   juego (sin dependencias externas)
www/packs/index.json                   lista de paquetes
www/packs/<id>/pack.json + imágenes    un paquete por carpeta (rutas relativas a su carpeta)
tools/generar-paquetes.js              recrea los SVG provisionales
tools/android-setup.sh                 prepara el proyecto Android (Capacitor)
package.json, capacitor.config.json    configuración de Capacitor 8
assets/                                iconos y pantalla de inicio (provisionales)
```
Al arrancar, el juego carga `packs/index.json` y cada `pack.json`; si no puede leerlos (p. ej. file://), usa `OFFICIAL`. Un paquete de carpeta con el mismo `id` sustituye al incluido.

## Pendiente

- Sustituir los SVG provisionales por las imágenes del autor.
- Más paquetes oficiales (p. ej. historia, de pago) y ampliar los existentes (los nuevos tienen 10 parejas; los primeros cinco, 8).
- Probar el empaquetado Android en un dispositivo y compilar el APK/AAB (ver README.md); empaquetado de escritorio (Tauri/Electron).
