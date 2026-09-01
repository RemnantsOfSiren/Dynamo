--!strict
--!optimize 2
--[[
	SerInstanceSigns v0.1.1

	Contains serialized instances type signs, 
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES	                                       --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- VARIABLES                                       --
-----------------------------------------------------
const signLookup = {}
const nameLookup = {}
const serInstanceSigns = {
	signLookup = signLookup :: { [number]: string },
	nameLookup = nameLookup :: { [string]: number },
}

return table.freeze(serInstanceSigns)
