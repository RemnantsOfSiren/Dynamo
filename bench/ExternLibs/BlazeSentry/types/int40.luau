--!strict
--!optimize 2
--[[
	Signed 40-bit integer
	5 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.I40
const READ: () -> number = reader.I40

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
