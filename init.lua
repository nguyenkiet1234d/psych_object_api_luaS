-- Psych Object API for Psych Engine 1.0.4.
-- Load this file from the Lua script that will use its globals:
-- dofile('mods/My-Mod/scripts/psych_object_api/init.lua')

-- ============================================================
-- Localized globals (perf): local/upvalue access is faster than
-- indexing _G on every call, which matters a lot inside hot
-- metamethods (__index/__newindex) that fire on every property
-- get/set. Shadowing with the SAME name means every call site
-- below is untouched and still resolves correctly.
-- NOTE: curStep is intentionally NOT localized here since it is
-- a live value mutated by the engine every step; capturing it
-- once would freeze it at file-load time.
-- ============================================================
local type, tostring, pairs, ipairs = type, tostring, pairs, ipairs
local setmetatable, assert, print = setmetatable, assert, print
local string, table, os, io = string, table, os, io
-- Further-localized string/table members: avoids one extra table
-- index per call at sites that run frequently (proxy chains, Haxe
-- code compilation, debug logging).
local sFormat, sGmatch = string.format, string.gmatch
local tInsert, tRemove, tConcat = table.insert, table.remove, table.concat

local getProperty, setProperty, callMethod = getProperty, setProperty, callMethod
local getPropertyFromClass, setPropertyFromClass, callMethodFromClass = getPropertyFromClass, setPropertyFromClass, callMethodFromClass
local getPropertyFromGroup, setPropertyFromGroup = getPropertyFromGroup, setPropertyFromGroup
local debugPrint = debugPrint

local makeLuaSprite, makeAnimatedLuaSprite, makeGraphic = makeLuaSprite, makeAnimatedLuaSprite, makeGraphic
local addLuaSprite, removeLuaSprite = addLuaSprite, removeLuaSprite
local addAnimationByPrefix, addAnimationByIndices, playAnim = addAnimationByPrefix, addAnimationByIndices, playAnim
local setScrollFactor, scaleObject, setObjectCamera, setBlendMode, screenCenter = setScrollFactor, scaleObject, setObjectCamera, setBlendMode, screenCenter

local setSpriteShader, removeSpriteShader, initLuaShader = setSpriteShader, removeSpriteShader, initLuaShader
local setShaderFloat, setShaderInt, setShaderBool = setShaderFloat, setShaderInt, setShaderBool
local setShaderFloatArray, setShaderIntArray, setShaderBoolArray = setShaderFloatArray, setShaderIntArray, setShaderBoolArray
local setShaderSampler2D = setShaderSampler2D

local makeLuaText, addLuaText, removeLuaText = makeLuaText, addLuaText, removeLuaText
local setTextString, setTextSize, setTextWidth, setTextHeight = setTextString, setTextSize, setTextWidth, setTextHeight
local setTextColor, setTextFont, setTextBorder, setTextAlignment = setTextColor, setTextFont, setTextBorder, setTextAlignment

local cameraSetTarget, getMouseX, getMouseY = cameraSetTarget, getMouseX, getMouseY
local noteTweenX, noteTweenY, noteTweenAngle, noteTweenAlpha, noteTweenDirection = noteTweenX, noteTweenY, noteTweenAngle, noteTweenAlpha, noteTweenDirection

-- Native Psych Lua functions for Tweens, Timers, and Sounds
local doTweenX, doTweenY, doTweenAngle, doTweenAlpha = doTweenX, doTweenY, doTweenAngle, doTweenAlpha
local doTweenZoom, doTweenColor, cancelTween = doTweenZoom, doTweenColor, cancelTween
local runTimer, cancelTimer = runTimer, cancelTimer
local playSound, pauseSound, resumeSound, stopSound, playMusic = playSound, pauseSound, resumeSound, stopSound, playMusic

-- Internal Haxe bridge used by camera filters and compilers.
local runHaxeCode = runHaxeCode

local PsychObject = {}
local debugEnabled = false
local debugHistory = {}
local debugMode = 'console'
local debugLogPath = 'mods/psych_object_api.log'
local debugFileHandle = nil
local debugTerminalOpened = false

local function debugValue(value)
    if type(value) == 'string' then return sFormat('%q', value) end
    if type(value) == 'table' then return '{...}' end
    return tostring(value)
end

local function debugPath(path)
    if path == 'boyfriend' then return 'bf' end
    if path:sub(1, 10) == 'boyfriend.' then return 'bf' .. path:sub(10) end
    return path
