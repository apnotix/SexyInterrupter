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

function SexyInterrupter:UNIT_SPELLCAST_CHANNEL_START(...) 
	local event, unitTag, castGUID, spellID = ...;

	if (unitTag == "target" and SI_Globals.numInterrupters > 0) then
		local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo("target");

		SexyInterrupter:ShowInterruptWarning(notInterruptible, startTime, endTime);
	end
end

function SexyInterrupter:UNIT_SPELLCAST_START(...)
	local event, unitTag, castGUID, spellID = ...;

	if (unitTag == "target" and SI_Globals.numInterrupters > 0) then
		local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId = UnitCastingInfo("target");

		SexyInterrupter:ShowInterruptWarning(notInterruptible, startTime, endTime);
	end
end

function SexyInterrupter:UNIT_SPELLCAST_STOP(...)
	local event, unitTag, castGUID, spellID = ...;

    if unitTag == "target" and SexyInterrupterInterruptNowText:IsVisible() then
        SexyInterrupterInterruptNowText:SetTimeVisible(0);

		SexyInterrupterBlueWarningFrame:Hide();
	end
end

function SexyInterrupter:PLAYER_TARGET_CHANGED()
	local targetName = UnitName("target");
	
	if targetName then
		--local encounterId = self:GetEntcounterId(targetName);
		
		--print('PLAYER_TARGET_CHANGED', encounterId);
	end

    if SexyInterrupterInterruptNowText:IsVisible() then
        SexyInterrupterInterruptNowText:SetTimeVisible(0);
		
		SexyInterrupterBlueWarningFrame:Hide();
    end
end

function SexyInterrupter:PLAYER_REGEN_DISABLED() 
	if self.db.profile.general.modeincombat then
		SexyInterrupterAnchor:Show();
	end
end

function SexyInterrupter:PLAYER_REGEN_ENABLED() 
	if self.db.profile.general.modeincombat then
		SexyInterrupterAnchor:Hide();
	end
end

function SexyInterrupter:CHAT_MSG_ADDON(event, prefix, msg, channel, sender)
    if prefix == "SexyInterrupter" and not strfind(sender, select(1, UnitName("player"))) then
        SexyInterrupter:AddonMessageReceived(msg, sender)
    end
end

function SexyInterrupter:OnUpdate()
	local currentplayer = SexyInterrupter:GetInterrupter(select(1, UnitName("player")));

	for cx, value in pairs(SexyInterrupter:GetCurrentInterrupters()) do
		if currentplayer and currentplayer.sortpos > SexyInterrupter.db.profile.general.maxrows and SexyInterrupter.db.profile.general.maxrows == cx then
			value = currentplayer;
		end

        if value.readyTime > 0 then
			local bar = _G["SexyInterrupterStatusBar" .. cx];

			if bar then			
				if (value.readyTime - GetTime() <= 0) then
					bar.cooldownText:SetText('');
					value.readyTime = 0;
					
					bar:SetMinMaxValues(0, 100);
					bar:SetValue(100);
					return;
				end

				local cooldownText = value.readyTime - GetTime();

				bar:SetValue(cooldownText);
				bar.cooldownText:SetText(string.format('%.1f', cooldownText));
			end
		end
	end
end