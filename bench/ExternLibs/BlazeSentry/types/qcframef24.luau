--!strict
--!optimize 2
--[[
    Quaternion CFrame
	21 bytes
    a tiny bit less precise than matrix cframe but less bandwidth

    each component is serialized as float24
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE_QCF: (CFrame) -> () = writer.QCF24
const READ_QCF: () -> CFrame = reader.QCF24

return table.freeze({
	write = WRITE_QCF,
	read = READ_QCF,
	exType = "CFrame"
})