end

local function closeDebugFile()
    if debugFileHandle then
        pcall(function() debugFileHandle:flush() end)
        pcall(function() debugFileHandle:close() end)
        debugFileHandle = nil
    end
end

local function ensureDebugFile()
    if debugFileHandle then return true end
    local file, errorMessage = io.open(debugLogPath, 'a')
    if not file then return false, errorMessage end
    debugFileHandle = file
    return true
end

local function writeDebugFile(message)
    local ok, errorMessage = ensureDebugFile()
    if not ok then return false, errorMessage end
    local success, writeError = pcall(function()
        debugFileHandle:write(os.date('%Y-%m-%d %H:%M:%S ') .. message .. '\n')
        debugFileHandle:flush()
    end)
    if not success then
        closeDebugFile()
        return false, writeError
    end
    return true
end

local function debugOutput(message, color)
    if debugMode == 'console' or debugMode == 'both' then
        debugPrint('[PsychObject] ' .. message, color or 'FFFFFF')
        print('[PsychObject] ' .. message)
    end
    if debugMode == 'file' or debugMode == 'both' then writeDebugFile('[PsychObject] ' .. message.." step: "..(curStep or 0)) end
end

local function debugTrace(action, result)
    if debugEnabled then
        local failed = result == false
        local message = action .. (failed and ' -> FAILED' or ' -> OK')
        tInsert(debugHistory, message)
        if #debugHistory > 5000 then tRemove(debugHistory, 1) end
        debugOutput(message, failed and 'FF5555' or '55FF88')
    end
    return result
end

-- ============================================================
-- FILTER HELPERS CHO FLXG VÀ CAMERA
-- ============================================================
local function generateFilterCode(targetExpr, filters)
    if type(filters) ~= 'table' then filters = { filters } end
    -- Accumulate into a table and join once instead of repeated ..
    -- concatenation (each .. in a loop allocates a new string).
    local parts = { "var filtersArr = [];\n" }
    for _, f in ipairs(filters) do
        local shaderName = type(f) == 'string' and f or tostring(f)
        tInsert(parts, sFormat([[
            var s = game.initLuaShader('%s');
            if (s != null) filtersArr.push(new openfl.filters.ShaderFilter(s));
        ]], shaderName))
    end
    tInsert(parts, targetExpr .. ".filters = filtersArr;")
    return tConcat(parts)
end

local function resolveFilterArgs(self, args)
    if args ~= nil then return args end
    return self
end

local gameHelpers = {
    setFilters = function(self, args)
        return runHaxeCode(generateFilterCode("FlxG.game", resolveFilterArgs(self, args)))
    end,
    clearFilters = function()
        return runHaxeCode("FlxG.game.filters = null;")
    end
}

local function createCamFilterHelpers(camName)
    return {
        setFilters = function(self, args)
            return runHaxeCode(generateFilterCode("game." .. camName, resolveFilterArgs(self, args)))
        end,
        clearFilters = function()
            return runHaxeCode("game." .. camName .. ".filters = null;")
        end
    }
end

-- Mở rộng hệ thống children để tối ưu lookup cache
local characterChildren = {
    animation = {curAnim = {}},
    cameraPosition = {},
    offset = {},
    scale = {},
    scrollFactor = {},
    velocity = {},
    colorTransform = {}
}

local flxGChildren = {
    camera = {flashSprite = {}, scroll = {}, scale = {}, target = {}},
    sound = {music = {}},
    save = {data = {}},
    keys = {justPressed = {}, pressed = {}, justReleased = {}},
    mouse = {x = {}, y = {}, justPressed = {}, pressed = {}, justReleased = {}},
    random = {},
    game = {}
}

local uiChildren = {
    scale = {},
    offset = {},
    scrollFactor = {},

}

local function appendPath(path, key)
    if path == nil or path == '' then return tostring(key) end
    return path .. '.' .. tostring(key)
end

-- ============================================================
-- REFERENCE RESOLVER (HAXE CALL COMPILER)
-- ============================================================
PsychObject.Ref = setmetatable({}, {
    __call = function(_, target, field)
        local ok, pType = pcall(function() return target:getProxyType() end)
        local expr = ''
        
        if ok and pType == 'class' then
            expr = target:className() .. '.' .. tostring(field)
        elseif ok and pType == 'object' then
            local path = target:path()
            expr = (path == '' and 'game' or path) .. '.' .. tostring(field)
        else
            expr = tostring(target) .. '.' .. tostring(field)
        end
        
        return { __isHaxeRef = true, expr = expr }
    end
})

