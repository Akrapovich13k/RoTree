--!strict
local Config = require(script.Parent.Parent.Config)

local RemoteScanner = {}

export type RemoteEntry = {
	name: string,
	className: string,
	fullPath: string,
	parentService: string,
}

function RemoteScanner.IsRemote(inst: Instance): boolean
	return Config.REMOTE_CLASSES[inst.ClassName] == true
end

local function rootService(inst: Instance): string
	local cur: Instance? = inst
	while cur and cur.Parent and cur.Parent ~= game do
		cur = cur.Parent
	end
	return if cur then cur.Name else "?"
end

function RemoteScanner.Scan(roots: { Instance }): { RemoteEntry }
	local out: { RemoteEntry } = {}
	for _, root in roots do
		local stack: { Instance } = { root }
		while #stack > 0 do
			local cur = table.remove(stack) :: Instance
			if RemoteScanner.IsRemote(cur) then
				table.insert(out, {
					name = cur.Name,
					className = cur.ClassName,
					fullPath = cur:GetFullName(),
					parentService = rootService(cur),
				})
			end
			for _, child in cur:GetChildren() do
				table.insert(stack, child)
			end
		end
	end
	return out
end

return RemoteScanner
