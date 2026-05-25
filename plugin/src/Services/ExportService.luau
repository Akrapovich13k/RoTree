--!strict
-- Orchestrates a single export run. Walks the chosen roots, builds the
-- combined payload, and hands it to HttpBridge.

local Selection = game:GetService("Selection")

local Config = require(script.Parent.Parent.Config)
local Ignore = require(script.Parent.Parent.Utils.Ignore)
local HttpBridge = require(script.Parent.HttpBridge)
local ScriptScanner = require(script.Parent.ScriptScanner)
local GuiScanner = require(script.Parent.GuiScanner)
local RemoteScanner = require(script.Parent.RemoteScanner)
local PartScanner = require(script.Parent.PartScanner)
local AttributeScanner = require(script.Parent.AttributeScanner)
local TagScanner = require(script.Parent.TagScanner)
local PropertyScanner = require(script.Parent.PropertyScanner)
local ContextGenerator = require(script.Parent.ContextGenerator)

local ExportService = {}

export type TreeNode = {
	name: string,
	className: string,
	fullPath: string,
	isScript: boolean,
	isGui: boolean,
	isRemote: boolean,
	isPart: boolean,
	isModel: boolean,
	tags: { string }?,
	children: { TreeNode }?,
}

export type ExportKind = "full" | "selected" | "safe" | "scripts" | "remotes" | "gui"

local CollectionService = game:GetService("CollectionService")

local function buildTree(roots: { Instance }, ignore: Ignore.Rules, instCounter: { n: number }): { TreeNode }
	local nodes: { TreeNode } = {}
	for _, root in roots do
		local function walk(inst: Instance): TreeNode
			instCounter.n += 1
			local node: TreeNode = {
				name = inst.Name,
				className = inst.ClassName,
				fullPath = inst:GetFullName(),
				isScript = Config.SCRIPT_CLASSES[inst.ClassName] == true,
				isGui = Config.GUI_CLASSES[inst.ClassName] == true,
				isRemote = Config.REMOTE_CLASSES[inst.ClassName] == true,
				isPart = Config.PART_CLASSES[inst.ClassName] == true,
				isModel = inst:IsA("Model"),
			}
			local tags = CollectionService:GetTags(inst)
			if #tags > 0 then node.tags = tags end

			local children = inst:GetChildren()
			if #children > 0 then
				local list: { TreeNode } = {}
				for _, child in children do
					if Ignore.IsIgnored(ignore, child:GetFullName()) then continue end
					table.insert(list, walk(child))
				end
				if #list > 0 then node.children = list end
			end
			return node
		end
		table.insert(nodes, walk(root))
	end
	return nodes
end

local function getRoots(kind: ExportKind): { Instance }
	if kind == "selected" then
		local sel = Selection:Get()
		if #sel == 0 then
			-- fall back to a single placeholder
			return {}
		end
		return sel
	end

	local out: { Instance } = {}
	for _, name in Config.ROOT_SERVICES do
		local ok, svc = pcall(function() return game:GetService(name) end)
		if ok and svc then
			table.insert(out, svc)
		end
	end
	return out
end

local function fetchIgnore(): Ignore.Rules
	local text = HttpBridge.GetIgnore()
	if not text then return Ignore.Empty() end
	return Ignore.Parse(text)
end

function ExportService.Run(kind: ExportKind, safeMode: boolean): (boolean, string?, { [string]: any }?)
	local ignore = fetchIgnore()
	local roots = getRoots(kind)
	if #roots == 0 and kind == "selected" then
		return false, "No selection in Studio. Pick something in the Explorer first.", nil
	end

	local instCounter = { n = 0 }
	local tree: { TreeNode } = {}
	local scripts: { ScriptScanner.ScriptEntry } = {}
	local gui: { GuiScanner.GuiEntry } = {}
	local remotes: { RemoteScanner.RemoteEntry } = {}
	local parts: { PartScanner.PartEntry } = {}
	local attributes: { [string]: { [string]: any } } = {}
	local tags: { [string]: { string } } = {}
	local properties: { [string]: { [string]: any } } = {}

	if kind == "full" or kind == "safe" or kind == "selected" then
		tree = buildTree(roots, ignore, instCounter)
		scripts = ScriptScanner.Scan(roots, { ignore = ignore, safeMode = safeMode or kind == "safe" })
		gui = GuiScanner.Scan(roots)
		remotes = RemoteScanner.Scan(roots)
		parts = PartScanner.Scan(roots, { maxParts = 2000 })
		attributes = AttributeScanner.Scan(roots)
		tags = TagScanner.Scan()
		properties = PropertyScanner.Scan(roots, { maxInstances = 5000 })
	elseif kind == "scripts" then
		scripts = ScriptScanner.Scan(roots, { ignore = ignore, safeMode = safeMode })
	elseif kind == "remotes" then
		remotes = RemoteScanner.Scan(roots)
	elseif kind == "gui" then
		gui = GuiScanner.Scan(roots)
	end

	local moduleCount = 0
	for _, s in scripts do
		if s.className == "ModuleScript" then moduleCount += 1 end
	end

	local stats = {
		instances = instCounter.n,
		scripts = #scripts,
		remotes = #remotes,
		gui = #gui,
		parts = #parts,
		modules = moduleCount,
	}

	local contextMd = ContextGenerator.Build({
		placeName = game.Name,
		placeId = game.PlaceId,
		tree = tree,
		scripts = scripts,
		remotes = remotes,
		gui = gui,
		stats = stats,
	})

	local payload = {
		kind = kind,
		placeName = game.Name,
		placeId = game.PlaceId,
		gameId = game.GameId,
		exportedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		pluginVersion = Config.PLUGIN_VERSION,
		safeMode = safeMode,
		tree = tree,
		scripts = scripts,
		remotes = remotes,
		gui = gui,
		parts = parts,
		attributes = attributes,
		tags = tags,
		properties = properties,
		stats = stats,
		aiContext = contextMd,
	}

	local ok, err = HttpBridge.SendExport(payload)
	if not ok then
		return false, "Bridge unreachable: " .. tostring(err) .. ". Run 'RoTree: Start Bridge' in VS Code.", stats
	end
	return true, nil, stats
end

return ExportService
