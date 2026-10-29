local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_copmovement_init = CopMovement.init
function CopMovement:init(unit)
	fs_original_copmovement_init(self, unit)
	self.fs_blockers_nr = 0
	self.fs_keep_groundray = 0
	self.fs_fake_ray_position = Vector3()
	self.fs_m_stand_pos = self._m_stand_pos
end

local fs_original_copmovement_chkactionforbidden = CopMovement.chk_action_forbidden
function CopMovement:chk_action_forbidden(action_type)
	if self.fs_blockers_nr > 0 or self._parachute_unit then
		return fs_original_copmovement_chkactionforbidden(self, action_type)
	end
end

local fs_original_copmovement_actionrequest = CopMovement.action_request
function CopMovement:action_request(action_desc)
	local action = fs_original_copmovement_actionrequest(self, action_desc)
	if action and action.chk_block and not action.fs_counted_blocker then
		action.fs_counted_blocker = self
		self.fs_blockers_nr = self.fs_blockers_nr + 1
	end
	return action
end

local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_z = mvector3.z
local mvec3_mul = mvector3.multiply
local mvec3_add = mvector3.add
local mvec3_sub = mvector3.subtract
local mvec3_norm = mvector3.normalize
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local temp_vec3 = Vector3()
local math_down = math.DOWN
local math_abs = math.abs
local math_lerp = math.lerp
local math_min = math.min

local _units_per_navseg = FullSpeedSwarm.units_per_navseg
function CopMovement:set_position(pos)
	mvec3_set(self._m_pos, pos)
	self._m_stand_pos = nil

	self._obj_head:m_position(self._m_head_pos)
	self._obj_spine:m_position(self._m_com)
	self._nav_tracker:move(pos)
	self._unit:set_position(pos)

	if self.fs_do_track then
		local new_seg = self._nav_tracker:nav_segment()
		local old_seg = self.fs_cur_seg
		if new_seg ~= old_seg then
			local new_list = _units_per_navseg[new_seg]
			local u_key = self._unit:key()
			if old_seg then
				_units_per_navseg[old_seg][u_key] = nil
			end
			if not new_list then
				new_list = {}
				_units_per_navseg[new_seg] = new_list
			end
			new_list[u_key] = self.fs_do_track
		end
		self.fs_cur_seg = new_seg
	end
end

function CopMovement:set_m_pos(pos)
	mvec3_set(self._m_pos, pos)
	self._m_stand_pos = nil
	self._obj_head:m_position(self._m_head_pos)
	self._nav_tracker:move(pos)
	self._obj_spine:m_position(self._m_com)
end

local vec_stand = Vector3(0, 0, 160)
function CopMovement:m_stand_pos()
	local pos = self._m_stand_pos
	if not pos then
		pos = self.fs_m_stand_pos
		mvec3_set(pos, self._m_pos)
		mvec3_add(pos, vec_stand)
		self._m_stand_pos = pos
	end
	return pos
end

function CopMovement:upd_ground_ray(from_pos)
	local fake_ray = self.fs_old_gnd_ray
	if fake_ray and self.fs_keep_groundray > 0 then
		if math_abs(fake_ray.field_z - self._nav_tracker:field_z()) < 2 then
			self.fs_keep_groundray = self.fs_keep_groundray - 1
		else
			self.fs_keep_groundray = 0
		end

	else
		local hit_ray
		local new_pos = from_pos or self._m_pos
		local field_z = self._nav_tracker:field_z()
		local ground_z = field_z - 22
		local fake_ray_pos = self.fs_fake_ray_position
		mvec3_set(temp_vec1, new_pos)
		mvec3_set(temp_vec2, new_pos)
		mvec3_set_z(temp_vec1, ground_z + 171)
		mvec3_set_z(temp_vec2, ground_z - 140)
		local gnd_ray = World:raycast('ray', temp_vec1, temp_vec2, 'slot_mask', self._slotmask_gnd_ray, 'ray_type', 'walk')
		if gnd_ray then
			local dubious
			local hit_pos = gnd_ray.position
			local hit_pos_z = mvec3_z(hit_pos)
			local new_pos_z = mvec3_z(new_pos)

			if new_pos_z - field_z > -40 and new_pos_z - hit_pos_z > 100 then
				mvec3_set_z(temp_vec1, ground_z + 100)
				gnd_ray = World:raycast('ray', temp_vec1, temp_vec2, 'slot_mask', self._slotmask_gnd_ray, 'ray_type', 'walk') or gnd_ray
				hit_pos = gnd_ray.position
				hit_pos_z = mvec3_z(hit_pos)
				if hit_pos_z - new_pos_z > 99 then
					dubious = true
				end
			end

			if not from_pos then
				ground_z = (new_pos_z + hit_pos_z) / 2
			elseif not dubious and math_abs(new_pos_z - hit_pos_z) < 100 then
				self.fs_keep_groundray = self.fs_dt and (self._ext_anim.run and 0.1 or 0.4) / self.fs_dt or 4
				ground_z = hit_pos_z
			else
				self.fs_keep_groundray = 0
				ground_z = fake_ray_pos.z
			end

			hit_ray = gnd_ray
		else
			self.fs_keep_groundray = 4
			if fake_ray then
				ground_z = mvec3_z(fake_ray.position) - fake_ray.field_z + ground_z
			end
		end

		mvec3_set(fake_ray_pos, new_pos)
		mvec3_set_z(fake_ray_pos, ground_z)

		if fake_ray then
			fake_ray.field_z = field_z
			fake_ray.unit = hit_ray and hit_ray.unit
		else
			fake_ray = {
				field_z = field_z,
				position = fake_ray_pos,
				ray = math_down,
				unit = hit_ray and hit_ray.unit
			}
			self.fs_old_gnd_ray = fake_ray
		end
	end

	self._action_common_data.gnd_ray = fake_ray
	self._gnd_ray = fake_ray
