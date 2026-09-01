--!strict
--!optimize 2
--[[
    shared types storage + sign map

    signMap is populated by src/init.luau after all modules are loaded
    (avoids circular dependency: config -> types -> config)

    used by BlazeSentry, Config, and Dynanode
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("./shared/exports")
-----------------------------------------------------
-- MODULE                                          --
-----------------------------------------------------
const module = {
	signMap = {} :: { [number]: exports.possibleNode },
	types = {} :: exports.blazeSentryTypes,
}

return module
