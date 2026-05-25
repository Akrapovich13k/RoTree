--!strict
-- Reads "all" properties of every instance using PropertyDump + pcall.
-- Output: { [fullPath] = { [propName] = serialized value } }

local PropertyDump = require(script.Parent.PropertyDump)

local PropertyScanner = {}

local function serializeValue(v: any): any
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then
		return v
	end
	if t == "Vector3" then return { x = v.X, y = v.Y, z = v.Z } end
	if t == "Vector2" then return { x = v.X, y = v.Y } end
	if t == "Color3" then return { r = v.R, g = v.G, b = v.B } end
	if t == "BrickColor" then return { name = v.Name, number = v.Number } end
	if t == "UDim" then return { scale = v.Scale, offset = v.Offset } end
	if t == "UDim2" then
		return {
			x = { scale = v.X.Scale, offset = v.X.Offset },
			y = { scale = v.Y.Scale, offset = v.Y.Offset },
		}
	end
	if t == "CFrame" then
		local components = { v:GetComponents() }
		return { components = components }
	end
	if t == "Vector3int16" then return { x = v.X, y = v.Y, z = v.Z } end
	if t == "Rect" then
		return {
			min = { x = v.Min.X, y = v.Min.Y },
			max = { x = v.Max.X, y = v.Max.Y },
		}
	end
	if t == "Ray" then
		return {
			origin = { x = v.Origin.X, y = v.Origin.Y, z = v.Origin.Z },
			direction = { x = v.Direction.X, y = v.Direction.Y, z = v.Direction.Z },
		}
	end
	if t == "NumberRange" then return { min = v.Min, max = v.Max } end
	if t == "NumberSequence" then
		local keys = {}
		for _, kp in v.Keypoints do
			table.insert(keys, { time = kp.Time, value = kp.Value, envelope = kp.Envelope })
		end
		return { keypoints = keys }
	end
	if t == "ColorSequence" then
		local keys = {}
		for _, kp in v.Keypoints do
			table.insert(keys, {
				time = kp.Time,
				value = { r = kp.Value.R, g = kp.Value.G, b = kp.Value.B },
			})
		end
		return { keypoints = keys }
	end
	if t == "EnumItem" then return v.Name end
	if t == "Instance" then
		return { _ref = v:GetFullName(), className = v.ClassName }
	end
	if t == "table" then return v end
	return tostring(v)
end

export type Options = {
	maxInstances: number?,
	skipPaths: { [string]: boolean }?,
}

function PropertyScanner.Scan(roots: { Instance }, opts: Options?): { [string]: { [string]: any } }
	local options = opts or {}
	local cap = options.maxInstances or 5000
	local skip = options.skipPaths or {}

	local out: { [string]: { [string]: any } } = {}
	local count = 0

	for _, root in roots do
		local stack: { Instance } = { root }
		while #stack > 0 do
			if count >= cap then return out end
			local cur = table.remove(stack) :: Instance
			local path = cur:GetFullName()
			if not skip[path] then
				local props = PropertyDump.GetPropertiesFor(cur.ClassName)
				local bag: { [string]: any } = {}
				local any = false
				for _, propName in props do
					local ok, value = pcall(function()
						return (cur :: any)[propName]
					end)
					if ok and value ~= nil then
						-- Skip references to script instances themselves (we already export Source elsewhere)
						if propName == "Source" and (cur.ClassName == "Script" or cur.ClassName == "LocalScript" or cur.ClassName == "ModuleScript") then
							-- skip, handled by ScriptScanner
						else
							local serialized = serializeValue(value)
							if serialized ~= nil then
								bag[propName] = serialized
								any = true
							end
						end
					end
				end
				if any then
					out[path] = bag
					count += 1
				end
			end
			for _, child in cur:GetChildren() do
				table.insert(stack, child)
			end
		end
	end
	return out
end

return PropertyScanner
