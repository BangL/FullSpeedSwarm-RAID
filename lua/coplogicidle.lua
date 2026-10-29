local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local CopLogicBase = CopLogicBase
local CopLogicIdle = CopLogicIdle

-- same as RAID's, but important units are updated every 0.1 s instead of every frame
function CopLogicIdle.queued_update(data)
	local my_data = data.internal_data
	local delay = data.logic._upd_enemy_detection(data)

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)
		return
	end

	local objective = data.objective

	if my_data.has_old_action then
		CopLogicBase._upd_stop_old_action(data, my_data, objective)

		if my_data.has_old_action then
			CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t + delay, data.important and true)
			return
		end
	end

	if data.team and data.team.id == 'criminal1' and (not objective or objective.type == 'free') and (not data.path_fail_t or data.t - data.path_fail_t > 6) then
		managers.groupai:state():on_criminal_jobless(data.unit)

		if my_data ~= data.internal_data then
			return
		end
	end

	if CopLogicBase._chk_relocate(data) then
		return
	end

	CopLogicIdle._perform_objective_action(data, my_data, objective)
	CopLogicIdle._upd_stance_and_pose(data, my_data, objective)
	CopLogicIdle._upd_pathing(data, my_data)
	CopLogicIdle._upd_scan(data, my_data)

	if data.cool then
		CopLogicIdle.upd_suspicion_decay(data)
	end

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)
		return
	end

	if data.important then
		delay = 0.1
	else
		delay = delay or 0.1
	end

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t + delay, data.important and true)
end
