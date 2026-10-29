local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_criminalsmanager_setunit = CriminalsManager.set_unit
function CriminalsManager:set_unit(name, unit, ...)
	if alive(unit) then
		fs_original_criminalsmanager_setunit(self, name, unit, ...)
	end
end
