local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_copbrain_converttocriminal = CopBrain.convert_to_criminal
function CopBrain:convert_to_criminal(mastermind_criminal)
	fs_original_copbrain_converttocriminal(self, mastermind_criminal)
	self._logic_data.fs_ext_movement.fs_do_track = nil
	local cur_seg = self._logic_data.fs_ext_movement.fs_cur_seg
	if cur_seg then
		FullSpeedSwarm.units_per_navseg[cur_seg][self._unit:key()] = nil
	end
end

local fs_original_copbrain_onactioncompleted = CopBrain.on_action_completed
function CopBrain:on_action_completed(action)
	local u_mov = action.fs_counted_blocker
	if u_mov then
		action.fs_counted_blocker = nil
		u_mov.fs_blockers_nr = u_mov.fs_blockers_nr - 1
	end

	return fs_original_copbrain_onactioncompleted(self, action)
end

local fs_original_copbrain_resetlogicdata = CopBrain._reset_logic_data
function CopBrain:_reset_logic_data()
	fs_original_copbrain_resetlogicdata(self)
	self._logic_data.detected_attention_objects_i = FullSpeedSwarm.metaize_i(self._logic_data.detected_attention_objects)
	self._logic_data._tweak_table = self._unit:base()._tweak_table
	self._logic_data.fs_ext_movement = self._unit:movement()
	self._logic_data.fs_on_queued_task = function(id)
		if self._logic_data.internal_data.queued_tasks then
			self._logic_data.internal_data.queued_tasks[id] = nil
		end
	end
end
