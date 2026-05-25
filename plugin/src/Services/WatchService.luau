--!strict
-- Watches the DataModel for changes and triggers a debounced re-export.
-- Event-driven: no polling. Quiet game = no work. Burst of edits = ONE
-- export at the end of the burst.

local Config = require(script.Parent.Parent.Config)

local WatchService = {}

export type Options = {
	debounceSeconds: number?,
	minIntervalSeconds: number?,
	onTrigger: () -> (),
}

local connections: { RBXScriptConnection } = {}
local scheduled = false
local lastRunAt = 0
local enabled = false
local opts: Options = { onTrigger = function() end }

local function now()
	return os.clock()
end

local function disconnectAll()
	for _, c in connections do
		pcall(function() c:Disconnect() end)
	end
	connections = {}
end

local function schedule()
	if not enabled then return end
	if scheduled then return end
	scheduled = true

	local debounce = (opts.debounceSeconds or 3)
	task.delay(debounce, function()
		scheduled = false
		if not enabled then return end
		local minInterval = opts.minIntervalSeconds or 5
		local since = now() - lastRunAt
		if since < minInterval then
			-- We just ran. Wait a little more, then re-check.
			task.delay(minInterval - since, function()
				if enabled then
					lastRunAt = now()
					opts.onTrigger()
				end
			end)
			return
		end
		lastRunAt = now()
		opts.onTrigger()
	end)
end

local function attach()
	disconnectAll()
	for _, name in Config.ROOT_SERVICES do
		local ok, svc = pcall(function() return game:GetService(name) end)
		if ok and svc then
			table.insert(connections, svc.DescendantAdded:Connect(schedule))
			table.insert(connections, svc.DescendantRemoving:Connect(schedule))
		end
	end
end

function WatchService.IsEnabled(): boolean
	return enabled
end

function WatchService.Configure(o: Options)
	opts = o
end

function WatchService.Enable()
	if enabled then return end
	enabled = true
	attach()
end

function WatchService.Disable()
	enabled = false
	disconnectAll()
end

function WatchService.Toggle(): boolean
	if enabled then
		WatchService.Disable()
	else
		WatchService.Enable()
	end
	return enabled
end

return WatchService
