local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local ids_movement = Idstring('movement')

local fs_original_copactionhurt_freezeragdoll = CopActionHurt._freeze_ragdoll
function CopActionHurt:_freeze_ragdoll()
	fs_original_copactionhurt_freezeragdoll(self)
	self._unit:set_extension_update_enabled(ids_movement, false)
	local dmg_ext = self._unit:damage()
	if dmg_ext then
		dmg_ext.fs_ragdollizable = true
	end
end