local ReferenceResolver = {}

function ReferenceResolver.needsCompilation(args)
    if type(args) ~= 'table' then return false end
    for _, v in pairs(args) do
        if type(v) == 'table' then
            if v.__isHaxeRef then return true end
            local ok, pType = pcall(function() return v:getProxyType() end)
            if ok and (pType == 'object' or pType == 'class') then return true end
            if ReferenceResolver.needsCompilation(v) then return true end 
        end
    end
    return false
end

function ReferenceResolver.serialize(val)
    if type(val) == 'number' or type(val) == 'boolean' then return tostring(val) end
    if type(val) == 'string' then return sFormat('%q', val) end
    
    if type(val) == 'table' then
        if val.__isHaxeRef then return val.expr end
        
        local ok, pType = pcall(function() return val:getProxyType() end)
        if ok then
            if pType == 'class' then
                return val:className()
            elseif pType == 'object' then
                local path = val:path()
                if path == '' then return 'game' end
                local hxExpr = "game"
                for part in sGmatch(path, "[^%.]+") do
                    hxExpr = "Reflect.getProperty(" .. hxExpr .. ", '" .. part .. "')"
                end
                return hxExpr
            end
        end

        local isArray, count = true, 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= 'number' then isArray = false break end
        end
        
        if count == 0 then return '[]' end

        local elements = {}
        if isArray then
            for i = 1, #val do tInsert(elements, ReferenceResolver.serialize(val[i])) end
            return '[' .. tConcat(elements, ', ') .. ']'
        else
            for k, v in pairs(val) do
                tInsert(elements, tostring(k) .. ': ' .. ReferenceResolver.serialize(v))
            end
            return '{' .. tConcat(elements, ', ') .. '}'
        end
    end
    
    return 'null'
end

function ReferenceResolver.executeClassCall(className, method, args)
    local haxeArgs = {}
    for i = 1, #(args or {}) do 
        tInsert(haxeArgs, ReferenceResolver.serialize(args[i])) 
    end
    local argString = tConcat(haxeArgs, ', ')
    
    local haxeCode = sFormat("return %s.%s(%s);", className, method, argString)
    
    if debugEnabled then debugTrace('Haxe Compile Class Call: ' .. haxeCode, true) end
    return runHaxeCode(haxeCode)
end

function ReferenceResolver.executeObjectCall(path, method, args)
    local haxeArgs = {}
    for i = 1, #(args or {}) do 
        tInsert(haxeArgs, ReferenceResolver.serialize(args[i])) 
    end
    local argString = tConcat(haxeArgs, ', ')
    
    local hxTarget = "game"
    if path ~= '' then
        for part in sGmatch(path, "[^%.]+") do
            hxTarget = "Reflect.getProperty(" .. hxTarget .. ", '" .. part .. "')"
        end
    end
    
    local haxeCode = sFormat("return Reflect.callMethod(%s, Reflect.getProperty(%s, '%s'), [%s]);", hxTarget, hxTarget, method, argString)
    
    if debugEnabled then debugTrace('Haxe Compile Object Call: ' .. path .. '.' .. method, true) end
    return runHaxeCode(haxeCode)
end

