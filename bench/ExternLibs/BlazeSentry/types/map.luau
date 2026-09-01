--!strict
--!optimize 2
--[[
	Key-value Map
	2 + nodeSize(n) bytes
	max amount of 65535 entries
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
const WRITE_LEN: (number) -> () = writer.U16
const READ_LEN: () -> number = reader.U16

@native
const function mapNodeBuild<K, V>(keyType: typeNode<K>, valueType: typeNode<V>): typeNode<{ [K]: V }>
	const valWrite: (V) -> () = valueType.write
	const valRead: () -> V = valueType.read
	const keyWrite: (K) -> () = keyType.write
	const keyRead: () -> K = keyType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function map_write(value: { [K]: V }): ()
		local len: number = 0
		for _ in value do
			len += 1
		end
		WRITE_LEN(len)
		for k: K, v: V in value do
			keyWrite(k)
			valWrite(v)
		end

	end

	@native
	const function map_read(): { [K]: V }
		local len: number = READ_LEN()
		const tbl: { [K]: V } = {}

		for i = 1, len :: number do
			local key: K = keyRead()
			local val: V = valRead()
			tbl[key] = val
		end
		return tbl
	end

	return table.freeze({
		write = map_write,
		read = map_read,
		exType = "map"
	}) :: typeNode<{ [K]: V }>
end

return mapNodeBuild
