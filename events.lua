local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SexyInterrupter:GROUP_ROSTER_UPDATE()
    for i = 1, GetNumGroupMembers() do
		local unit = "party" .. i;

		if IsInRaid() then
			unit = "raid" .. i;
		end
		
		if not UnitExists(unit) then	
			unit = 'player';
		end
		
		local name, realm = UnitName(unit);
		local fullname = name;

		if realm ~= "" and realm ~= nil then 
			fullname = name .. '-' .. realm;
        end

        local interrupter = SexyInterrupter:GetInterrupter(fullname);

        if interrupter ~= nil then
            if not UnitIsConnected(unit) then
                interrupter.offline = true;
            else 
                interrupter.offline = false;
            end
            
            if UnitIsAFK(unit) then
                interrupter.afk = true;
            else
                interrupter.afk = false;
            end
            
            if UnitIsDeadOrGhost(unit) then
                interrupter.dead = true;
            else
                interrupter.dead = false;
            end
            
            if UnitInRange(unit) then
                interrupter.inrange = true;
            else
                interrupter.inrange = false;
            end
        end

        SexyInterrupter:SendMessage("requestuser", fullname);
    end

    SexyInterrupter:SendMessage("versioninfo", SexyInterrupter.Version);
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

function SexyInterrupter:UNIT_SPELLCAST_CHANNEL_START(...) 
	local event, unitTag, castGUID, spellID = ...;

	if unitTag == "target" and SI_Globals.numInterrupters > 0 then
		local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo("target");

		SexyInterrupter:ShowInterruptWarning(notInterruptible, startTime, endTime);
	end
end

function SexyInterrupter:UNIT_SPELLCAST_START(...)
	local event, unitTag, castGUID, spellID = ...;

	if unitTag == "target" and SI_Globals.numInterrupters > 0 then
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