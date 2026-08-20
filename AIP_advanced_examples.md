# Advanced Examples — Classes & Advanced Patterns (Psych Object API)

This file explains advanced usage particularly around class proxies, ReferenceResolver behavior, and patterns you are likely to forget. It includes concrete examples and permalinks to the implementation.

## Implementation Anchors

- [classProxy implementation](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L385-L506)
- [ReferenceResolver.serialize & needsCompilation](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L224-L280)
- [PsychObject.Ref](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L204-L220)

---

## 1) Calling static class methods (no Haxe refs)

Use `:call` for class methods. This will use `callMethodFromClass` when args are simple.

```lua
-- Simple static method call
local res = FlxG:call('someStaticMethod', { 123, 'hello' })
```

**Example with actual Psych classes:**
```lua
-- Get current conductor beat
local beat = Conductor:call('getBeat')

-- Get a random element
local randomVal = FlxG.random:call('int', { 0, 100 })
```

---

## 2) Calling class methods that require engine object references

If you pass a proxy (like `game.boyfriend`) or an explicit `Ref`, ReferenceResolver detects it and compiles a Haxe call. This is required when the Haxe method expects an actual engine object reference.

```lua
-- Option A: use a proxy directly
PlayState:call('doSomethingWithTarget', { game.boyfriend, 2.0 })

-- Option B: create an explicit Haxe field reference (for example to pass a field rather than the whole object)
local hxRef = Ref(game.boyfriend, 'x')
PlayState:call('setTargetX', { hxRef })
```

**Example with real usage:**
```lua
-- Pass the boyfriend object to a PlayState method
PlayState:call('updateCharacterPos', { game.boyfriend })

-- Pass a specific field reference
local healthRef = Ref(game, 'health')
PlayState:call('setHealth', { healthRef, 0.5 })
```

---

## 3) Working with class.instance

Access `ClassProxy.instance` when a common instance exists. This yields an object proxy for the instance. Useful when the engine exposes a static `instance` or similar.

```lua
-- Get the PlayState instance and modify it
local inst = PlayState.instance
inst:bulkSet({ someField = 123 })

-- Access instance properties
local currentSong = PlayState.instance:get('curSongName')
```

---

## 4) bulkSet for classes & objects

Use `bulkSet` to reduce multiple `setProperty` calls (faster & clearer):

```lua
-- Object bulk set
game.boyfriend:bulkSet({ x = 100, y = 200, visible = true })

-- Class bulk set
Character:bulkSet({ speed = 2.5, health = 100 })

-- PlayState bulk set
PlayState:bulkSet({ inCutscene = true, paused = false })
```

---

## 5) When serialization can't handle your argument

Lua functions cannot be serialized into Haxe by ReferenceResolver. If a Haxe callback is required, either:
- Expose the callback on Haxe side and call it by name from Lua (via `runHaxeCode`), or
- Use `runHaxeCode` to compose a Haxe call that builds a closure.

```lua
-- DON'T do this (Lua function can't be serialized):
-- PlayState:call('setCallback', { function() print('test') end })

-- DO this instead:
Haxe.run("PlayState.instance.onBeatHit = function() trace('Beat hit!'); end;")

-- Or expose a named Lua handler that Haxe calls
function onSomeEvent()
    print("Event fired!")
end
```

---

## 6) Debugging class calls

Enable Debug; ReferenceResolver emits the exact compiled Haxe code when it compiles a call. Use `Debug.enable(true)` and `Debug.mode('both')` to see Haxe code + console logging.

```lua
-- Enable debugging
Debug.enable(true)
Debug.mode('both')  -- 'console', 'file', or 'both'

-- Set a custom log file
Debug.file('mods/custom_debug.log', true)

-- All subsequent calls will be logged
PlayState:call('doSomething', { game.boyfriend })
-- Console shows the exact Haxe code: 
--   "return PlayState.doSomething(game);"

-- Get debug history
local history = Debug.history()
for i, msg in ipairs(history) do print(msg) end

-- Clear history when done
Debug.clear()
```

---

## 7) Common class mistakes

**❌ Forgetting to use `:` for method invocation (loses self).**
```lua
-- WRONG - loses self reference
PlayState.call('someMethod', {})

-- RIGHT - passes self properly
PlayState:call('someMethod', {})
```

**❌ Passing plain Lua tables when the Haxe method expects object references.**
```lua
-- WRONG - table won't serialize correctly as an engine object
local target = { x = 100, y = 200 }
PlayState:call('setTarget', { target })

-- RIGHT - use the actual proxy or Ref
PlayState:call('setTarget', { game.boyfriend })
```

**❌ Not using bulkSet for multiple property changes.**
```lua
-- SLOW - multiple function calls
game.boyfriend:set('x', 100)
game.boyfriend:set('y', 200)
game.boyfriend:set('alpha', 0.8)

-- FAST - single operation
game.boyfriend:bulkSet({ x = 100, y = 200, alpha = 0.8 })
```

---

## Additional Examples by Class

### Conductor
```lua
-- Get beat/step
local beat = Conductor:call('getBeat')
local step = Conductor:call('getStep')

-- Modify properties
Conductor:set('bpm', 140)
Conductor:set('crochet', 480)
```

### ClientPrefs
```lua
-- Read preference
local downScroll = ClientPrefs.data:get('downScroll')

-- Modify preference
ClientPrefs.data:set('fullscreen', true)

-- Bulk set multiple prefs
ClientPrefs.data:bulkSet({ 
    downScroll = true, 
    ghost = false,
    antialiasing = true
})
```

### Paths
```lua
-- Get image/sound/music paths
local imagePath = Paths:call('image', { 'characters/bf' })
local soundPath = Paths:call('sound', { 'combo' })
local musicPath = Paths:call('inst', { 'song-name' })
```

### Mods
```lua
-- Get active mod list
local activeMods = Mods:call('getActiveMods')

-- Parse mod data
local modData = Mods:call('parseFolder', { 'some-mod' })
```

### PlayState
```lua
-- Access current state
local curBeat = PlayState:get('curBeat')
local paused = PlayState:get('isPaused')

-- Modify state
PlayState:set('camZoom', 1.3)
PlayState:bulkSet({ inCutscene = false, canPause = true })
```

---

## Tips & Tricks

1. **Always use `:` for method calls** — It ensures `self` is passed correctly.
2. **Debug mode is your friend** — Enable it to see the actual Haxe code being compiled.
3. **Use `Ref()` for field references** — When you need to pass a specific field instead of the whole object.
4. **Batch operations with `bulkSet`** — Faster and cleaner than multiple `set` calls.
5. **Check the init.lua source** — Look at the implementation links above when you're unsure about proxy behavior.
