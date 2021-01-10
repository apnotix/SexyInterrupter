local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SexyInterrupter:GROUP_ROSTER_UPDATE()
	SexyInterrupter:UpdateInterrupters();
	SexyInterrupter:UpdateUI();
	SexyInterrupter:UpdateInterrupterStatus();

	SexyInterrupter:UpdateInterrupterSettings();
end

function SexyInterrupter:COMBAT_LOG_EVENT_UNFILTERED()
	local timestamp, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, extraArg1, extraArg2, extraArg3, extraArg4, extraArg5, extraArg6, extraArg7, extraArg8, extraArg9, extraArg10 = CombatLogGetCurrentEventInfo()

	local spellName = extraArg2;
    local spellId = extraArg1;
	local spells = self.interruptSpells;

	if event == "SPELL_CAST_SUCCESS" then
        if (tContains(spells, spellId)) then
			local cooldown = GetSpellBaseCooldown(spellId);
			local interrupter = SexyInterrupter:GetInterrupter(sourceName);

			if interrupter then
				local cooldownLeft = cooldown / 1000;
				
				-- Shadowpriest talent
				if spellId == 15487 and interrupter.talents ~= nil and strfind(interrupter.talents, '263716') then
					cooldownLeft = cooldownLeft - 15;
				end

				interrupter.cooldown = cooldownLeft;
				interrupter.readyTime = GetTime() + cooldownLeft;
				
				SexyInterrupter:UpdateInterrupterStatus();

				if UnitName("player") == interrupter.name then
					SexyInterrupter:SendInterrupt(interrupter.name, interrupter.cooldown);
				end

			end
        end
	elseif event == 'SPELL_INTERRUPT' then
		--print('SPELL_INTERRUPT', sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, extraArg1, extraArg2, extraArg3, extraArg4, extraArg5, extraArg6, extraArg7, extraArg8, extraArg9, extraArg10);

		if self.db.profile.notification.interruptmessage and (sourceGUID == UnitGUID('player') or sourceGUID == UnitGUID('pet')) then
			SexyInterrupter:ShowInterruptMessage(destName, extraArg4, extraArg5);
		end
	end
end

function SexyInterrupter:UPDATE_INSTANCE_INFO() 
	local name, type, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize = GetInstanceInfo();
	local isInstance, instanceType = IsInInstance();

	if isInstance then
		-- print('UPDATE_INSTANCE_INFO', name, type, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize);
		-- print('UPDATE_INSTANCE_INFO', isInstance, instanceType);
	end
end