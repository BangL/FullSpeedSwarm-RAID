local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

core:module('CoreElementShape')

local fs_original_elementshape_isinsideshape = ElementShape.is_inside_shape
function ElementShape:is_inside_shape(pos)
	if self._shape_units then
		return fs_original_elementshape_isinsideshape(self, pos)
	end

	for _, shape in ipairs(self._shapes) do
		if shape:fs_is_inside(pos) then
			return true
		end
	end
	return false
end
