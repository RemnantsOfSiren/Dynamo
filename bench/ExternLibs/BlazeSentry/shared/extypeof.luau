--!strict
--[[
    Used by @union.luau for determining the value type
    uses a couple of extra steps regarding the type inferring (float vs int, array vs map, in the future possibly other differences)
]]
--!optimize 2

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const TABLE_TYPE: string = "table"
const NUMBER_TYPE: string = "number"
const ENUM_TYPE: string = "EnumItem"

const INT: string = "int"
const FLOAT: string = "float"
const ARRAY: string = "array"
const MAP: string = "map"

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const TYPEOF: <T>(T) -> string = typeof
const TOSTRING: <T>(T) -> string = tostring

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------

@native
const function extypeof<T>(value: T): string
	local vType: string = TYPEOF(value)
    if vType == NUMBER_TYPE then
        vType = (value :: number) // 1 == value and INT or FLOAT
    elseif vType == TABLE_TYPE then
        vType = (#(value :: { [any]: any }) == 0 and next(value :: { [any]: any }) ~= nil) and MAP or ARRAY
    elseif vType == ENUM_TYPE then
        -- to get the name of the enum, we can use tostring
        vType = "Enum." .. TOSTRING((value :: EnumItem).EnumType)
    end
    return vType
end

return extypeof