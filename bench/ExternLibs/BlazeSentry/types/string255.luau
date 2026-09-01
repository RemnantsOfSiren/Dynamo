--!strict
--!optimize 2
--[[
	string255
	1 + strlen bytes
	max amount of 255 characters
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (string, number) -> () = writer.STR_S
const READ: () -> (string?) = reader.STR_S

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function string255_write(value: string): ()
	const len: number = #value
	WRITE(value, len)
end

return table.freeze({
	write = string255_write,
	read = READ, -- avoid possible extra function call
	exType = "string"
})
