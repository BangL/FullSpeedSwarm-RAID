local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not FullSpeedSwarm.settings.optimized_inputs then
	return
end

core:module('CoreControllerManager')

function ControllerManager:update(t, dt)
	for _, controller in ipairs(self.__really_active) do
		controller:update(t, dt)
	end

	self:check_connect_change()
end
