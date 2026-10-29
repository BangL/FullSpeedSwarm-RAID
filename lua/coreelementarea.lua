local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if Network:is_client() then
	return
end

core:module('CoreElementArea')

local table_insert = table.insert
local table_delete = table.delete
local table_icontains = table.icontains

ElementAreaTrigger.fs_is_inside = ElementAreaTrigger._is_inside_shape

function ElementAreaTrigger:is_inside_shape(pos)
	for _, shape in ipairs(self._shapes) do
		if shape:fs_is_inside(pos) then
			return true
		end
	end
	return false
end

function ElementAreaTrigger:fs_is_inside_shape_elements(pos)
	local use_disabled_shapes = self._values.use_disabled_shapes
	for _, element in ipairs(self._shape_elements) do
		if (use_disabled_shapes or element:enabled()) and element:is_inside_shape(pos) then
			return true
		end
	end
	return false
end

local function _is_never_inside()
	return false
end

function ElementAreaTrigger:rebuild_function_is_inside()
	if #self._shapes > 0 and #self._shape_elements > 0 then
		return self._is_inside_shape

	elseif #self._shapes > 0 then
		return self.is_inside_shape

	elseif #self._shape_elements > 0 then
		return self.fs_is_inside_shape_elements

	else
		return _is_never_inside
	end
end

function ElementAreaTrigger:_add_shape(shape)
	table_insert(self._shapes, shape)
	self.fs_is_inside = self:rebuild_function_is_inside()
end

local fs_original_elementareatrigger_onscriptactivated = ElementAreaTrigger.on_script_activated
function ElementAreaTrigger:on_script_activated()
	fs_original_elementareatrigger_onscriptactivated(self)
	self.fs_is_inside = self:rebuild_function_is_inside()
end

local tmp_vec1 = Vector3()
function ElementAreaTrigger:_should_trigger(unit)
	local values = self._values
	if unit and unit:alive() then
		local inside
		local u_mov = unit:movement()
		if u_mov then
			inside = self:fs_is_inside(u_mov:m_pos())
		else
			unit:m_position(tmp_vec1)
			inside = self:fs_is_inside(tmp_vec1)
		end

		local trigger_on = values.trigger_on
		local self_inside = self._inside
		local was_inside = self_inside[1] and table_icontains(self_inside, unit)
		local rule_ok = (inside or was_inside) and self:_check_instigator_rules(unit)
		if was_inside then
			if not inside or not rule_ok then
				table_delete(self_inside, unit)
				if trigger_on == 'on_exit' or trigger_on == 'both' then
					return true
				end
			end
		elseif inside and rule_ok then
			table_insert(self_inside, unit)
			if trigger_on == 'on_enter' or trigger_on == 'both' then
				return true
			end
		end

		if trigger_on == 'while_inside' and inside and rule_ok then
			return true
		end
	end

	if values.amount == 'all' then
		local project_amount_all = self:project_amount_all()
		if project_amount_all ~= self._last_project_amount_all then
			self._last_project_amount_all = project_amount_all
			self:_clean_destroyed_units()
			return true
		end
	end

	return false
end

function ElementAreaTrigger:instigators()
	local values = self._values
	if values.unit_ids then
		local instigators = {}
		local worlddefinition = self._mission_script:worlddefinition()
		for _, id in ipairs(values.unit_ids) do
			local unit = worlddefinition:get_unit_by_id(id)
			if alive(unit) then
				instigators[#instigators + 1] = unit
			end
		end
		return instigators
	end

	local pic = managers.mission.project_instigators_cache
	local cache_key = values.instigator
	local instigators = pic and pic[cache_key]
	if not instigators then
		instigators = self:project_instigators()
		if pic then
			pic[cache_key] = instigators
		end
	end

	local spawn_unit_elements = values.spawn_unit_elements
	if spawn_unit_elements and spawn_unit_elements[1] then
		-- the cached list is shared by all triggers of this instigator type, extend a copy
		local result = {}
		for i, unit in ipairs(instigators) do
			result[i] = unit
		end
		for _, id in ipairs(spawn_unit_elements) do
			local element = self:get_mission_element(id)
			if element then
				for _, unit in ipairs(element:units()) do
					result[#result + 1] = unit
				end
			end
		end
		instigators = result
	end

	return instigators
end

function ElementAreaTrigger:update_area()
	local values = self._values
	if not values.enabled then
		return
	end

	if values.trigger_on == 'on_empty' then
		self._inside = {}
		for _, unit in ipairs(self:instigators()) do
			self:_should_trigger(unit)
		end

		if self._inside[1] == nil then
			self:on_executed()
		end

	else
		local instigators = self:instigators()
		if instigators[1] == nil then
			if self:_should_trigger(nil) then
				self:_check_amount(nil)
			end
		else
			for _, unit in ipairs(instigators) do
				if self:_should_trigger(unit) then
					self:_check_amount(unit)
				end
			end
		end
	end
end

function ElementAreaReportTrigger:update_area()
	if not self._values.enabled then
		return
	end

	local instigators = self:instigators()
	if instigators[1] == nil then
		self:_check_state(nil)
	else
		for _, unit in ipairs(instigators) do
			if unit:alive() then
				self:_check_state(unit)
			end
		end
	end
end

function ElementAreaReportTrigger:_check_state(unit)
	self:_clean_destroyed_units()

	if unit and unit:alive() then
		local inside
		local u_mov = unit:movement()
		if u_mov then
			inside = self:fs_is_inside(u_mov:m_pos())
		else
			unit:m_position(tmp_vec1)
			inside = self:fs_is_inside(tmp_vec1)
		end

		local was_inside = self._inside[1] and table_icontains(self._inside, unit)
		if inside or was_inside then
			local rule_ok = self:_check_instigator_rules(unit)
			if inside and not rule_ok then
				self:_rule_failed(unit)
			end

			if was_inside then
				if not inside or not rule_ok then
					self:_remove_inside(unit)
				else
					self:_while_inside(unit)
				end
			elseif rule_ok then
				self:_add_inside(unit)
			end
		end
	end

	local project_amount_all = self:project_amount_all()
	if project_amount_all ~= self._last_project_amount_all then
		self._last_project_amount_all = project_amount_all
		self:_clean_destroyed_units()
		return true
	end

	return false
end

function ElementAreaReportTrigger:_clean_destroyed_units()
	local _inside = self._inside
	for i = #_inside, 1, -1 do
		local unit = _inside[i]
		if i > #_inside then
			-- qued, removed by a callback of a previous removal
		elseif not unit or not unit:alive() then
			self:_remove_inside_by_index(i)
		else
			local ucd = unit:character_damage()
			if ucd and ucd:dead() and not unit:vehicle_driving() then
				self:on_executed(unit, 'on_death')
				self:_remove_inside_by_index(i)
			end
		end
	end
end
