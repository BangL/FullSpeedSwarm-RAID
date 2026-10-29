local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

-- options menu

FullSpeedSwarmMenu = FullSpeedSwarmMenu or class(BLTMenu)

function FullSpeedSwarmMenu:Init(root)
	self._something_changed = false
	self._forced = FullSpeedSwarm:get_gameplay_options_forced_values()

	self:Title({
		text = 'fs_options_menu_title',
	})
	self:Label({
		text = nil,
		localize = false,
		h = 8,
	})

	self:EnableScrolling()

	self:_MakeSeparator('fs_options_cat_performance')
	self:_MakeOptionSlider('task_throughput', 0, 3000)
	self:_MakeOptionMultiChoice('walking_quality', { 'a', 'b', 'c' })
	self:_MakeOptionMultiChoice('lod_updater', { 'a', 'b', 'c' })
	self:_MakeOptionToggle('optimized_inputs')
	self:_MakeOptionToggle('high_violence_mode')

	self:_MakeSeparator('fs_options_cat_gameplay')
	self:_MakeOptionToggle('improved_tactics')
	self:_MakeOptionToggle('iter_chase')
	self:_MakeOptionToggle('nervous_game')
	self:_MakeOptionToggle('cop_awareness')
	self:_MakeOptionToggle('fastpaced')
	self:_MakeOptionToggle('eyes_wide_open')
end

function FullSpeedSwarmMenu:_MakeSeparator(text)
	self:SubTitle({ text = text, localize = true, y_offset = 16 })
end

function FullSpeedSwarmMenu:_value(option)
	local forced = self._forced[option]
	if forced ~= nil then
		return forced
	end
	return FullSpeedSwarm.settings[option]
end

function FullSpeedSwarmMenu:_MakeOptionToggle(option)
	local id = 'fs_options_' .. option
	self:Toggle({
		name = id,
		text = id .. '_title',
		desc = id .. '_desc',
		value = self:_value(option),
		enabled = self._forced[option] == nil,
		callback = callback(self, self, 'OnOptionChanged', option),
		auto_select_on_hover = true,
	})
end

function FullSpeedSwarmMenu:_MakeOptionSlider(option, min, max)
	local id = 'fs_options_' .. option
	self:Slider({
		name = id,
		text = id .. '_title',
		desc = id .. '_desc',
		value = self:_value(option),
		min = min,
		max = max,
		value_format = '%.0f',
		enabled = self._forced[option] == nil,
		callback = callback(self, self, 'OnOptionChanged', option),
		auto_select_on_hover = true,
	})
end

function FullSpeedSwarmMenu:_MakeOptionMultiChoice(option, items)
	local id = 'fs_options_' .. option
	local params = {
		name = id,
		text = id .. '_title',
		desc = id .. '_desc',
		value = self:_value(option),
		enabled = self._forced[option] == nil,
		callback = callback(self, self, 'OnOptionChanged', option),
		items = {},
		auto_select_on_hover = true,
	}
	for i, suffix in ipairs(items) do
		table.insert(params.items, {
			text_id = id .. '_multi_' .. suffix,
			value = i,
		})
	end
	self:MultiChoice(params)
end

function FullSpeedSwarmMenu:OnOptionChanged(option, value)
	if self._forced[option] ~= nil then
		return
	end

	if type(value) == 'table' then
		value = value.value
	end
	if option == 'task_throughput' then
		value = math.floor(value)
	end

	if FullSpeedSwarm.settings[option] ~= value then
		FullSpeedSwarm.settings[option] = value
		self._something_changed = true

		if option == 'task_throughput' then
			FullSpeedSwarm:update_max_task_throughput()
		elseif option == 'walking_quality' then
			FullSpeedSwarm:update_walking_quality()
		end
	end
end

function FullSpeedSwarmMenu:Close()
	if self._something_changed then
		FullSpeedSwarm:save()
		FullSpeedSwarm:finalize_settings()
		FullSpeedSwarm:update_max_task_throughput()
	end
end

Hooks:Add('MenuComponentManagerInitialize', 'FullSpeedSwarm_MenuComponentManagerInitialize', function(self)
	RaidMenuHelper:CreateMenu({
		name = 'fs_options_menu',
		name_id = 'fs_options_menu_title',
		inject_list = 'blt_options',
		icon = 'waypoint_special_power',
		class = FullSpeedSwarmMenu,
	})
end)
