--!strict
--!optimize 2
--[[
    Quaternion CFrame
	28 bytes
    a tiny bit less precise than matrix cframe but less bandwidth

    each component is serialized as float32
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE_QCF: (CFrame) -> () = writer.QCF32
const READ_QCF: () -> CFrame = reader.QCF32

return table.freeze({
	write = WRITE_QCF,
	read = READ_QCF,
	exType = "CFrame"
})
