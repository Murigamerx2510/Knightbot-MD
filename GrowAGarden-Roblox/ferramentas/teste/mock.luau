-- Simulador minimo do Roblox para testar os scripts do jogo fora do Studio.
-- Valida nomes de classes, propriedades, metodos, eventos e enums usando a API oficial
-- (__API_TEXT gerado a partir do API-Dump), e os tipos dos valores atribuidos.

local realTypeof = typeof
local realPrint = print
local H = {}
H.realPrint = realPrint
__H = H
H.errors = {}
H.warnings = {}
H.logs = {}
H.unimplemented = {}
H.deprecatedUse = {}

local function report(kind, message)
	if kind == "error" then
		table.insert(H.errors, message)
		realPrint("[ERRO] " .. message)
	else
		table.insert(H.warnings, message)
		if H.verbose then
			realPrint("[AVISO] " .. message)
		end
	end
end
H.report = report

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

local API = { classes = {}, enums = {} }
do
	local currentClass, currentEnum
	for line in string.gmatch(__API_TEXT, "[^\n]+") do
		local parts = string.split(line, " ")
		local tag = parts[1]
		if tag == "C" then
			currentClass = { name = parts[2], super = parts[3], flags = parts[4], props = {}, funcs = {}, events = {}, callbacks = {} }
			API.classes[parts[2]] = currentClass
		elseif tag == "P" then
			local cat, typeName = string.match(parts[3], "^(%w+):(.+)$")
			currentClass.props[parts[2]] = { cat = cat, type = typeName, flags = parts[4], default = parts[5] or "" }
		elseif tag == "F" then
			currentClass.funcs[parts[2]] = { flags = parts[3] }
		elseif tag == "E" then
			currentClass.events[parts[2]] = { flags = parts[3] }
		elseif tag == "B" then
			currentClass.callbacks[parts[2]] = { flags = parts[3] }
		elseif tag == "N" then
			currentEnum = { name = parts[2], items = {}, byValue = {}, list = {} }
			API.enums[parts[2]] = currentEnum
		elseif tag == "I" then
			currentEnum.items[parts[2]] = tonumber(parts[3])
			table.insert(currentEnum.list, parts[2])
		end
	end
end
H.API = API

local memberCache = {}
local function members(className)
	local cached = memberCache[className]
	if cached then
		return cached
	end
	local result = { props = {}, funcs = {}, events = {}, callbacks = {}, chain = {} }
	local name = className
	while name and API.classes[name] do
		local class = API.classes[name]
		table.insert(result.chain, name)
		for _, kind in { "props", "funcs", "events", "callbacks" } do
			for member, info in class[kind] do
				if result[kind][member] == nil then
					result[kind][member] = info
				end
			end
		end
		name = class.super
	end
	memberCache[className] = result
	return result
end

local function hasFlag(info, flag)
	return info.flags and string.find(info.flags, flag, 1, true) ~= nil
end

local function isA(className, target)
	for _, name in members(className).chain do
		if name == target then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
-- typeof
---------------------------------------------------------------------

__typeof = function(value)
	if type(value) == "table" then
		local mt = getmetatable(value)
		if type(mt) == "table" and rawget(mt, "__type") then
			return rawget(mt, "__type")
		end
	end
	return realTypeof(value)
end

local function isType(value, name)
	return __typeof(value) == name
end

local function checkNumber(value, what)
	if type(value) ~= "number" then
		error(string.format("%s: esperado number, recebeu %s", what, __typeof(value)), 3)
	end
end

local function immutable(t, k)
	error("Nao e possivel alterar " .. tostring(k) .. " de " .. __typeof(t), 2)
end

---------------------------------------------------------------------
-- Vector3 / Vector2
---------------------------------------------------------------------

local Vector3MT = { __type = "Vector3" }
local function V3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vector3MT)
end
local Vector3Methods = {}
function Vector3Methods.Lerp(a, b, t)
	return V3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function Vector3Methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function Vector3Methods.Cross(a, b)
	return V3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3Methods.Max(a, b)
	return V3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function Vector3Methods.Min(a, b)
	return V3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function Vector3Methods.Abs(a)
	return V3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
Vector3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return V3(v.X / m, v.Y / m, v.Z / m)
	elseif Vector3Methods[k] then
		return Vector3Methods[k]
	end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
Vector3MT.__newindex = immutable
Vector3MT.__add = function(a, b)
	if not isType(a, "Vector3") or not isType(b, "Vector3") then
		error("Vector3 + " .. __typeof(b) .. " invalido", 2)
	end
	return V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3MT.__sub = function(a, b)
	if not isType(a, "Vector3") or not isType(b, "Vector3") then
		error("Vector3 - " .. __typeof(b) .. " invalido", 2)
	end
	return V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3MT.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return V3(a.X * b, a.Y * b, a.Z * b)
	elseif isType(b, "Vector3") then
		return V3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	error("Vector3 * " .. __typeof(b) .. " invalido", 2)
end
Vector3MT.__div = function(a, b)
	if type(b) == "number" then
		return V3(a.X / b, a.Y / b, a.Z / b)
	elseif isType(b, "Vector3") then
		return V3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end
	error("Vector3 / " .. __typeof(b) .. " invalido", 2)
end
Vector3MT.__unm = function(a)
	return V3(-a.X, -a.Y, -a.Z)
end
Vector3MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3MT.__tostring = function(v)
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end
Vector3 = {
	new = function(x, y, z)
		x, y, z = x or 0, y or 0, z or 0
		checkNumber(x, "Vector3.new X")
		checkNumber(y, "Vector3.new Y")
		checkNumber(z, "Vector3.new Z")
		return V3(x, y, z)
	end,
	zero = V3(0, 0, 0),
	one = V3(1, 1, 1),
	xAxis = V3(1, 0, 0),
	yAxis = V3(0, 1, 0),
	zAxis = V3(0, 0, 1),
}

local Vector2MT = { __type = "Vector2" }
local function V2(x, y)
	return setmetatable({ X = x, Y = y }, Vector2MT)
end
Vector2MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	end
	error(tostring(k) .. " is not a valid member of Vector2", 2)
end
Vector2MT.__newindex = immutable
Vector2MT.__add = function(a, b)
	return V2(a.X + b.X, a.Y + b.Y)
end
Vector2MT.__sub = function(a, b)
	return V2(a.X - b.X, a.Y - b.Y)
end
Vector2MT.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return V2(a.X * b, a.Y * b)
	end
	return V2(a.X * b.X, a.Y * b.Y)
end
Vector2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
Vector2 = {
	new = function(x, y)
		x, y = x or 0, y or 0
		checkNumber(x, "Vector2.new X")
		checkNumber(y, "Vector2.new Y")
		return V2(x, y)
	end,
	zero = V2(0, 0),
	one = V2(1, 1),
}

---------------------------------------------------------------------
-- CFrame
---------------------------------------------------------------------

local CFrameMT = { __type = "CFrame" }
local function CF(x, y, z, r)
	-- r = matriz de rotacao 3x3 em ordem de linhas
	return setmetatable({ X = x, Y = y, Z = z, _r = r }, CFrameMT)
