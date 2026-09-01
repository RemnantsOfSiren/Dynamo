--!strict
--!optimize 2
--[[
    InstanceMap.server V0.1.4

    Initializes server instance map
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const instanceMap = require("./")
const config = require("../../shared/config")

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const ATTRIBUTE_NAME: string = config.instanceIdAttribute

-----------------------------------------------------
-- MAIN                                            --
-----------------------------------------------------
local i: number = 0

const function onInstance(instance: Instance): ()
	const success = pcall(instance.SetAttribute, instance, ATTRIBUTE_NAME, i + 1)

	if success then
		i += 1
		instanceMap[i] = instance
	end
end

game.DescendantAdded:Connect(onInstance)

for _, instance: Instance in game:GetDescendants() do
	onInstance(instance)
end

return nil