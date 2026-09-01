--!strict
--!optimize 2
--[[
	Unsigned 8-bit integer
	1 byte
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U8
const READ: () -> number = reader.U8

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