end
local IDENTITY_R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function mulR(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function transposeR(a)
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end
local function applyR(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
local function rotX(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

local function checkFinite(cf)
	for _, v in { cf.X, cf.Y, cf.Z, table.unpack(cf._r) } do
		if v ~= v or v == math.huge or v == -math.huge then
			report("error", "CFrame com NaN/infinito criado:\n" .. debug.traceback())
			break
		end
	end
	return cf
end

local CFrameMethods = {}
function CFrameMethods.Inverse(a)
	local rt = transposeR(a._r)
	local x, y, z = applyR(rt, -a.X, -a.Y, -a.Z)
	return CF(x, y, z, rt)
end
function CFrameMethods.PointToWorldSpace(a, v)
	local x, y, z = applyR(a._r, v.X, v.Y, v.Z)
	return V3(a.X + x, a.Y + y, a.Z + z)
end
function CFrameMethods.PointToObjectSpace(a, v)
	local x, y, z = applyR(transposeR(a._r), v.X - a.X, v.Y - a.Y, v.Z - a.Z)
	return V3(x, y, z)
end
function CFrameMethods.VectorToWorldSpace(a, v)
	return V3(applyR(a._r, v.X, v.Y, v.Z))
end
function CFrameMethods.VectorToObjectSpace(a, v)
	return V3(applyR(transposeR(a._r), v.X, v.Y, v.Z))
end
function CFrameMethods.ToWorldSpace(a, b)
	return a * b
end
function CFrameMethods.ToObjectSpace(a, b)
	return CFrameMethods.Inverse(a) * b
end
function CFrameMethods.Lerp(a, b, t)
	local rotation = if t >= 0.5 then b._r else a._r
	return CF(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t, rotation)
end
function CFrameMethods.GetComponents(a)
	return a.X, a.Y, a.Z, table.unpack(a._r)
end
CFrameMT.__index = function(cf, k)
	if k == "Position" or k == "p" then
		return V3(cf.X, cf.Y, cf.Z)
	elseif k == "LookVector" then
		return V3(-cf._r[3], -cf._r[6], -cf._r[9])
	elseif k == "RightVector" then
		return V3(cf._r[1], cf._r[4], cf._r[7])
	elseif k == "UpVector" then
		return V3(cf._r[2], cf._r[5], cf._r[8])
	elseif k == "Rotation" then
		return CF(0, 0, 0, cf._r)
	elseif CFrameMethods[k] then
		return CFrameMethods[k]
	end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CFrameMT.__newindex = immutable
CFrameMT.__mul = function(a, b)
	if not isType(a, "CFrame") then
		error("CFrame: operando invalido " .. __typeof(a), 2)
	end
	if isType(b, "CFrame") then
		local x, y, z = applyR(a._r, b.X, b.Y, b.Z)
		return checkFinite(CF(a.X + x, a.Y + y, a.Z + z, mulR(a._r, b._r)))
	elseif isType(b, "Vector3") then
		return CFrameMethods.PointToWorldSpace(a, b)
	end
	error("CFrame * " .. __typeof(b) .. " invalido", 2)
end
CFrameMT.__add = function(a, b)
	if not isType(b, "Vector3") then
		error("CFrame + " .. __typeof(b) .. " invalido", 2)
	end
	return CF(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a._r)
end
CFrameMT.__sub = function(a, b)
	if not isType(b, "Vector3") then
		error("CFrame - " .. __typeof(b) .. " invalido", 2)
	end
	return CF(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a._r)
end
CFrameMT.__tostring = function(cf)
	return string.format("%g, %g, %g", cf.X, cf.Y, cf.Z)
end

local function lookAtR(at, target, up)
	up = up or V3(0, 1, 0)
	local f = target - at
	local m = f.Magnitude
	if m < 1e-9 then
		return IDENTITY_R
	end
	f = f / m
	local right = Vector3Methods.Cross(f, up)
	if right.Magnitude < 1e-6 then
		report("warning", "CFrame.lookAt com direcao paralela ao vetor 'up'")
		right = Vector3Methods.Cross(f, V3(0, 0, 1))
		if right.Magnitude < 1e-6 then
			right = Vector3Methods.Cross(f, V3(1, 0, 0))
		end
	end
	right = right.Unit
	local newUp = Vector3Methods.Cross(right, f)
	-- colunas: right, up, -forward
	return { right.X, newUp.X, -f.X, right.Y, newUp.Y, -f.Y, right.Z, newUp.Z, -f.Z }
end

CFrame = {
	new = function(...)
		local n = select("#", ...)
		local a, b, c = ...
		if n == 0 then
			return CF(0, 0, 0, IDENTITY_R)
		elseif n == 1 then
			if not isType(a, "Vector3") then
				error("CFrame.new: argumento invalido " .. __typeof(a), 2)
			end
			return CF(a.X, a.Y, a.Z, IDENTITY_R)
		elseif n == 2 then
			if not isType(a, "Vector3") or not isType(b, "Vector3") then
				error("CFrame.new(pos, lookAt) invalido", 2)
			end
			return CF(a.X, a.Y, a.Z, lookAtR(a, b))
		elseif n == 3 then
			checkNumber(a, "CFrame.new X")
			checkNumber(b, "CFrame.new Y")
			checkNumber(c, "CFrame.new Z")
			return checkFinite(CF(a, b, c, IDENTITY_R))
		elseif n == 12 then
			local v = { ... }
			return CF(v[1], v[2], v[3], { v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12] })
		end
		error("CFrame.new com " .. n .. " argumentos nao suportado no simulador", 2)
	end,
	Angles = function(rx, ry, rz)
		checkNumber(rx, "CFrame.Angles rx")
		checkNumber(ry, "CFrame.Angles ry")
		checkNumber(rz, "CFrame.Angles rz")
		return CF(0, 0, 0, mulR(mulR(rotX(rx), rotY(ry)), rotZ(rz)))
	end,
	fromEulerAnglesYXZ = function(rx, ry, rz)
		return CF(0, 0, 0, mulR(mulR(rotY(ry), rotX(rx)), rotZ(rz)))
	end,
	lookAt = function(at, target, up)
		if not isType(at, "Vector3") or not isType(target, "Vector3") then
			error("CFrame.lookAt: argumentos invalidos", 2)
		end
		if up ~= nil and not isType(up, "Vector3") then
			error("CFrame.lookAt: up invalido", 2)
		end
		return checkFinite(CF(at.X, at.Y, at.Z, lookAtR(at, target, up)))
	end,
	identity = CF(0, 0, 0, IDENTITY_R),
}
CFrame.fromEulerAnglesXYZ = CFrame.Angles

---------------------------------------------------------------------
-- Color3, UDim, UDim2, sequencias, TweenInfo, Random
---------------------------------------------------------------------

local Color3MT = { __type = "Color3" }
local function C3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, Color3MT)
end
local Color3Methods = {}
function Color3Methods.Lerp(a, b, t)
	if not isType(b, "Color3") then
		error("Color3:Lerp espera Color3", 2)
	end
	checkNumber(t, "Color3:Lerp alpha")
	return C3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function Color3Methods.ToHSV(c)
	local max, min = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	return 0, (if max == 0 then 0 else (max - min) / max), max
end
Color3MT.__index = function(c, k)
	if Color3Methods[k] then
		return Color3Methods[k]
	end
	error(tostring(k) .. " is not a valid member of Color3", 2)
end
Color3MT.__newindex = immutable
Color3MT.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {
	new = function(r, g, b)
		r, g, b = r or 0, g or 0, b or 0
		checkNumber(r, "Color3.new")
		checkNumber(g, "Color3.new")
		checkNumber(b, "Color3.new")
		return C3(r, g, b)
	end,
	fromRGB = function(r, g, b)
		r, g, b = r or 0, g or 0, b or 0
		checkNumber(r, "Color3.fromRGB")
		checkNumber(g, "Color3.fromRGB")
		checkNumber(b, "Color3.fromRGB")
		return C3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		checkNumber(h, "Color3.fromHSV")
		checkNumber(s, "Color3.fromHSV")
		checkNumber(v, "Color3.fromHSV")
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		if i == 0 then
			return C3(v, t, p)
		elseif i == 1 then
			return C3(q, v, p)
		elseif i == 2 then
			return C3(p, v, t)
		elseif i == 3 then
			return C3(p, q, v)
		elseif i == 4 then
			return C3(t, p, v)
		end
		return C3(v, p, q)
	end,
}

local UDimMT = { __type = "UDim" }
UDimMT.__index = function(_, k)
	error(tostring(k) .. " is not a valid member of UDim", 2)
end
UDimMT.__newindex = immutable
UDim = {
	new = function(scale, offset)
		scale, offset = scale or 0, offset or 0
		checkNumber(scale, "UDim.new")
		checkNumber(offset, "UDim.new")
		return setmetatable({ Scale = scale, Offset = offset }, UDimMT)
	end,
}
local UDim2MT = { __type = "UDim2" }
UDim2MT.__index = function(u, k)
	if k == "Width" then
		return u.X
	elseif k == "Height" then
		return u.Y
	end
	error(tostring(k) .. " is not a valid member of UDim2", 2)
end
UDim2MT.__newindex = immutable
local function U2(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2MT)
end
UDim2MT.__add = function(a, b)
	return U2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		xs, xo, ys, yo = xs or 0, xo or 0, ys or 0, yo or 0
		checkNumber(xs, "UDim2.new")
		checkNumber(xo, "UDim2.new")
		checkNumber(ys, "UDim2.new")
		checkNumber(yo, "UDim2.new")
		return U2(xs, xo, ys, yo)
	end,
	fromScale = function(x, y)
		checkNumber(x, "UDim2.fromScale")
		checkNumber(y, "UDim2.fromScale")
		return U2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		checkNumber(x, "UDim2.fromOffset")
		checkNumber(y, "UDim2.fromOffset")
		return U2(0, x, 0, y)
	end,
}

local function simpleType(name, fields)
	local mt = { __type = name }
	mt.__index = function(_, k)
		error(tostring(k) .. " is not a valid member of " .. name, 2)
	end
	mt.__newindex = immutable
	return function(data)
		return setmetatable(data, mt)
	end
