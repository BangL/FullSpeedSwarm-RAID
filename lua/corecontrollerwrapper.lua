local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not FullSpeedSwarm.settings.optimized_inputs then
	return
end

core:module('CoreControllerWrapper')

local mvec3_copy = mvector3.copy

local fs_original_controllerwrapper_init = ControllerWrapper.init
function ControllerWrapper:init(...)
	self.fs_timer_wall_running = TimerManager:wall_running()
	fs_original_controllerwrapper_init(self, ...)
end

function ControllerWrapper:fs_reset()
	self.fs_has_delay_trigger_queue = not not next(self._delay_trigger_queue)
	self.fs_has_delay_map = not not next(self._delay_map)
	self.fs_has_multi_input_map = not not next(self._multi_input_map)
end

for _, fname in ipairs({
	'init',
	'rebind_connections',
	'queue_delay_trigger',
	'remove_trigger',
	'_really_activate',
	'_really_deactivate',
}) do
	local fs_original_controllerwrapper_func = ControllerWrapper[fname]
	ControllerWrapper[fname] = function(self, ...)
		fs_original_controllerwrapper_func(self, ...)
		self:fs_reset()
	end
end

function ControllerWrapper:update(t, dt)
	self:reset_cache(true)
	if self.fs_has_delay_trigger_queue then
		self:update_delay_trigger_queue()
	end
	self:check_connect_changed_status()

	if alive(self._virtual_controller) then
		self._virtual_controller:clear_axis_triggers()
	end
end

function ControllerWrapper:reset_cache(check_time)
	local reset_cache_time = self.fs_timer_wall_running:time()

	if not check_time or self._reset_cache_time < reset_cache_time then
		self._input_any_cache = nil
		self._input_any_pressed_cache = nil
		self._input_any_released_cache = nil

		if next(self._input_pressed_cache) then
			self._input_pressed_cache = {}
		end

		if next(self._input_bool_cache) then
			self._input_bool_cache = {}
		end

		if next(self._input_float_cache) then
			self._input_float_cache = {}
		end

		if next(self._input_axis_cache) then
			self._input_axis_cache = {}
		end

		if self.fs_has_multi_input_map then
			self:update_multi_input()
		end
		if self.fs_has_delay_map then
			self:update_delay_input()
		end

		self._reset_cache_time = reset_cache_time
	end
end

local mvec3_x = mvector3.x
local mvec3_y = mvector3.y
local mvec3_z = mvector3.z
local mvec3_set_static = mvector3.set_static
function ControllerWrapper:get_modified_axis(connection_name, connection, axis)
	local mul_x, mul_y, mul_z = connection:fs_get_multiplier()
	if mul_x then
		mvec3_set_static(axis, mvec3_x(axis) * mul_x, mvec3_y(axis) * mul_y, mvec3_z(axis) * mul_z)
	end

	local inv_x, inv_y, inv_z = connection:fs_get_inversion()
	if inv_x then
		mvec3_set_static(axis, mvec3_x(axis) * inv_x, mvec3_y(axis) * inv_y, mvec3_z(axis) * inv_z)
	end

	return self:lerp_axis(connection_name, connection, axis)
end

local id_strings = {}
local clbks = {}
function ControllerWrapper:get_input_axis_clbk(connection_name, func)
	if not self:enabled() then
		return
	end

	local id = id_strings[connection_name]
	if not id then
		id = Idstring(connection_name)
		id_strings[connection_name] = id
	end

	local clbkey = connection_name .. tostring(func) -- assume no callbacks spam
	local f = clbks[clbkey]
	if not f then
		local connection = self._setup:get_connection(connection_name)
		f = function(axis_id, controller_name, axis)
			local unscaled_axis = mvec3_copy(axis)
			func(
				self:get_modified_axis(connection_name, connection, axis),
				self:get_unscaled_axis(connection_name, connection, unscaled_axis),
				connection:get_multiplier()
			)
		end
		clbks[clbkey] = f
	end

	self._virtual_controller:add_axis_trigger(id, f)
end
