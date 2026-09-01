--!strict
--!optimize 2
--[[
	EnumMap v0.1.0

	Contains all roblox enums, both index and reverse mappings
	Used by dynanode
]]
const idMap: { [number]: Enum } = Enum:GetEnums()
const reverseMap: { [Enum]: number } = {}
for id: number, enum: Enum in idMap do
	reverseMap[enum] = id
end

return table.freeze({
	idMap = idMap,
	reverseMap = reverseMap,
})