end
local makeNumberRange = simpleType("NumberRange")
NumberRange = {
	new = function(min, max)
		checkNumber(min, "NumberRange.new")
		max = max or min
		checkNumber(max, "NumberRange.new")
		if max < min then
			error("NumberRange: max < min", 2)
		end
		return makeNumberRange({ Min = min, Max = max })
	end,
}
local makeNumberSequence = simpleType("NumberSequence")
local makeNSK = simpleType("NumberSequenceKeypoint")
NumberSequenceKeypoint = {
	new = function(t, v, e)
		return makeNSK({ Time = t, Value = v, Envelope = e or 0 })
	end,
}
NumberSequence = {
	new = function(a, b)
		if type(a) == "number" then
			return makeNumberSequence({ Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } })
		elseif type(a) == "table" and not getmetatable(a) then
			return makeNumberSequence({ Keypoints = a })
		end
		error("NumberSequence.new: argumento invalido " .. __typeof(a), 2)
	end,
}
local makeColorSequence = simpleType("ColorSequence")
local makeCSK = simpleType("ColorSequenceKeypoint")
ColorSequenceKeypoint = {
	new = function(t, c)
		return makeCSK({ Time = t, Value = c })
	end,
}
ColorSequence = {
	new = function(a, b)
		if isType(a, "Color3") then
			if b ~= nil and not isType(b, "Color3") then
				error("ColorSequence.new: segundo argumento invalido", 2)
			end
			return makeColorSequence({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } })
		elseif type(a) == "table" and not getmetatable(a) then
			return makeColorSequence({ Keypoints = a })
		end
		error("ColorSequence.new: argumento invalido " .. __typeof(a), 2)
	end,
}

---------------------------------------------------------------------
-- Enum
---------------------------------------------------------------------

local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = function(item, k)
	if k == "IsA" then
		return function(self, name)
			return rawget(self, "EnumType").Name == name
		end
	end
	error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
EnumItemMT.__newindex = immutable
EnumItemMT.__tostring = function(item)
	return "Enum." .. rawget(item, "EnumType").Name .. "." .. rawget(item, "Name")
end
local EnumTypeMT = { __type = "Enum" }
local enumTypes = {}
EnumTypeMT.__index = function(enumType, k)
	if k == "GetEnumItems" then
		return function()
			local list = {}
			for _, name in API.enums[rawget(enumType, "Name")].list do
				table.insert(list, enumType[name])
			end
			return list
		end
	end
	local items = rawget(enumType, "_items")
	if items[k] then
		return items[k]
	end
	error(tostring(k) .. " is not a valid member of \"Enum." .. rawget(enumType, "Name") .. "\"", 2)
end
EnumTypeMT.__newindex = immutable
for name, info in API.enums do
	local enumType = setmetatable({ Name = name, _items = {} }, EnumTypeMT)
	for itemName, value in info.items do
		rawget(enumType, "_items")[itemName] = setmetatable({ Name = itemName, Value = value, EnumType = enumType }, EnumItemMT)
	end
	enumTypes[name] = enumType
end
Enum = setmetatable({}, {
	__index = function(_, k)
		if enumTypes[k] then
			return enumTypes[k]
		end
		error(tostring(k) .. " is not a valid member of Enums", 2)
	end,
	__newindex = immutable,
})

TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delayTime)
		time = time or 1
		checkNumber(time, "TweenInfo.new time")
		if style ~= nil and not (isType(style, "EnumItem") and rawget(style, "EnumType").Name == "EasingStyle") then
			error("TweenInfo.new: EasingStyle invalido", 2)
		end
		if direction ~= nil and not (isType(direction, "EnumItem") and rawget(direction, "EnumType").Name == "EasingDirection") then
			error("TweenInfo.new: EasingDirection invalido", 2)
		end
		return setmetatable({ Time = time, EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0 }, { __type = "TweenInfo" })
	end,
}

local RandomMT = { __type = "Random" }
local RandomMethods = {}
local function nextRaw(rng)
	-- LCG 48 bits
	rng._s = (rng._s * 25214903917 + 11) % 281474976710656
	return rng._s / 281474976710656
end
function RandomMethods.NextNumber(rng, min, max)
	local r = nextRaw(rng)
	if min ~= nil then
		checkNumber(min, "Random:NextNumber min")
		checkNumber(max, "Random:NextNumber max")
		return min + (max - min) * r
	end
	return r
end
function RandomMethods.NextInteger(rng, min, max)
	checkNumber(min, "Random:NextInteger min")
	checkNumber(max, "Random:NextInteger max")
	if math.floor(min) ~= min or math.floor(max) ~= max then
		error("Random:NextInteger precisa de inteiros", 2)
	end
	if max < min then
		error("Random:NextInteger: max < min", 2)
	end
	return min + math.floor(nextRaw(rng) * (max - min + 1))
end
RandomMT.__index = function(_, k)
	if RandomMethods[k] then
		return RandomMethods[k]
	end
	error(tostring(k) .. " is not a valid member of Random", 2)
end
local randomCounter = 12345
Random = {
	new = function(seed)
		if seed == nil then
			randomCounter += 7919
			seed = randomCounter
		end
		checkNumber(seed, "Random.new seed")
		return setmetatable({ _s = math.abs(math.floor(seed)) % 281474976710656 + 1 }, RandomMT)
	end,
}

---------------------------------------------------------------------
-- Agendador (task) com relogio virtual
---------------------------------------------------------------------

local clock = 0
local EPOCH = 1790000000
local timers = {} -- { time, seq, thread, args }
local seq = 0

H.now = function()
	return clock
end

local function resume(thread, ...)
	if coroutine.status(thread) == "dead" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		report("error", tostring(err) .. "\n" .. debug.traceback(thread))
	end
end
H.resume = resume

local function schedule(time, thread, ...)
	seq += 1
	table.insert(timers, { time = time, seq = seq, thread = thread, args = table.pack(...) })
end

