--!strict
--!optimize 2
--[[
    Quaternion CFrame
	14 bytes

    each component is serialized as float16
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const WRITE_QCF: (CFrame) -> () = writer.QCF16
const READ_QCF: () -> CFrame = reader.QCF16

return table.freeze({
	write = WRITE_QCF,
	read = READ_QCF,
	exType = "CFrame",
})
