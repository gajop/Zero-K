----------------------------------------------------------------------------------------------------------------------------------------------------------------function gadget:GetInfo()  return {    name      = "Boolean Disable",    desc      = "Handles disables which act in a boolean way (similar to engine default emp).",    author    = "Google Frog",    date      = "25th August 2013",    license   = "GNU GPL, v2 or later",    layer     = -1,    enabled   = true  --  loaded by default?  }end----------------------------------------------------------------------------------------------------------------------------------------------------------------if (not gadgetHandler:IsSyncedCode()) then  return false  --  no unsynced codeendlocal FRAMES_PER_SECOND = 30local DECAY_FRAMES = 1200 -- time in frames it takes to decay 100% para to 0 local disarmWeapons = {}local paraWeapons = {}for wid = 1, #WeaponDefs do	local wd = WeaponDefs[wid]	local wcp = wd.customParams or {}	if wcp.disarmdamagemult then		disarmWeapons[wid] = {			damageMult = wcp.disarmdamagemult,			normalDamage = 1 - (wcp.disarmdamageonly or 0),			disarmTimer = wcp.disarmtimer*FRAMES_PER_SECOND,		}	elseif wd.paralyzer then		paraWeapons[wid] = {			paraTime = wd.damages.paralyzeDamageTime*FRAMES_PER_SECOND,			maxParaDamage = (wd.damages.paralyzeDamageTime+40)/40,		}	endendlocal partialUnits = {}local paraUnits = {}-- structure of the above tables.-- table[frameID] = {count = x, data = {[1] = unitID, [2] = unitID, ... [x] = unitID}-- They hold the units in a frame that change state-- paraUnits are those that unparalyse on frame frameID-- partialUnits are those that lose all paralysis damage on frame frameID-- Elements are NOT REMOVED from table[frameID].data, only set to nil as the table does not need to be reused.local partialUnitID = {}local paraUnitID = {}-- table[unitID] = {frameID = x, index = y}-- stores current frame and index of unitID in their respective tables----------------------------------------------------------------------------------------------------------------------------------------------------------------local f = 0 -- frame, set in game framelocal function applyEffect(unitID)	Spring.SetUnitRulesParam(unitID, "disarmed", 1)	GG.attUnits[unitID] = true	GG.UpdateUnitAttributes(unitID)endlocal function removeEffect(unitID)	Spring.SetUnitRulesParam(unitID, "disarmed", 0)	GG.UpdateUnitAttributes(unitID)endlocal function addUnitID(unitID, byFrame, byUnitID, frame, extraParamFrames)	byFrame[frame] = byFrame[frame] or {count = 0, data = {}}	byFrame[frame].count = byFrame[frame].count + 1	byFrame[frame].data[byFrame[frame].count] = unitID	byUnitID[unitID] = {frameID = frame, index = byFrame[frame].count}	Spring.SetUnitRulesParam(unitID, "disarmframe", frame + extraParamFrames)endlocal function removeUnitID(unitID, byFrame, byUnitID)	byFrame[byUnitID[unitID].frameID].data[byUnitID[unitID].index] = nil	byUnitID[unitID] = nilend-- move a unit from one frame to anotherlocal function moveUnitID(unitID, byFrame, byUnitID, frame, extraParamFrames)	byFrame[byUnitID[unitID].frameID].data[byUnitID[unitID].index] = nil		byFrame[frame] = byFrame[frame] or {count = 0, data = {}}	byFrame[frame].count = byFrame[frame].count + 1	byFrame[frame].data[ byFrame[frame].count] = unitID	byUnitID[unitID] = {frameID = frame, index = byFrame[frame].count}		Spring.SetUnitRulesParam(unitID, "disarmframe", frame + extraParamFrames)endlocal function addParalysisDamageToUnit(unitID, damage, pTime)	local health,_,paralyzeDamage = Spring.GetUnitHealth(unitID)	local extraTime = math.floor(damage/health*DECAY_FRAMES) -- time that the damage would add	if partialUnitID[unitID] then -- if the unit is partially paralysed		local newPara = partialUnitID[unitID].frameID+extraTime		if newPara - f > DECAY_FRAMES then -- the new para damage exceeds 100%			removeUnitID(unitID, partialUnits, partialUnitID) -- remove from partial table			newPara = newPara - DECAY_FRAMES -- take away the para used to get 100%			if pTime and pTime < newPara - f then -- prevent weapon going over para timer				newPara = math.floor(pTime) + f			end			addUnitID(unitID, paraUnits, paraUnitID, newPara, DECAY_FRAMES)			applyEffect(unitID)		else			moveUnitID(unitID, partialUnits, partialUnitID, newPara, 0)		end	elseif paraUnitID[unitID] then -- the unit is fully paralysed, just add more damage		local newPara = paraUnitID[unitID].frameID		if (not pTime) or pTime > newPara - f then -- if the para time on the unit is less than this weapons para timer			newPara = newPara+extraTime			if pTime and pTime < newPara - f then -- prevent going over para time				newPara = math.floor(pTime) + f			end			moveUnitID(unitID, paraUnits, paraUnitID, newPara, DECAY_FRAMES)		end	else -- unit is not paralysed at all		--if paralyzeDamage > 0 then		--	damage = damage + paralyzeDamage		--	extraTime = math.floor(damage/health*DECAY_FRAMES)		--end		if extraTime > DECAY_FRAMES then -- if the new paralysis puts it over 100%			local newPara = extraTime + f			newPara = newPara - DECAY_FRAMES			if pTime and pTime < newPara - f then -- prevent going over para time				newPara = math.floor(pTime) + f			end			addUnitID(unitID, paraUnits, paraUnitID, newPara, DECAY_FRAMES)			applyEffect(unitID)		else			addUnitID(unitID, partialUnits, partialUnitID, extraTime+f, 0)		end	endendGG.addParalysisDamageToUnit = addParalysisDamageToUnitfunction gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,                             weaponDefID, attackerID, attackerDefID, attackerTeam)		if disarmWeapons[weaponDefID] then		local def = disarmWeapons[weaponDefID]		addParalysisDamageToUnit(unitID, damage*def.damageMult, def.disarmTimer)		return damage*def.normalDamage	end	--[[	if paraWeapons[weaponDefID] and (partialUnitID[unitID] or paraUnitID[unitID]) then		local health,maxHealth,paralyzeDamage = Spring.GetUnitHealth(unitID)		local remainingHealth = paraWeapons[weaponDefID].maxParaDamage*health - paralyzeDamage		if remainingHealth > 0 then			local realDamage = math.min(remainingHealth, damage)			Spring.Echo(realDamage)			addParalysisDamageToUnit(unitID, damage)		end	end	--]]	return damageendfunction gadget:GameFrame(n)	f = n	if paraUnits[n] then		for i = 1, paraUnits[n].count do			local unitID = paraUnits[n].data[i]			if unitID then				removeEffect(unitID)				paraUnitID[unitID] = nil				addUnitID(unitID, partialUnits, partialUnitID, DECAY_FRAMES+n, 0)			end		end		paraUnits[n] = nil	end		if partialUnits[n] then		for i = 1, partialUnits[n].count do			local unitID = partialUnits[n].data[i]			if unitID then				partialUnitID[unitID] = nil				Spring.SetUnitRulesParam(unitID, "disarmframe", -1)			end		end		partialUnits[n] = nil	endendfunction gadget:UnitDestroyed(unitID, unitDefID, unitTeam)	if partialUnitID[unitID] then		removeUnitID(unitID, partialUnits, partialUnitID)	end	if paraUnitID[unitID] then		removeUnitID(unitID, paraUnits, paraUnitID)	endend