local function objectProxy(path, children, helpers, childHelpers)
    local proxy = {}
    local childCache = {}

    local methods = {
        getProxyType = function() return 'object' end,
        get = function(_, property, allowMaps)
            return getProperty(appendPath(path, property), allowMaps == true)
        end,
        set = function(_, property, value, allowMaps, allowInstances)
            local fullPath = appendPath(path, property)
            local result = setProperty(fullPath, value, allowMaps == true, allowInstances == true)
            if debugEnabled then debugTrace(debugPath(fullPath) .. ' = ' .. debugValue(value), result) end
            return result
        end,
        bulkSet = function(_, props, allowMaps, allowInstances)
            for k, v in pairs(props) do
                setProperty(appendPath(path, k), v, allowMaps == true, allowInstances == true)
            end
            if debugEnabled then debugTrace('bulkSet ' .. path, true) end
            return true
        end,
        call = function(_, method, args)
            if ReferenceResolver.needsCompilation(args) then
                return ReferenceResolver.executeObjectCall(path, method, args)
            else
                local fullPath = appendPath(path, method)
                local result = callMethod(fullPath, args or {})
                if debugEnabled then debugTrace('call ' .. fullPath, result) end
                return result
            end
        end,
        path = function() return path end,
    }

    local lookup = methods
    if helpers then
        for k, v in pairs(helpers) do
            if lookup[k] == nil then lookup[k] = v end
        end
    end

    return setmetatable(proxy, {
        __index = function(_, key)
            local found = lookup[key]
            if found then return found end

            local child = children and children[key]
            if child then
                local cached = childCache[key]
                if not cached then
                    local childHelper = childHelpers and childHelpers[key] or nil
                    cached = objectProxy(appendPath(path, key), child, childHelper)
                    childCache[key] = cached
                end
                return cached
            end

            return getProperty(appendPath(path, key))
        end,
        __newindex = function(_, key, value)
            local fullPath = appendPath(path, key)
            local result = setProperty(fullPath, value)
            if debugEnabled then
                debugTrace(debugPath(fullPath) .. ' = ' .. debugValue(value), result)
            end
        end
    })
end

local function classProxy(className, children)
    local proxy = {}
    local childCache = {}

    local function classObjectProxy(path, childNodes, helpers)
        local classObject = {}
        local classChildCache = {}

        local classObjectMethods = {
            getProxyType = function() return 'class' end,
            className = function()
                return className .. (path ~= '' and ('.' .. path) or '')
            end,
            get = function(_, property, allowMaps)
                return getPropertyFromClass(className, appendPath(path, property), allowMaps == true)
            end,
            set = function(_, property, value, allowMaps, allowInstances)
                local fullPath = appendPath(path, property)
                local result = setPropertyFromClass(className, fullPath, value, allowMaps == true, allowInstances == true)
                if debugEnabled then debugTrace('set ' .. className .. '.' .. fullPath, result) end
                return result
            end,
            bulkSet = function(_, props, allowMaps, allowInstances)
                for k, v in pairs(props) do
                    setPropertyFromClass(className, appendPath(path, k), v, allowMaps == true, allowInstances == true)
                end
                if debugEnabled then debugTrace('bulkSet ' .. className .. '.' .. path, true) end
                return true
            end
        }

        local lookup = classObjectMethods
        if helpers then
            for k, v in pairs(helpers) do
                if lookup[k] == nil then lookup[k] = v end
            end
        end

        return setmetatable(classObject, {
            __index = function(_, key)
                local found = lookup[key]
                if found then return found end

                local child = childNodes and childNodes[key]
                if child then
                    if not classChildCache[key] then
                        classChildCache[key] = classObjectProxy(appendPath(path, key), child)
                    end
                    return classChildCache[key]
                end

                return getPropertyFromClass(className, appendPath(path, key))
            end,
            __newindex = function(_, key, value)
                local fullPath = appendPath(path, key)
                local result = setPropertyFromClass(className, fullPath, value)
                if debugEnabled then
                    debugTrace('set ' .. className .. '.' .. fullPath, result)
                end
            end
        })
    end

    local methods = {
        getProxyType = function() return 'class' end,
        get = function(_, property, allowMaps)
            return getPropertyFromClass(className, property, allowMaps == true)
        end,
        set = function(_, property, value, allowMaps, allowInstances)
            local result = setPropertyFromClass(className, property, value, allowMaps == true, allowInstances == true)
            if debugEnabled then debugTrace('set ' .. className .. '.' .. property, result) end
            return result
        end,
        bulkSet = function(_, props, allowMaps, allowInstances)
            for k, v in pairs(props) do
                setPropertyFromClass(className, k, v, allowMaps == true, allowInstances == true)
            end
            if debugEnabled then debugTrace('bulkSet ' .. className, true) end
            return true
        end,
        call = function(_, method, args)
            if ReferenceResolver.needsCompilation(args) then
                return ReferenceResolver.executeClassCall(className, method, args)
            else
                local result = callMethodFromClass(className, method, args or {})
                if debugEnabled then debugTrace('call ' .. className .. '.' .. method, result) end
                return result
            end
        end,
        className = function() return className end,
    }

    local instanceProxy = nil

    return setmetatable(proxy, {
        __index = function(_, key)
            if key == 'instance' then
                if not instanceProxy then instanceProxy = objectProxy('') end
                return instanceProxy
            end

            if methods[key] then return methods[key] end

            local child = children and children[key]
            if child then
                if not childCache[key] then
                    local helpers = (key == 'game') and gameHelpers or nil
                    childCache[key] = classObjectProxy(key, child, helpers)
                end
                return childCache[key]
            end

            return getPropertyFromClass(className, key)
        end,
        __newindex = function(_, key, value)
            local result = setPropertyFromClass(className, key, value)
            if debugEnabled then
                debugTrace('set ' .. className .. '.' .. key, result)
            end
        end
    })
