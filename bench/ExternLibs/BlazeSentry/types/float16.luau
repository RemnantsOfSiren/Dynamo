--!strict
--[[
	Float16
	2 bytes

	IEEE 754 half precision float
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
const WRITE: (number) -> () = writer.F16
const READ: () -> number = reader.F16

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "float"
})
