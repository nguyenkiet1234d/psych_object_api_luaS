# Psych Object API — Psych Engine 1.0.4

A Lua library that simplifies Psych Engine's Reflection API into clean object property syntax like `bf.x`, plus factories for sprites, animated sprites, text, cameras, notes, and shaders.

## Installation

1. Place the `psych_object_api` folder in your mod's `scripts/` directory
2. Add this line at the top of any song/stage/event/note-type Lua script that uses the API:

```lua
local Psych = dofile('mods/My-Mod/scripts/psych_object_api/init.lua')
```

Note: Psych Engine runs each Lua script in its own state, so you cannot use `addLuaScript` for imports. Each script must `dofile` separately.

After loading, global aliases are created: `bf`, `dad`, `gf`, `game`, `FlxG`, `PlayState`, `Sprite`, `Text`, `Camera`, `Debug`, `Ref`, and more.

## Quick Start

```lua
local Psych = dofile('mods/My-Mod/scripts/psych_object_api/init.lua')

function onCreatePost()
    -- Simple property access
    bf.x = 700
    dad.alpha = 0.7
    gf.scale.x = 1.15
    gf.scale.y = 1.15

    -- Create a sprite
    local logo = Sprite.new('logo', 'myImages/logo', 30, 30, {
        camera = 'hud',
        scale = {0.5, 0.5}
    })

    -- Native Psych tweens still work
    doTweenAlpha('logoFade', 'logo', 0, 0.4, 'quadOut')

    -- Camera access
    camHUD.zoom = 1
    game.boyfriend.x = 700
end
```

## Documentation

### Main Documentation Files

- **[AIP_advanced_examples.md](AIP_advanced_examples.md)** — Advanced patterns: class proxies, ReferenceResolver behavior, common mistakes
- **[AIP_en.md](AIP_en.md)** — English API overview and best practices
- **[DEBUG.md](DEBUG.md)** — Debug logging format and API
- **[DEBUGGING.md](DEBUGGING.md)** — Complete debugging guide with examples

### API Reference

**Object Proxies:**
```lua
bf, dad, gf              -- Character proxies
game                     -- Root game object
camGame, camHUD, camOther -- Cameras
iconP1, iconP2          -- UI icons
healthBar, healthBarBG   -- Health bar UI
```

**Class Proxies:**
```lua
FlxG                     -- Flixel globals
PlayState                -- Current play state
Conductor                -- Beat/timing system
Paths                    -- Asset path builder
Mods, ClientPrefs        -- Game configuration
FlxMath, FlxColor, FlxTween -- Flixel utilities
```

**Factories:**
```lua
Sprite.new(tag, image, x, y, options)       -- Create sprite
Sprite.animated(tag, image, x, y, options)  -- Create animated sprite
Text.new(tag, text, width, x, y, options)   -- Create text object
```

**Core Operations:**
```lua
obj:get(property)        -- Read property
obj:set(property, value) -- Write property
obj:bulkSet({...})       -- Set multiple at once
obj:call(method, args)   -- Call method
```

**Debug:**
```lua
Debug.enable(true)       -- Enable logging
Debug.mode('console'|'file'|'both')  -- Log destination
Debug.file(path, clear)  -- Log file path
Debug.info(message)      -- Custom log message
```

## Examples

### Character Property Access

```lua
-- Read/write nested properties
bf.x = 100
bf.y = 200
bf.alpha = 0.8
bf.scale.x = 1.2
bf.scale.y = 1.2
bf.animation.play('idle')  -- Chain with method calls
```

### Sprite Creation & Animation

```lua
local spr = Sprite.new('mySprite', 'images/sprite', 0, 0, {
    scale = {2, 2},
    camera = 'hud',
    add = true  -- auto-add to stage
})

spr:addAnimation('walk', 'walk', 24, true)
spr:play('walk')
spr:scaleTo(1.5, 1.5)
spr.alpha = 0.5
```

### Class Methods with References

```lua
-- When passing proxies to class methods, ReferenceResolver handles compilation
PlayState:call('updateCharacter', { game.boyfriend })

-- Use Ref() for explicit field references
local healthRef = Ref(game, 'health')
PlayState:call('setHealth', { healthRef, 0.5 })
```

### Bulk Property Changes

```lua
-- Faster than multiple :set() calls
game.boyfriend:bulkSet({
    x = 100,
    y = 200,
    alpha = 0.8,
    visible = true
})
```

## Debugging

If something isn't working:

```lua
-- Enable debug logging
Debug.enable(true)
Debug.mode('both')  -- console and file
Debug.file('mods/debug.log', true)

-- Your calls will now log with detailed traces
bf:set('x', 500)  -- Shows in debug output
PlayState:call('method', { game.boyfriend })  -- Shows compiled Haxe code
```

Check [DEBUGGING.md](DEBUGGING.md) for complete guide.

## Performance Notes

- **Cache proxies**: `local spr = Sprite.get('tag')` to avoid recreating
- **Use bulkSet**: Better than multiple `:set()` calls
- **Minimize hot loop calls**: Native Psych functions inside loops, not proxies
- **Property caching**: For frequently read properties, store locally

## Common Patterns

### Safe Method Calls with Error Handling

```lua
local ok, result = pcall(function()
    return PlayState:call('risky_method', { game.boyfriend })
end)

if ok then
    print("Success: " .. tostring(result))
else
    print("Failed: " .. tostring(result))
end
```

### Conditional Property Access

```lua
if bf:get('alive') then
    bf.alpha = 1.0
else
    bf.alpha = 0.5
end
```

### Building Dynamic Paths

```lua
-- Using object paths
local character = 'boyfriend'  -- or 'dad', 'gf'
local prop = 'x'
local value = game[character]:get(prop)  -- Works!
```

## Troubleshooting

### "nil value" errors

**Cause**: Property or method doesn't exist on target object  
**Fix**: Use debug logging to check path, verify object is initialized

### "FAILED" in debug logs

**Cause**: Haxe compilation or serialization error  
**Fix**: Check debug traces, use `Ref()` for complex references, simplify arguments

### Script state conflicts

**Cause**: Each Lua script has isolated state; `addLuaScript` doesn't share globals  
**Fix**: Each script must `dofile('...init.lua')` independently

## License

Free to use and modify. Credit appreciated!

## See Also

- **Psych Engine**: https://github.com/ShadowMario/FNF-PsychEngine
- **Flixel**: https://flixel.org/