end

function PsychObject.object(path, children) return objectProxy(path, children) end
function PsychObject.class(className, children) return classProxy(className, children) end

local function newGroupProxy(groupName, index)
    local methods = {
        get = function(_, property, allowMaps)
            return getPropertyFromGroup(groupName, index, property, allowMaps == true)
        end,
        set = function(_, property, value, allowMaps, allowInstances)
            local result = setPropertyFromGroup(groupName, index, property, value, allowMaps == true, allowInstances == true)
            if debugEnabled then debugTrace('set group ' .. groupName .. '[' .. index .. '].' .. property, result) end
            return result
        end
    }

    return setmetatable({}, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            return getPropertyFromGroup(groupName, index, key)
        end,
        __newindex = function(_, key, value)
            local result = setPropertyFromGroup(groupName, index, key, value)
            if debugEnabled then debugTrace('set group ' .. groupName .. '[' .. index .. '].' .. key, result) end
        end
    })
end

local groupProxyCache = {}
function PsychObject.group(groupName, index)
    if index == nil then return newGroupProxy(groupName, index) end
    local cache = groupProxyCache[groupName]
    if not cache then cache = {}; groupProxyCache[groupName] = cache end
    local proxy = cache[index]
    if not proxy then proxy = newGroupProxy(groupName, index); cache[index] = proxy end
    return proxy
end

local spriteChildren = {
    animation = {curAnim = {}},
    clipRect = {},
    offset = {},
    origin = {},
    scale = {},
    scrollFactor = {},
    velocity = {},
    colorTransform = {}
}

local function assertTag(tag)
    assert(type(tag) == 'string' and tag ~= '', 'Sprite/Text tag must be a non-empty string')
    assert(not tag:find('.', 1, true), 'Sprite/Text tag cannot contain a dot: ' .. tag)
end

local spriteHelpers = {
    add = function(self, inFront)
        local tag = self:path()
        local result = addLuaSprite(tag, inFront == true)
        if debugEnabled then debugTrace('add sprite ' .. tag, result) end
    end,
    remove = function(self, destroy, group)
        local tag = self:path()
        local result = removeLuaSprite(tag, destroy ~= false, group)
        if debugEnabled then debugTrace('remove sprite ' .. tag, result) end
    end,
    makeGraphic = function(self, width, height, color)
        local tag = self:path()
        local result = makeGraphic(tag, width, height, color or 'FFFFFF')
        if debugEnabled then debugTrace('make graphic ' .. tag, result) end
    end,
    addAnimation = function(self, name, prefix, frameRate, loop)
        local tag = self:path()
        local result = addAnimationByPrefix(tag, name, prefix, frameRate or 24, loop ~= false)
        if debugEnabled then debugTrace('add animation ' .. tag .. '.' .. name, result) end
        return result
    end,
    addAnimationByIndices = function(self, name, prefix, indices, frameRate, loop)
        local tag = self:path()
        local result = addAnimationByIndices(tag, name, prefix, indices, frameRate or 24, loop == true)
        if debugEnabled then debugTrace('add indexed animation ' .. tag .. '.' .. name, result) end
        return result
    end,
    play = function(self, name, forced, reverse, startFrame)
        local tag = self:path()
        local result = playAnim(tag, name, forced == true, reverse == true, startFrame or 0)
        if debugEnabled then debugTrace('play animation ' .. tag .. '.' .. name, result) end
        return result
    end,
    scaleTo = function(self, x, y, updateHitbox)
        local tag = self:path()
        local result = scaleObject(tag, x, y, updateHitbox ~= false)
        if debugEnabled then debugTrace('scale sprite ' .. tag, result) end
    end,
    scroll = function(self, x, y)
        local tag = self:path()
        local result = setScrollFactor(tag, x, y)
        if debugEnabled then debugTrace('scroll factor ' .. tag, result) end
    end,
    camera = function(self, camera)
        local tag = self:path()
        local result = setObjectCamera(tag, camera or 'game')
        if debugEnabled then debugTrace('set camera ' .. tag, result) end
    end,
    center = function(self, axis)
        local tag = self:path()
        local result = screenCenter(tag, axis or 'xy')
        if debugEnabled then debugTrace('center sprite ' .. tag, result) end
    end,
    blend = function(self, mode)
        local tag = self:path()
        local result = setBlendMode(tag, mode or '')
        if debugEnabled then debugTrace('set blend ' .. tag, result) end
    end,
    shader = function(self, shaderName)
        local tag = self:path()
        local result = setSpriteShader(tag, shaderName)
        if debugEnabled then debugTrace('attach shader ' .. shaderName .. ' to ' .. tag, result) end
        return result
    end,
    removeShader = function(self)
        local tag = self:path()
        local result = removeSpriteShader(tag)
        if debugEnabled then debugTrace('detach shader from ' .. tag, result) end
        return result
    end,
    shaderFloat = function(self, uniform, value) return setShaderFloat(self:path(), uniform, value) end,
    shaderInt = function(self, uniform, value) return setShaderInt(self:path(), uniform, value) end,
    shaderBool = function(self, uniform, value) return setShaderBool(self:path(), uniform, value) end,
    shaderFloats = function(self, uniform, values) return setShaderFloatArray(self:path(), uniform, values) end,
    shaderTexture = function(self, uniform, imagePath) return setShaderSampler2D(self:path(), uniform, imagePath) end
}

