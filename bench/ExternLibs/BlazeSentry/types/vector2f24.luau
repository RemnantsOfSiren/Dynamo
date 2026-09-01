--!strict
--!optimize 2
--[[
	vector2
	roblox Vector2 type
	6 bytes
	each axis is serialized as float24
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE_V2: (Vector2) -> () = writer.V2F24
const READ_V2: () -> Vector2 = reader.V2F24


return table.freeze({
	write = WRITE_V2,
	read = READ_V2,
	exType = "Vector2"
})
