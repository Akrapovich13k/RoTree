--!strict
local CollectionService = game:GetService("CollectionService")

local TagScanner = {}

function TagScanner.Scan(): { [string]: { string } }
	local out: { [string]: { string } } = {}
	local tags = CollectionService:GetAllTags()
	for _, tag in tags do
		local list: { string } = {}
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(list, inst:GetFullName())
		end
		if #list > 0 then
			out[tag] = list
		end
	end
	return out
end

return TagScanner
