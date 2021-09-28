
-- This is a special type (for advanced users only).
-- Sole purpose of bypassing type checker and being able to pass table's values directly when doing stringcalls.
registerType("unknown", "xxx")

--[[ Example Test E2 code:
function myFunc(Msg:string) { print("[myFunc(s)] " + Msg) }
function myFunc(Num) { print("[myFunc(n)] Num=" + Num) }
local F = "myFunc"
local T = table(
  (1337) = "Hello from unknown",
  ("Epic") = "Very epic.",
  (9000) = 9001
)
F(T[1337, unknown])
F(T["Epic", unknown])
F(T[9000, unknown])

# Output:
# [myFunc(s)] Hello from unknown
# [myFunc(s)] Very epic.
# [myFunc(n)] Num=9001
]]
