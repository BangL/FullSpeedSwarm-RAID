local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

function CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
	if shoot then
		if not my_data.firing then
			data.fs_ext_movement:set_allow_fire(true)
			my_data.firing = true
			if data.unit:slot() ~= 16 and data.char_tweak.chatter.aggressive then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, 'aggressive')
			end
		end
	elseif my_data.firing then
		data.fs_ext_movement:set_allow_fire(false)
		my_data.firing = nil
	end
end

DelayedCalls:Add('DelayedModFSS_CopLogicAttack', 0, function()
	if FullSpeedSwarm.final_settings.cop_awareness then
		local mask_enemies = managers.slot:get_mask('enemies')
		local fs_original_coplogicattack_updaim = CopLogicAttack._upd_aim
		local CopActionWalk = CopActionWalk
		function CopLogicAttack._upd_aim(data, my_data)
			local char_tweak = data.char_tweak
			if not char_tweak.always_face_enemy and data.unit:in_slot(mask_enemies) then
				char_tweak.always_face_enemy = true
			end

			-- a walking cop is not "running", so he keeps firing while he moves
			local original_function = CopActionWalk.haste
			CopActionWalk.haste = CopActionWalk.fs_haste

			fs_original_coplogicattack_updaim(data, my_data)

			CopActionWalk.haste = original_function
		end
	end
end)