local spriteProxyCache = {}
local function spriteProxy(tag)
    local cached = spriteProxyCache[tag]
    if cached then return cached end
    assertTag(tag)
    local proxy = objectProxy(tag, spriteChildren, spriteHelpers)
    spriteProxyCache[tag] = proxy
    return proxy
end

local textHelpers = {
    add = function(self) return addLuaText(self:path()) end,
    remove = function(self, destroy) return removeLuaText(self:path(), destroy ~= false) end,
    string = function(self, value) return setTextString(self:path(), value) end,
    size = function(self, value) return setTextSize(self:path(), value) end,
    width = function(self, value) return setTextWidth(self:path(), value) end,
    height = function(self, value) return setTextHeight(self:path(), value) end,
    color = function(self, value) return setTextColor(self:path(), value) end,
    font = function(self, value) return setTextFont(self:path(), value) end,
    border = function(self, size, color, style) return setTextBorder(self:path(), size, color, style or 'outline') end,
    align = function(self, value) return setTextAlignment(self:path(), value) end,
    camera = function(self, camera) return setObjectCamera(self:path(), camera or 'hud') end,
    center = function(self, axis) return screenCenter(self:path(), axis or 'xy') end
}

local textProxyCache = {}
local function textProxy(tag)
    local cached = textProxyCache[tag]
    if cached then return cached end
    assertTag(tag)
    local proxy = objectProxy(tag, spriteChildren, textHelpers)
    textProxyCache[tag] = proxy
    return proxy
end

PsychObject.Sprite = {}
function PsychObject.Sprite.get(tag) return spriteProxy(tag) end
function PsychObject.Sprite.new(tag, image, x, y, options)
    assertTag(tag)
    options = options or {}
    makeLuaSprite(tag, image or '', x or 0, y or 0)

    if options.graphic then makeGraphic(tag, options.graphic[1], options.graphic[2], options.graphic[3] or 'FFFFFF') end
    if options.scrollFactor then setScrollFactor(tag, options.scrollFactor[1], options.scrollFactor[2] or options.scrollFactor[1]) end
    if options.scale then scaleObject(tag, options.scale[1], options.scale[2] or options.scale[1], true) end
    if options.camera then setObjectCamera(tag, options.camera) end
    if options.blend then setBlendMode(tag, options.blend) end
    if options.center then screenCenter(tag, options.center == true and 'xy' or options.center) end
    if options.add ~= false then addLuaSprite(tag, options.inFront == true) end

    return spriteProxy(tag)
end

