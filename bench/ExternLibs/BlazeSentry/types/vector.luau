--!strict
--!optimize 2
--[[
	vector
	luau primitive vector type
	12 bytes
	each axis is serialized as float32
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE_VEC: (vector | Vector3) -> () = writer.VF32
const READ_VEC: () -> vector | Vector3 = reader.VF32

return table.freeze({
	write = WRITE_VEC,
	read = READ_VEC,
	exType = "Vector3"
})
