local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings

-- Not ported: the assault tactics (RAID rewrote GroupAIStateBesiege:_set_assault_objective_to_group and has no tactics maps)

local fs_groupaistatebesiege_createobjectivefromgroupobjective = GroupAIStateBesiege._create_objective_from_group_objective
function GroupAIStateBesiege._create_objective_from_group_objective(grp_objective, ...)
	local objective = fs_groupaistatebesiege_createobjectivefromgroupobjective(grp_objective, ...)

	if objective and fs_settings.improved_tactics then
		objective.fs_patchable = false
		if grp_objective.type ~= 'assault_area' then
			-- qued
		elseif grp_objective.moving_in or grp_objective.charge then
			objective.stance = 'cbt'
		elseif objective.type == 'phalanx' then
			-- qued
		elseif objective.path_style ~= 'coarse_complete' then
			-- qued
		elseif objective.path_data and objective.path_data[2] then
			objective.fs_patchable = true
		else
			objective.path_data = nil
			objective.path_style = nil
			objective.fs_patchable = true
		end
	end

	return objective
end

local fs_original_groupaistatebesiege_setteamrelation = GroupAIStateBesiege.set_team_relation
function GroupAIStateBesiege:set_team_relation(...)
	fs_original_groupaistatebesiege_setteamrelation(self, ...)
	FullSpeedSwarm:invalidate_attention_caches()
end
