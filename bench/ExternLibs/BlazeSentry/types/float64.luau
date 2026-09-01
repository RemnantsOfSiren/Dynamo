--!strict
--[[
	Float64
	8 bytes

	IEEE 754 double precision float
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
const WRITE: (number) -> () = writer.F64
const READ: () -> number = reader.F64

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "float"
})
