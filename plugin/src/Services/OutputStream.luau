--!strict
-- Captures Roblox Studio's Output panel and streams it to the bridge.
-- Subscribes to LogService.MessageOut, buffers entries, flushes in batches
-- every ~1.5 s. Initial backfill via GetLogHistory(). Always-on by default.

local LogService = game:GetService("LogService")

local HttpBridge = require(script.Parent.HttpBridge)

local OutputStream = {}

export type Entry = {
	time: string,
	elapsed: number,
	level: string, -- "Print" | "Info" | "Warning" | "Error"
	text: string,
}

local MAX_BUFFER = 5000

local buffer: { Entry } = {}
local startedAt = os.clock()
local enabled = false
local conn: RBXScriptConnection? = nil
local flushThread: thread? = nil

local function levelOf(mt: Enum.MessageType): string
	if mt == Enum.MessageType.MessageError then return "Error" end
	if mt == Enum.MessageType.MessageWarning then return "Warning" end
	if mt == Enum.MessageType.MessageInfo then return "Info" end
	return "Print"
end

local function push(message: string, mt: Enum.MessageType)
	if #buffer >= MAX_BUFFER then table.remove(buffer, 1) end
	table.insert(buffer, {
		time = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		elapsed = os.clock() - startedAt,
		level = levelOf(mt),
		text = message,
	})
end

local function flush()
	if #buffer == 0 then return end
	-- Take a snapshot and clear; if the POST fails, we drop these to avoid
	-- unbounded growth when the bridge is offline.
	local entries = buffer
	buffer = {}
	task.spawn(function()
		HttpBridge.SendLog(entries)
	end)
end

local function loop()
	while enabled do
		task.wait(1.5)
		if not enabled then break end
		flush()
	end
end

function OutputStream.IsEnabled(): boolean
	return enabled
end

function OutputStream.Enable()
	if enabled then return end
	enabled = true
	-- Backfill the existing log history so the AI sees what happened before
	-- the plugin was opened.
	local ok, history = pcall(function() return LogService:GetLogHistory() end)
	if ok and typeof(history) == "table" then
		for _, e in history do
			push(e.message, e.messageType)
		end
	end
	conn = LogService.MessageOut:Connect(push)
	flushThread = task.spawn(loop)
end

function OutputStream.Disable()
	enabled = false
	if conn then
		pcall(function() conn:Disconnect() end)
		conn = nil
	end
end

function OutputStream.FlushNow()
	flush()
end

return OutputStream
