local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

function PlayerManager:has_category_upgrade(category, upgrade)
	local upgs_ctg = self._global.upgrades[category]
	if upgs_ctg and upgs_ctg[upgrade] then
		return true
	end
	return false
end
