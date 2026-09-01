--!strict
--!optimize 2
--[[
	Signed 8-bit integer
	1 byte
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.I8
const READ: () -> number = reader.I8

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
