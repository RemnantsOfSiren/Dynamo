--!strict
--!optimize 2
--[[
    CFrame(matrix)
	24 bytes

	each component is serialized as float16
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE_CF: (CFrame) -> () = writer.CF16
const READ_CF: () -> CFrame = reader.CF16

return table.freeze({
	write = WRITE_CF,
	read = READ_CF,
	exType = "CFrame",
})
