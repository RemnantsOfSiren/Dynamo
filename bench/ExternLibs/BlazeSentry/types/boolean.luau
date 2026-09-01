--!strict
--!optimize 2
--[[
	Boolean
	1 byte
	simple true/false value
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

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function boolean_write(value: boolean): ()
	WRITE(value and 1 or 0)
end

@native
const function boolean_read(): boolean
	const value: number = READ()
	return value == 1
end

return table.freeze({
	write = boolean_write,
	read = boolean_read,
	exType = "boolean"
})