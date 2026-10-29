local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

-- Not ported: the filtered attention lists (they decide who can notice whom, RAID's stealth relies on its own lists)
-- and the spawn delay (RAID has its own, GroupAIStateBase:_chk_spawn_point_camped).

local _is_loud
local function _set_loud(loud)
	_is_loud = loud
end
table.insert(FullSpeedSwarm.call_on_loud, _set_loud)

local fs_settings = FullSpeedSwarm.final_settings

local fs_original_groupaistatebase_setdifficulty = GroupAIStateBase.set_difficulty
function GroupAIStateBase:set_difficulty(...)
	fs_original_groupaistatebase_setdifficulty(self, ...)
	DelayedCalls:Add('DelayedModFSS_setdifficulty', 0, function()
		FullSpeedSwarm:update_max_task_throughput()
	end)
end

local fs_original_groupaistatebase_onsimulationended = GroupAIStateBase.on_simulation_ended
function GroupAIStateBase:on_simulation_ended(...)
	fs_original_groupaistatebase_onsimulationended(self, ...)
	FullSpeedSwarm:set_loud(false)
end

local fs_original_groupaistatebase_load = GroupAIStateBase.load
function GroupAIStateBase:load(...)
	fs_original_groupaistatebase_load(self, ...)
	FullSpeedSwarm:invalidate_attention_caches()
end

local fs_original_groupaistatebase_registerAIattentionobject = GroupAIStateBase.register_AI_attention_object
function GroupAIStateBase:register_AI_attention_object(unit, ...)
	fs_original_groupaistatebase_registerAIattentionobject(self, unit, ...)

	local att_info = self._attention_objects.all[unit:key()]
	if att_info then
		att_info.fs_ext_animdata = unit:anim_data()
		att_info.fs_ext_base = unit:base()
		att_info.fs_ext_brain = unit:brain()
		att_info.fs_ext_movement = unit:movement()
		att_info.fs_ext_cdmg = unit:character_damage()
	end
end

function GroupAIStateBase.on_unit_detection_updated()
	-- qued, debug drawing only
end

function GroupAIStateBase:fs_destroy_attention_object(unit_key)
	for _, data in pairs(self._police) do
		local logic_data = data.unit:brain()._logic_data
		local attention_info2 = logic_data and logic_data.detected_attention_objects[unit_key]
		if attention_info2 then
			CopLogicBase._destroy_detected_attention_object_data(logic_data, attention_info2)
			if logic_data.attention_obj and logic_data.attention_obj.u_key == unit_key then
				CopLogicBase._set_attention_obj(logic_data, nil, nil)
			end
		end
	end
end

local fs_original_groupaistatebase_creategroup = GroupAIStateBase._create_group
function GroupAIStateBase:_create_group(...)
	local result = fs_original_groupaistatebase_creategroup(self, ...)
	result.fs_attention_obj_aware_t = {}
	return result
end

-- areas change when worlds are merged or unloaded too
local _fs_cache_areas_from_nav_seg_id = {}

for _, fname in ipairs({'add_area', '_create_area_data', 'unload_world_nav_data', 'on_nav_segment_state_change'}) do
	local fs_original_func = GroupAIStateBase[fname]
	if fs_original_func then
		GroupAIStateBase[fname] = function(self, ...)
			_fs_cache_areas_from_nav_seg_id = {}
			return fs_original_func(self, ...)
		end
	end
end

local fs_original_groupaistatebase_getareasfromnavsegid = GroupAIStateBase.get_areas_from_nav_seg_id
function GroupAIStateBase:get_areas_from_nav_seg_id(nav_seg_id)
	local areas = _fs_cache_areas_from_nav_seg_id[nav_seg_id]

	if not areas then
		areas = fs_original_groupaistatebase_getareasfromnavsegid(self, nav_seg_id)
		_fs_cache_areas_from_nav_seg_id[nav_seg_id] = areas
	end

	return areas
end

if Network:is_server() then
	local fs_original_groupaistatebase_isareasafe = GroupAIStateBase.is_area_safe
	function GroupAIStateBase:is_area_safe(area)
		if area and _is_loud and fs_settings.improved_tactics and area.fs_unsafe_till_t and self._t < area.fs_unsafe_till_t then
			return false
		end
		return fs_original_groupaistatebase_isareasafe(self, area)
	end

	local fs_original_groupaistatebase_onenemyunregistered = GroupAIStateBase.on_enemy_unregistered
	function GroupAIStateBase:on_enemy_unregistered(unit)
		fs_original_groupaistatebase_onenemyunregistered(self, unit)

		if _is_loud and fs_settings.improved_tactics and unit:character_damage():dead() then
			local mov = unit:movement()
			local nav_seg = mov.fs_death_navseg or mov:nav_tracker():nav_segment()
			local area = self:get_area_from_nav_seg_id(nav_seg)
			if area then
				local tda = self._tweak_data.assault
				local force = 80 / (self:get_difficulty_dependent_value(tda.force) * self:_get_balancing_multiplier(tda.force_balance_mul))
				if not area.fs_unsafe_till_t or self._t > area.fs_unsafe_till_t then
					area.fs_unsafe_till_t = self._t + 5 * force
				else
					area.fs_unsafe_till_t = math.min(area.fs_unsafe_till_t + 7 * force, self._t + 60)
				end
			end
		end
	end
end
