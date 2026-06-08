--!strict
-- Single source of truth for plugin constants.

local Config = {}

Config.PLUGIN_NAME = "RoTree"
Config.PLUGIN_VERSION = "0.2.0"
Config.PLUGIN_SUBTITLE = "Roblox Game Tree Bridge"

Config.BRIDGE_HOST = "http://localhost"
Config.BRIDGE_PORT = 34873
Config.BRIDGE_TIMEOUT = 10

Config.ROOT_SERVICES = {
	"Workspace",
	"ReplicatedStorage",
	"ReplicatedFirst",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPlayer",
	"StarterPack",
	"Lighting",
	"SoundService",
	"Teams",
	"MaterialService",
	"TextChatService",
	"Chat",
	"InsertService",
}

Config.SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

Config.GUI_CLASSES = {
	ScreenGui = true,
	SurfaceGui = true,
	BillboardGui = true,
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	CanvasGroup = true,
}

Config.REMOTE_CLASSES = {
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	UnreliableRemoteEvent = true,
}

Config.PART_CLASSES = {
	Part = true,
	MeshPart = true,
	UnionOperation = true,
	WedgePart = true,
	TrussPart = true,
	CornerWedgePart = true,
	SpawnLocation = true,
	Seat = true,
	VehicleSeat = true,
}

-- Patterns triggering DOUBLE confirmation in PatchService.
Config.CRITICAL_PATTERNS = {
	"DataStoreService",
	"DataStore2",
	"ProfileService",
	"leaderstats",
	"MarketplaceService",
	"GamePass",
	"DevProduct",
	"Anticheat",
	"AntiExploit",
}

Config.MAX_PATCH_DELETES = 20
Config.MAX_SOURCE_BYTES_PER_SCRIPT = 200_000

-- Endpoints
Config.ENDPOINT_EXPORT = "/rotree/export"
Config.ENDPOINT_IGNORE = "/rotree/ignore"
Config.ENDPOINT_PATCH_LIST = "/rotree/patches"
Config.ENDPOINT_PATCH_GET = "/rotree/patches/" -- + id
Config.ENDPOINT_PING = "/rotree/ping"

function Config.BridgeUrl(path: string): string
	return Config.BRIDGE_HOST .. ":" .. tostring(Config.BRIDGE_PORT) .. path
end

return Config
