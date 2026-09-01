--!strict
--!optimize 2
--[[
    CFrame(matrix) 
	36 bytes

	each component is serialized as float24
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE_CF: (CFrame) -> () = writer.CF24
const READ_CF: () -> CFrame = reader.CF24

return table.freeze({
	write = WRITE_CF,
	read = READ_CF,
	exType = "CFrame"
})
