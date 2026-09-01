--!strict
--!optimize 2
--[[
	Instance
	3 bytes

    Writes a U24 instance ID, when deserializing does a instanceMap lookup
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const constants = require("../shared/config/constants")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const instanceMap = require("../static/instanceMap")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U24
const READ: () -> number = reader.U24

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function instance_write(value: Instance): ()
	const id: number = value:GetAttribute(constants.instanceIdAttribute) :: any
	WRITE(id)
end
const function instance_read(): Instance
	const id: number = READ()
	return instanceMap[id :: number]
end

return table.freeze({
	write = instance_write,
	read = instance_read,
	exType = "Instance"
})
