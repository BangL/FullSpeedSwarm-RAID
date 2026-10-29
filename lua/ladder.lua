local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

for obj_name, ext_name in pairs({
	CopSound = 'sound',
	NetworkBaseExtension = 'network',
	Pickup = 'pickup',
	PlayerAnimationData = 'anim_data',
	PlayerEquipment = 'equipment',
	PlayerInventory = 'inventory',
	PlayerSound = 'sound',
	ScriptUnitData = 'unit_data',
	TeamAISound = 'sound',
}) do
	local obj = _G[obj_name]
	if obj and obj.init and not obj.update then
		local ids_ext = Idstring(ext_name)
		local fs_original_object_init = obj.init
		obj.init = function(self, unit, ...)
			fs_original_object_init(self, unit, ...)
			if type(unit) == 'userdata' then
				unit:set_extension_update_enabled(ids_ext, false)
			end
		end
	end
end
