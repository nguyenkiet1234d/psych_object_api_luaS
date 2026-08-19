# Debugging Guide — Psych Object API (init.lua)

Hướng dẫn chi tiết để debug khi sử dụng Psych Object API (file init.lua) trong Psych Engine.
Mục tiêu: giúp bạn bật logging, đọc log, hiểu trace Haxe compilation do ReferenceResolver sinh ra, và khắc phục lỗi thường gặp.

Repo / source (permalinks dùng commit hiện tại):
- init.lua: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua

Các phần quan trọng trong mã (tham khảo):
- debugTrace / debugOutput: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L105-L122
- writeDebugFile / ensureDebugFile / closeDebugFile: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L75-L103
- PsychObject.Debug API: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L804-L829
- ReferenceResolver.compile/serialize: https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L224-L313

---

1) Bật/tắt debug nhanh

- Bật debug (console):
  Debug.enable(true)
  Debug.mode('console')

- Ghi vào file log (file only):
  Debug.mode('file')
  Debug.file('mods/my_debug.log', true) -- path và clear file

- Cả hai (console + file):
  Debug.mode('both')
  Debug.file('mods/psych_object_api.log', true)

- Tắt debug:
  Debug.enable(false)
  -- hoặc đóng file và tắt:
  PsychObject.shutdownDebug()

Lưu ý: Debug.enable(true) sẽ in credit và trạng thái, và bắt đầu ghi lịch sử debugHistory (một table lưu các message).

2) Ý nghĩa các chế độ

- console: in ra console thông qua debugPrint / print; tiện khi đang phát triển trên máy và muốn thấy output trực tiếp.
- file: ghi vào `debugLogPath` (mặc định 'mods/psych_object_api.log') — dùng khi console không thể hiển thị hoặc cần lưu lại lịch sử.
- both: đồng thời cả console và file.

3) Vị trí file log & quyền ghi

- Mặc định log ghi vào mods/psych_object_api.log. Bạn có thể đổi bằng Debug.file(path, clear).
- Nếu file không thể mở (permission hoặc đường dẫn không tồn tại), hàm ensureDebugFile sẽ trả false; debugOutput sẽ không ghi. Nếu gặp lỗi ghi, hàm sẽ đóng file handle tự động để tránh crash.
- Nếu log không xuất hiện khi chọn mode 'file': kiểm tra quyền ghi thư mục, đường dẫn tương đối so với root game (thử dùng đường dẫn đầy đủ nếu cần).

4) debugHistory và Debug.info

- debugHistory = table lưu các message với limit circular (~5000 bản ghi). Dùng Debug.history() để lấy table này.
- Debug.info(msg): in message nếu debugEnabled.
- Debug.clear(): xóa debugHistory.

5) Tìm lỗi Haxe serialization / compiled code

- Khi một call cần biên dịch Haxe (ReferenceResolver.needsCompilation trả true), code sẽ build chuỗi Haxe (ReferenceResolver.executeClassCall / executeObjectCall) và gọi runHaxeCode.
- Nếu debugEnabled thì reference resolver sẽ gọi debugTrace('Haxe Compile ...', true) — bạn sẽ thấy thông báo kèm đoạn code Haxe được sinh ra trong console/file.

Ví dụ: nếu bạn gọi PlayState:call('method', { game.boyfriend }), ReferenceResolver sẽ serialize đối tượng proxy thành một chuỗi `Reflect.getProperty(game, 'boyfriend')...` và compile 1 dòng Haxe. Quan sát dòng Haxe này trong log giúp bạn biết engine nhận gì.

Permalink: ReferenceResolver serialization
https://github.com/nguyenkiet1234d/new_aip_luaa/blob/b78003ebfb1f614cbbeb44a68c14f2321f191b6f/init.lua#L224-L280

6) Mẫu phiên debug (bước-by-step)

1. Bật logging: Debug.enable(true); Debug.mode('both'); Debug.file('mods/my_debug.log', true)
2. Thực hiện call nghi ngờ (ví dụ PlayState:call('doSomething', { game.boyfriend }))
3. Mở console để xem output; kiểm tra file mods/my_debug.log để xem log đầy đủ.
4. Tìm trong log các dòng bắt đầu bằng "[PsychObject] Haxe Compile" — đó là code Haxe do ReferenceResolver sinh ra.
5. Sao chép chuỗi Haxe từ log và thử chạy trực tiếp trong Haxe console hoặc dùng runHaxeCode(...) trong Lua để kiểm nghiệm (cẩn thận: runHaxeCode có thể gây lỗi runtime nếu code sai).
6. Nếu runHaxeCode bị lỗi: log sẽ in thông báo FAILED (màu đỏ) — check syntax hoặc object path.

