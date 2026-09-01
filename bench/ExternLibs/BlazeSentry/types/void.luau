--!strict
--!optimize 2
--[[
	void
	empty table
	0 bytes
]]

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function void_write(_value: {}): ()
end

@native
const function void_read(): {}
	return {}
end

return table.freeze({
	write = void_write,
	read = void_read,
	exType = "void"
})
