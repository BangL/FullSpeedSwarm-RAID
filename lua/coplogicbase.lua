local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

-- RAID's detection (CopLogicBase._upd_attention_obj_detection) drives the stealth gameplay (suspicion indicators,
-- investigation thresholds, pickpocket upgrades), it is kept as is. Only the parts around it are optimized.

local alive = alive
local math_min = math.min

local fs_settings = FullSpeedSwarm.final_settings

local _nervous_game, _eyes_wide_open
local function _set_loud(loud)
	_nervous_game = loud and fs_settings.nervous_game
	_eyes_wide_open = loud and fs_settings.eyes_wide_open
end
table.insert(FullSpeedSwarm.call_on_loud, _set_loud)

function CopLogicBase.on_attention_obj_identified(data, attention_u_key, attention_info, reason)
	local att_unit = attention_info.unit
	if att_unit then
		local att_cdmg = attention_info.fs_ext_cdmg or att_unit:character_damage()
		if att_cdmg and att_cdmg:dead() then
			managers.voice_over:guard_saw_body(data.unit)
		elseif att_unit:carry_data() then
			managers.voice_over:guard_saw_bag(data.unit)
		else
			local gstate = managers.groupai:state()
			local att_mov = attention_info.fs_ext_movement or att_unit:movement()
			if att_cdmg and att_mov and att_mov.SO_access and gstate:whisper_mode() then
				gstate:propagate_alert({
					'vo_cbt',
					data.unit:movement():m_head_pos(),
					data.char_tweak.shout_radius or 0,
					att_mov:SO_access(),
					att_unit
				})
			end
		end
	end

	local group = data.group
	if group then
		local aware_t = group.fs_attention_obj_aware_t
		local t = aware_t and aware_t[attention_u_key]
		if not t or data.t - t > 1 then
			if aware_t then
				aware_t[attention_u_key] = data.t
			end
			for u_key, u_data in pairs(group.units) do
				if u_key ~= data.key and alive(u_data.unit) then
					u_data.unit:brain():clbk_group_member_attention_identified(data.unit, attention_u_key)
				end
			end
		end
	end
end

local fs_original_coplogicbase_queuetask = CopLogicBase.queue_task
function CopLogicBase.queue_task(internal_data, id, func, data, exec_t, asap)
	if _eyes_wide_open then
		local t = data and data.t
		if t and exec_t and exec_t - t < 2 then
			exec_t = math_min(exec_t, t + 0.1)
		end
	end

	local qd_tasks = internal_data.queued_tasks
	if qd_tasks and qd_tasks[id] and managers.enemy:update_queue_task(id, func, data, exec_t, nil, asap) then
		return
	end

	fs_original_coplogicbase_queuetask(internal_data, id, func, data, exec_t, asap)
end

local fs_original_coplogicbase_createdetectedattentionobjectdata = CopLogicBase._create_detected_attention_object_data
function CopLogicBase._create_detected_attention_object_data(time, my_unit, u_key, attention_info, settings, ...)
	local new_entry = fs_original_coplogicbase_createdetectedattentionobjectdata(time, my_unit, u_key, attention_info, settings, ...)

	new_entry.fs_ext_animdata = attention_info.fs_ext_animdata
	new_entry.fs_ext_base = attention_info.fs_ext_base
	new_entry.fs_ext_brain = attention_info.fs_ext_brain
	new_entry.fs_ext_cdmg = attention_info.fs_ext_cdmg
	new_entry.fs_ext_movement = attention_info.fs_ext_movement

	if _nervous_game or my_unit:slot() == 16 then
		-- identified on the next check
		new_entry.notice_progress = 1
		new_entry.notice_progress_wanted = 1.01
		if new_entry.dis < 2000 then
			new_entry.next_verify_t = time
		end
	end

	return new_entry
end

local fs_original_coplogicbase_destroydetectedattentionobjectdata = CopLogicBase._destroy_detected_attention_object_data
function CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
	fs_original_coplogicbase_destroydetectedattentionobjectdata(data, attention_info)

	local daoi = data.detected_attention_objects_i
	if daoi then
		local a_key = attention_info.u_key
		local n = daoi[0]
		for i = 1, n do
			if daoi[i].u_key == a_key then
				daoi[i] = daoi[n]
				daoi[n] = nil
				daoi[0] = n - 1
				break
			end
		end
	end
end

local fs_original_coplogicbase_destroyalldetectedattentionobjectdata = CopLogicBase._destroy_all_detected_attention_object_data
function CopLogicBase._destroy_all_detected_attention_object_data(data)
	fs_original_coplogicbase_destroyalldetectedattentionobjectdata(data)
	data.detected_attention_objects_i = FullSpeedSwarm.metaize_i(data.detected_attention_objects)
end

DelayedCalls:Add('DelayedModFSS_tweaktweak', 0, function()
	if fs_settings.nervous_game then
		for name, character in pairs(tweak_data.character) do
			if name ~= 'presets' and type(character) == 'table' and type(character.weapon) == 'table' then
				for _, weapon in pairs(character.weapon) do
					if type(weapon) == 'table' and weapon.focus_delay then
						weapon.focus_delay = math.min(1, weapon.focus_delay)
					end
				end
			end
		end
		for _, presets in pairs(tweak_data.character.presets.weapon) do
			for _, preset in pairs(presets) do
				if type(preset) == 'table' and preset.focus_delay then
					preset.focus_delay = math.max(0.5, preset.focus_delay / 3)
				end
			end
		end
	end
end)
