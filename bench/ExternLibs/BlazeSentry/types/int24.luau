--!strict
--!optimize 2
--[[
	Signed 24-bit integer
	3 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.I24
const READ: () -> number = reader.I24

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
