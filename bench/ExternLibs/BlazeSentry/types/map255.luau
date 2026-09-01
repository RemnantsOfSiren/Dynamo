--!strict
--!optimize 2
--[[
	Key-value Map
	1 + nodeSize(n) bytes
	max amount of 255 entries
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
const WRITE_LEN: (number) -> () = writer.U8
const READ_LEN: () -> number = reader.U8

@native
const function map255NodeBuild<K, V>(keyType: typeNode<K>, valueType: typeNode<V>): typeNode
	const valWrite: (V) -> () = valueType.write
	const valRead: () -> V = valueType.read
	const keyWrite: (K) -> () = keyType.write
	const keyRead: () -> K = keyType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function map255_write(value: { [K]: V }): ()
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
	const function map255_read(): { [K]: V }
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
		write = map255_write,
		read = map255_read,
		exType = "map"
	}) :: typeNode
end

return map255NodeBuild
