# Debug Logging — Psych Object API

## Overview

The Psych Object API includes a comprehensive debug logging system to help you trace and diagnose issues with proxy objects, method calls, and Haxe code compilation.

## Log Format

### Log Line Structure

Each log line in the debug file follows this format:

```
2026-08-19 12:34:56 [PsychObject] <message> step: <curStep>
```

### Example Log Lines

```
2026-08-19 12:34:56 [PsychObject] Psych Object API - by kietNguyen (tea) step: 0
2026-08-19 12:35:01 [PsychObject] set boyfriend.x = 100 -> OK step: 123
2026-08-19 12:35:05 [PsychObject] call camGame.reset -> FAILED step: 124
2026-08-19 12:35:10 [PsychObject] Haxe Compile Object Call: boyfriend.y step: 125
```

### Components Explained

- **Timestamp**: `YYYY-MM-DD HH:MM:SS` — exact time the log was written
- **[PsychObject]**: Fixed prefix identifying logs from this API
- **Message**: The actual log content (operation, result, value)
- **-> OK / -> FAILED**: Operation status indicator
- **step**: Current game step when log was written (or 0 if unavailable)

## Enabling & Configuring Debug

### Quick Start

```lua
-- Enable debugging to console
Debug.enable(true)
Debug.mode('console')

-- Or enable to file
Debug.mode('file')
Debug.file('mods/psych_object_api.log', true)

-- Or both console and file
Debug.mode('both')
```

### API Functions

| Function | Purpose |
|----------|----------|
| `Debug.enable(true/false)` | Turn debugging on/off |
| `Debug.mode('console'\|'file'\|'both')` | Set where logs go |
| `Debug.file(path, clear)` | Set log file path; clear=true wipes existing log |
| `Debug.info(message)` | Manually log a message |
| `Debug.history()` | Get table of all logged messages (limited to ~5000) |
| `Debug.clear()` | Clear debug history |
| `Debug.isEnabled()` | Check if debugging is active |
| `Debug.getMode()` | Get current debug mode |

## Debug Modes

### Console Mode

Logs print to the game console via `debugPrint()` and `print()`. Useful when developing locally and need immediate feedback.

```lua
Debug.enable(true)
Debug.mode('console')
```

### File Mode

Logs write only to a file (default: `mods/psych_object_api.log`). Useful when:
- Console is unavailable or cluttered
- You need to preserve full log history
- Debugging headless or in production

```lua
Debug.mode('file')
Debug.file('mods/my_debug.log', true)  -- clear on startup
```

### Both Mode

Simultaneously logs to console AND file. Maximum visibility.

```lua
Debug.mode('both')
Debug.file('mods/psych_object_api.log', true)
Debug.enable(true)
```

## Common Use Cases

### Debugging a Specific Call

```lua
Debug.enable(true)
Debug.mode('both')

-- This call will be logged with full details
PlayState:call('someMethod', { game.boyfriend, 2.5 })

-- Check for "Haxe Compile" lines to see generated code
local history = Debug.history()
for i, msg in ipairs(history) do
    if msg:find('Haxe Compile') then
        print("Generated Haxe: " .. msg)
    end
end
```

### Logging Custom Messages

```lua
Debug.enable(true)

Debug.info("Starting initialization...")
game.boyfriend:set('x', 500)
Debug.info("Boyfriend position set")
```

### Monitoring Multiple Calls

```lua
Debug.enable(true)
Debug.mode('file')
Debug.file('mods/detailed_debug.log', true)

-- All these calls will be logged to file
game.boyfriend:set('x', 100)
game.boyfriend:set('y', 200)
game.dad:set('alpha', 0.5)

-- Check log file after for detailed trace
```

## Troubleshooting

### No Log Output Visible

1. **Check mode**: Verify `Debug.getMode()` returns expected value
2. **Check enabled**: Verify `Debug.isEnabled()` returns `true`
3. **Check file path**: Try `Debug.file('mods/test.log', true)` with a known accessible path
4. **Check permissions**: Ensure game process has write permission to `mods/` directory

### Log File Not Created

```lua
-- Try with explicit path
local ok, err = Debug.file('mods/psych_api_debug.log', true)
if not ok then
    print("Debug file error: " .. tostring(err))
end
```

### Too Many Logs / Memory Issues

```lua
-- Clear history periodically
Debug.clear()

-- Or disable history capture
Debug.enable(false)
```

## Shutting Down Debug

```lua
-- Clean shutdown
PsychObject.shutdownDebug()
-- Closes file handle and disables all logging
```
