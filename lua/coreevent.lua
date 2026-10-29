local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if core then
	core:module('CoreEvent')
end

local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove

-- remove() stays vanilla (cb.next = nil), Field Repairs' queue of MissionScript relies on it.
-- The sort key is kept apart in cb.fs_key, so removed entries don't break the binary search.

function CallbackHandler:update(dt)
	local tbl = self._sorted
	local t = self._t
	t = t + dt
	self._t = t
	while true do
		local cb = tbl[1]
		if cb == nil then
			return
		elseif cb.next == nil then
			table_remove(tbl, 1)
		elseif t < cb.fs_key then
			return
		else
			table_remove(tbl, 1)
			cb.f(cb, t)

			local times = cb.times
			if times >= 0 then
				times = times - 1
				cb.times = times
				if times <= 0 then
					cb.next = nil
				end
			end

			if cb.next then
				cb.next = cb.next + cb.interval
				self:__insert_sorted(cb)
			end
		end
	end
end

-- ref http://lua-users.org/wiki/BinaryInsert
function CallbackHandler:__insert_sorted(cb)
	local new_val = cb.next
	cb.fs_key = new_val
	local tbl = self._sorted
	local i_start, i_end, i_mid, i_state = 1, #tbl, 1, 0

	while i_start <= i_end do
		i_mid = math_floor((i_start + i_end) * 0.5)
		local mid_val = tbl[i_mid].fs_key
		if new_val <= mid_val then
			i_end, i_state = i_mid - 1, 0
		else
			i_start, i_state = i_mid + 1, 1
		end
	end
	table_insert(tbl, i_mid + i_state, cb)
end
