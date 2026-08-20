# Debugging Guide — Psych Object API (init.lua)

Comprehensive guide to debugging when using Psych Object API in Psych Engine. Topics cover enabling logging, reading logs, understanding Haxe compilation traces from ReferenceResolver, and fixing common issues.

## Implementation Anchors

- [init.lua source](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua)
- [debugTrace / debugOutput](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L105-L122)
- [writeDebugFile / ensureDebugFile / closeDebugFile](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L75-L103)
- [PsychObject.Debug API](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L804-L829)
- [ReferenceResolver.serialize & needsCompilation](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L224-L280)

---

## Quick Start — Enable Debug Now

### Enable to Console (Fastest)

```lua
Debug.enable(true)
Debug.mode('console')
```

### Enable to File (Best for Long Sessions)

```lua
Debug.mode('file')
Debug.file('mods/my_debug.log', true)  -- path and clear file
Debug.enable(true)
```

### Enable to Both (Maximum Visibility)

```lua
Debug.enable(true)
Debug.mode('both')
Debug.file('mods/psych_object_api.log', true)
```

### Disable When Done

```lua
Debug.enable(false)
-- or fully shutdown:
PsychObject.shutdownDebug()
```

---

## Understanding Debug Modes

| Mode | Output | Best For |
|------|--------|----------|
| `console` | Print to debugPrint/print | Live development, quick feedback |
| `file` | Write to log file only | Production, console unavailable, persistent history |
| `both` | Both console and file | Comprehensive debugging, archives + live view |

---

## Log File Location & Permissions

### Default Location

```
mods/psych_object_api.log
```

### Custom Location

```lua
Debug.file('mods/my_mod/debug.log', false)  -- false = don't clear
Debug.file('mods/my_mod/debug.log', true)   -- true = clear on start
```

### Permission Issues

If you can't write to the log file:

1. Check directory exists: `mods/` folder must be present
2. Check game has write permission
3. Try absolute path if relative fails: `Debug.file('/tmp/debug.log')`
4. Check error with: `local ok, err = Debug.file('path'); if not ok then print(err) end`

---

## Debug History & Custom Logging

### Access Debug History

```lua
local history = Debug.history()
for i, msg in ipairs(history) do
    print("[" .. i .. "] " .. msg)
end
```

History is limited to ~5000 messages (circular buffer).

### Log Custom Messages

```lua
Debug.info('My custom message')  -- Only prints if debugEnabled
```

### Clear History

```lua
Debug.clear()
```

---

## Understanding Haxe Compilation Traces

### When Does Compilation Happen?

When you pass object proxies or explicit `Ref` objects to class/object method calls, ReferenceResolver detects this and **compiles to Haxe code** instead of using native callMethod.

### Example: What Gets Compiled

```lua
-- This requires Haxe compilation (uses game.boyfriend proxy)
PlayState:call('doSomething', { game.boyfriend, 2.0 })

-- Log output shows:
-- [PsychObject] Haxe Compile Class Call: return PlayState.doSomething(game, 2.0);
```

### How to Read Haxe Traces

```lua
Debug.enable(true)
Debug.mode('both')

-- Trigger a compilation
PlayState:call('method', { game.boyfriend })

-- Look for this in console/log:
-- [PsychObject] Haxe Compile Class Call: return PlayState.method(...)
```

### Debugging Serialization Errors

If you see "FAILED" in the logs:

1. Copy the Haxe code from the log
2. Test it directly:
   ```lua
   Haxe.run('return PlayState.method(game);')  -- try your Haxe code
   ```
3. Common issues:
   - Invalid Haxe syntax in serialized arguments
   - Wrong object path in Reflect.getProperty chain
   - Method doesn't exist on the class
   - Arguments don't match method signature

---

## Step-by-Step Debug Session

### 1. Enable Logging

```lua
Debug.enable(true)
Debug.mode('both')
Debug.file('mods/debug.log', true)
```

### 2. Perform Minimal Failing Call

Isolate the problematic operation:

```lua
local ok, err = pcall(function()
    PlayState:call('suspiciousMethod', { game.boyfriend })
end)
if not ok then
    Debug.info('Call failed: ' .. tostring(err))
end
```

### 3. Check Logs for Haxe Code

```lua
local history = Debug.history()
for i, msg in ipairs(history) do
    if msg:find('Haxe Compile') then
        print("Generated: " .. msg)
    end
    if msg:find('FAILED') then
        print("Error: " .. msg)
    end
end
```

### 4. Test Haxe Code Directly

```lua
-- Extract and test the Haxe code
Haxe.run('return PlayState.suspiciousMethod(game);')
```

### 5. Apply Fix

Common fixes:

```lua
-- Use Ref for field access
local hxRef = Ref(game.boyfriend, 'x')
PlayState:call('setX', { hxRef })

-- Or avoid complex arguments
PlayState:call('simpleMethod', { 123, 'text' })  -- no proxies
```

---

## Common Errors & Solutions

### "No logs after enabling file mode"

**Solution:**

```lua
print(Debug.getMode())      -- Check mode is 'file' or 'both'
print(Debug.isEnabled())    -- Check enabled is true
print(Debug.history())      -- Check history has entries

-- Try different path
Debug.file('mods/test_log.txt', true)
```

### "Haxe code in log but runHaxeCode fails"

**Solution:**

1. Check if Lua tables with functions are being passed (can't serialize)
2. Use `Ref(target, 'field')` instead of complex arguments
3. Verify method exists on target class

```lua
-- WRONG - can't serialize Lua function
PlayState:call('method', { function() end })

-- RIGHT - use Ref for clarity
local ref = Ref(game, 'boyfriend')
PlayState:call('method', { ref })
```

### "debugHistory consumes too much memory"

**Solution:**

```lua
Debug.clear()  -- Clear periodically
-- Or disable history
Debug.enable(false)  -- Stops capturing
```

### "Call says OK in log but still fails in game"

**Solution:**

Log only captures the Lua->Haxe call result. The method itself may still fail. Check:

1. Method return value: `local result = PlayState:call('method', {...})`
2. Side effects: did the method actually modify state?
3. Haxe console: engine may log Haxe-level errors separately

---

## Advanced: Adding Custom Traces

### Log from Your Script

```lua
if Debug.isEnabled() then
    Debug.info('Starting level: ' .. curLevel)
end

-- Safe custom logging
if Debug.isEnabled() then
    Debug.info('Boyfriend x = ' .. game.boyfriend:get('x'))
end
```

### Wrap Calls in pcall for Safety

```lua
Debug.enable(true)

local ok, result = pcall(function()
    return PlayState:call('riskySomething', {...})
end)

if ok then
    Debug.info('Call succeeded: ' .. tostring(result))
else
    Debug.info('Call failed with error: ' .. tostring(result))
end
```

---

## Debug Checklist

- [ ] Enable debug: `Debug.enable(true)`
- [ ] Set mode: `Debug.mode('both')` for max visibility
- [ ] Set file: `Debug.file('mods/my.log', true)` if needed
- [ ] Reproduce minimal failing case with `pcall` wrapper
- [ ] Check logs for "Haxe Compile" or "-> FAILED" lines
- [ ] Copy Haxe code and test with `Haxe.run(...)`
- [ ] Fix and retry
- [ ] Clean shutdown: `PsychObject.shutdownDebug()`

---

## See Also

- [DEBUG.md](DEBUG.md) - Log format reference
- [AIP_advanced_examples.md](AIP_advanced_examples.md) - Advanced patterns with debugging examples