task = {}
function task.spawn(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(thread, ...)
	return thread
end
function task.defer(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	schedule(clock, thread, ...)
	return thread
end
function task.delay(t, fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	schedule(clock + (t or 0), thread, ...)
	return thread
end
function task.wait(t)
	local thread = coroutine.running()
	if not thread or not coroutine.isyieldable() then
		error("task.wait chamado fora de uma thread que pode pausar", 2)
	end
	local start = clock
	schedule(clock + math.max(t or 0, 1 / 60), thread)
	coroutine.yield()
	return clock - start
end
function task.cancel(thread)
	for i = #timers, 1, -1 do
		if timers[i].thread == thread then
			table.remove(timers, i)
		end
	end
end
wait = function(t)
	return task.wait(t)
end
tick = function()
	return EPOCH + clock
end
time = function()
	return clock
end
local realOs = os
os = setmetatable({
	time = function(t)
		if t ~= nil then
			error("os.time(tabela) nao suportado no simulador")
		end
		return math.floor(EPOCH + clock)
	end,
	clock = function()
		return clock
	end,
}, { __index = realOs })
warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	local message = table.concat(parts, " ")
	if string.find(message, "Erro", 1, true) then
		report("error", "warn() com erro: " .. message)
	else
		report("warning", "warn(): " .. message)
	end
end
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	table.insert(H.logs, table.concat(parts, " "))
	if H.verbose then
		realPrint(table.concat(parts, " "))
	end
end

---------------------------------------------------------------------
-- Sinais
---------------------------------------------------------------------

local SignalMT = { __type = "RBXScriptSignal" }
local ConnectionMT = { __type = "RBXScriptConnection" }
local SignalMethods = {}
local function newSignal(name)
	return setmetatable({ _name = name, _connections = {}, _waiting = {} }, SignalMT)
end
function SignalMethods.Connect(signal, fn)
	if type(fn) ~= "function" then
		error("Connect espera uma funcao", 2)
	end
	local connection = setmetatable({ Connected = true, _fn = fn, _signal = signal }, ConnectionMT)
	table.insert(signal._connections, connection)
	return connection
end
function SignalMethods.Once(signal, fn)
	local connection
	connection = SignalMethods.Connect(signal, function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end
function SignalMethods.Wait(signal)
	local thread = coroutine.running()
	table.insert(signal._waiting, thread)
	return coroutine.yield()
end
SignalMT.__index = function(_, k)
	if SignalMethods[k] then
		return SignalMethods[k]
	end
	error(tostring(k) .. " is not a valid member of RBXScriptSignal", 2)
end
ConnectionMT.__index = function(_, k)
	if k == "Disconnect" then
		return function(connection)
			connection.Connected = false
			local list = connection._signal._connections
			for i = #list, 1, -1 do
				if list[i] == connection then
					table.remove(list, i)
				end
			end
		end
	end
	error(tostring(k) .. " is not a valid member of RBXScriptConnection", 2)
end
local function fire(signal, ...)
	local list = table.clone(signal._connections)
	for _, connection in list do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
	local waiting = signal._waiting
	signal._waiting = {}
	for _, thread in waiting do
		resume(thread, ...)
	end
end
H.newSignal = newSignal
H.fire = fire

---------------------------------------------------------------------
-- Instancias
---------------------------------------------------------------------

local InstanceMT = { __type = "Instance" }
local state = setmetatable({}, { __mode = "k" })
H.state = state
local implementations = {} -- [ClassName] = { method = fn }

local TRUE_DEFAULTS = {
	CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true, Archivable = true,
	Visible = true, Enabled = true, AutoButtonColor = true, ResetOnSpawn = true, RequiresHandle = true,
	CanBeDropped = true, RequiresLineOfSight = true, Neutral = true, GlobalShadows = true,
}
-- valores padrao reais do Roblox para enums herdados (a API-Dump nao traz)
local ENUM_DEFAULTS = {
	FillDirection = "Vertical", HorizontalAlignment = "Left", VerticalAlignment = "Top",
	SortOrder = "LayoutOrder", TextXAlignment = "Center", TextYAlignment = "Center",
	ScrollingDirection = "XY", ZIndexBehavior = "Sibling",
}
local NUMBER_DEFAULTS = { TextSize = 14, MaxActivationDistance = 10, Thickness = 1, Brightness = 1, Range = 8, Rate = 20, TextStrokeTransparency = 1 }

local function parseDefault(prop)
	local d = prop.default
	if prop.cat == "Primitive" then
		if prop.type == "bool" then
			if d == "true" then
				return true
			elseif d == "false" then
				return false
			end
			return nil
		elseif prop.type == "string" then
			return d
		else
			return tonumber(d)
		end
	elseif prop.cat == "Enum" then
		local info = API.enums[prop.type]
		if info and info.items[d] then
			return enumTypes[prop.type][d]
		end
	elseif prop.cat == "DataType" and d ~= "" then
		local n = {}
		for number in string.gmatch(d, "[-%d%.e]+") do
			table.insert(n, tonumber(number))
		end
		if prop.type == "Vector3" and #n == 3 then
			return V3(n[1], n[2], n[3])
		elseif prop.type == "Color3" and #n == 3 then
			return C3(n[1], n[2], n[3])
		elseif prop.type == "Vector2" and #n == 2 then
			return V2(n[1], n[2])
		elseif prop.type == "UDim2" and #n == 4 then
			return U2(n[1], n[2], n[3], n[4])
		end
	end
	return nil
end

local function defaultValue(className, name, prop)
	if name == "Name" then
		return className
	end
	if TRUE_DEFAULTS[name] ~= nil and prop.type == "bool" then
		return TRUE_DEFAULTS[name]
	end
	if API.classes[className].props[name] then
		local parsed = parseDefault(prop)
		if parsed ~= nil then
			return parsed
		end
	end
	if name == "Size" and prop.type == "Vector3" then
		return V3(4, 1, 2)
	end
	if prop.cat == "Enum" and ENUM_DEFAULTS[name] and API.enums[prop.type] and API.enums[prop.type].items[ENUM_DEFAULTS[name]] then
		return enumTypes[prop.type][ENUM_DEFAULTS[name]]
	end
	if name == "Shape" and prop.type == "PartType" then
		return enumTypes.PartType.Block
	end
	if prop.cat == "Primitive" then
		if prop.type == "bool" then
			return false
		elseif prop.type == "string" then
			return ""
		else
			return NUMBER_DEFAULTS[name] or 0
		end
	elseif prop.cat == "Enum" then
		local info = API.enums[prop.type]
		if info and info.list[1] then
			return enumTypes[prop.type][info.list[1]]
		end
	elseif prop.cat == "DataType" then
		local t = prop.type
		if t == "Vector3" then
			return V3(0, 0, 0)
		elseif t == "Vector2" then
			return V2(0, 0)
		elseif t == "CFrame" then
			return CF(0, 0, 0, IDENTITY_R)
		elseif t == "Color3" then
			return C3(0.64, 0.64, 0.64)
		elseif t == "UDim2" then
			return U2(0, 0, 0, 0)
		elseif t == "UDim" then
			return UDim.new(0, 0)
		elseif t == "Content" or t == "ContentId" then
			return ""
		elseif t == "NumberRange" then
			return NumberRange.new(0)
		end
	end
	return nil
end

local function isInstance(v)
	return type(v) == "table" and state[v] ~= nil
end
H.isInstance = isInstance

local function fullName(inst)
	local names = {}
	local node = inst
	while node and state[node] and state[node].className ~= "DataModel" do
		table.insert(names, 1, state[node].props.Name or state[node].className)
		node = state[node].parent
	end
	return table.concat(names, ".")
end
H.fullName = fullName

local function checkValue(prop, value, className, name)
	local where = className .. "." .. name
	if value == nil then
		if prop.cat == "Class" then
			return
		end
		error(string.format("Nao pode definir %s como nil", where), 4)
	end
	local cat, t = prop.cat, prop.type
	if cat == "Primitive" then
		if t == "bool" then
			if type(value) ~= "boolean" then
				error(string.format("%s espera boolean, recebeu %s", where, __typeof(value)), 4)
			end
		elseif t == "string" then
			if type(value) ~= "string" and type(value) ~= "number" then
				error(string.format("%s espera string, recebeu %s", where, __typeof(value)), 4)
			end
		else
			if type(value) ~= "number" then
				error(string.format("%s espera number, recebeu %s", where, __typeof(value)), 4)
			end
			if value ~= value then
				error(string.format("%s recebeu NaN", where), 4)
			end
		end
	elseif cat == "DataType" then
		if t == "Content" or t == "ContentId" or t == "ProtectedString" then
			if type(value) ~= "string" then
				error(string.format("%s espera string, recebeu %s", where, __typeof(value)), 4)
			end
		elseif __typeof(value) ~= t then
			error(string.format("%s espera %s, recebeu %s", where, t, __typeof(value)), 4)
		end
	elseif cat == "Enum" then
		if __typeof(value) == "EnumItem" then
			if rawget(value, "EnumType").Name ~= t then
				error(string.format("%s espera Enum.%s, recebeu %s", where, t, tostring(value)), 4)
			end
		elseif type(value) == "string" then
			if not API.enums[t].items[value] then
				error(string.format("%s: '%s' nao e item de Enum.%s", where, value, t), 4)
			end
			report("warning", where .. " recebeu string em vez de EnumItem")
		elseif type(value) == "number" then
			report("warning", where .. " recebeu number em vez de EnumItem")
		else
			error(string.format("%s espera Enum.%s, recebeu %s", where, t, __typeof(value)), 4)
		end
	elseif cat == "Class" then
		if not isInstance(value) then
			error(string.format("%s espera Instance, recebeu %s", where, __typeof(value)), 4)
		end
		if not isA(state[value].className, t) then
			error(string.format("%s espera %s, recebeu %s", where, t, state[value].className), 4)
		end
	end
end

local function getSignal(inst, key)
	local st = state[inst]
	st.signals[key] = st.signals[key] or newSignal(key)
	return st.signals[key]
end

local newInstance

local function isDescendantOf(inst, ancestor)
	local node = state[inst].parent
	while node do
		if node == ancestor then
			return true
		end
		node = state[node].parent
	end
	return false
end

local function descendants(inst, out)
	out = out or {}
	for _, child in state[inst].children do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

local function inDataModel(inst)
	local node = inst
	while node do
		if state[node].className == "DataModel" then
			return true
		end
		node = state[node].parent
	end
	return false
end

local function propChanged(inst, name)
	local st = state[inst]
	local signal = st.signals["Changed:" .. name]
	if signal then
		fire(signal)
	end
end

local function setParent(inst, parent)
	local st = state[inst]
	if st.destroyed then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", st.props.Name or st.className, if parent then tostring(state[parent].props.Name) else "NULL"), 4)
	end
	if parent ~= nil and not isInstance(parent) then
		error("Parent precisa ser uma Instance", 4)
	end
	if parent == inst or (parent and isDescendantOf(parent, inst)) then
		error("Tentativa de criar um ciclo de Parent em " .. fullName(inst), 4)
	end
	local old = st.parent
	if old == parent then
		return
	end
	if old then
		local list = state[old].children
		for i = #list, 1, -1 do
			if list[i] == inst then
				table.remove(list, i)
			end
		end
		fire(getSignal(old, "ChildRemoved"), inst)
	end
	st.parent = parent
	if parent then
		table.insert(state[parent].children, inst)
		fire(getSignal(parent, "ChildAdded"), inst)
		local node = parent
		local added = { inst }
		descendants(inst, added)
		while node do
			local signal = state[node].signals.DescendantAdded
			if signal then
				for _, d in added do
					fire(signal, d)
				end
			end
			node = state[node].parent
		end
		-- WaitForChild pendentes
		local waiters = state[parent].waiters
		local name = st.props.Name or st.className
		if waiters[name] then
			local list = waiters[name]
			waiters[name] = nil
			for _, thread in list do
				resume(thread, inst)
			end
		end
	end
	propChanged(inst, "Parent")
	fire(getSignal(inst, "AncestryChanged"), inst, parent)
end

-- Propriedades com comportamento especial
local getters = {}
local setters = {}

getters.Parent = function(inst)
	return state[inst].parent
end
getters.ClassName = function(inst)
	return state[inst].className
end
getters.Position = function(inst, default)
	local st = state[inst]
	if isA(st.className, "BasePart") then
		local cf = st.props.CFrame or CF(0, 0, 0, IDENTITY_R)
		return V3(cf.X, cf.Y, cf.Z)
	end
	return default()
end
setters.Position = function(inst, value, default)
	local st = state[inst]
	if isA(st.className, "BasePart") then
		local cf = st.props.CFrame or CF(0, 0, 0, IDENTITY_R)
		st.props.CFrame = CF(value.X, value.Y, value.Z, cf._r)
		return
	end
	default()
end
setters.Size = function(inst, value, default)
	local st = state[inst]
	if st.className == "Part" then
		local shape = st.props.Shape
		if shape and rawget(shape, "Name") == "Ball" then
			local d = math.min(value.X, value.Y, value.Z)
			value = V3(d, d, d)
		end
		if value.X < 0.001 or value.Y < 0.001 or value.Z < 0.001 then
			value = V3(math.max(value.X, 0.001), math.max(value.Y, 0.001), math.max(value.Z, 0.001))
		end
		st.props.Size = value
		return
	end
	default()
end
setters.PrimaryPart = function(inst, value, default)
	if value ~= nil and not isDescendantOf(value, inst) then
		report("error", "PrimaryPart de " .. fullName(inst) .. " precisa ser descendente do Model\n" .. debug.traceback())
	end
	default()
end
getters.WorldPivot = function(inst)
	local st = state[inst]
	local primary = st.props.PrimaryPart
	if primary and state[primary] then
		local pst = state[primary]
		return (pst.props.CFrame or CF(0, 0, 0, IDENTITY_R)) * (pst.props.PivotOffset or CF(0, 0, 0, IDENTITY_R))
	end
	if st.props.WorldPivot then
		return st.props.WorldPivot
	end
	-- sem pivot definido: centro da caixa
	local box = implementations.Model.GetBoundingBox(inst)
	return box
end
setters.WorldPivot = function(inst, value)
	local st = state[inst]
	local primary = st.props.PrimaryPart
	if primary and state[primary] then
		local pst = state[primary]
		pst.props.PivotOffset = CFrameMethods.Inverse(pst.props.CFrame or CF(0, 0, 0, IDENTITY_R)) * value
	else
		st.props.WorldPivot = value
	end
end

local function memberError(inst, key)
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), state[inst].className, fullName(inst)), 3)
end

InstanceMT.__index = function(inst, key)
	local st = state[inst]
	if type(key) ~= "string" then
		memberError(inst, key)
	end
	local m = members(st.className)
	local prop = m.props[key]
	if prop then
		if hasFlag(prop, "x") or hasFlag(prop, "p") then
			error(string.format("Sem permissao para ler %s.%s", st.className, key), 2)
		end
		if hasFlag(prop, "d") then
			H.deprecatedUse[st.className .. "." .. key] = true
		end
		local getter = getters[key]
		local function default()
			local value = st.props[key]
			if value == nil and not st.propsSet[key] then
				value = defaultValue(st.className, key, prop)
			end
			return value
		end
		if getter then
			return getter(inst, default)
		end
		return default()
	end
	local func = m.funcs[key]
	if func then
		if hasFlag(func, "p") then
			error(string.format("Sem permissao para chamar %s:%s", st.className, key), 2)
		end
		if hasFlag(func, "d") then
			H.deprecatedUse[st.className .. ":" .. key] = true
		end
		for _, className in m.chain do
			local impl = implementations[className]
			if impl and impl[key] then
				local fn = impl[key]
				return function(self, ...)
					if self ~= inst then
						error(string.format("Use ':' para chamar %s (ex.: obj:%s())", key, key), 2)
					end
					return fn(inst, ...)
				end
			end
		end
		return function(self)
			if self ~= inst then
				error(string.format("Use ':' para chamar %s", key), 2)
			end
			H.unimplemented[st.className .. ":" .. key] = true
			return nil
		end
	end
	local event = m.events[key]
	if event then
		if hasFlag(event, "d") then
			H.deprecatedUse[st.className .. "." .. key] = true
		end
		return getSignal(inst, key)
	end
	if m.callbacks[key] then
		error(string.format("%s e um callback; so pode ser definido", key), 2)
	end
	for _, child in st.children do
		if (state[child].props.Name or state[child].className) == key then
			return child
		end
	end
	memberError(inst, key)
end

InstanceMT.__newindex = function(inst, key, value)
	local st = state[inst]
	local m = members(st.className)
	local prop = m.props[key]
	if prop then
		if hasFlag(prop, "r") or hasFlag(prop, "x") or hasFlag(prop, "w") then
			error(string.format("Nao e possivel alterar %s.%s (somente leitura/sem permissao)", st.className, key), 2)
		end
		if hasFlag(prop, "d") then
			H.deprecatedUse[st.className .. "." .. key] = true
		end
		checkValue(prop, value, st.className, key)
		if key == "Parent" then
			setParent(inst, value)
			return
		end
		if key == "Name" then
			value = tostring(value)
		end
		local old = st.props[key]
		local function default()
			st.props[key] = value
			st.propsSet[key] = true
		end
		local setter = setters[key]
		if setter then
			setter(inst, value, default)
		else
			default()
		end
		if old ~= value then
			propChanged(inst, key)
		end
		return
	end
	if m.callbacks[key] then
		if value ~= nil and type(value) ~= "function" then
			error(key .. " precisa ser uma funcao", 2)
		end
		st.callbacks[key] = value
		return
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), st.className, fullName(inst)), 2)
end
InstanceMT.__tostring = function(inst)
	return state[inst].props.Name or state[inst].className
