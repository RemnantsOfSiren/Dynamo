--!strict
--!optimize 2
--[[
	BlazeSentry Serialized Instance Schemas
	container populated at runtime
]]
const exports = require("../shared/exports")

type typeNode<T = any> = exports.typeNode<T>

const instanceSchemas: { [string]: { [string]: typeNode } } = {}

return instanceSchemas
