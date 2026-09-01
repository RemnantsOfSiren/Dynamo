--!strict
--!optimize 2
--[[
    Union
    1 + nodeSize bytes

    max of 255 possible unions

    each node.exType must be unique; otherwise cannot determine the node for the input value
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const extypeof = require("../shared/extypeof")
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
type unionOfPack<T> = exports.unionOfPack<T>

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const UNSUPPORTED_EXTYPES: { [string]: boolean } = config.unsupportedUnionExTypes :: { [string]: boolean }

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U8
const READ: () -> number = reader.U8

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native local function unionNodeBuild<T...>(...: T...): typeNode<unionOfPack<(T...) -> ()>>
    const variants: { typeNode } = { ... } :: { typeNode }
    const exTypeMap: { [string]: typeNode } = {}
    const signMap: { [typeNode]: number } = {}

    for i: number, variant: typeNode in variants do
        const exType: string = variant.exType
        if exTypeMap[exType] then
            error(`[BlazeSentry]: Union type node build failed – The variants include duplicate ExType while proper type node cannot be inferred for duplicate ExTypes; duplicate exType: {variant.exType}`, 0)
        elseif UNSUPPORTED_EXTYPES[exType] then
            error(`[BlazeSentry]: Union type node build failed – Unsupported union type: {exType}`, 0)
		end
        exTypeMap[exType] = variant
        signMap[variant] = i
    end

    @native local function union_write(value: unionOfPack<(T...) -> ()>): ()
        const exType: string = extypeof(value)
        const node: typeNode = exTypeMap[exType]

        local sign: number = signMap[node]
        WRITE(sign)
        node.write(value)
    end

    @native local function union_read(): (number, unionOfPack<(T...) -> ()>?)
        local sign: number = READ()

        local node: typeNode = variants[sign :: number]
        return node.read()
    end

    return table.freeze({
        write = union_write,
        read = union_read,
        exType = "union"
    }) :: typeNode<unionOfPack<(T...) -> ()>>
end

return unionNodeBuild