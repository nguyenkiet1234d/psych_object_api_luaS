# DEBUG LOGS (Psych Object API)

What is logged
- Each log line in the file starts with a timestamp (YYYY-MM-DD HH:MM:SS) followed by "[PsychObject]" and the message.
- If enabled, the caller file and line are appended as " @path/to/file.lua:LINE".
- Each line ends with " step: <curStep>" (curStep or 0).

Example lines
```
2026-08-19 12:34:56 [PsychObject] Psych Object API - by kietNguyen (tea) @mods/My-Mod/scripts/myscript.lua:10 step: 0
2026-08-19 12:35:01 [PsychObject] set boyfriend.x = 100 -> OK @mods/My-Mod/scripts/game_logic.lua:42 step: 123
2026-08-19 12:35:05 [PsychObject] call camGame.reset -> FAILED @mods/My-Mod/scripts/camera.lua:88 step: 124
```

How to enable / configure
- Enable debug: `Debug.enable(true)`
- Set debug mode: `Debug.mode('console' | 'file' | 'both')`
- Set debug file path: `Debug.file('mods/psych_object_api.log', clear)`
- Set caller stack level used when logging: `Debug.callerLevel(n)`
  - Default: 4
  - If file:line points to the wrapper instead of your script, increase or decrease `n` until it points to the expected callsite.

Notes
- If the environment disables `debug.getinfo`, the caller info will be omitted (function is wrapped in `pcall`).
- The printed caller path strips a leading `@` (Lua debug convention) so it shows a filesystem-like path.
