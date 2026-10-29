local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings
if fs_settings.eyes_wide_open then
	-- qued
elseif fs_settings.task_throughput < 200 then
	return
end

-- the brain of a bot is updated 10 times per second through the task queue instead of every frame
local CopLogicBase = CopLogicBase
local ids_brain = Idstring('brain')
function TeamAIBrain:set_update_enabled_state(state)
	self._unit:set_extension_update_enabled(ids_brain, false)

	local data = self.fs_brain_data
	if not data then
		data = { unit = self._unit, internal_data = {} }
		self.fs_brain_data = data
	end

	local task_key = 'TeamAIBrain.update' .. tostring(self._unit:key())
	local my_data = data.internal_data

	if state then
		local unit = self._unit
		local timer = TimerManager:game()
		local clbk
		clbk = function()
			if not alive(unit) then
				return
			end
			local t = timer:time()
			data.t = t
			self:update(unit, t, timer:delta_time())
			local qt = my_data.queued_tasks
			if not (qt and qt[task_key]) then
				CopLogicBase.queue_task(my_data, task_key, clbk, data, t + 0.1)
			end
		end
		data.t = timer:time()
		CopLogicBase.queue_task(my_data, task_key, clbk, data, data.t + math.random() / 10)
	else
		CopLogicBase.chk_unqueue_task(my_data, task_key)
	end
end
