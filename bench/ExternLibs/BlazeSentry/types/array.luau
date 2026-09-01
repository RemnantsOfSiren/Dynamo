--!strict
--!optimize 2
--[[
	Array
	2 + vSize(n) bytes

	max 65535 elements
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const WRITE_U16: (number) -> () = writer.U16
const READ_U16: () -> number = reader.U16
const CREATE: typeof(table.create) = table.create

@native
const function arrayNodeBuild<T>(valueType: typeNode<T>): typeNode<{ T }>
	const valWrite: (T?) -> () = valueType.write
	const valRead: () -> T = valueType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function array_write(value: { T }): ()
		const len: number = #value
		WRITE_U16(len)
		for i: number, v: T in value do
			valWrite(v)
		end
	end

	@native
	const function array_read(): { T }
		const len: number = READ_U16()
		const array: { T } = CREATE(len :: number)

		for i = 1, len :: number do
			array[i] = valRead()
		end

		return array
	end

	return table.freeze({
		write = array_write,
		read = array_read,
		exType = "array"
	}) :: typeNode<{ T }>
end


return arrayNodeBuild
