local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local is_server = Network:is_server()

local fs_original_copdamage_die = CopDamage.die
function CopDamage:die(attack_data, ...)
	fs_original_copdamage_die(self, attack_data, ...)

	if is_server then
		local attacker_unit = attack_data and attack_data.attacker_unit
		if alive(attacker_unit) and attacker_unit:in_slot(managers.slot:get_mask('criminals_no_deployables')) then
			self._unit:unit_data().fs_attacker_pos = attacker_unit:position()
		end
	end

	local dmg_ext = self._unit:damage()
	if dmg_ext then
		dmg_ext.fs_dont_care_about_damage = true
	end
end
