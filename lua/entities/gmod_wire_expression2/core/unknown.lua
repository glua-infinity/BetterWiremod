local UNKNOWN_TYPENAME, UNKNOWN_TYPEID, createUnknown, isUnknown, bool, raise = "unknown", "xxx", E2Lib.createUnknown, E2Lib.isUnknown, E2Lib.bool, E2Lib.raiseException

-- This is a special type (for advanced users only).
-- Sole purpose of bypassing type checker and being able to pass table's values directly when doing stringcalls.
registerType("unknown", "xxx", nil,
	nil,
	nil,
	function(retval)
		if retval == nil or isUnknown(retval) then return end
		error(string.format("Return value is not '%s', but a '%s'!", UNKNOWN_TYPENAME, type(retval)), 0)
	end,
	function(v)
		-- If typecheck returns true, the type is wrong.
		-- So, we allow every value to 'downcast' to unknown by returning false... actually not really since we bypass typecheck.
		E2Lib.debugPrint("************* typeof v:", type(v))
		return not isUnknown(v)
	end
)

local function ThrowError(self, condition, message)
	condition = bool(condition)
	if condition ~= 0 or condition == true then return end
	raise(message, 3, self.trace)
	--self:throw(message)
end

__e2setcost(2)

--- XXX = XXX
registerOperator("ass", UNKNOWN_TYPEID, UNKNOWN_TYPEID, function(self, args)
	local lhs, op2, scope = args[2], args[3], args[4]
	local      rhs = op2[1](self, op2)
	self.Scopes[scope][lhs] = rhs
	self.Scopes[scope].vclk[lhs] = true
	return rhs
end)

__e2setcost(1)

--- if (unknown)
e2function number operator_is(unknown xxx)
	return bool(isUnknown(xxx))
end

--- XXX == XXX
e2function number operator==(unknown lhs, unknown rhs)
	return bool(lhs == rhs)
end

--- XXX != XXX
e2function number operator!=(unknown lhs, unknown rhs)
	return bool(lhs ~= rhs)
end

__e2setcost(5)

e2function unknown table:operator[](index)
	local typeid = this.ntypes[index]
	if typeid == nil then return nil end
	return createUnknown(typeid, this.n[index])
end

e2function unknown table:operator[](string key)
	local typeid = this.stypes[key]
	if typeid == nil then return nil end
	return createUnknown(typeid, this.s[key])
end

e2function unknown table:operator[](unknown xxx)
	if not isUnknown(xxx) then return nil end
	local typeid, value = xxx[1], xxx[2]
	if typeid == nil then return nil end
	if isnumber(value) then
		typeid = this.ntypes[value]
		if typeid == nil then return nil end
		return createUnknown(typeid, this.n[value])
	end
	if isstring(value) then
		typeid = this.stypes[value]
		if typeid == nil then return nil end
		return createUnknown(typeid, this.s[value])
	end
	ThrowError(self, false, "'unknown' key must be either of type string or number, got " .. E2Lib.typeName(typeid))
end

e2function void table:operator[](unknown xxxKey, unknown xxxValue)
	ThrowError(self, isUnknown(xxxKey), "'unknown' key is invalid")
	local keyTypeid, keyValue = xxxKey[1], xxxKey[2]
	ThrowError(self, keyTypeid == "s" or keyTypeid == "n", "'unknown' key must be either of type string or number, got " .. E2Lib.typeName(keyTypeid))
	E2Lib.debugPrint("keyTypeid:", keyTypeid, "keyValue:", keyValue)
	local valueTypeid, valueValue
	if isUnknown(xxxValue) then
		valueTypeid, valueValue = xxxValue[1], xxxValue[2]
		ThrowError(self, valueTypeid ~= "xgt", "unsupported operation, 'unknown' value type is gtable which is restricted as table value")
		E2Lib.debugPrint("valueTypeid:", valueTypeid, "valueValue:", valueValue)
	else
		-- Do nothing; This will remove/unset the key from table
	end
	if isnumber(keyValue) then -- numeric index
		this.n[keyValue], this.ntypes[keyValue] = valueValue, valueTypeid
	else --if isstring(keyValue) then -- string key
		this.s[keyValue], this.stypes[keyValue] = valueValue, valueTypeid
	end
end

__e2setcost(1)

--- Returns invalid/default (unknown) value.
e2function unknown nounknown()
	return nil
end

__e2setcost(2)

--- Retrieves internal value's typeid.
e2function string unknown:typeid()
	return isUnknown(this) and this[1] or ""
end

__e2setcost(3)

--- Determines whether internal value is valid according to internal typeid type-check.
e2function number unknown:isValid()
	if not isUnknown(this) then return 0 end
	local typeid, value = this[1], this[2]
	local e2type = wire_expression_types2[typeid]
	if e2type[6] then
		return e2type[6](value) and 0 or 1
	end
	return 0
end

registerCallback("postinit", function()
	local fixDefault, fixNormal = E2Lib.fixDefault, E2Lib.fixNormal
	__e2setcost(5)
	for typeName, e2type in next, wire_expression_types do
		local typeid = e2type[1]

		--- XXX = <Value>
		--[[
		registerOperator("ass", typeid, UNKNOWN_TYPEID, function(self, args)
			local lhs, op2, scope = args[2], args[3], args[4]
			local      rhs = createUnknown(typeid, op2[1](self, op2))
			self.Scopes[scope][lhs] = rhs
			self.Scopes[scope].vclk[lhs] = true
			return rhs
		end)
		]]

		if typeid == UNKNOWN_TYPEID then continue end

		-- XXX = unknown(<Value>)
		registerFunction(UNKNOWN_TYPENAME, typeid, UNKNOWN_TYPEID, function(self, args)
			local op1 = args[2]
			local value = op1[1](self, op1)
			return createUnknown(typeid, value)
		end)

		local name, defaultValue = fixNormal(typeName), e2type[2]

		-- Value = XXX:<type>()
		registerFunction(name, UNKNOWN_TYPEID .. ":", typeid, function(self, args)
			local op1 = args[2]
			local xxx = op1[1](self, op1)
			return isUnknown(xxx) and xxx[1] == typeid and xxx[2] or fixDefault(defaultValue) -- Type check
		end)
	end
end)

--[[ Example Test E2 code:
function myFunc(Msg:string) { print("[myFunc(s)] " + Msg) }
function myFunc(Num) { print("[myFunc(n)] Num=" + Num) }
local F = "myFunc"
local T = table(
    (1337) = "Hello from unknown",
    ("Epic") = "Very epic.",
    (9000) = 9001
)
local XXX = T[1337] # equivalent to T[1337, unknown]
F(XXX)
F(T["Epic"])
F(T[9000])

print("XXX:typeid() = " + XXX:typeid())
print("XXX:isValid() = " + XXX:isValid())

# Output:
# [myFunc(s)] Hello from unknown
# [myFunc(s)] Very epic.
# [myFunc(n)] Num=9001
# XXX:typeid() = s
# XXX:isValid() = 1
]]