end

newInstance = function(className, internal)
	local class = API.classes[className]
	if not class then
		error("Classe desconhecida: " .. tostring(className), 3)
	end
	if not internal then
		if string.find(class.flags, "n", 1, true) or string.find(class.flags, "s", 1, true) then
			error("Nao e possivel criar Instance do tipo " .. className, 3)
		end
		if string.find(class.flags, "d", 1, true) then
			H.deprecatedUse["Instance.new(" .. className .. ")"] = true
		end
	end
	local inst = setmetatable({}, InstanceMT)
	state[inst] = {
		className = className,
		props = {},
		propsSet = {},
		children = {},
		parent = nil,
		attributes = {},
		signals = {},
		callbacks = {},
		tags = {},
		waiters = {},
		destroyed = false,
		scale = 1,
	}
	return inst
end
H.newInstance = newInstance

Instance = {
	new = function(className, parent)
		if type(className) ~= "string" then
			error("Instance.new espera o nome da classe", 2)
		end
		local inst = newInstance(className, false)
		if parent ~= nil then
			inst.Parent = parent
		end
		return inst
	end,
}

-- Valores permitidos em atributos
local ATTRIBUTE_TYPES = {
	string = true, boolean = true, number = true, UDim = true, UDim2 = true, BrickColor = true,
	Color3 = true, Vector2 = true, Vector3 = true, CFrame = true, NumberSequence = true,
	ColorSequence = true, NumberRange = true, Rect = true, Font = true, EnumItem = true,
}

local function deepCloneInstance(inst)
	local st = state[inst]
	local copy = newInstance(st.className, true)
	local cst = state[copy]
	for k, v in st.props do
		cst.props[k] = v
	end
	for k, v in st.propsSet do
		cst.propsSet[k] = v
	end
	for k, v in st.attributes do
		cst.attributes[k] = v
	end
	for k, v in st.tags do
		cst.tags[k] = v
	end
	cst.scale = st.scale
	cst.source = st.source
	local map = { [inst] = copy }
	for _, child in st.children do
		local childCopy, childMap = deepCloneInstance(child)
		state[childCopy].parent = copy
		table.insert(cst.children, childCopy)
		for a, b in childMap do
			map[a] = b
		end
	end
	return copy, map
end

