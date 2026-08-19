# Psych Object API — Psych Engine 1.0.4

Thư viện Lua này làm gọn Reflection API của Psych thành cú pháp thuộc tính như `bf.x`, đồng thời thêm factory/proxy cho sprite, animated sprite, text, camera, notes và shader runtime.

## Cài và nạp

Các file đã nằm đúng trong `mods/My-Mod/scripts/psych_object_api/`. Thêm dòng này ở đầu **mỗi** song/stage/event/note-type Lua sử dụng API:

```lua
local Psych = dofile('mods/My-Mod/scripts/psych_object_api/init.lua')
```

Psych chạy mỗi Lua script trong một Lua state riêng, nên không thể dùng `addLuaScript` làm `import`; mỗi script cần `dofile` riêng. Sau khi nạp, các alias `bf`, `dad`, `gf`, `game`, `camGame`, `camHUD`, `camOther`, `FlxG`, `Sprite`, `Text`, `Camera`, `Note`, `Shader`, `Debug` đều sẵn có. `game` là root PlayState; camera dùng các alias riêng `camGame`, `camHUD`, `camOther`.

Các hàm native của Psych Engine như `doTweenX`, `doTweenY`, `doTweenAngle`, `doTweenAlpha`, `runTimer`, `triggerEvent`, `precacheImage`, `precacheSound`, `precacheMusic` được dùng trực tiếp thay vì tạo wrapper trùng cú pháp.

Nếu shader làm Debug Console khó xem, dùng file log và mở một PowerShell duy nhất để theo dõi:

```lua
Debug.mode('file') -- both {console and file }
Debug.file('mods/My-Mod/psych_object_api.log', true)
Debug.enable(true)

```

## Bắt đầu nhanh

```lua
local Psych = dofile('mods/My-Mod/scripts/psych_object_api/init.lua')

function onCreatePost()
    bf.x = 700
    dad.alpha = 0.7
    gf.scale.x = 1.15
    gf.scale.y = 1.15

    local logo = Sprite.new('logo', 'myImages/logo', 30, 30, {
        camera = 'hud', scale = {0.5, 0.5}
    })
    doTweenAlpha('logoFade', 'logo', 0, 0.4, 'quadOut')

    camHUD.zoom = 1
    game.boyfriend.x = 700
end
```

## Tài liệu

Xem [API.md](API.md) để có reference đầy đủ, bảng tham số, lifecycle callback và các lỗi thường gặp. `examples/full_hud.lua` là ví dụ HUD hoàn chỉnh; `examples/proxy_demo.lua` là ví dụ ngắn.
