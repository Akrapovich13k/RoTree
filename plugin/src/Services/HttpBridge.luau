--!strict
-- The SOLE module that touches the network. Audit this file to verify that
-- RoTree only ever talks to localhost.

local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.Parent.Config)

local HttpBridge = {}

local function sanitizeForJson(value: any, seen: { [any]: boolean }?): any
	local valueType = typeof(value)

	if valueType == "nil" or valueType == "string" or valueType == "boolean" then
		return value
	end

	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return tostring(value)
		end
		return value
	end

	if valueType == "Vector3" then return { x = value.X, y = value.Y, z = value.Z } end
	if valueType == "Vector2" then return { x = value.X, y = value.Y } end
	if valueType == "Color3" then return { r = value.R, g = value.G, b = value.B } end
	if valueType == "BrickColor" then return { name = value.Name, number = value.Number } end
	if valueType == "UDim" then return { scale = value.Scale, offset = value.Offset } end
	if valueType == "UDim2" then
		return {
			x = { scale = value.X.Scale, offset = value.X.Offset },
			y = { scale = value.Y.Scale, offset = value.Y.Offset },
		}
	end
	if valueType == "CFrame" then return { components = { value:GetComponents() } } end
	if valueType == "Vector3int16" then return { x = value.X, y = value.Y, z = value.Z } end
	if valueType == "Vector2int16" then return { x = value.X, y = value.Y } end
	if valueType == "Rect" then
		return {
			min = { x = value.Min.X, y = value.Min.Y },
			max = { x = value.Max.X, y = value.Max.Y },
		}
	end
	if valueType == "NumberRange" then return { min = value.Min, max = value.Max } end
	if valueType == "NumberSequence" then
		local keypoints = {}
		for _, keypoint in value.Keypoints do
			table.insert(keypoints, {
				time = keypoint.Time,
				value = keypoint.Value,
				envelope = keypoint.Envelope,
			})
		end
		return { keypoints = keypoints }
	end
	if valueType == "ColorSequence" then
		local keypoints = {}
		for _, keypoint in value.Keypoints do
			table.insert(keypoints, {
				time = keypoint.Time,
				value = sanitizeForJson(keypoint.Value, seen),
			})
		end
		return { keypoints = keypoints }
	end
	if valueType == "EnumItem" then return value.Name end
	if valueType == "Instance" then
		return {
			_ref = value:GetFullName(),
			className = value.ClassName,
		}
	end

	if valueType == "table" then
		seen = seen or {}
		if seen[value] then
			return "[Circular]"
		end
		seen[value] = true

		local isArray = true
		local maxIndex = 0
		local count = 0
		for key in value do
			if typeof(key) == "number" and key % 1 == 0 and key >= 1 then
				maxIndex = math.max(maxIndex, key)
				count += 1
			else
				isArray = false
				break
			end
		end

		local output = {}
		if isArray and maxIndex == count then
			for index = 1, maxIndex do
				output[index] = sanitizeForJson(value[index], seen)
			end
		else
			for key, childValue in value do
				output[tostring(key)] = sanitizeForJson(childValue, seen)
			end
		end

		seen[value] = nil
		return output
	end

	return tostring(value)
end

local function headers()
	return {
		["Content-Type"] = "application/json",
		["X-RoTree-Version"] = Config.PLUGIN_VERSION,
	}
end

local function request(method: string, path: string, body: any?): (boolean, any)
	local url = Config.BridgeUrl(path)
	-- Defense in depth: refuse anything that isn't localhost.
	if not url:lower():match("^http://localhost:") and not url:lower():match("^http://127%.0%.0%.1:") then
		return false, "RoTree refused a non-localhost URL: " .. url
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = method,
			Headers = headers(),
			Body = if body ~= nil then HttpService:JSONEncode(sanitizeForJson(body)) else nil,
		})
	end)

	if not ok then
		return false, tostring(response)
	end
	if not response.Success then
		return false, string.format("HTTP %d: %s", response.StatusCode, tostring(response.Body))
	end
	local decoded: any = response.Body
	if response.Body and #response.Body > 0 then
		local jok, decoded2 = pcall(function() return HttpService:JSONDecode(response.Body) end)
		if jok then decoded = decoded2 end
	end
	return true, decoded
end

function HttpBridge.Ping(): boolean
	local ok = request("GET", Config.ENDPOINT_PING)
	return ok
end

function HttpBridge.SendExport(payload: any): (boolean, string?)
	local ok, res = request("POST", Config.ENDPOINT_EXPORT, payload)
	if not ok then return false, tostring(res) end
	return true, nil
end

function HttpBridge.GetIgnore(): string?
	local ok, res = request("GET", Config.ENDPOINT_IGNORE)
	if not ok then return nil end
	if typeof(res) == "table" then return res.text end
	return tostring(res)
end

function HttpBridge.ListPatches(): { { id: string, title: string } }
	local ok, res = request("GET", Config.ENDPOINT_PATCH_LIST)
	if not ok or typeof(res) ~= "table" then return {} end
	return res :: any
end

function HttpBridge.GetPatch(id: string): any?
	local ok, res = request("GET", Config.ENDPOINT_PATCH_GET .. id)
	if not ok then return nil end
	return res
end

function HttpBridge.PollAutoApply(): any?
	local ok, res = request("GET", "/rotree/auto-apply/next")
	if not ok or typeof(res) ~= "table" then return nil end
	return (res :: any).patch
end

function HttpBridge.ReportApplyResult(result: { id: string, success: boolean, applied: number, failed: number, error: string? }): boolean
	local ok = request("POST", "/rotree/auto-apply/result", result)
	return ok
end

function HttpBridge.SendLog(entries: { any }): boolean
	if #entries == 0 then return true end
	local ok = request("POST", "/rotree/log", { entries = entries })
	return ok
end

return HttpBridge