local Generic = {}
implementations.Instance = Generic
function Generic.FindFirstChild(inst, name, recursive)
	if type(name) ~= "string" then
		error("FindFirstChild espera string", 3)
	end
	for _, child in state[inst].children do
		if (state[child].props.Name or state[child].className) == name then
			return child
		end
	end
	if recursive then
		for _, child in state[inst].children do
			local found = Generic.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Generic.FindFirstChildOfClass(inst, className)
	for _, child in state[inst].children do
		if state[child].className == className then
			return child
		end
	end
	return nil
end
function Generic.FindFirstChildWhichIsA(inst, className, recursive)
	if not API.classes[className] then
		report("error", "FindFirstChildWhichIsA com classe invalida: " .. tostring(className))
	end
	for _, child in state[inst].children do
		if isA(state[child].className, className) then
			return child
		end
	end
	if recursive then
		for _, child in state[inst].children do
			local found = Generic.FindFirstChildWhichIsA(child, className, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Generic.FindFirstAncestorWhichIsA(inst, className)
	local node = state[inst].parent
	while node do
		if isA(state[node].className, className) then
			return node
		end
		node = state[node].parent
	end
	return nil
end
function Generic.FindFirstAncestor(inst, name)
	local node = state[inst].parent
	while node do
		if state[node].props.Name == name then
			return node
		end
		node = state[node].parent
	end
	return nil
end
function Generic.WaitForChild(inst, name, timeout)
	local found = Generic.FindFirstChild(inst, name)
	if found then
		return found
	end
	local thread = coroutine.running()
	local waiters = state[inst].waiters
	waiters[name] = waiters[name] or {}
	table.insert(waiters[name], thread)
	local limit = timeout or 5
	local done = false
	task.delay(limit, function()
		if done then
			return
		end
		local list = waiters[name]
		if list then
			local index = table.find(list, thread)
			if index then
				table.remove(list, index)
				if not timeout then
					report("error", "Infinite yield possible em WaitForChild('" .. name .. "') de " .. fullName(inst))
				end
				resume(thread, nil)
			end
		end
	end)
	local result = coroutine.yield()
	done = true
	return result
end
function Generic.GetChildren(inst)
	return table.clone(state[inst].children)
end
function Generic.GetDescendants(inst)
	return descendants(inst)
end
function Generic.IsA(inst, className)
	return isA(state[inst].className, className)
end
function Generic.IsDescendantOf(inst, ancestor)
	return isDescendantOf(inst, ancestor)
end
function Generic.IsAncestorOf(inst, descendant)
	return isDescendantOf(descendant, inst)
end
function Generic.GetFullName(inst)
	return fullName(inst)
end
function Generic.Destroy(inst)
	local st = state[inst]
	if st.destroyed then
		return
	end
	for _, child in table.clone(st.children) do
		Generic.Destroy(child)
	end
	if st.parent then
		setParent(inst, nil)
	end
	st.destroyed = true
	fire(getSignal(inst, "Destroying"))
	for _, signal in st.signals do
		signal._connections = {}
	end
end
function Generic.ClearAllChildren(inst)
	for _, child in table.clone(state[inst].children) do
		Generic.Destroy(child)
	end
end
function Generic.Clone(inst)
	local copy, map = deepCloneInstance(inst)
	-- referencias internas (PrimaryPart, Adornee) apontam para as copias
	for original, cloned in map do
		local cst = state[cloned]
		for k, v in cst.props do
			if isInstance(v) and map[v] then
				cst.props[k] = map[v]
			end
		end
	end
	return copy
end
function Generic.GetAttribute(inst, name)
	return state[inst].attributes[name]
end
function Generic.SetAttribute(inst, name, value)
	if type(name) ~= "string" or name == "" or #name > 100 or string.find(name, "[^%w_]") or string.sub(name, 1, 3) == "RBX" then
		error("Nome de atributo invalido: " .. tostring(name), 3)
	end
	if value ~= nil and not ATTRIBUTE_TYPES[__typeof(value)] then
		error(string.format("SetAttribute('%s'): tipo %s nao suportado", name, __typeof(value)), 3)
	end
	local old = state[inst].attributes[name]
	state[inst].attributes[name] = value
	if old ~= value then
		local signal = state[inst].signals["Attr:" .. name]
		if signal then
			fire(signal)
		end
		local any = state[inst].signals.AttributeChanged
		if any then
			fire(any, name)
		end
	end
end
function Generic.GetAttributes(inst)
	return table.clone(state[inst].attributes)
end
function Generic.GetAttributeChangedSignal(inst, name)
	return getSignal(inst, "Attr:" .. name)
end
function Generic.GetPropertyChangedSignal(inst, name)
	if not members(state[inst].className).props[name] then
		error(string.format("%s nao e uma propriedade de %s", tostring(name), state[inst].className), 3)
	end
	return getSignal(inst, "Changed:" .. name)
end
function Generic.AddTag(inst, tag)
	state[inst].tags[tag] = true
end
function Generic.RemoveTag(inst, tag)
	state[inst].tags[tag] = nil
end
function Generic.HasTag(inst, tag)
	return state[inst].tags[tag] == true
end

---------------------------------------------------------------------
-- Partes e modelos
---------------------------------------------------------------------

local function partCFrame(part)
	return state[part].props.CFrame or CF(0, 0, 0, IDENTITY_R)
end

local function partsOf(inst)
	local list = {}
	if isA(state[inst].className, "BasePart") then
		table.insert(list, inst)
	end
	for _, d in descendants(inst) do
		if isA(state[d].className, "BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local PV = {}
implementations.PVInstance = PV
function PV.GetPivot(inst)
	local st = state[inst]
	if isA(st.className, "BasePart") then
		return partCFrame(inst) * (st.props.PivotOffset or CF(0, 0, 0, IDENTITY_R))
	end
	return getters.WorldPivot(inst)
end
function PV.PivotTo(inst, cf)
	if not isType(cf, "CFrame") then
		error("PivotTo espera CFrame", 3)
	end
	checkFinite(cf)
	local st = state[inst]
	if isA(st.className, "BasePart") then
		local offset = st.props.PivotOffset or CF(0, 0, 0, IDENTITY_R)
		st.props.CFrame = cf * CFrameMethods.Inverse(offset)
		return
	end
	local pivot = PV.GetPivot(inst)
	local delta = cf * CFrameMethods.Inverse(pivot)
	for _, part in partsOf(inst) do
		state[part].props.CFrame = delta * partCFrame(part)
	end
	if not st.props.PrimaryPart and st.props.WorldPivot then
		st.props.WorldPivot = cf
	end
end

local ModelImpl = {}
implementations.Model = ModelImpl
function ModelImpl.GetBoundingBox(inst)
	local parts = partsOf(inst)
	if #parts == 0 then
		error("GetBoundingBox em Model sem partes: " .. fullName(inst), 3)
	end
	local minV, maxV = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		local cf = partCFrame(part)
		local size = state[part].props.Size or V3(4, 1, 2)
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local corner = cf * V3(size.X * sx, size.Y * sy, size.Z * sz)
					minV = Vector3Methods.Min(minV, corner)
					maxV = Vector3Methods.Max(maxV, corner)
				end
			end
		end
	end
	local center = (minV + maxV) / 2
	return CF(center.X, center.Y, center.Z, IDENTITY_R), maxV - minV
end
function ModelImpl.GetExtentsSize(inst)
	local _, size = ModelImpl.GetBoundingBox(inst)
	return size
end
function ModelImpl.GetScale(inst)
	return state[inst].scale
end
function ModelImpl.ScaleTo(inst, newScale)
	checkNumber(newScale, "Model:ScaleTo")
	if newScale <= 0 or newScale ~= newScale or newScale == math.huge then
		error("Model:ScaleTo: escala invalida " .. tostring(newScale), 3)
	end
	local st = state[inst]
	local factor = newScale / st.scale
	local pivot = PV.GetPivot(inst)
	for _, part in partsOf(inst) do
		local pst = state[part]
		local cf = partCFrame(part)
		local rel = CFrameMethods.ToObjectSpace(pivot, cf)
		local scaledPos = V3(rel.X * factor, rel.Y * factor, rel.Z * factor)
		pst.props.CFrame = pivot * CF(scaledPos.X, scaledPos.Y, scaledPos.Z, rel._r)
		local size = pst.props.Size or V3(4, 1, 2)
		pst.props.Size = V3(math.max(size.X * factor, 0.001), math.max(size.Y * factor, 0.001), math.max(size.Z * factor, 0.001))
		if pst.props.PivotOffset then
			local po = pst.props.PivotOffset
			pst.props.PivotOffset = CF(po.X * factor, po.Y * factor, po.Z * factor, po._r)
		end
	end
	st.scale = newScale
end
function ModelImpl.TranslateBy(inst, offset)
	PV.PivotTo(inst, PV.GetPivot(inst) + offset)
end

H.partCFrame = partCFrame

---------------------------------------------------------------------
-- DataModel e servicos
---------------------------------------------------------------------

game = newInstance("DataModel", true)
state[game].props.Name = "Game"
local services = {}
local DataModelImpl = {}
implementations.DataModel = DataModelImpl
implementations.ServiceProvider = {
	GetService = function(_, name)
		if services[name] then
			return services[name]
		end
		local class = API.classes[name]
		if not class or not string.find(class.flags, "s", 1, true) then
			error("'" .. tostring(name) .. "' nao e um servico valido", 3)
		end
		local service = newInstance(name, true)
		state[service].props.Name = name
		state[service].parent = game
		table.insert(state[game].children, service)
		services[name] = service
		return service
	end,
	FindService = function(_, name)
		return services[name]
	end,
}
function DataModelImpl.BindToClose(_, fn)
	H.bindToClose = H.bindToClose or {}
	table.insert(H.bindToClose, fn)
end
local GetService = implementations.ServiceProvider.GetService

workspace = GetService(game, "Workspace")
H.workspace = workspace
implementations.Workspace = {
	GetServerTimeNow = function()
		return EPOCH + clock
	end,
}
implementations.WorldRoot = {
	Raycast = function()
		return nil
	end,
}
local camera = newInstance("Camera", true)
state[camera].props.Name = "Camera"
state[camera].props.ViewportSize = V2(1280, 720)
setParent(camera, workspace)
state[workspace].props.CurrentCamera = camera

for _, name in { "Players", "ReplicatedStorage", "ServerScriptService", "Lighting", "StarterPlayer", "StarterGui", "StarterPack", "RunService", "TweenService", "Debris", "CollectionService", "ProximityPromptService", "DataStoreService", "UserInputService", "HttpService", "SoundService", "TextChatService" } do
	GetService(game, name)
end

-- RunService
local RunService = services.RunService
local isStudio = true
implementations.RunService = {
	IsStudio = function()
		return isStudio
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
}

-- Humanoid
implementations.Humanoid = {
	TakeDamage = function(humanoid, amount)
		checkNumber(amount, "Humanoid:TakeDamage")
		local st = state[humanoid]
		local health = humanoid.Health
		if health <= 0 then
			return
		end
		local newHealth = math.max(0, health - amount)
		st.props.Health = newHealth
		st.propsSet.Health = true
		if newHealth <= 0 then
			fire(getSignal(humanoid, "Died"))
		end
	end,
}

-- Debris
implementations.Debris = {
	AddItem = function(_, item, lifetime)
		if not isInstance(item) then
			error("Debris:AddItem espera Instance", 3)
		end
		task.delay(lifetime or 10, function()
			Generic.Destroy(item)
		end)
	end,
}

-- CollectionService
implementations.CollectionService = {
	AddTag = function(_, inst, tag)
		if not isInstance(inst) or type(tag) ~= "string" then
			error("CollectionService:AddTag argumentos invalidos", 3)
		end
		local had = state[inst].tags[tag]
		state[inst].tags[tag] = true
		if not had and H.tagSignals and H.tagSignals[tag] then
			fire(H.tagSignals[tag], inst)
		end
	end,
	RemoveTag = function(_, inst, tag)
		if not isInstance(inst) or type(tag) ~= "string" then
			error("CollectionService:RemoveTag argumentos invalidos", 3)
		end
		state[inst].tags[tag] = nil
	end,
	HasTag = function(_, inst, tag)
		return state[inst].tags[tag] == true
	end,
	GetInstanceAddedSignal = function(_, tag)
		H.tagSignals = H.tagSignals or {}
		H.tagSignals[tag] = H.tagSignals[tag] or newSignal("TagAdded:" .. tag)
		return H.tagSignals[tag]
	end,
	GetTagged = function(_, tag)
		local list = {}
		for _, d in descendants(game) do
			if state[d].tags[tag] then
				table.insert(list, d)
			end
		end
		return list
	end,
}

-- TweenService
implementations.TweenService = {
	Create = function(_, inst, info, goals)
		if not isInstance(inst) then
			error("TweenService:Create espera Instance", 3)
		end
		if __typeof(info) ~= "TweenInfo" then
			error("TweenService:Create espera TweenInfo", 3)
		end
		local m = members(state[inst].className)
		for key, value in goals do
			local prop = m.props[key]
			if not prop then
				error(string.format("TweenService:Create: %s nao e propriedade de %s", tostring(key), state[inst].className), 3)
			end
			checkValue(prop, value, state[inst].className, key)
			if prop.cat ~= "DataType" and not (prop.cat == "Primitive" and prop.type ~= "bool" and prop.type ~= "string") then
				error(string.format("TweenService nao consegue animar %s.%s (%s)", state[inst].className, key, prop.type), 3)
			end
		end
		local tween = newInstance("Tween", true)
		local tst = state[tween]
		tst.tweenTarget = inst
		tst.tweenGoals = goals
		tst.tweenInfo = info
		return tween
	end,
}
implementations.TweenBase = {
	Play = function(tween)
		local tst = state[tween]
		task.delay(tst.tweenInfo.Time, function()
			local target = tst.tweenTarget
			if state[target].destroyed then
				return
			end
			for key, value in tst.tweenGoals do
				target[key] = value
			end
			fire(getSignal(tween, "Completed"), Enum.PlaybackState.Completed)
		end)
	end,
	Cancel = function() end,
	Pause = function() end,
}

-- DataStoreService (em memoria, com validacao JSON)
local storeData = {}
H.storeData = storeData
H.dataStoreFailures = 0
local function jsonEncode(value, path, seen)
	local t = type(value)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return tostring(value)
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("DataStore: numero invalido (NaN/inf) em " .. path)
		end
		return string.format("%.17g", value)
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "table" then
		if getmetatable(value) then
			error("DataStore: valor do tipo " .. __typeof(value) .. " nao pode ser salvo em " .. path)
		end
		if seen[value] then
			error("DataStore: tabela ciclica em " .. path)
		end
		seen[value] = true
		local n = #value
		local count = 0
		local hasString = false
		for k in value do
			count += 1
			if type(k) == "string" then
				hasString = true
			elseif type(k) ~= "number" then
				error("DataStore: chave invalida em " .. path)
			end
		end
		local parts = {}
		if count == 0 then
			seen[value] = nil
			return "[]"
		end
		if not hasString then
			if count ~= n then
				error("DataStore: array com buracos ou chaves numericas soltas em " .. path)
			end
			for i = 1, n do
				table.insert(parts, jsonEncode(value[i], path .. "[" .. i .. "]", seen))
			end
			seen[value] = nil
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for k, v in value do
			if type(k) ~= "string" then
				error("DataStore: tabela mista (chaves string e numero) em " .. path)
			end
			table.insert(parts, string.format("%q", k) .. ":" .. jsonEncode(v, path .. "." .. k, seen))
		end
		seen[value] = nil
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("DataStore: tipo " .. t .. " nao pode ser salvo em " .. path)
end
H.jsonEncode = function(v)
	return jsonEncode(v, "valor", {})
end
local function deepCopyPlain(value)
	if type(value) ~= "table" or getmetatable(value) then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopyPlain(v)
	end
	return copy
end
H.deepCopyPlain = deepCopyPlain
implementations.DataStoreService = {
	GetDataStore = function(_, name)
		if type(name) ~= "string" then
			error("GetDataStore espera string", 3)
		end
		local store = newInstance("DataStore", true)
		state[store].props.Name = name
		storeData[name] = storeData[name] or {}
		state[store].storeName = name
		return store
	end,
}
implementations.GlobalDataStore = {
	GetAsync = function(store, key)
		task.wait(0.05)
		if H.dataStoreFailures > 0 then
			H.dataStoreFailures -= 1
			error("502: API Services rejected request with error. HTTP 0 (Simulado)")
		end
		local raw = storeData[state[store].storeName][key]
		return deepCopyPlain(raw)
	end,
	SetAsync = function(store, key, value, userIds)
		task.wait(0.05)
		if H.dataStoreFailures > 0 then
			H.dataStoreFailures -= 1
			error("502: API Services rejected request with error. HTTP 0 (Simulado)")
		end
		if userIds ~= nil then
			if type(userIds) ~= "table" then
				error("SetAsync: userIds deve ser uma tabela")
			end
			for _, id in userIds do
				if type(id) ~= "number" then
					error("SetAsync: userIds deve conter numeros")
				end
			end
		end
		local encoded = jsonEncode(value, key, {})
		if #encoded > 4000000 then
			error("SetAsync: dados maiores que 4MB")
		end
		storeData[state[store].storeName][key] = deepCopyPlain(value)
		H.lastSaveSize = #encoded
	end,
}

---------------------------------------------------------------------
-- Remotes (com copia e validacao dos argumentos)
---------------------------------------------------------------------

local function checkRemoteValue(value, path, seen)
	local t = __typeof(value)
	if t == "function" or t == "thread" or t == "userdata" then
		error("Remote: valor do tipo " .. t .. " nao pode ser enviado (" .. path .. ")")
	end
	if t == "table" then
		if seen[value] then
			error("Remote: tabela ciclica em " .. path)
		end
		seen[value] = true
		local n = #value
		local count, hasString, hasOther = 0, false, false
		for k, v in value do
			count += 1
			if type(k) == "string" then
				hasString = true
			elseif type(k) ~= "number" then
				hasOther = true
			end
			checkRemoteValue(v, path .. "." .. tostring(k), seen)
		end
		if hasOther then
			error("Remote: chave de tipo invalido em " .. path)
		end
		if hasString and count ~= 0 and n > 0 then
			error("Remote: tabela mista (array + dicionario) perde dados em " .. path)
		end
		if not hasString and count ~= n then
			error("Remote: array com buracos/chaves numericas perde dados em " .. path)
		end
		seen[value] = nil
	end
end
local function copyArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		checkRemoteValue(args[i], "arg" .. i, {})
		args[i] = deepCopyPlain(args[i])
	end
	return args
end
H.localPlayer = nil
implementations.RemoteEvent = {
	FireServer = function(remote, ...)
		local args = copyArgs(...)
		local player = H.localPlayer
		task.defer(function()
			fire(getSignal(remote, "OnServerEvent"), player, table.unpack(args, 1, args.n))
		end)
	end,
	FireClient = function(remote, player, ...)
		if not isInstance(player) or state[player].className ~= "Player" then
			error("FireClient espera um Player", 3)
		end
		local args = copyArgs(...)
		if player == H.localPlayer then
			task.defer(function()
				fire(getSignal(remote, "OnClientEvent"), table.unpack(args, 1, args.n))
			end)
		end
	end,
	FireAllClients = function(remote, ...)
		local args = copyArgs(...)
		if H.localPlayer then
			task.defer(function()
				fire(getSignal(remote, "OnClientEvent"), table.unpack(args, 1, args.n))
			end)
		end
	end,
}
implementations.RemoteFunction = {
	InvokeServer = function(remote, ...)
		local args = copyArgs(...)
		local handler = state[remote].callbacks.OnServerInvoke
		while not handler do
			task.wait(0.1)
			handler = state[remote].callbacks.OnServerInvoke
		end
		local results = table.pack(handler(H.localPlayer, table.unpack(args, 1, args.n)))
		for i = 1, results.n do
			checkRemoteValue(results[i], "retorno" .. i, {})
			results[i] = deepCopyPlain(results[i])
		end
		return table.unpack(results, 1, results.n)
	end,
}

---------------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------------

local Players = services.Players
implementations.Players = {
	GetPlayers = function()
		local list = {}
		for _, child in state[Players].children do
			if state[child].className == "Player" then
				table.insert(list, child)
			end
		end
		return list
	end,
}
implementations.Player = {
	GetMouse = function(player)
		return state[player].mouse
	end,
	Kick = function(player, message)
		H.kicked = H.kicked or {}
		table.insert(H.kicked, { player = player, message = message })
		task.defer(function()
			H.removePlayer(player)
		end)
	end,
	LoadCharacter = function(player)
		H.spawnCharacter(player)
	end,
}

function H.spawnCharacter(player)
	local pst = state[player]
	local old = pst.props.Character
	if old and not state[old].destroyed then
		Generic.Destroy(old)
	end
	local character = newInstance("Model", true)
	state[character].props.Name = state[player].props.Name
	local root = newInstance("Part", true)
	state[root].props.Name = "HumanoidRootPart"
	state[root].props.Size = V3(2, 2, 1)
	state[root].props.CFrame = CF(0, 3, 0, IDENTITY_R)
	setParent(root, character)
	local humanoid = newInstance("Humanoid", true)
	setParent(humanoid, character)
	state[character].props.PrimaryPart = root
	pst.props.Character = character
	-- mochila nova a cada vida
	local oldBackpack = Generic.FindFirstChildOfClass(player, "Backpack")
	if oldBackpack then
		Generic.Destroy(oldBackpack)
	end
	local backpack = newInstance("Backpack", true)
	state[backpack].props.Name = "Backpack"
	setParent(backpack, player)
	-- como no Roblox: CharacterAdded dispara ANTES do personagem ir para o Workspace
	fire(getSignal(player, "CharacterAdded"), character)
	task.defer(function()
		if not state[character].destroyed then
			setParent(character, workspace)
		end
	end)
	return character
end

function H.addPlayer(userId, name, isLocal)
	local player = newInstance("Player", true)
	local pst = state[player]
	pst.props.Name = name
	pst.props.DisplayName = name
	pst.props.UserId = userId
	local gui = newInstance("PlayerGui", true)
	state[gui].props.Name = "PlayerGui"
	setParent(gui, player)
	local scripts = newInstance("PlayerScripts", true)
	state[scripts].props.Name = "PlayerScripts"
	setParent(scripts, player)
	local mouse = newInstance("Mouse", true)
	state[mouse].props.Hit = CF(0, 0, 0, IDENTITY_R)
	pst.mouse = mouse
	if isLocal then
		H.localPlayer = player
		state[Players].props.LocalPlayer = player
	end
	setParent(player, Players)
	fire(getSignal(Players, "PlayerAdded"), player)
	return player
end

function H.removePlayer(player)
	if state[player].parent == nil then
		return
	end
	fire(getSignal(Players, "PlayerRemoving"), player)
	local character = state[player].props.Character
	if character then
		Generic.Destroy(character)
	end
	setParent(player, nil)
end

function H.setMouse(player, hitPosition, target)
	local mst = state[state[player].mouse]
	mst.props.Hit = CF(hitPosition.X, hitPosition.Y, hitPosition.Z, IDENTITY_R)
	mst.props.Target = target
end

function H.moveCharacter(player, position)
	local character = state[player].props.Character
	local root = Generic.FindFirstChild(character, "HumanoidRootPart")
	state[root].props.CFrame = CF(position.X, position.Y, position.Z, IDENTITY_R)
end

---------------------------------------------------------------------
-- Scripts e require
---------------------------------------------------------------------

__MODULES = __MODULES or {}
local moduleCache = {}
require = function(moduleScript)
	if not isInstance(moduleScript) or state[moduleScript].className ~= "ModuleScript" then
		error("require espera um ModuleScript, recebeu " .. __typeof(moduleScript), 2)
	end
	local cached = moduleCache[moduleScript]
	if cached then
		if cached.loading then
			error("require circular detectado em " .. fullName(moduleScript), 2)
		end
		return cached.value
	end
	local factory = __MODULES[state[moduleScript].source]
	if not factory then
		error("Modulo sem codigo: " .. fullName(moduleScript), 2)
	end
	local entry = { loading = true }
	moduleCache[moduleScript] = entry
	local result = table.pack(factory(moduleScript))
	if result.n ~= 1 then
		error("Modulo deve retornar exatamente 1 valor: " .. fullName(moduleScript), 2)
	end
	entry.loading = false
	entry.value = result[1]
	return result[1]
end

function H.makeScript(className, name, sourceKey, parent)
	local inst = newInstance(className, true)
	state[inst].props.Name = name
	state[inst].source = sourceKey
	setParent(inst, parent)
	return inst
end

function H.runScript(scriptInstance)
	local factory = __MODULES[state[scriptInstance].source]
	task.spawn(function()
		factory(scriptInstance)
	end)
end

---------------------------------------------------------------------
-- Laco principal da simulacao
---------------------------------------------------------------------

local function processTimers()
	while true do
		local bestIndex, best = nil, nil
		for i, timer in timers do
			if timer.time <= clock and (best == nil or timer.time < best.time or (timer.time == best.time and timer.seq < best.seq)) then
				bestIndex, best = i, timer
			end
		end
		if not best then
			return
		end
		table.remove(timers, bestIndex)
		resume(best.thread, table.unpack(best.args, 1, best.args.n))
	end
end

function H.step(dt)
	clock += dt
	processTimers()
	fire(getSignal(RunService, "Stepped"), clock, dt)
	fire(getSignal(RunService, "Heartbeat"), dt)
	fire(getSignal(RunService, "RenderStepped"), dt)
	processTimers()
end

function H.run(seconds, dt)
	dt = dt or 0.1
	local target = clock + seconds
	while clock < target - 1e-9 do
		H.step(math.min(dt, target - clock))
	end
end

function H.signal(inst, name)
	return getSignal(inst, name)
end

function H.setStudio(value)
	isStudio = value
end

function H.prop(inst, name)
	return state[inst].props[name]
end

function H.services()
	return services
end

return H
