local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

function EventListenerHolder:init(unit)
	if type(unit) == 'userdata' and tostring(unit):match('^%[Unit ') then
		unit:set_extension_update_enabled(Idstring('event_listener'), false)
	end
end

function EventListenerHolder:_add(key, event_types, clbk)
	if not clbk then
		return
	end

	if self._listener_keys and self._listener_keys[key] then
		return
	end

	local listeners = self._listeners
	if not listeners then
		self._listeners = {}
		self._listener_keys = {}
		listeners = self._listeners
	end

	for _, event in pairs(event_types) do
		local i
		local event_listeners = listeners[event]
		if not event_listeners then
			event_listeners = { {}, {} }
			listeners[event] = event_listeners
			i = 1
		else
			i = table.icontains(event_listeners[1], key) or #event_listeners[1] + 1
		end
		event_listeners[1][i] = key
		event_listeners[2][i] = clbk
	end

	self._listener_keys[key] = event_types
end

function EventListenerHolder:_append_new_additions()
	if self._additions then
		local listeners = self._listeners
		if not listeners then
			self._listeners = {}
			self._listener_keys = {}
			listeners = self._listeners
		end

		for key, new_entry in pairs(self._additions) do
			if new_entry[1] then
				for _, event in ipairs(new_entry[2]) do
					local i
					local event_listeners = listeners[event]
					if not event_listeners then
						event_listeners = { {}, {} }
						listeners[event] = event_listeners
						i = 1
					else
						i = table.icontains(event_listeners[1], key) or #event_listeners[1] + 1
					end
					event_listeners[1][i] = key
					event_listeners[2][i] = new_entry[1]
				end
				self._listener_keys[key] = new_entry[2]
			end
		end

		self._additions = nil
	end
end

function EventListenerHolder:call(event, ...)
	if self._listeners then
		local event_listeners = self._listeners[event]
		if event_listeners then
			local was_calling = self._calling
			self._calling = true

			-- snapshot: nested calls may dispose trash and shift the arrays
			local keys = {}
			local clbks = {}
			for i, key in ipairs(event_listeners[1]) do
				keys[i] = key
				clbks[i] = event_listeners[2][i]
			end
			for i = 1, #keys do
				local clbk = clbks[i]
				if clbk and self:_not_trash(keys[i]) then
					clbk(...)
				end
			end

			if not was_calling then
				self._calling = nil

				self:_append_new_additions()
				self:_dispose_trash()
			end
		end
	end
end

function EventListenerHolder:_remove(key)
	if not self._listener_keys then
		return
	end

	local listeners_keys = self._listener_keys[key]
	if listeners_keys then
		local listeners = self._listeners
		for _, event in pairs(listeners_keys) do
			local event_listeners = listeners[event]
			local i = table.icontains(event_listeners[1], key)
			if i then
				table.remove(event_listeners[1], i)
				table.remove(event_listeners[2], i)
				if not event_listeners[1][1] then
					listeners[event] = nil
				end
			end
		end

		if next(listeners) then
			self._listener_keys[key] = nil
		else
			self._listeners = nil
			self._listener_keys = nil
		end
	end
end
