# AIP (English) — Psych Object API Detailed Guide

English companion documentation for the Psych Object API. This guide explains how proxies work, how to use the API, best practices, common mistakes, and debugging strategies.

## Implementation Anchors

Permalinks to key sections in init.lua:

- [PsychObject.Ref (Haxe reference callable)](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L204-L220)
- [ReferenceResolver.needsCompilation & serialize](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L224-L280)
- [objectProxy implementation (core object proxy)](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L315-L383)
- [classProxy implementation (core class proxy)](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L385-L506)
- [spriteHelpers (add/play/scale/etc)](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L561-L637)
- [Global aliases (bf, game, FlxG, PlayState, etc)](https://github.com/nguyenkiet1234d/psych_object_api_luaS/blob/main/init.lua#L870-L931)

---

## Overview

The `init.lua` file provides Lua "proxy" objects that forward property reads/writes and method calls to the Psych Engine via native functions like:

- `getProperty() / setProperty()` for object properties
- `getPropertyFromClass() / setPropertyFromClass()` for class properties
- `callMethod() / callMethodFromClass()` for method invocation

When your code passes **proxy objects or explicit Haxe references** as arguments, the **ReferenceResolver** automatically serializes them into Haxe expressions and calls `runHaxeCode()` instead of the native functions.

This allows:

```lua
-- Simple pass-through (no compilation needed)
local x = bf:get('x')

-- Complex: proxy passed to class method (triggers Haxe compilation)
PlayState:call('updateCharacter', { game.boyfriend })
```

---

## Common Entry Points

### Creating Objects

```lua
-- Sprites
local spr = Sprite.new('tag', 'image', 0, 0, options)
local spr = Sprite.animated('tag', 'image', 0, 0, options)
local spr = Sprite.get('tag')  -- Get existing

-- Text
local txt = Text.new('tag', 'text', width, x, y, options)
local txt = Text.get('tag')  -- Get existing
```

### Accessing Objects

```lua
-- Characters
bf, dad, gf  -- Global aliases for character proxies

-- Game root
game  -- Root game object, access any Psych property

-- Cameras
camGame, camHUD, camOther

-- Classes
FlxG, PlayState, Conductor, Paths, Mods, ClientPrefs, etc.
```

### Core Operations

```lua
-- Object proxy methods
obj:get(property)                    -- Read property
obj:set(property, value)             -- Write property
obj:bulkSet({prop1 = val1, ...})     -- Bulk set
obj:call(method, {arg1, arg2})       -- Call method

-- Class proxy methods
Class:get(property)
Class:set(property, value)
Class:call(method, {args})
Class:bulkSet({...})
Class.instance  -- Access static instance
```

---

## When to Use `:` vs `.`

### Colon (`:`) — Method Calls

Use `:` when calling methods. The proxy automatically passes itself as `self`.

```lua
-- Correct
spr:play('idle')
bf:set('x', 100)
bf:get('y')

-- Wrong (loses self, will error)
spr.play('idle')
bf.set('x', 100)
```

### Dot (`.`) — Property Access

Use `.` for property access. The proxy's `__index` and `__newindex` metamethods handle it.

```lua
-- Correct - read property
local x = bf.x

-- Correct - write property
bf.alpha = 0.5

-- Correct - chain access
gf.scale.x = 1.2

-- Note: spr.play is the method reference, spr:play() calls it
local playFunc = spr.play
playFunc(spr, 'idle')  -- Manually pass self
```

---

## How Proxies Work

### Object Proxy Example

```lua
-- bf is an object proxy wrapping the 'boyfriend' path
bf.x = 100

-- What happens internally:
-- 1. bf.__newindex is called with key='x', value=100
-- 2. setProperty('boyfriend.x', 100) is invoked
-- 3. Psych Engine updates the property

local x = bf.x
-- 1. bf.__index is called with key='x'
-- 2. getProperty('boyfriend.x') returns the value
-- 3. Value returned to Lua
```

### Class Proxy Example

```lua
-- PlayState is a class proxy
PlayState:set('curBeat', 5)

-- What happens internally:
-- 1. setPropertyFromClass('states.PlayState', 'curBeat', 5)
-- 2. Psych Engine updates the class property

local beat = PlayState:get('curBeat')
-- 1. getPropertyFromClass('states.PlayState', 'curBeat')
-- 2. Value returned
```

### Nested Proxy Chains

```lua
-- Each dot creates a new nested proxy from the children map
bf.animation.curAnim.name

-- Internally:
-- 1. bf (object proxy for 'boyfriend')
-- 2. bf.animation (child proxy for 'boyfriend.animation')
-- 3. bf.animation.curAnim (child proxy for 'boyfriend.animation.curAnim')
-- 4. bf.animation.curAnim.name (final property access)

-- Cached for performance: repeated access doesn't recreate proxies
```

---

## ReferenceResolver & Haxe Compilation

### When Does Compilation Happen?

The ReferenceResolver detects when your arguments contain **object/class proxies or explicit Ref() objects**. If found, it compiles to Haxe instead of using native callMethod.

### Example: Detecting Compilation Need

```lua
-- SIMPLE: No proxies, no compilation
PlayState:call('setValue', { 42, 'hello' })
-- Uses callMethodFromClass normally

-- COMPLEX: Proxy argument, triggers compilation
PlayState:call('setCharacter', { game.boyfriend })
-- ReferenceResolver detects game.boyfriend is a proxy
-- Generates Haxe: return PlayState.setCharacter(Reflect.getProperty(game, 'boyfriend'));
-- Uses runHaxeCode to execute
```

### Explicit Haxe References with Ref()

```lua
-- Create an explicit reference to a field
local hxRef = Ref(game.boyfriend, 'x')  -- Reference to boyfriend.x
PlayState:call('setTargetX', { hxRef })

-- ReferenceResolver serializes: Reflect.getProperty(game, 'boyfriend').x
-- Useful when you need to pass a specific field, not the whole object
```

---

## Performance Notes & Best Practices

### Cache Proxies

```lua
-- GOOD: Cache, reuse
local bf = Sprite.get('boyfriend')
for i = 1, 100 do
    bf.x = i * 10
end

-- SLOW: Recreates proxy each iteration
for i = 1, 100 do
    Sprite.get('boyfriend').x = i * 10
end
```

### Use bulkSet for Multiple Changes

```lua
-- GOOD: Single operation
game.boyfriend:bulkSet({ x = 100, y = 200, alpha = 0.8 })

-- SLOWER: Multiple calls
game.boyfriend:set('x', 100)
game.boyfriend:set('y', 200)
game.boyfriend:set('alpha', 0.8)
```

### Avoid Hot Loop Proxy Calls

```lua
-- Hot loop (runs every frame)
function update()
    -- BAD: Creates proxy each frame
    Sprite.get('mySprite').x = Sprite.get('mySprite').x + 1

    -- GOOD: Cache outside loop
    -- (in onCreatePost or similar)
end

-- Better approach:
function onCreatePost()
    mySprite = Sprite.get('mySprite')  -- Cache once
end

function update()
    mySprite.x = mySprite.x + 1  -- Use cached
end
```

### Cache Frequently Read Properties

```lua
-- If reading same property multiple times
local bf_health = bf:get('health')
if bf_health > 50 then ... end
if bf_health < 100 then ... end

-- Cheaper than multiple bf:get('health') calls
```

---

## Debugging

### Enable Debug Logging

```lua
Debug.enable(true)
Debug.mode('console')  -- or 'file' or 'both'
```

When debug is on:
- All property sets/gets are logged
- Method calls show their status (OK or FAILED)
- Haxe compilation code is printed

### Using Debug History

```lua
Debug.enable(true)

-- Do some operations
bf:set('x', 100)
PlayState:call('something', { game.boyfriend })

-- Review history
local history = Debug.history()
for i, msg in ipairs(history) do
    print(msg)  -- See all logged operations
end
```

### Finding Haxe Compilation Issues

```lua
Debug.enable(true)
Debug.mode('both')

-- Look for these patterns in logs:
-- "[PsychObject] Haxe Compile" — Shows generated code
-- "[PsychObject] ... -> FAILED" — Shows errors

PlayState:call('method', { game.boyfriend })  -- May log Haxe code if compilation happens
```

---

## Advanced Patterns

### Passing Proxies to Class Methods

```lua
-- ReferenceResolver handles serialization automatically
PlayState:call('updateBF', { game.boyfriend })

-- Expanded: Shows what happens internally
-- 1. game.boyfriend is detected as a proxy
-- 2. Serialized to: Reflect.getProperty(game, 'boyfriend')
-- 3. Haxe generated: return PlayState.updateBF(Reflect.getProperty(game, 'boyfriend'));
-- 4. runHaxeCode executes it
```

### Using Ref() for Field References

```lua
-- Sometimes you need a field reference, not the whole object
local xRef = Ref(game.boyfriend, 'x')
PlayState:call('setX', { xRef })

-- Serialized to: Reflect.getProperty(game, 'boyfriend').x
-- Useful when method expects a field reference instead of object
```

### Static Class Instance Access

```lua
-- Some classes expose a static instance
local psInstance = PlayState.instance  -- Returns object proxy for current instance
psInstance:set('paused', true)  -- Modify instance

-- Equivalent to: setProperty('', 'paused', true)  -- operates on current state
```

---

## Common Mistakes to Avoid

### ❌ Using `.` Instead of `:` for Method Calls

```lua
-- WRONG
bf.set('x', 100)  -- Loses self reference

-- CORRECT
bf:set('x', 100)  -- self passed automatically
```

### ❌ Passing Lua Functions to Haxe Methods

```lua
-- WRONG - Lua functions can't serialize to Haxe
PlayState:call('setCallback', { function() print('test') end })

-- RIGHT - Expose callback in Haxe or use name-based call
Haxe.run("PlayState.instance.onSomething = function() trace('test'); end;")
```

### ❌ Forgetting Colon on bulkSet

```lua
-- WRONG
bf.bulkSet({ x = 100, y = 200 })

-- CORRECT
bf:bulkSet({ x = 100, y = 200 })
```

### ❌ Passing Complex Lua Tables as Arguments

```lua
-- WRONG - nested Lua tables don't serialize well
local config = { x = 100, callbacks = { onDone = function() end } }
PlayState:call('configure', { config })

-- RIGHT - simplify, pass individual values
PlayState:call('setX', { 100 })
```

---

## Troubleshooting

### Call returns nil unexpectedly

**Check:**
- Method name is correct
- Method exists on target class/object
- Method has return value (not void)
- Debug logs show "OK" not "FAILED"

### "FAILED" in debug logs

**Check:**
- Haxe syntax in compilation trace is valid
- Object path is correct
- Arguments match method signature
- Method is callable from Lua side

### Nested property access returns nil

**Check:**
- Parent object exists and is initialized
- Child property name is spelled correctly
- Child is included in proxy children map
- Use debug to trace: `Debug.info('value = ' .. tostring(obj.prop))`

---

## See Also

- [AIP_advanced_examples.md](AIP_advanced_examples.md) — Advanced class patterns
- [DEBUGGING.md](DEBUGGING.md) — Complete debugging guide
- [init.lua](init.lua) — Source code with inline comments
