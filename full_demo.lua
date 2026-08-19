-- examples/full_demo.lua
-- A full-featured demo script that exercises many features of the Psych Object API
-- This script is written defensively (pcall guards) so it won't crash if some assets/methods are missing in a particular build.

-- Assumes init.lua has been loaded already by the mod loader and global proxies (Sprite, Psych, etc.) exist.

local function safe(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        Debug.info('safe: call failed: ' .. tostring(res))
        return nil
    end
    return res
end

-- Prepare debug
safe(function()
    Debug.enable(true)
    Debug.mode('console')
    Debug.info('Running full_demo.lua')
end)

-- Create a background rectangle-style graphic sprite
local bg = safe(function()
    return PsychObject.Sprite.new('demo_bg', '', 0, 0, {
        graphic = {800, 600, '222233'},
        scrollFactor = {1, 1},
        scale = {1, 1},
        camera = 'game',
        center = true,
        add = true,
        inFront = false
    })
end)

-- Create an animated player sprite (animation may not exist; guarded)
local player = safe(function()
    return PsychObject.Sprite.animated('demo_player', 'player_spritesheet', 120, 180, {
        animation = { name = 'idle', prefix = 'idle_', frameRate = 12, loop = true, play = true },
        scrollFactor = {1, 1},
        scale = {1.0, 1.0},
        add = true,
        inFront = true
    })
end)

-- Create HUD text
local label = safe(function()
    return PsychObject.Text.new('demo_label', 'Demo: PsychObject API', 400, 10, 10, { size = 20, color = 'FFFFFF', add = true })
end)

-- Play music/sound (guarded)
safe(function() Sound.music('music_demo') end)

-- Tween example: move player to the right over 1.5s (guarded)
safe(function()
    if player then
        -- Use Tween wrapper; arguments depend on engine signature — adjust as needed
        -- This example uses a generic pcall with runHaxeCode if the native tween signature differs.
        local startX = player.x or player:get('x')
        local targetX = (startX or 120) + 200
        -- Try using Tween.x wrapper (may require a tag name used by engine tween system)
        local ok = pcall(function() Tween.x('demo_move', 'demo_player', 1.5, targetX) end)
        if not ok then
            -- Fallback: set via simple timer simulation (not exact) - example only
            player.x = targetX
        end
    end
end)

-- Shader filter example: try to attach shader to player (guarded)
safe(function()
    if player then
        -- Try to load shader (initLuaShader returns shader object). Shader name/path may vary.
        local shaderName = 'demo_shader'
        pcall(function() PsychObject.Shader.load(shaderName) end)
        pcall(function() player:shader(shaderName) end)
        -- Set a uniform if available
        pcall(function() player:shaderFloat('u_time', 1.0) end)
    end
end)

-- Using group proxy to modify opponent strum 0 (guarded)
safe(function()
    local note0 = PsychObject.group('opponentStrums', 0)
    if note0 then
        note0: set('alpha', 0.6)
    end
end)

-- Demonstrate class call with a proxy argument (uses ReferenceResolver path)
safe(function()
    -- Many engines expose PlayState methods; this is an example call that will be compiled to Haxe
    if PlayState then
        PlayState:call('focusOn', { game.boyfriend, 0.5 }) -- safe: will either use callMethodFromClass or Haxe compile
    end
end)

-- Demonstrate Ref usage (explicit Haxe reference)
safe(function()
    -- create a Haxe field reference to boyfriend.x and pass to a hypothetical method
    if PlayState then
        local hxRef = Ref(game.boyfriend, 'x')
        PlayState:call('setTargetX', { hxRef, 999 })
    end
end)

-- Cleanup sample: Remove demo sprites after some safe delay (this is pseudo; replace with your mod lifecycle hook)
-- This block is only illustrative and does not schedule a delayed call — implement with your mod's timer API if needed.
-- safe(function() player:remove(true) end)
-- safe(function() bg:remove(true) end)

Debug.info('full_demo.lua finished')

return true
