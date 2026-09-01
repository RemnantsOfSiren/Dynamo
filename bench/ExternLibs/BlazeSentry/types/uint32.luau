--!strict
--!optimize 2
--[[
	Unsigned 32-bit integer
	4 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U32
const READ: () -> number = reader.U32


return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
