--!strict
--!optimize 2
--[[
	vector2
	roblox Vector2 type
	4 bytes
	each axis is serialized as float16
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE_V2: (Vector2) -> () = writer.V2F16
const READ_V2: () -> Vector2 = reader.V2F16

return table.freeze({
	write = WRITE_V2,
	read = READ_V2,
	exType = "Vector2"
})
