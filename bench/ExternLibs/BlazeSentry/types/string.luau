--!strict
--!optimize 2
--[[
	string
	2 + strlen bytes

	max amount of 65535 characters
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE: (string, number) -> () = writer.STR
const READ: () -> (string?) = reader.STR

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function string_write(value: string): ()
	const len: number = #value
	WRITE(value, len)
end

return table.freeze({
	write = string_write,
	read = READ, -- avoid possible extra function call
	exType = "string"
})
