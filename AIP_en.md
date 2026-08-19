# AIP (English) — Psych Object API (detailed)

This is an English companion document for the Vietnamese AIP file. It explains the Psych Object API implemented in init.lua, how proxies work, how to use the API, best practices, common mistakes, and includes permalinks to important implementation locations in the repository.

Repo and commit used for permalinks:
https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua

Key implementation anchors (permalinks):
- PsychObject.Ref (callable Haxe reference):
  https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L204-L220
- ReferenceResolver.needsCompilation & serialize:
  https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L224-L280
- objectProxy implementation (core object proxy):
  https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L315-L383
- classProxy implementation (core class proxy):
  https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L385-L506
- Sprite helpers (add/play/scale/etc):
  https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L561-L637
- Global aliases section (bf, game, FlxG, PlayState, etc):
  https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L870-L931

Overview
- The init.lua file provides Lua "proxy" objects that forward property reads/writes and method calls to the engine via getProperty / setProperty / callMethod (and their class/group variants).
- When arguments include proxy objects or explicit Haxe references, the ReferenceResolver serializes the arguments into Haxe expressions and calls runHaxeCode instead of the native callMethod bridge. See the links above.

Common entry points
- PsychObject.Sprite.get(tag) / PsychObject.Sprite.new(...)
- PsychObject.Text.get(tag) / PsychObject.Text.new(...)
- PsychObject.object(path) and PsychObject.class(className)
- PsychObject.group(groupName, index)
- Global aliases: bf, dad, gf, game, Sprite, Text, Debug, Ref, PlayState, FlxG, etc.

When to use : vs .
- Use colon (:) to call methods (self passed automatically). Eg: sprite:play("idle").
- Use dot (.) to read/write properties which triggers the proxy metamethods: local x = sprite.x; sprite.alpha = 0.5.
- Performance difference between : and . is negligible compared to the cost of bridging to the engine — cache values and functions in hot loops.

Performance notes and best practices
- Cache proxies and frequently used functions locally: local s = Sprite.get('tag'); local get = s.get
- Use bulkSet when changing many properties at once.
- Avoid constructing new proxies repeatedly in hot loops — the proxy caches exist (spriteProxyCache, groupProxyCache).

Debugging
- Debug.enable(true), Debug.mode('console'|'file'|'both'), Debug.file(path, clear)
- When debugEnabled is on the ReferenceResolver and proxies emit Haxe code traces which are helpful for diagnosing serialization issues.

Advanced usage & classes
- Use Ref(proxy, 'field') to create an explicit Haxe reference that the ReferenceResolver recognizes. See PsychObject.Ref anchor above.
- Passing a proxy value to a class/object call will be serialized into Haxe Reflect.getProperty chain (for objects) or class name (for classes).

If you want more targeted examples for specific engine methods (PlayState methods, Conductor, etc.), tell me which methods you need and I can add example calls using the ReferenceResolver patterns.
