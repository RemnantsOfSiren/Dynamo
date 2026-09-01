--!strict
--[[
	Float24
	3 bytes

	Custom precision float
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
const WRITE: (number) -> () = writer.F24
const READ: () -> number = reader.F24

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "float"
})
