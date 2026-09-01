--!strict
--!optimize 2
--[[
	Unsigned 48-bit integer
	6 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U48
const READ: () -> number = reader.U48

return table.freeze({
	write = WRITE,
	read = READ,
	exType = "int",
})
