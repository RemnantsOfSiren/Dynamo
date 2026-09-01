--!strict
--!optimize 2
--[[
	Signed 48-bit integer
	6 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.I48
const READ: () -> number = reader.I48

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int",
})
