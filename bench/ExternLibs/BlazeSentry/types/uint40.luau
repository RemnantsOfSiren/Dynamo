--!strict
--!optimize 2
--[[
	Unsigned 40-bit integer
	5 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U40
const READ: () -> number = reader.U40


return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int"
})
