# AIP (md version with more details )

Phiên bản Markdown chi tiết cho `init.lua` (Psych Object API) — tài liệu này giải thích từ A–Z về cách dùng, biến, hàm, mẫu, lỗi thường gặp, tối ưu hiệu năng, và các ví dụ thực tế.

> Lưu ý: tài liệu viết bằng tiếng Việt, chủ yếu dành cho người dùng Psych Engine modding sử dụng file `init.lua` bạn đã cung cấp.

---

## Mục lục

1. Giới thiệu nhanh
2. Cấu trúc tổng quan của `init.lua`
3. Các khái niệm chính: Proxy, Ref, ReferenceResolver
4. API chính (PsychObject) — danh sách và mô tả
   - Sprite, Text, Camera, Note, Tween, Timer, Sound, Shader, Haxe, Debug, Ref
5. Chi tiết triển khai quan trọng (cách hoạt động nội bộ)
   - objectProxy / classProxy / group proxy
   - getProperty / setProperty gọi qua metamethod
   - Haxe compilation via ReferenceResolver
6. Ví dụ dùng thực tế (cơ bản → nâng cao)
7. Hiệu năng & best practices (tối ưu trong hot paths)
   - Khi cache local, khi dùng bulkSet, v.v.
8. Khi nào dùng `:` và khi nào dùng `.` (cách đúng và tối ưu)
9. Lỗi thường gặp và cách khắc phục
10. Debugging (bật/tắt, log file)
11. Chuẩn code và lưu ý an toàn (assertTag, tên tag, dấu chấm)
12. Tóm tắt nhanh

---

## 1) Giới thiệu nhanh

`init.lua` là một API tiện ích cho Psych Engine (phiên bản tương thích trong repo) cung cấp các proxy Lua để truy cập và thao tác các object, class, nhóm (group) trong engine một cách tự nhiên — giống cú pháp Haxe/JS. Bạn có thể viết `game.camGame.zoom` hoặc `bf.x` trong Lua thay vì gọi trực tiếp getProperty/setProperty.

Mục tiêu của file:
- Tạo các proxy object/class để read/write/call các property/method của engine
- Cung cấp helpers cho sprite/text creation, camera filters, shader helpers, tween/timer/sound wrappers
- Hỗ trợ chuyển tham số đặc biệt sang Haxe thông qua ReferenceResolver khi cần
- Cung cấp debug trace với chế độ console/file/both


## 2) Cấu trúc tổng quan của init.lua

- Localize biến global và function (tối ưu truy cập): e.g., local getProperty = getProperty
- Định nghĩa PsychObject table, debug utilities
- ReferenceResolver: phát hiện khi phải biên dịch sang Haxe và serialize argument
- objectProxy/classProxy/groupProxy: tạo metamethods (__index/__newindex) xử lý get/set/call
- Sprite/Text helper wrappers (spriteProxy, textProxy, PsychObject.Sprite)
- Tạo các alias toàn cục: bf, dad, gf, game, Sprite, Text, Debug, ...

File kết thúc bằng `return PsychObject` để có thể require/dofile lấy PsychObject.


## 3) Khái niệm chính

- Proxy: một table Lua với metamethod __index/__newindex để forward thao tác tới engine qua getProperty/setProperty, hoặc cung cấp method tiện ích (`get`, `set`, `call`, `bulkSet`).
- Ref (PsychObject.Ref): biểu diễn tham chiếu Haxe — dùng khi muốn truyền một biểu thức Haxe thô (vd: game.camGame)
- ReferenceResolver: kiểm tra đối số (args) có chứa Haxe refs hoặc proxy-class/object hay không; nếu có thì serialize thành Haxe code và gọi runHaxeCode thay vì callMethod


## 4) API chính (PsychObject) — mô tả chi tiết

Lưu ý: hầu hết các API return proxy object để chaining.

- PsychObject.object(path, children)
  - Trả về object proxy cho path (ví dụ "boyfriend" hoặc "iconP1").
  - proxy hỗ trợ methods: get, set, bulkSet, call, path, getProxyType
  - Nếu `children` là một table, những child keys sẽ tạo tiếp các proxy con cached

- PsychObject.class(className, children)
  - Trả về proxy đại diện cho class Haxe: cho phép get/set/static fields, call class methods
  - methods: get, set, bulkSet, call, className, instance
  - `instance` trả về objectProxy('') (đại diện instance mặc định — tuỳ engine)

- PsychObject.group(groupName, index)
  - Trả về proxy cho group item cụ thể (sử dụng getPropertyFromGroup/setPropertyFromGroup)

- PsychObject.Sprite
  - .get(tag) — lấy proxy của sprite theo tag
  - .new(tag, image, x, y, options) — tạo sprite và trả proxy
  - .animated(...) — tạo animated sprite
  - sprite proxy có nhiều helper methods: add, remove, play, addAnimation, scaleTo, scroll, camera, center, blend, shader, removeShader, shaderFloat, v.v.

