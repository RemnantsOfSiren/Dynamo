--!strict
--!optimize 2
--[[
    Full precision CFrame(matrix) 
	48 bytes

	each component is serialized as float32
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE_CF: (CFrame) -> () = writer.CF32
const READ_CF: () -> CFrame = reader.CF32

return table.freeze({
	write = WRITE_CF,
	read = READ_CF,
	exType = "CFrame"
})