function PsychObject.Sprite.animated(tag, image, x, y, options)
    assertTag(tag)
    options = options or {}
    makeAnimatedLuaSprite(tag, image or '', x or 0, y or 0, options.spriteType or 'auto')

    local sprite = spriteProxy(tag)
    if options.animation then
        sprite:addAnimation(options.animation.name, options.animation.prefix, options.animation.frameRate, options.animation.loop)
        if options.animation.play ~= false then sprite:play(options.animation.name, true) end
    end
    if options.scrollFactor then sprite:scroll(options.scrollFactor[1], options.scrollFactor[2] or options.scrollFactor[1]) end
    if options.scale then sprite:scaleTo(options.scale[1], options.scale[2] or options.scale[1]) end
    if options.camera then sprite:camera(options.camera) end
    if options.add ~= false then sprite:add(options.inFront) end

    return sprite
end

PsychObject.Text = {}
function PsychObject.Text.get(tag) return textProxy(tag) end
function PsychObject.Text.new(tag, value, width, x, y, options)
    assertTag(tag)
    options = options or {}
    makeLuaText(tag, value or '', width or 0, x or 0, y or 0)

    if options.size then setTextSize(tag, options.size) end
    if options.color then setTextColor(tag, options.color) end
    if options.font then setTextFont(tag, options.font) end
    if options.border then setTextBorder(tag, options.border[1], options.border[2], options.border[3] or 'outline') end
    if options.align then setTextAlignment(tag, options.align) end
    if options.camera then setObjectCamera(tag, options.camera) end
    if options.add ~= false then addLuaText(tag) end

    return textProxy(tag)
end

PsychObject.Camera = {
    game = objectProxy('camGame', {scroll = {}, scale = {}}, createCamFilterHelpers('camGame')),
    hud = objectProxy('camHUD', {scroll = {}, scale = {}}, createCamFilterHelpers('camHUD')),
    other = objectProxy('camOther', {scroll = {}, scale = {}}, createCamFilterHelpers('camOther')),
    follow = objectProxy('camFollow'),
    followPos = objectProxy('camFollowPos'),
    target = cameraSetTarget,
    mouseX = getMouseX,
    mouseY = getMouseY
}

PsychObject.Note = {
    player = function(index) return PsychObject.group('playerStrums', index) end,
    opponent = function(index) return PsychObject.group('opponentStrums', index) end,
    all = function(index) return PsychObject.group('strumLineNotes', index) end,
    unspawn = function(index) return PsychObject.group('unspawnNotes', index) end,
    note = function(index) return PsychObject.group('notes', index) end,
    tweenX = noteTweenX,
    tweenY = noteTweenY,
    tweenAngle = noteTweenAngle,
    tweenAlpha = noteTweenAlpha,
    tweenDirection = noteTweenDirection
}

-- Native Engine Tween Wrappers
PsychObject.Tween = {
    x = doTweenX,
    y = doTweenY,
    angle = doTweenAngle,
    alpha = doTweenAlpha,
    zoom = doTweenZoom,
    color = doTweenColor,
    cancel = cancelTween
}

-- Native Engine Timer Wrappers
PsychObject.Timer = {
    start = runTimer,
    cancel = cancelTimer
}

-- Native Engine Sound Wrappers
PsychObject.Sound = {
    play = playSound,
    music = playMusic,
    pause = pauseSound,
    resume = resumeSound,
    stop = stopSound
}

PsychObject.Shader = {
    load = initLuaShader,
    attach = setSpriteShader,
    detach = removeSpriteShader,
    float = setShaderFloat,
    floats = setShaderFloatArray,
    int = setShaderInt,
    ints = setShaderIntArray,
    bool = setShaderBool,
    bools = setShaderBoolArray,
    texture = setShaderSampler2D
}

PsychObject.Haxe = {
    run = function(code)
        if debugEnabled then debugTrace('run haxe: ' .. code, true) end
        return runHaxeCode(code)
    end,
    eval = function(expr)
        if debugEnabled then debugTrace('eval haxe: ' .. expr, true) end
        return runHaxeCode('return ' .. expr .. ';')
    end
}

local DEBUG_CREDIT = "Psych Object API - by kietNguyen (tea)" 

PsychObject.Debug = {
    enable = function(value)
        debugEnabled = value ~= false
        if debugEnabled then debugOutput(DEBUG_CREDIT, 'FFD700') end
        debugOutput('debug ' .. (debugEnabled and 'enabled' or 'disabled'), '55AAFF')
    end,
    isEnabled = function() return debugEnabled end,
    info = function(message) if debugEnabled then debugOutput(tostring(message), 'FFFFFF') end end,
    mode = function(value)
        assert(value == 'console' or value == 'file' or value == 'both', "Debug mode must be 'console', 'file', or 'both'")
        debugMode = value
    end,
    getMode = function() return debugMode end,
    file = function(path, clear)
        assert(type(path) == 'string' and path ~= '', 'Debug log path must be a non-empty string')
        closeDebugFile()
        debugLogPath = path
        if clear then
            local file = io.open(debugLogPath, 'w')
            if file then file:close() end
        end
        return debugLogPath
    end,
    history = function() return debugHistory end,
    clear = function() debugHistory = {} end
}

