# Advanced Examples — Classes & Advanced Patterns (Psych Object API)

This file explains advanced usage particularly around class proxies, ReferenceResolver behavior, and patterns you are likely to forget. It includes concrete examples and permalinks to the implementation.

Permalinks (implementation anchors used in examples):
- classProxy implementation: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L385-L506
- ReferenceResolver.serialize & needsCompilation: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L224-L280
- PsychObject.Ref: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L204-L220

1) Calling static class methods (no Haxe refs)

```lua
-- Use :call for class methods. This will use callMethodFromClass when args are simple.
local res = FlxG:call('someStaticMethod', { 123, 'hello' })
```

2) Calling class methods that require engine object references

- If you pass a proxy (like game.boyfriend) or an explicit Ref, ReferenceResolver detects it and compiles a Haxe call. This is required when the Haxe method expects an actual engine object reference, not a Lua-serialized value.

```lua
-- Option A: use a proxy directly
PlayState:call('doSomethingWithTarget', { game.boyfriend, 2.0 })

-- Option B: create an explicit Haxe field reference (for example to pass a field rather than the whole object)
local hxRef = Ref(game.boyfriend, 'x')
PlayState:call('setTargetX', { hxRef })
```

3) Working with class.instance

- Access `ClassProxy.instance` when a common instance exists. This yields an object proxy for the instance. Useful when the engine exposes a static `instance` or similar.

```lua
local inst = PlayState.instance
inst:bulkSet({ someField = 123 })
```

4) bulkSet for classes & objects

- Use bulkSet to reduce multiple setProperty calls (faster & clearer):

```lua
Character:bulkSet({ x = 100, y = 200, visible = true })
```

5) When serialization can't handle your argument

- Lua functions cannot be serialized into Haxe by ReferenceResolver. If a Haxe callback is required, either:
  - Expose the callback on Haxe side and call it by name from Lua (via runHaxeCode), or
  - Use runHaxeCode to compose a Haxe call that builds a closure.

6) Debugging class calls

- Enable Debug; ReferenceResolver emits the exact compiled Haxe code when it compiles a call. Use Debug.enable(true) and Debug.mode('both') to see Haxe code + console logging.

7) Common class mistakes

- Forgetting to use `:` for method invocation (loses self). Use `:` for call/bulkSet/get/set/call to ensure `self` is passed properly.
- Passing plain Lua tables when the Haxe method expects object references—use Ref or pass the proxy.

If you'd like I can add examples for specific classes (Conductor, ClientPrefs, Paths, Mods, etc.). Provide method names or behaviors you want to show and I will add concrete examples that call them safely (wrapped in pcall where appropriate).
