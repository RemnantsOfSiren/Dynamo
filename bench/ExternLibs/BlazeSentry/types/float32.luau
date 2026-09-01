--!strict
--[[
	Float32
	4 bytes

	IEEE 754 single precision float
]]
--!optimize 2
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.F32
const READ: () -> number = reader.F32

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "float"
})
