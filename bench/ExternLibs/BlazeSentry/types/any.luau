--!strict
--!optimize 2
--[[
	any
	supported types:
	- int8
	- int16
	- int32
	- uint8
	- uint16
	- uint32
	- float32
	- boolean
	- string
	- string255
	- array
	- array255
	- map
	- void
	- nothing
	- vector/vector3 (configurable)
	- vector2
	- cframe
	- color3
	- instance

	1 + nodeSize bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const dynanode = require("../shared/dynanode")

return table.freeze({
	write = dynanode.write,
	read = dynanode.read,
	exType = "any"
})