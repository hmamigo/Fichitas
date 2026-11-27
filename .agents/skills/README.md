# Skills de terceros

Carpeta de *skills* para agentes (OpenCode las lee de `.agents/skills/<nombre>/SKILL.md`).
No son código del juego: son guías de trabajo y no las carga Godot.

## Origen

Todo el contenido viene de **gamedev-skills/awesome-gamedev-agent-skills**
(https://github.com/gamedev-skills/awesome-gamedev-agent-skills), commit
`c6ca6c41c839b68319ffc08430b99ab768debc32`, licencia Apache-2.0 (ver `LICENSE` y
`NOTICE` en esta carpeta). Los hashes de cada skill están en `skills-lock.json`.

Se instalaron con el CLI oficial (`skills add ... --copy`), sin modificar los archivos.

## Instaladas

`game-ui-ux`, `performance-optimization`, `godot-3d-essentials`, `godot-animation`,
`godot-audio`, `godot-export`, `godot-gdscript`, `godot-gdscript-headless-testing`,
`godot-nodes-scenes`, `godot-shaders`, `godot-signals-groups`, `godot-ui-control`.

Se descartaron `godot-physics`, `godot-multiplayer`, `godot-csharp`, `godot-tilemap` y
`godot-2d-movement` porque el juego no usa esas partes del motor.

## Revisión de seguridad

- Auditorías en skills.sh: *Gen Agent Trust Hub*, *Socket* y *Snyk* en **Pass** para las 12.
- Revisión manual del contenido: solo Markdown y chequeos de solo lectura
  (`check_scripts_compile.gd`, `check_3d_scene.gd`, `check_godot_project.py`); sin
  descargas, sin acceso a credenciales y sin instrucciones de instalar dependencias.
- Instalación fija al commit de arriba y verificada byte a byte contra la fuente.

## Actualizar

```bash
DISABLE_TELEMETRY=1 npx skills add https://github.com/gamedev-skills/awesome-gamedev-agent-skills \
  --skill godot-gdscript godot-nodes-scenes godot-signals-groups godot-3d-essentials \
          godot-ui-control godot-animation godot-audio godot-shaders godot-export \
          godot-gdscript-headless-testing performance-optimization game-ui-ux \
  -a opencode -y --copy
```

Después hay que volver a revisar el diff antes de commitear: los skills se ejecutan con
los mismos permisos que el agente.
