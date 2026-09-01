--!strict
--!optimize 2
--[[
	Unsigned 24-bit integer
	3 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U24
const READ: () -> number = reader.U24


return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
