local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_coresoundenvironmentmanager_init = CoreSoundEnvironmentManager.init
function CoreSoundEnvironmentManager:init(...)
	self.fs_max_check_objects_id = 0
	fs_original_coresoundenvironmentmanager_init(self, ...)
end

local fs_original_coresoundenvironmentmanager_addcheckobject = CoreSoundEnvironmentManager.add_check_object
function CoreSoundEnvironmentManager:add_check_object(...)
	local id = fs_original_coresoundenvironmentmanager_addcheckobject(self, ...)
	if type(id) == 'number' and id > self.fs_max_check_objects_id then
		self.fs_max_check_objects_id = id
	end
	return id
end

function CoreSoundEnvironmentManager:update(t, dt)
	local nr = self.fs_max_check_objects_id
	local check_objects = self._check_objects
	for id = 1, nr do
		local data = check_objects[id]
		if data and data.active then
			self:_update_object(t, dt, id, data)
		end
	end
end
