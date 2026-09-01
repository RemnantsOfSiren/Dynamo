--!strict
--!optimize 2
--[[
	color3
	roblox Color3 type
	3 bytes
	each RGB field is serialized as uint8
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (Color3) -> () = writer.COLOR3
const READ: () -> Color3 = reader.COLOR3

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "Color3"
})
