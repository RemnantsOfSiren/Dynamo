--!strict
--!optimize 2
--[[
	Unsigned 16-bit integer
	2 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U16
const READ: () -> number = reader.U16

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
