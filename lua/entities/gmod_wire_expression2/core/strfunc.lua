local nicename = E2Lib.fixNormal

local function checkFuncName( self, funcname )
	if self.funcs[funcname] then
		return self.funcs[funcname], self.funcs_ret[funcname], true
	elseif wire_expression2_funcs[funcname] then
		return wire_expression2_funcs[funcname][3], wire_expression2_funcs[funcname][2]
	end
end

registerCallback("construct", function(self) self.strfunc_cache = {{}, {}} end)

local insert = table.insert
local concat = table.concat
local function findFunc( self, funcname, typeids, typeids_str )
	local func, func_return_type, func_custom
	local cache = self.strfunc_cache[1]

	local str = funcname .. "(" .. typeids_str .. ")"

	if cache[str] then
		if cache[str][4] then self.prf = self.prf + 15 end
		return cache[str][1], cache[str][2]
	end

	local typeIDsLength = #typeids
	self.prf = self.prf + 5

	if typeIDsLength > 0 then
		if not func then
			func, func_return_type, func_custom = checkFuncName( self, str )
		end

		if not func then
			func, func_return_type, func_custom = checkFuncName( self, funcname .. "(" .. typeids[1] .. ":" .. concat(typeids,"",2) .. ")" )
		end

		if not func then
			for i = typeIDsLength, 1, -1 do
				func, func_return_type, func_custom = checkFuncName( self, funcname .. "(" .. concat(typeids,"",1,i) .. "...)" )
				if func then break end
			end

			if not func then
				func, func_return_type, func_custom = checkFuncName( self, funcname .. "(...)" )
			end
		end

		if not func then
			for i = typeIDsLength, 2, -1 do
				func, func_return_type, func_custom = checkFuncName( self, funcname .. "(" .. typeids[1] .. ":" ..  concat(typeids,"",2,i) .. "...)" )
				if func then break end
			end

			if not func then
				func, func_return_type, func_custom = checkFuncName( self, funcname .. "(" .. typeids[1] .. ":...)" )
			end
		end
	else
		func, func_return_type, func_custom = checkFuncName( self, funcname .. "()" )
	end

	if func then
		self.prf = self.prf + 20
		if self.funcs[str] then self.prf = self.prf + 15 end

		local limiter = self.strfunc_cache[2]
		local limiterLength = #limiter + 1

		cache[str] = { func, func_return_type, limiterLength, func_custom }
		insert( limiter, 1, str )

		if limiterLength == 101 then
			self.strfunc_cache[1][ limiter[101] ] = nil
			self.strfunc_cache[2][101] = nil
		end
	end

	return func, func_return_type
end

__e2setcost(5)

local function ShallowCopy(tbl)
	local ret = {}
	for k, v in next, tbl do
		ret[k] = v
	end
	return ret
end

registerOperator( "stringcall", "", "", function(self, args)
	local op1, funcargs, typeids, typeids_str, returntype = args[2], args[3], args[4], args[5], args[6]
	local funcname = op1[1](self,op1)

	E2Lib.debugPrint("[----- stringcall -----]")
	E2Lib.debugPrint(" ** funcargs:") E2Lib.debugPrint(funcargs)
	-- typeids == funcargs[#funcargs]
	local argn, restoreTypes = 2, {}
	for key, value in next, typeids do
		if value == "xxx" then -- resolve 'unknown' value
			local arg = funcargs[argn]
			restoreTypes[key] = { arg, ShallowCopy(arg) }
			local targetTypeID, targetValue
			if arg.TraceName == "GET" or arg.TraceName == "VAR" or arg.TraceName == "LITERAL" then
				local targetTable = arg[1](self, arg)
				if targetTable then
					targetTypeID, targetValue = targetTable[1], targetTable[2]
				else
					targetTypeID = value
				end
			else
				error("unsupported 'unknown' typing: " .. tostring(arg.TraceName))
			end
			E2Lib.debugPrint(" *** target typeid: " .. targetTypeID .. "  target value: " .. tostring(targetValue))
			E2Lib.debugPrint(" *** arg BEFORE:") E2Lib.debugPrint(arg)
			E2Lib.debugPrint(" *** typeid BEFORE: " .. typeids[key])
			typeids[key], arg.TraceName, arg[1], arg[2], arg[3] = targetTypeID, "LITERAL", function() return targetValue end
			E2Lib.debugPrint(" *** typeid AFTER: " .. typeids[key])
			E2Lib.debugPrint(" *** arg AFTER:") E2Lib.debugPrint(arg)
		else
			E2Lib.debugPrint(" *** skipping key: " .. key .. "  value: " .. value)
		end
		argn = argn + 1
	end
	typeids_str = table.concat(typeids)
	E2Lib.debugPrint(" ** typeids_str: " .. typeids_str)
	local func, func_return_type = findFunc( self, funcname, typeids, typeids_str )

	if not func then E2Lib.raiseException( "No such function: " .. funcname .. "(" .. tps_pretty( typeids_str ) .. ")", 0 ) end

	if returntype ~= "" and func_return_type ~= returntype then
		error( "Mismatching return types. Got " .. nicename(wire_expression_types2[returntype][1]) .. ", expected " .. nicename(wire_expression_types2[func_return_type][1] ), 0 )
	end

	local ret = func( self, funcargs )
	for key, data in next, restoreTypes do
		local ref, copy = data[1], data[2]
		typeids[key] = "xxx"
		for k, v in next, ref do
			ref[k] = nil
		end
		for k, v in next, copy do
			ref[k] = v
		end
	end
	E2Lib.debugPrint(" ** restored original types, funcargs:") E2Lib.debugPrint(funcargs)
	if returntype ~= "" then
		return ret
	end
end)
