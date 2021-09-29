local UNKNOWN_TYPENAME, UNKNOWN_TYPEID, createUnknown = "unknown", "xxx", E2Lib.createUnknown

-- This is a special type (for advanced users only).
-- Sole purpose of bypassing type checker and being able to pass table's values directly when doing stringcalls.
registerType("unknown", "xxx", nil,
	nil,
	nil,
	function(retval)
		if retval == nil or istable(retval) then return end
		error(string.format("Return value is not '%s', but a '%s'!", UNKNOWN_TYPENAME, type(retval)), 0)
	end,
	function(v)
		-- If typecheck returns true, the type is wrong.
		-- So, we allow every value to 'downcast' to unknown by returning false.
		print("************* typeof v:", type(v)) -- REMOVEME
		return false --v ~= nil or not istable(v)
	end
)

__e2setcost(3)

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
	return istable(xxx) and 1 or 0
end

--- XXX == XXX
e2function number operator==(unknown lhs, unknown rhs)
	return lhs == rhs and 1 or 0
end

--- XXX != XXX
e2function number operator!=(unknown lhs, unknown rhs)
	return lhs ~= rhs and 1 or 0
end

__e2setcost(5)

e2function unknown table:operator[](index)
	local value = this.n[index]
	if value == nil then return nil end
	return createUnknown(this.ntypes[index], value)
end

e2function unknown table:operator[](string key)
	local value = this.s[key]
	if value == nil then return nil end
	return createUnknown(this.stypes[key], value)
end

__e2setcost(1)

--- Return invalid/default (unknown) value.
e2function unknown nounknown()
	return nil
end

--- Retrieve value's internal typeid.
e2function string unknown:typeid()
	return this and this[1] or ""
end

registerCallback("postinit", function()
	local fixDefault, fixNormal = E2Lib.fixDefault, E2Lib.fixNormal
	local skip_types = {
		--xgt = true;
		xxx = true;
	}
	__e2setcost(5)
	for typeName, v in next, wire_expression_types do
		local typeid = v[1]
		if skip_types[typeid] then continue end

		-- XXX = unknown(<Value>)
		registerFunction(UNKNOWN_TYPENAME, typeid, UNKNOWN_TYPEID, function(self, args)
			local op1 = args[2]
			local value = op1[1](self, op1)
			return createUnknown(typeid, value)
		end)

		local name, defaultValue = fixNormal(typeName), v[2]

		-- Value = XXX:<type>()
		registerFunction(name, UNKNOWN_TYPEID .. ":", typeid, function(self, args)
			local op1 = args[2]
			local obj = op1[1](self, op1)
			return obj[1] == typeid and obj[2] or fixDefault(defaultValue) -- Type check
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
F(T[1337])   # same thing as T[1337, unknown]
F(T["Epic"]) # same thing as T["Epic", unknown]
F(T[9000])   # same thing as T[9000, unknown]

# Output:
# [myFunc(s)] Hello from unknown
# [myFunc(s)] Very epic.
# [myFunc(n)] Num=9001
]]
