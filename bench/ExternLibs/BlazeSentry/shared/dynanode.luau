--!optimize 2
--[[
	Dynanode V0.1.0

	Dynamic node behaviour shared by @any.luau and @dynamic.luau

	Infers types at runtime
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local typesModule: typeof(require("../types")) = nil
local serInstanceSigns: typeof(require("../static/serInstanceSigns")) = nil
const inferValueType = require("./inferValueType")
const config = require("./config")
const exports = require("./exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const enumMap = require("../static/enumMap")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

type possibleNode = exports.possibleNode

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const UNKNOWN: number = config.unknownType
const typeSigns = config.typeSigns

local ANY_NODE: typeNode<any> = nil
local SIGNMAP: typeof(typesModule.signMap) = nil

const ANYID: number = typeSigns.any
const ARRAYID: number = typeSigns.array
const ARRAY255ID: number = typeSigns.array255
const MAPID: number = typeSigns.map
const SER_INSTANCE_ID: number = typeSigns.serInstance
local SER_INSTANCE_SIGNMAP: typeof(serInstanceSigns.signLookup) = nil
local SER_INSTANCE_NAMEMAP: typeof(serInstanceSigns.nameLookup) = nil
const ENUM_ID: number = typeSigns.enum
const ENUM_ID_MAP: { [number]: Enum } = enumMap.idMap
const ENUM_REVERSE_MAP: { [Enum]: number } = enumMap.reverseMap

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const READ_SIGN: () -> number = reader.U8
const WRITE_SIGN: (number) -> () = writer.U8
const WRITE_ID: (number) -> () = writer.U16
const READ_ID: () -> number = reader.U16
const TYPE: <T>(T) -> string = type

return table.freeze({
	write = @native function<T>(value: T): ()
		-- initialize types & other related constants on first op (prevent recursive dependency from any <-> types <--> dynanode)
		if typesModule == nil then
			typesModule = require("../types")
			serInstanceSigns = require("../static/serInstanceSigns")
			SER_INSTANCE_NAMEMAP = serInstanceSigns.nameLookup
			SER_INSTANCE_SIGNMAP = serInstanceSigns.signLookup
			SIGNMAP = typesModule.signMap
			ANY_NODE = SIGNMAP[ANYID]
		end
		const sign: number = inferValueType(value)
		if sign == UNKNOWN then
			-----------------------------------------------------
			-- UNKNOWN HANDLING                                --
			-----------------------------------------------------
			error(`[BlazeSentry]: Dynamic write failed – Unknown/Unsupported type {typeof(value)}`, 0)
		end
		local node: possibleNode = SIGNMAP[sign]
		if not node then
			return
		end

		WRITE_SIGN(sign)

		if TYPE(node) == "function" then
			-- inline handling
			-- arrays/maps do not store per value/key signs as it will always be `any(dynamic)`
			if sign == ARRAYID or sign == ARRAY255ID then
				node = node(ANY_NODE)
			elseif sign == MAPID then
				node = node(ANY_NODE, ANY_NODE)
			elseif sign == SER_INSTANCE_ID then
				const className: string = value.ClassName
				node = node(className)
				-- write ID
				const isign: number = SER_INSTANCE_NAMEMAP[className]
				WRITE_SIGN(isign)
			elseif sign == ENUM_ID then
				const enum: Enum = value.EnumType
				const id: number = ENUM_REVERSE_MAP[enum]
				WRITE_ID(id)
				node = node(enum)
			end
		end

		-- now the node write
		node.write(value)
	end,

	read = @native function(): any
		if typesModule == nil then
			typesModule = require("../types")
			serInstanceSigns = require("../static/serInstanceSigns")
			SER_INSTANCE_NAMEMAP = serInstanceSigns.nameLookup
			SER_INSTANCE_SIGNMAP = serInstanceSigns.signLookup
			SIGNMAP = typesModule.signMap
			ANY_NODE = SIGNMAP[ANYID]
		end
		local sign: number = READ_SIGN()

		local node: possibleNode = SIGNMAP[sign]
		if not node then
			return
		end

		if TYPE(node) == "function" then
			if sign == ARRAYID or sign == ARRAY255ID then
				node = node(ANY_NODE)
			elseif sign == MAPID then
				node = node(ANY_NODE, ANY_NODE)
			elseif sign == SER_INSTANCE_ID then
				local isign: number = READ_SIGN()
				const className: string = SER_INSTANCE_SIGNMAP[isign]
				if not className then
					return
				end
				node = node(className)
			elseif sign == ENUM_ID then
				local id: number = READ_ID()
				const enum: Enum = ENUM_ID_MAP[id]
				if not enum then
					return
				end
				node = node(enum)
			end
		end

		return node.read()
	end,
})