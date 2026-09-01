--!strict
--!optimize 2
--[[
	Signed 16-bit integer
	2 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.I16
const READ: () -> number = reader.I16

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