- PsychObject.Text
  - .get(tag) và .new(tag, value, width, x, y, options)
  - helpers: add, remove, string, size, width, height, color, font, border, align, camera, center

- PsychObject.Camera
  - game/hud/other/follow/followPos proxies
  - target, mouseX, mouseY (thực tế target = cameraSetTarget)
  - camGame.setFilters(...) via Haxe filter helpers

- PsychObject.Note
  - player/opponent/all/unspawn/note -> group proxies
  - tweenX/Y/Angle/Alpha/Direction -> note tween functions

- PsychObject.Tween / Timer / Sound / Shader / Haxe / Debug
  - wrappers trực tiếp cho các hàm native: doTweenX, runTimer, playSound, initLuaShader, runHaxeCode, v.v.
  - PsychObject.Haxe.run(code) và .eval(expr) để gọi Haxe code
  - Debug helpers: Debug.enable, Debug.mode, Debug.file(path, clear), Debug.history(), Debug.clear()

- PsychObject.Ref
  - Gọi như Ref(target, field) để nhận về một table {__isHaxeRef=true, expr='...'}. Thường dùng khi cần pass một Haxe reference vào gọi class/object method (ReferenceResolver sẽ detect)


## 5) Chi tiết triển khai quan trọng

- Localization (local ...) giảm overhead tra bảng global mỗi lần gọi — rất quan trọng cho performance.
- Metamethods: objectProxy và classProxy tạo table với __index và __newindex:
  - __index trả về method nếu tồn tại, child proxy nếu là child schema, hoặc fallback getProperty/getPropertyFromClass
  - __newindex gọi setProperty/setPropertyFromClass
- child cache: mỗi proxy lưu childCache để không tạo nhiều proxy cho cùng path
- ReferenceResolver.serialize:
  - Serializes Lua values to Haxe code: numbers/booleans -> tostring, strings -> quoted, tables -> [ ... ] hoặc {k: v}
  - Nếu value là proxy object/class, chuyển thành Reflect.getProperty(...) chain để tham chiếu object Haxe thực
- executeClassCall / executeObjectCall: nối argument đã serialize vào code Haxe và runHaxeCode để thực thi


## 6) Ví dụ dùng thực tế

1) Lấy proxy cho sprite và điều khiển animation

```lua
local b = Sprite.get("hero")
-- Gọi method play (self truyền tự động bằng :)
b:play("idle", true)
-- Thay đổi alpha bằng __newindex (sẽ gọi setProperty)
b.alpha = 0.5
-- Hoặc dùng helper set
b:set("alpha", 0.8)
```

2) Tạo sprite mới với options

```lua
local s = PsychObject.Sprite.new("bg", "bgImage", 0, 0, {
  graphic = {800, 600, '000000'},
  scrollFactor = {1, 1},
  scale = {1, 1},
  camera = 'game',
  center = true
})

s:scaleTo(1.2, 1.2)
s:add(true) -- add in front
```

3) Gọi method class Haxe có argument là reference tới game object

```lua
-- Giả sử có method class: SomeClass.doSomething(target)
-- Muốn truyền game.boyfriend để Haxe nhận dạng proper object reference
local res = Ref( game.boyfriend, 'x' ) -- hoặc Psych.Ref( game.boyfriend, 'x' )
-- Thực ra để gọi method ta dùng: ClassProxy:call
PlayState:call('someHaxeMethod', { Ref(game, 'camGame') })
```

4) Dùng bulkSet để cập nhật nhiều property cùng lúc (hiệu quả hơn gọi set nhiều lần)

```lua
local p = PsychObject.object('boyfriend')
p:bulkSet({ x = 100, y = 200, alpha = 1 })
```

5) Filters via Haxe: set filters trên cam

```lua
-- Dùng camera helper để set filter
game.camGame:setFilters({ 'myShader' })
-- Hoặc trống để clear
game.camGame:clearFilters()
```

6) Debug logging

```lua
Debug.enable(true)
Debug.mode('both') -- console + file
Debug.file('mods/mylog.log', true) -- đổi file và clear
Debug.info('Start script')
```


## 7) Hiệu năng & best practices

- Vấn đề hiệu năng chính: mỗi lần truy cập thuộc tính qua proxy kích hoạt getProperty/setProperty (về phía engine) — đó là chi phí lớn nhất.
- Chiến lược giảm chi phí:
  1. Cache proxy vào local: local b = Sprite.get("hero")
  2. Cache hàm method vào local khi gọi nhiều lần:
     local get = b.get -- cache function lookup
     for i=1,10000 do local x = get(b, 'x') end
  3. Cache giá trị nếu không đổi: local bx = b.x
  4. Dùng bulkSet khi cần set nhiều thuộc tính cùng lúc
  5. Tránh truy xuất quan trọng trong mỗi frame nếu không cần — đọc 1 lần rồi reuse

- Localization kỹ lưỡng: init.lua đã local hóa các hàm native ở đầu file để giảm chi phí tra bảng global — bạn không cần làm thêm nếu dùng API.