7) Kiểm tra lỗi ghi file (không thể mở file)

- Khi Debug.file() gọi ensureDebugFile và io.open trả nil, Debug.file trả false cùng message lỗi. Giải pháp:
  - Kiểm tra thư mục tồn tại; tạo thư mục nếu cần.
  - Kiểm tra quyền truy cập (game process cần quyền ghi).
  - Dùng đường dẫn tuyệt đối nếu relative gây lỗi.

8) Phân tích debugTrace messages

- debugTrace nhận 2 tham số: action (string) và result (boolean/nil).
- Nếu result == false thì message thêm "-> FAILED" (cờ lỗi) và in màu khác. Nhiệm vụ bạn: tìm những message FAILED và trace nguyên nhân.
- Ví dụ message: "call PlayState.someMethod -> FAILED" có thể do:
  - method không tồn tại
  - serialize args tạo code Haxe sai
  - runHaxeCode trả lỗi runtime
  - setProperty / getProperty lỗi (đường dẫn sai)

9) Thử nghiệm an toàn

- Bao mọi call nghi ngờ bằng pcall để tránh crash toàn script, ví dụ:
  local ok, res = pcall(function() PlayState:call('method', {...}) end)
  if not ok then Debug.info('PlayState call failed: ' .. tostring(res)) end

- Bạn có thể tắt debug sau khi debug xong: PsychObject.shutdownDebug() để đóng file và tắt logging.

10) Các lỗi thường gặp liên quan debug và cách khắc phục nhanh

- Không thấy log nào sau khi bật file mode:
  - Kiểm tra Debug.mode có thực sự set; gọi Debug.getMode() để kiểm tra.
  - Kiểm tra Debug.file(...) trả về path hợp lệ.
  - Kiểm tra quyền ghi, thử dùng đường dẫn mods/debug.log hoặc /tmp/debug.log.

- Log chứa Haxe code nhưng runHaxeCode lỗi cú pháp:
  - Kiểm tra serialize của ReferenceResolver: nếu bạn truyền Lua table phức tạp (chứa function), serializer trả 'null' hoặc tạo mã bất hợp lệ.
  - Thử truyền Ref(target, 'field') thay vì truyền table để giữ reference Haxe sạch.

- debugHistory quá dài / memory concern:
  - Debug.history() trả table; nếu không cần lưu, gọi Debug.clear().

11) Khi cần thêm trace (custom)

- Bạn có thể dùng Debug.info('my message') bất kỳ đâu trong code Lua để in thông tin debug (nếu debugEnabled). Example:
  Debug.info('Value of x = ' .. tostring(bf.x))

- Nếu muốn log thêm từ init.lua, thêm debugOutput(...) hoặc debugTrace(...) tại vị trí cần (chỉnh code source).

12) Debugging Haxe-level failures

- Khi Haxe code được run nhưng lỗi xuất hiện trong Haxe stack, thông báo lỗi có thể xuất ra console hoặc file (tùy engine). Hãy sao chép cả stack trace và Haxe code đã biên dịch để tìm nguyên nhân.
- Đôi khi lỗi do Reflect.getProperty chain không đúng path — kiểm tra biến `path` output từ ReferenceResolver (log sẽ show).

13) Checklist để debug hiệu quả

- 1) Bật Debug.enable(true) + Debug.mode('both')
- 2) Nếu cần ghi file, Debug.file('path', true)
- 3) Reproduce minimal failing call — giảm tham số, dùng pcall
- 4) Kiểm tra logs: tìm "Haxe Compile" hoặc các message "-> FAILED"
- 5) Copy Haxe code ra, test bằng runHaxeCode hoặc Haxe console
- 6) Fix: dùng Ref(...) nếu cần reference Haxe, chuyển Lua function sang Haxe, hoặc sửa path

---

Nếu bạn muốn, mình có thể tiếp tục và:
- A) Chèn các ví dụ debug trực tiếp vào README (ví dụ lệnh mẫu và output mẫu). (Mình sẽ commit file `DEBUGGING.md` đã làm.)
- B) Thêm script nhỏ `tools/inspect_debug.lua` để in Debug.history() và tail log file (thuận tiện khi dev).
- C) Thêm một ví dụ thực tế (demo) với deliberate failing case để bạn thấy log output và Haxe code.

Bạn muốn mình làm tiếp A/B/C nào không?