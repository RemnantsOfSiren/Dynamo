--!strict
--!optimize 2
--[[
	nothing
	0 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function nothing_write(value: nil): ()
	return
end

@native
const function nothing_read(): nil
	return nil
end

return table.freeze({
	write = nothing_write,
	read = nothing_read,
	exType = "nil"
})