function PsychObject.shutdownDebug()
    closeDebugFile()
    debugEnabled = false
    return true
end

-- Haxe-like `game` root child schema.
-- Known object roots become real proxies so chains such as:
--   game.camFollow.x
--   game.camGame.zoom
--   game.boyfriend.animation.curAnim.name
-- work naturally. Unknown/scalar fields still use the native getProperty fallback.
local gameRootChildren = {
    boyfriend = characterChildren,
    dad = characterChildren,
    gf = characterChildren,

    camGame = {scroll = {}, scale = {}},
    camHUD = {scroll = {}, scale = {}},
    camOther = {scroll = {}, scale = {}},

    camFollow = {},
    camFollowPos = {},

    iconP1 = uiChildren,
    iconP2 = uiChildren,
    healthBar = uiChildren,
    healthBarBG = uiChildren,
    scoreTxt = uiChildren,
    timeTxt = uiChildren,
    botplayTxt = uiChildren
}

local gameRootChildHelpers = {
    camGame = createCamFilterHelpers('camGame'),
    camHUD = createCamFilterHelpers('camHUD'),
    camOther = createCamFilterHelpers('camOther')
}

-- ============================================================
-- GAME OBJECT ALIASES (Bổ sung toàn bộ UI / Elements)
-- ============================================================
bf = objectProxy('boyfriend', characterChildren)
dad = objectProxy('dad', characterChildren)
gf = objectProxy('gf', characterChildren)
game = objectProxy('', gameRootChildren, nil, gameRootChildHelpers)

-- Core UI Elements
iconP1 = objectProxy('iconP1', uiChildren)
iconP2 = objectProxy('iconP2', uiChildren)
healthBar = objectProxy('healthBar', uiChildren)
healthBarBG = objectProxy('healthBarBG', uiChildren)
scoreTxt = objectProxy('scoreTxt', uiChildren)
timeTxt = objectProxy('timeTxt', uiChildren)
botplayTxt = objectProxy('botplayTxt', uiChildren)

-- Main Cameras
camGame = PsychObject.Camera.game
camHUD = PsychObject.Camera.hud
camOther = PsychObject.Camera.other

-- ============================================================
-- CLASS PROXIES (Bổ sung đầy đủ cho Psych 1.0.4)
-- ============================================================
FlxG = classProxy('flixel.FlxG', flxGChildren)
Conductor = classProxy('backend.Conductor')
ClientPrefs = classProxy('backend.ClientPrefs', {data = {}, defaultData = {}})
PlayState = classProxy('states.PlayState')
Paths = classProxy('backend.Paths')
CoolUtil = classProxy('backend.CoolUtil')
Language = classProxy('backend.Language')
Difficulty = classProxy('backend.Difficulty')
Mods = classProxy('backend.Mods')
Highscore = classProxy('backend.Highscore')
Song = classProxy('backend.Song')

-- Flixel Utilities
FlxMath = classProxy('flixel.math.FlxMath')
FlxEase = classProxy('flixel.tweens.FlxEase')
FlxColor = classProxy('flixel.util.FlxColor')
FlxTween = classProxy('flixel.tweens.FlxTween')
FlxTimer = classProxy('flixel.util.FlxTimer')

-- Base Game Objects (Dành cho việc ép kiểu/tham chiếu Haxe)
Character = classProxy('objects.Character')
BGSprite = classProxy('objects.BGSprite')
FlxSprite = classProxy('flixel.FlxSprite')

-- System Namespaces
Psych = PsychObject
Sprite = PsychObject.Sprite
Text = PsychObject.Text
Camera = PsychObject.Camera
Note = PsychObject.Note
Shader = PsychObject.Shader
Tween = PsychObject.Tween
Timer = PsychObject.Timer
Sound = PsychObject.Sound
Haxe = PsychObject.Haxe
Debug = PsychObject.Debug
Ref = PsychObject.Ref

return PsychObject
