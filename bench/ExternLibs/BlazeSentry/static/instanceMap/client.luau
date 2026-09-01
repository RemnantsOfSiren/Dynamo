--!strict
--!optimize 2
--[[
    InstanceMap.client V0.1.6

    Initializes client instance map
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const instanceMap = require("./")
const config = require("../../shared/config")

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const DELAY: <A..., R...>(number?, ((A...) -> (R...)) | thread, A...) -> thread = task.delay
const SPAWN: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread = task.spawn
const RUNNING: () -> thread = coroutine.running
const YIELD: <A..., R...>(A...) -> (R...) = coroutine.yield

const ATTRIBUTE_NAME: string = config.instanceIdAttribute

-----------------------------------------------------
-- MAIN                                            --
-----------------------------------------------------
const function retryGetAttribute(co: thread, instance: Instance): ()
	SPAWN(co, instance:GetAttribute(ATTRIBUTE_NAME))
end

const function deferFetch(instance: Instance): number?
	const co = RUNNING()
	DELAY(0, retryGetAttribute, co, instance)
	return YIELD()
end

const function onInstance(instance: Instance): ()
	local success: boolean, id: number? = pcall(instance.GetAttribute :: (Instance, string) -> number?, instance, ATTRIBUTE_NAME)
	if not success then
		return
	end
	if not id then
		id = deferFetch(instance)
		if not id then
			return
		end
	end
	instanceMap[id :: number] = instance
end

game.DescendantAdded:Connect(onInstance)

for _, instance: Instance in game:GetDescendants() do
	task.spawn(onInstance, instance)
end

return nil