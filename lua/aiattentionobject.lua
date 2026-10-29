local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local REACT_MIN = AIAttentionObject.REACT_MIN
local REACT_MAX = AIAttentionObject.REACT_MAX

-- results of get_attention are cached per handler, the cache is dropped when the handler changes
-- or when team relations change (all caches at once, through the generation number)
local _gen = 0
function FullSpeedSwarm:invalidate_attention_caches()
	_gen = _gen + 1
end

local function _reset_cache(self)
	self.rel_cache = {}
	self.fs_rel_gen = _gen
end

for _, fname in ipairs({'init', 'add_attention', 'remove_attention', 'set_attention', 'override_attention', 'set_team', 'link', 'load'}) do
	local fs_original_func = AIAttentionObject[fname]
	if fs_original_func then
		AIAttentionObject[fname] = function(self, ...)
			local result = fs_original_func(self, ...)
			_reset_cache(self)
			return result
		end
	end
end

local fs_original_aiattentionobject_getattention = AIAttentionObject.get_attention
function AIAttentionObject:get_attention(filter, min, max, team)
	if self._attention_data and type(filter) == 'number' then
		local rel_cache = self.rel_cache
		if not rel_cache or self.fs_rel_gen ~= _gen then
			_reset_cache(self)
			rel_cache = self.rel_cache
		end

		local cache_key = (min or REACT_MIN) .. filter .. (max or REACT_MAX) .. (team and team.id or '')
		local result = rel_cache[cache_key]
		if result == nil then
			result = fs_original_aiattentionobject_getattention(self, filter, min, max, team)
			rel_cache[cache_key] = result or false
		end
		return result or nil
	end
	return fs_original_aiattentionobject_getattention(self, filter, min, max, team)
end
