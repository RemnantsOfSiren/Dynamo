--!strict
--!optimize 2
--[[
	vector3
	roblox Vector3 type
	6 bytes
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
const WRITE_VEC: (vector | Vector3) -> () = writer.VF16
const READ_VEC: () -> vector | Vector3 = reader.VF16

return table.freeze({
	write = WRITE_VEC,
	read = READ_VEC,
	exType = "Vector3"
})