end

if Network:is_server() then
	function CopMovement:fs_update_pre_destroyed()
		self._gnd_ray = nil
	end

	local fs_original_copmovement_predestroy = CopMovement.pre_destroy
	function CopMovement:pre_destroy()
		self._gnd_ray = nil
		self.update = CopMovement.fs_update_pre_destroyed
		fs_original_copmovement_predestroy(self)
	end

	local ids_movement = Idstring('movement')
	function CopMovement:update(unit, t, dt)
		if not managers.navigation:is_streamed_data_ready() then
			return
		end

		local session = managers.network:session()
		if session and not session:local_peer():loaded() then
			return
		end

		if self._wait_load then
			return
		end

		self.fs_dt = dt
		self._gnd_ray = nil
		local old_need_upd = self._need_upd
		self._need_upd = false

		self:_upd_actions(t)

		if self._need_upd ~= old_need_upd then
			unit:set_extension_update_enabled(ids_movement, self._need_upd)
		end
		if self._force_head_upd then
			self._force_head_upd = nil
			self:upd_m_head_pos()
		end
	end

	local idle_1 = {type = 'idle', body_part = 1}
	local idle_2 = {type = 'idle', body_part = 2}
	function CopMovement:_upd_actions(t)
		local a_actions = self._active_actions
		local has_no_action = true
		for i_action = 1, 4 do
			local action = a_actions[i_action]
			if action then
				local action_update = action.update
				if action_update then
					action_update(action, t)
				end
				if not self._need_upd then
					local action_need_upd = action.need_upd
					if action_need_upd then
						self._need_upd = action_need_upd(action)
					end
				end
				local action_expired = action.expired
				if action_expired and action_expired(action) then
					a_actions[i_action] = false
					local action_on_exit = action.on_exit
					if action_on_exit then
						action_on_exit(action)
					end
					self._ext_brain:on_action_completed(action)
					self._ext_base:chk_freeze_anims()
				else
					has_no_action = nil
				end
			end
		end

		if has_no_action then
			has_no_action = not (a_actions[1] or a_actions[2] or a_actions[3] or a_actions[4])
		end

		local queued_actions = self._queued_actions
		local has_no_queued_action = not queued_actions or not next(queued_actions)
		if has_no_action and has_no_queued_action then
			self:action_request(idle_1)
		end
		if not a_actions[1] and not a_actions[2] and has_no_queued_action and not self:chk_action_forbidden('action') then
			self:action_request(a_actions[3] and idle_2 or idle_1)
		end
		self:_upd_stance(t)
		if not self._need_upd then
			local ext_anim = self._ext_anim
			if ext_anim.base_need_upd or ext_anim.upper_need_upd or self._stance.transition or self._suppression.transition or ext_anim.panic then
				self._need_upd = true
			end
		end
	end
else
	local fs_original_copmovement_update = CopMovement.update
	function CopMovement:update(unit, t, dt)
		self.fs_dt = dt
		fs_original_copmovement_update(self, unit, t, dt)
	end
end
