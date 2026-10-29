local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

-- RAID enables the update of carry_data only when needed already, only the steal SO is changed

local fs_original_carrydata_chkregisterstealso = CarryData._chk_register_steal_SO
function CarryData:_chk_register_steal_SO(...)
	fs_original_carrydata_chkregisterstealso(self, ...)

	local objective = self._steal_SO_data and self._steal_SO_data.pickup_objective
	if objective and objective.action then
		objective.action.blocks = {
			act = -1,
			action = -1,
			aim = -1,
			heavy_hurt = -1,
			hurt = -1,
			light_hurt = -1,
			shoot = -1,
			turn = -1,
			walk = -1
		}
	end
end
