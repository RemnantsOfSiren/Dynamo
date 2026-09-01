--!strict
--!optimize 2
--[[
	BooleanPacked
	1 byte
	8 packed booleans in 1 byte
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U8
const READ: () -> number = reader.U8
const OR: (...number) -> number = bit32.bor
const LSHIFT: (number, number) -> number = bit32.lshift
const EXTRACT: (number, number, number?) -> number = bit32.extract

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function booleanPacked_write(value: { boolean }): ()
    local byte: number = 0
    for i: number, bool: boolean in value do
        byte = OR(byte, LSHIFT(bool and 1 or 0, i - 1))
    end
	WRITE(byte)
end

@native
const function booleanPacked_read(): { boolean }
	const byte: number = READ()
    local boolPack: { boolean } = {}
    for i = 0, 7 do
		boolPack[i + 1] = EXTRACT(byte, i) == 1
    end
	return boolPack
end

return table.freeze({
	write = booleanPacked_write,
	read = booleanPacked_read,
	exType = "array"
})