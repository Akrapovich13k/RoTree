--!strict
-- Converts JSON-friendly property values (as emitted by PropertyScanner) back
-- into real Roblox datatypes so the plugin can assign them with foo[Prop] = v.
--
-- Accepted shapes:
--   number / string / boolean    → as-is
--   { r, g, b }                  → Color3
--   { x, y, z }                  → Vector3
--   { x, y }                     → Vector2
--   { scale, offset }            → UDim
--   { x = UDim, y = UDim }       → UDim2
--   { components = { 12 nums } } → CFrame
--   { min, max } (numbers)       → NumberRange
--   { min, max } (Vector2-ish)   → Rect
--   { origin, direction }        → Ray
--   { keypoints = { … } }        → NumberSequence / ColorSequence (by value type)
--   { name, number? }            → BrickColor
--   { __enum, value }            → Enum.<__enum>.<value>
--   string for an enum-typed prop → tries Enum[propName][value]
--   [x, y, z]                    → Vector3 (or Color3 if all in [0,1])
--   [x, y]                       → Vector2
--   [a, b, c, d]                 → UDim2(a, b, c, d)

local PropertyDeserializer = {}

local function isMap(t: any): boolean
	if type(t) ~= "table" then return false end
	for k in pairs(t) do
		if type(k) ~= "number" then return true end
	end
	return false
end

local function isArray(t: any): boolean
	if type(t) ~= "table" then return false end
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then return false end
		n += 1
	end
	for i = 1, n do
		if t[i] == nil then return false end
	end
	return n > 0
end

local function unwrapEnum(propName: string, value: string): any?
	-- Try Enum[<TypeName>][value] using a few candidate type names.
	local candidates = { propName }
	-- Common synonyms
	if propName == "Shape" then table.insert(candidates, "PartType") end
	if propName == "Face" then table.insert(candidates, "NormalId") end
	if propName == "Style" then
		table.insert(candidates, "FrameStyle")
		table.insert(candidates, "ButtonStyle")
		table.insert(candidates, "TrussStyle")
	end
	for _, name in candidates do
		local ok, e = pcall(function() return Enum[name][value] end)
		if ok and e ~= nil then return e end
	end
	return nil
end

local function tryUDimFromMap(v: any): UDim?
	if type(v) == "table" and v.scale ~= nil and v.offset ~= nil then
		return UDim.new(v.scale, v.offset)
	end
	return nil
end

local function deserialize(value: any, propName: string?): any
	local vt = type(value)
	if vt == "string" then
		if propName then
			local e = unwrapEnum(propName, value)
			if e ~= nil then return e end
		end
		return value
	end
	if vt == "number" or vt == "boolean" or vt == "nil" then return value end

	if vt == "table" then
		-- Explicit type tag wins
		if value.__enum and value.value ~= nil then
			local ok, e = pcall(function() return Enum[value.__enum][value.value] end)
			if ok and e ~= nil then return e end
		end

		-- Map shapes
		if isMap(value) then
			if value.r ~= nil and value.g ~= nil and value.b ~= nil then
				return Color3.new(value.r, value.g, value.b)
			end
			if value.x ~= nil and value.y ~= nil and value.z ~= nil then
				return Vector3.new(value.x, value.y, value.z)
			end
			if value.x ~= nil and value.y ~= nil and (type(value.x) == "table" or type(value.y) == "table") then
				local xu = tryUDimFromMap(value.x) or UDim.new(0, 0)
				local yu = tryUDimFromMap(value.y) or UDim.new(0, 0)
				return UDim2.new(xu.Scale, xu.Offset, yu.Scale, yu.Offset)
			end
			if value.x ~= nil and value.y ~= nil then
				return Vector2.new(value.x, value.y)
			end
			if value.scale ~= nil and value.offset ~= nil then
				return UDim.new(value.scale, value.offset)
			end
			if value.components and type(value.components) == "table" then
				local c = value.components
				return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
			end
			if value.min ~= nil and value.max ~= nil then
				if type(value.min) == "number" then
					return NumberRange.new(value.min, value.max)
				elseif type(value.min) == "table" then
					return Rect.new(value.min.x, value.min.y, value.max.x, value.max.y)
				end
			end
			if value.origin and value.direction then
				return Ray.new(
					Vector3.new(value.origin.x, value.origin.y, value.origin.z),
					Vector3.new(value.direction.x, value.direction.y, value.direction.z)
				)
			end
			if value.keypoints and type(value.keypoints) == "table" then
				local first = value.keypoints[1]
				if first then
					if type(first.value) == "number" then
						local nk = {}
						for _, kp in value.keypoints do
							table.insert(nk, NumberSequenceKeypoint.new(kp.time, kp.value, kp.envelope or 0))
						end
						return NumberSequence.new(nk)
					elseif type(first.value) == "table" then
						local ck = {}
						for _, kp in value.keypoints do
							local v = kp.value
							table.insert(ck, ColorSequenceKeypoint.new(kp.time, Color3.new(v.r, v.g, v.b)))
						end
						return ColorSequence.new(ck)
					end
				end
			end
			if value.name ~= nil and value.number ~= nil then
				local ok, bc = pcall(function() return BrickColor.new(value.name) end)
				if ok then return bc end
			end
			if value.name ~= nil and value.number == nil then
				local ok, bc = pcall(function() return BrickColor.new(value.name) end)
				if ok then return bc end
			end
		end

		-- Array shapes
		if isArray(value) then
			if #value == 12 then
				local c = value
				return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
			end
			if #value == 4 then
				-- UDim2(sx, ox, sy, oy)
				return UDim2.new(value[1], value[2], value[3], value[4])
			end
			if #value == 3 then
				if propName == "Color" or propName == "Color3"
					or propName == "TextColor3" or propName == "BackgroundColor3"
					or propName == "BorderColor3" or propName == "ImageColor3"
					or propName == "TextStrokeColor3" or propName == "ScrollBarImageColor3"
					or (value[1] <= 1 and value[2] <= 1 and value[3] <= 1
						and value[1] >= 0 and value[2] >= 0 and value[3] >= 0) then
					return Color3.new(value[1], value[2], value[3])
				end
				return Vector3.new(value[1], value[2], value[3])
			end
			if #value == 2 then
				return Vector2.new(value[1], value[2])
			end
		end
	end

	return value
end

function PropertyDeserializer.Convert(propName: string, value: any): any
	return deserialize(value, propName)
end

function PropertyDeserializer.ConvertProps(props: { [string]: any }): { [string]: any }
	local out: { [string]: any } = {}
	for k, v in props do
		out[k] = deserialize(v, k)
	end
	return out
end

return PropertyDeserializer
