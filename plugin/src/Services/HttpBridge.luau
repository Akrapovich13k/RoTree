--!strict
-- The SOLE module that touches the network. Audit this file to verify that
-- RoTree only ever talks to localhost.

local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.Parent.Config)

local HttpBridge = {}

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
			Body = if body ~= nil then HttpService:JSONEncode(body) else nil,
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
