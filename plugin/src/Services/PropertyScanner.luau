--!strict
-- Reads "all" properties of every instance using PropertyDump + pcall.
-- Output: { [fullPath] = { [propName] = serialized value } }

local PropertyDump = require(script.Parent.PropertyDump)
local Config = require(script.Parent.Parent.Config)

local PropertyScanner = {}

-- Classes that are always captured, even past the numeric cap. These are the
-- low-volume, high-signal instances an AI cares about (GUI, UI helpers,
-- scripts, remotes, value objects, lights, sound, humanoids…). Bulk classes
-- (parts, attachments, welds, meshes) share the capped budget instead, so a
-- huge Workspace can never starve, say, the GUI under StarterGui — which is the
-- bug this guards against.
local PRIORITY_EXTRA: { [string]: boolean } = {
	Light = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Sound = true,
	SoundGroup = true,
	Humanoid = true,
	HumanoidDescription = true,
	Camera = true,
	Atmosphere = true,
	Sky = true,
}

local function isPriorityClass(className: string): boolean
	if Config.GUI_CLASSES[className] then return true end
	if Config.REMOTE_CLASSES[className] then return true end
	if Config.SCRIPT_CLASSES[className] then return true end
	if string.sub(className, 1, 2) == "UI" then return true end -- UIStroke, UIGradient, UICorner…
	if string.sub(className, -5) == "Value" then return true end -- StringValue, ObjectValue…
	return PRIORITY_EXTRA[className] == true
end

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
	-- Capture budget for *bulk* (non-priority) instances. Priority instances
	-- (GUI/UI/scripts/remotes/values…) are always captured on top of this.
	maxInstances: number?,
	-- Hard cap on how many instances we visit, to bound cost on giant places.
	maxVisited: number?,
	skipPaths: { [string]: boolean }?,
}

local function readProps(cur: Instance): { [string]: any }?
	local props = PropertyDump.GetPropertiesFor(cur.ClassName)
	local bag: { [string]: any } = {}
	local any = false
	for _, propName in props do
		local ok, value = pcall(function()
			return (cur :: any)[propName]
		end)
		if ok and value ~= nil then
			-- Skip references to script instances themselves (Source is exported by ScriptScanner).
			if propName == "Source" and Config.SCRIPT_CLASSES[cur.ClassName] then
				-- skip
			else
				local serialized = serializeValue(value)
				if serialized ~= nil then
					bag[propName] = serialized
					any = true
				end
			end
		end
	end
	if not any then return nil end
	return bag
end

function PropertyScanner.Scan(roots: { Instance }, opts: Options?): { [string]: { [string]: any } }
	local options = opts or {}
	local cap = options.maxInstances or 20000
	local maxVisited = options.maxVisited or 150000
	local skip = options.skipPaths or {}

	local out: { [string]: { [string]: any } } = {}
	local captured = 0 -- counts only non-priority captures (against `cap`)
	local visited = 0

	-- Breadth-first across ALL roots at once. GUI lives shallow (StarterGui →
	-- ScreenGui → Frame → TextLabel), so a BFS reaches every GUI before it ever
	-- drowns in deep Workspace part hierarchies — the previous per-root DFS hit
	-- the cap inside Workspace and returned before touching StarterGui.
	local queue: { Instance } = {}
	for _, root in roots do
		table.insert(queue, root)
	end

	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1

		visited += 1
		if visited > maxVisited then break end

		local priority = isPriorityClass(cur.ClassName)
		if priority or captured < cap then
			local path = cur:GetFullName()
			if not skip[path] then
				local bag = readProps(cur)
				if bag then
					out[path] = bag
					if not priority then
						captured += 1
					end
				end
			end
		end

		for _, child in cur:GetChildren() do
			table.insert(queue, child)
		end
	end

	return out
end

return PropertyScanner
