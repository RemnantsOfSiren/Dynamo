--!strict
--!optimize 2
--[[
	Optional mark
	1 + nodeSize? bytes

	1 if value exists 0 if not

	if value does not exist, it takes only 1 byte
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
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U8
const READ: () -> number = reader.U8

@native
const function optionalNodeBuild<T>(node: typeNode<T>): typeNode<T?>
	const innerWrite: (T?) -> () = node.write
	const innerRead: () -> T = node.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function optional_write(value: T?): ()
		WRITE(value ~= nil and 1 or 0)

		if value ~= nil then
			innerWrite(value)
		end
	end

	@native
	const function optional_read(): T?
		const hasValue: number = READ()
		if hasValue == 1 then
			return innerRead()
		end
		return nil
	end

	return table.freeze({
		write = optional_write,
		read = optional_read,
		exType = "optional"
	}) :: typeNode<T?>
end

return optionalNodeBuild
