--!strict
--!optimize 2
--[[
	Enum
	
    2 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
type getItemType<T> = exports.getItemType<T>
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U16
const READ: () -> number = reader.U16
const TOSTRING: <T>(T) -> string = tostring

@native
const function enumNodeBuild<T>(input: T & Enum): typeNode<getItemType<T>>
	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function enum_write(value: getItemType<T> & EnumItem): ()
		WRITE(value.Value)
	end

	@native
	const function enum_read(): getItemType<T>
		const id: number = READ()
		return input:FromValue(id)
	end

	return table.freeze({
		write = enum_write,
		read = enum_read,
		exType = "Enum." .. TOSTRING(input)
	}) :: typeNode<getItemType<T>>
end

return enumNodeBuild
