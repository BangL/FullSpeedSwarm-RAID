local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

_G.FullSpeedSwarm = _G.FullSpeedSwarm or {}
FullSpeedSwarm._path = ModPath
FullSpeedSwarm._data_path = SavePath .. 'full_speed_swarm.json'
FullSpeedSwarm.in_arrest_logic = {}
FullSpeedSwarm.units_per_navseg = {}
FullSpeedSwarm.call_on_loud = {}
FullSpeedSwarm.final_settings = {}
FullSpeedSwarm.settings = {
	task_throughput = 600,

	lod_updater = 1,
	optimized_inputs = true,
	high_violence_mode = true,
	slower_but_safer = false, -- to be enabled in mods/saves/full_speed_swarm.json
	walking_quality = 1,

	cop_awareness = false,
	eyes_wide_open = false,
	fastpaced = false,
	improved_tactics = true,
	iter_chase = false,
	nervous_game = false,
}

function FullSpeedSwarm:update_walking_quality()
	-- CopBase is only loaded ingame, copbase.lua applies the setting on load
	if not CopBase then
		return
	end
	CopBase.fs_lod_stage = CopBase['fs_lod_stage_' .. self.settings.walking_quality]
end

-- Iter RAID has no settings, its path streamlining is always active
function FullSpeedSwarm:is_iter_active()
	if self.iter_active == nil and BLT and BLT.Mods then
		local mod = BLT.Mods:GetModByName('Iter RAID')
		self.iter_active = mod and mod:IsEnabled() and true or false
	end
	return self.iter_active
end

function FullSpeedSwarm:get_gameplay_options_forced_values()
	local result = {}

	if not self:is_iter_active() then
		result.improved_tactics = false
	end

	if self.host_settings then
		for _, opt in pairs({
			'task_throughput',
			'cop_awareness',
			'eyes_wide_open',
			'fastpaced',
			'improved_tactics',
			'iter_chase',
			'nervous_game',
		}) do
			if self.host_settings[opt] ~= nil then
				result[opt] = self.host_settings[opt]
			end
		end
	end

	return result
end

-- RAID keeps the Lua state between camp and missions, the loud state is set back by the game
function FullSpeedSwarm:set_loud(loud)
	loud = loud and true or false
	if self.is_loud ~= loud then
		self.is_loud = loud
		for _, fct in ipairs(self.call_on_loud) do
			fct(loud)
		end
	end
end

function FullSpeedSwarm:calc_max_task_throughput()
	local gstate = managers and managers.groupai and managers.groupai:state()
	if not gstate or not gstate._tweak_data then
		return 600
	end

	local tda = gstate._tweak_data.assault
	if not tda or not tda.force or not tda.force_balance_mul then
		return 600
	end
	local force = gstate:get_difficulty_dependent_value(tda.force)
	local force_balance_mul = tda.force_balance_mul[#tda.force_balance_mul]
	local mul = self.final_settings.eyes_wide_open and 10 or 7
	return math.ceil(force * force_balance_mul) * mul
end

function FullSpeedSwarm:update_max_task_throughput()
	local new_value = self.settings.task_throughput
	-- RAID's tick rate is in tasks per second (EnemyManager._tickrate)
	local base_rate = tweak_data and tweak_data.group_ai and tweak_data.group_ai.ai_tick_rate_stealth or 100
	if self.final_settings.eyes_wide_open or new_value < base_rate then
		new_value = self:calc_max_task_throughput()
	end
	if type(self.apply_max_task_throughput) == 'function' then
		self:apply_max_task_throughput(new_value)
	end
end

function FullSpeedSwarm:finalize_settings()
	for k in pairs(self.final_settings) do
		self.final_settings[k] = nil
	end

	for k, v in pairs(self.settings) do
		self.final_settings[k] = v
	end

	for k, v in pairs(self:get_gameplay_options_forced_values()) do
		self.final_settings[k] = v
	end
end

function FullSpeedSwarm:load()
	local file = io.open(self._data_path, 'r')
	if file then
		for k, v in pairs(json.decode(file:read('*all')) or {}) do
			if self.settings[k] ~= nil then
				self.settings[k] = v
			end
		end
		file:close()
	end

	self:finalize_settings()
end

function FullSpeedSwarm:save()
	local file = io.open(self._data_path, 'w+')
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

FullSpeedSwarm:load()
DelayedCalls:Add('DelayedFSS_finalizesettings', 0, function()
	-- the mod list (Iter RAID) may not have been known at load time
	FullSpeedSwarm:finalize_settings()
	FullSpeedSwarm:update_max_task_throughput()
end)

if Global.load_level and BLT:GetOS() == 'windows' and jit and jit.opt then
	DelayedCalls:Add('DelayedFSS_jitune', 0, function()
		jit.opt.start('maxtrace=16384', 'maxrecord=32768', 'maxmcode=65536')
	end)
end

function FullSpeedSwarm.metaize_i(tbl)
	local _i = { [0] = 0 }
	local mt = {
		__newindex = function (t, k, v)
			-- assigning nil to an absent key also lands here, which would leave a hole in the index
			if v ~= nil then
				_i[0] = _i[0] + 1
				_i[_i[0]] = v
				rawset(t, k, v)
			end
		end
	}
	setmetatable(tbl, mt)
	return _i
end

core:module('CoreCode')

if _G.FullSpeedSwarm.settings.slower_but_safer then
	function alive(obj)
		local tp = type(obj)
		if tp == 'userdata' or tp == 'table' and type(obj.alive) == 'function' then
			return obj:alive()
		end
		return false
	end
else
	function alive(obj)
		return obj and obj:alive()
	end
end