- Tránh tạo proxy liên tục trong vòng lặp; proxy đã cached ở spriteProxyCache / textProxyCache / groupProxyCache.


## 8) Khi nào dùng ":" và khi nào dùng "."

- Dấu `:` (colon)
  - Dùng để gọi method có định nghĩa `function(self, ...)` — đồng thời Lua tự truyền `self` làm arg đầu tiên.
  - Ví dụ: b:play('idle', true) tương đương b.play(b, 'idle', true).
  - Sử dụng `:` khi gọi các helper methods trong proxy (b:play, b:add, p:bulkSet, v.v.). Đây là cách idiomatic, đúng ngữ nghĩa.

- Dấu `.` (dot)
  - Dùng để truy xuất thuộc tính (b.x) — sẽ kích hoạt __index metamethod và gọi getProperty fallback.
  - Dùng để lấy một phương thức mà bạn muốn gọi thủ công truyền self: local fn = b.play; fn(b, 'idle')
  - Khi dùng `.` để gọi method, bạn phải truyền `self` thủ công: b.play(b, 'idle') hoặc local f = b.play; f(b, ...)

- Về hiệu năng: sự khác biệt giữa `:` và `.` là không đáng kể so với chi phí gọi metamethod và go-between engine. Thứ quan trọng hơn là:
  - Giảm số lần gọi metamethod bằng cách cache values hoặc functions
  - Dùng bulk APIs nếu có

Tóm lại:
- Dùng `:` cho method calls; dùng `.` cho property access.
- Nếu muốn tối ưu, cache method reference hoặc giá trị vào local.


## 9) Lỗi thường gặp và cách khắc phục

1. object.get không tồn tại
   - Giải thích: file có `PsychObject.object(...)` và alias `PsychObject.Sprite.get`, `Sprite.get` v.v. Không có global tên `object`.
   - Cách sửa: dùng `PsychObject.object('path')` hoặc `Sprite.get('tag')`.

2. assertTag lỗi: tag chứa dấu chấm hoặc rỗng
   - Lỗi: assertTag sẽ assert nếu tag là empty string hoặc chứa dấu `.`
   - Sửa: đổi tag tránh dấu chấm: `"mySprite"` thay vì `"my.sprite"`.

3. Gọi method class/object với argument là proxy
   - Nếu truyền proxy hoặc Haxe ref, ReferenceResolver sẽ cố `serialize` và run Haxe code. Nếu serialize sai, gọi sẽ lỗi.
   - Debug: bật Debug.enable(true) để xem trace Haxe code đang chạy.

4. Tên branch / default branch assumption
   - Khi bạn tải file từ GitHub, đừng giả sử default branch là `main` — init.lua tôn trọng môi trường. Đây liên quan đến commit/đẩy file, không phải runtime.

5. Gọi method bằng dấu `.` mà quên truyền self
   - Lỗi logic: `b.play('anim')` sẽ cố gọi `play` như một function không có self — không truyền đúng. Hãy dùng `b:play('anim')`.

6. Tham chiếu group index nil
   - PsychObject.group('someGroup', nil) trả proxy không gắn index — tránh để index nil khi bạn muốn element cụ thể.


## 10) Debugging

- Bật debug: Debug.enable(true)
- Chế độ: Debug.mode('console'|'file'|'both')
- Lưu file log: Debug.file(path, clear)
- Debug.history() trả về lịch sử trace (một table), Debug.clear() để xoá
- Khi debugEnabled, API sẽ gọi debugTrace mỗi khi get/set/call và Haxe compile; điều này rất hữu ích để tìm chỗ lỗi serialize hoặc gọi Haxe không đúng.

File log mặc định là `mods/psych_object_api.log`.


## 11) Chuẩn code và lưu ý an toàn

- Không dùng dấu `.` trong sprite/text tag vì assertTag chặn điều này.
- Khi truyền options vào Sprite.new hoặc Text.new, kiểm tra type đúng (table, boolean, number) để tránh tham số lạ.
- Khi cần thao tác nhiều field, dùng bulkSet để tránh nhiều lần gõ setProperty.


## 12) Tóm tắt nhanh (cheat-sheet)

- Lấy proxy sprite: local s = Sprite.get('tag')
- Tạo sprite: local s = PsychObject.Sprite.new('tag', 'image', x, y, { scale = {1,1}, add = true })
- Lấy boyfriend x: local bx = bf.x  -- hoặc bf:get('x')
- Set alpha: bf.alpha = 0.5  -- hoặc bf:set('alpha', 0.5)
- Call method: PlayState:call('methodName', { arg1, arg2 })  -- automatically uses Haxe compilation if needed
- Debug on: Debug.enable(true); Debug.mode('both'); Debug.file('mods/log.txt', true)

---

Nếu bạn muốn, tôi có thể:
- Thêm ví dụ code hoàn chỉnh (minimized demo) tích hợp với Psych Engine
- Viết bản tóm tắt bằng tiếng Anh
- Thêm link tham chiếu cụ thể tới dòng mã (permalink) sau khi commit xong

