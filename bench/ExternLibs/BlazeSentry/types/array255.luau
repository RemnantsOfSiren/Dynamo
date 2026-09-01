--!strict
--!optimize 2
--[[
	Array255
	1 + vSize(n) bytes

	max 255 elements
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
const WRITE_U8: (number) -> () = writer.U8
const READ_U8: () -> number = reader.U8
const CREATE: typeof(table.create) = table.create

@native
const function arrayNodeBuild<T>(valueType: typeNode<T>): typeNode<{ T }>
	const valWrite: (T?) -> () = valueType.write
	const valRead: () -> T = valueType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function array255_write(value: { T }): ()
		const len: number = #value
		WRITE_U8(len)
		for i: number, v: T in value do
			valWrite(v)
		end
	end

	@native
	const function array255_read(): { T }
		const len: number = READ_U8()
		const array: { T } = CREATE(len)

		for i = 1, len do
			array[i] = valRead()
		end

		return array
	end

	return table.freeze({
		write = array255_write,
		read = array255_read,
		exType = "array"
	}) :: typeNode<{ T }>
end

return arrayNodeBuild
