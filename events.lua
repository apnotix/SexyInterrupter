local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SexyInterrupter:GROUP_ROSTER_UPDATE()
	-- Reset everyone first, then re-establish the local player unconditionally
	-- (UpdateOwnInterrupter recomputes canInterrupt for real, including
	-- whether an interrupt spell is actually trained) - solo or grouped.
	-- Previously this only ran the reset/self-update inside the "grouped"
	-- branch, so a stale group-mate entry (or a stale canInterrupt=true for
	-- yourself, from before you'd trained an interrupt) never got cleared
	-- after leaving a group, and the bar/flash kept showing it forever.
	for cx, value in pairs(SI_Globals.interrupters) do
		value.active = false;
	end

	SexyInterrupter:UpdateOwnInterrupter();

	if IsInGroup() or IsInRaid() or IsPartyLFG() then
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
				
				local inRange = SexyInterrupter:UnitInRangeCompat(unit);

				if inRange ~= nil then
					interrupter.inrange = inRange;
				end
			end

			SexyInterrupter:SendMessage("requestuser", fullname);
		end

		SexyInterrupter:SendMessage("versioninfo", SexyInterrupter.Version);
	end

	SexyInterrupter:UpdateInterrupterSettings();

	-- Re-render immediately so leaving a group (or the local canInterrupt
	-- re-check above) takes effect on screen right away, instead of only on
	-- the next comm message or spell cast. UpdateUI()'s own numRows==0 check
	-- already hides the anchor correctly (editing mode is handled there too),
	-- so no separate manual Hide() is needed here.
	SexyInterrupter:UpdateUI();
	SexyInterrupter:UpdateInterrupterStatus();
end

local function GetSpellCooldownCompat(spellId)
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(spellId);

		if info then
			return info.startTime, info.duration;
		end

		return nil, nil;
	elseif GetSpellCooldown then
		return GetSpellCooldown(spellId);
	end

	return nil, nil;
end

-- Manual counterpart to COMBAT_LOG_EVENT_UNFILTERED (see RegisterEvents() in
-- core.lua): triggered via the "/si kick" slash command. Scans the player's
-- own known interrupt spells for one that's currently on cooldown
-- (GetSpellCooldown isn't combat-log-restricted) and broadcasts that as
-- "just used" to the group, the same way the old combat-log handler did.
function SexyInterrupter:MarkOwnInterrupt()
	if not SI_Globals or SI_Globals.numInterrupters == 0 then
		return;
	end

	local interrupter = SexyInterrupter:GetInterrupter(select(1, UnitName("player")));

	if not interrupter then
		return;
	end

	local foundSpellId, cooldownLeft;

	for _, spellId in pairs(self.interruptSpells) do
		local start, duration = GetSpellCooldownCompat(spellId);

		-- Ignore the ~1.5s global cooldown; only a real interrupt cooldown counts.
		if start and start > 0 and duration and duration > 2 then
			foundSpellId = spellId;
			cooldownLeft = duration;
			break;
		end
	end

	if not cooldownLeft then
		DEFAULT_CHAT_FRAME:AddMessage(L["Addon name"] .. ": " .. L["Could not detect an active interrupt cooldown."], 1, 0.5, 0);
		return;
	end

	interrupter.abilities = interrupter.abilities or {};
	interrupter.abilities[foundSpellId] = {
		cooldown = cooldownLeft,
		readyTime = GetTime() + cooldownLeft,
	};

	SexyInterrupter:UpdateInterrupterStatus();
	SexyInterrupter:SendInterrupt(interrupter.name, foundSpellId, cooldownLeft);
end

function SexyInterrupter:COMBAT_LOG_EVENT_UNFILTERED()
	local timestamp, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, extraArg1, extraArg2, extraArg3, extraArg4, extraArg5, extraArg6, extraArg7, extraArg8, extraArg9, extraArg10 = CombatLogGetCurrentEventInfo()

	local spellName = extraArg2;
    local spellId = extraArg1;
	local spells = self.interruptSpells;

	if SI_Globals.numInterrupters > 0 then
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
			if self.db.profile.notification.interruptmessage and (sourceGUID == UnitGUID('player') or sourceGUID == UnitGUID('pet')) then
				SexyInterrupter:ShowInterruptMessage(destName, extraArg4, extraArg5);
			end
		end
	end
end

function SexyInterrupter:PLAYER_SPECIALIZATION_CHANGED(...)
	local event, unitTarget, arg1, arg2, arg3, arg4 = ...;
	local name, realm = UnitName(unitTarget);
	local interrupter = SexyInterrupter:GetInterrupter(name, realm);

	if interrupter ~= nil then
		interrupter.role = SexyInterrupter:GetSpecializationRoleCompat();

		if interrupter.role == nil then        
			interrupter.role = UnitGroupRolesAssigned("player");
		end

		if interrupter.classEN and interrupter.role ~= 'NONE' then
			interrupter.canInterrupt = self.unitCanInterrupt[strlower(interrupter.classEN)][strlower(interrupter.role)];
		else
			interrupter.canInterrupt = true;
		end

		if unitTarget == 'player' and interrupter.canInterrupt then
			interrupter.canInterrupt = SexyInterrupter:PlayerKnowsAnyInterruptSpell();
		end

		if interrupter.role == 'HEALER' then
			interrupter.prio = 3;
		elseif interrupter.role == 'DAMAGER' then
			interrupter.prio = 2;
		elseif interrupter.role == 'TANK' then
			interrupter.prio = 1;
		end
	end	
end

function SexyInterrupter:PARTY_MEMBER_DISABLE(...)
	local event, unitTarget, arg1, arg2, arg3, arg4 = ...;
	local name, realm = UnitName(unitTarget);
	local interrupter = SexyInterrupter:GetInterrupter(name, realm);

	if interrupter ~= nil then
		interrupter.offline = true;
	end	
end

function SexyInterrupter:PARTY_MEMBER_ENABLE(...)
	local event, unitTarget, arg1, arg2, arg3, arg4 = ...;
	local name, realm = UnitName(unitTarget);
	local interrupter = SexyInterrupter:GetInterrupter(name, realm);

	if interrupter ~= nil then
		interrupter.offline = false;
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

		-- Was passing the wrong locals (startTime/endTime, always nil - never
		-- declared in this function) instead of the ones actually captured
		-- above, so ShowInterruptWarning's timeVisible-from-cast-length logic
		-- never triggered and silently always fell back to its 10s default.
		SexyInterrupter:ShowInterruptWarning(notInterruptible, startTimeMS, endTimeMS);
	end
end

function SexyInterrupter:UNIT_SPELLCAST_STOP(...)
	local event, unitTag, castGUID, spellID = ...;

    if unitTag == "target" and SexyInterrupterInterruptNowText:IsVisible() then
        SexyInterrupterInterruptNowText:SetTimeVisible(0);

		SexyInterrupterBlueWarningFrame:Hide();
	end
end

-- Automatic interrupt-cooldown detection, replacing the COMBAT_LOG_EVENT_UNFILTERED
-- handler above (which can't be registered right now). UNIT_SPELLCAST_SUCCEEDED
-- isn't part of the restricted combat-log event family, and fires for any unit
-- we're registered for (we register broadly, like the other UNIT_SPELLCAST_*
-- handlers, and filter by name below) with a plain numeric spellID in normal
-- group content. Mirrors the SPELL_CAST_SUCCESS branch of the old handler.
function SexyInterrupter:UNIT_SPELLCAST_SUCCEEDED(...)
	local event, unitTarget, castGUID, spellID = ...;

	-- spellID (and castGUID) can come through as a "secret" value - Blizzard's
	-- newer protected-info guard - for casts from units outside normal group
	-- content (e.g. nameplate/world units), not just rated PvP as originally
	-- assumed. A secret value can't even be passed into tContains(); there's
	-- no way to tell whether it's one of our interrupt spells, so just skip
	-- this cast instead of erroring.
	if not unitTarget or SI_Globals.numInterrupters == 0 then
		return;
	end

	if issecretvalue and issecretvalue(spellID) then
		return;
	end

	if not tContains(self.interruptSpells, spellID) then
		return;
	end

	local name, realm = UnitName(unitTarget);

	if not name then
		return;
	end

	-- UnitName()'s realm return ist NICHT zuverlässig leer für die eigenen
	-- Einträge - auf diesem Client (verbundene Realms?) liefert es für
	-- unitTarget="player" einen internen/abgekürzten Realm-Token (z. B. "Kuh"
	-- statt des echten Realmnamens), der weder mit dem in
	-- UpdateOwnInterrupter() über GetRealmName() gebauten "Name-Realm" noch
	-- mit dem dort gespeicherten bloßen "Name" übereinstimmt - die Suche
	-- schlug dadurch für den eigenen eben genutzten Interrupt IMMER fehl und
	-- SendInterrupt wurde nie aufgerufen. Erst den bloßen Namen probieren
	-- (passt zu value.name in GetInterrupter), dann - falls nötig - mit dem
	-- ECHTEN Realmnamen (GetRealmName(), nicht UnitName()s eigenem
	-- Realm-Rückgabewert) als Fallback.
	local interrupter = SexyInterrupter:GetInterrupter(name);

	if not interrupter and unitTarget == "player" then
		interrupter = SexyInterrupter:GetInterrupter(name .. '-' .. GetRealmName());
	end

	if not interrupter then
		return;
	end

	local cooldownLeft = GetSpellBaseCooldown(spellID) / 1000;

	-- Shadowpriest talent
	if spellID == 15487 and interrupter.talents ~= nil and strfind(interrupter.talents, '263716') then
		cooldownLeft = cooldownLeft - 15;
	end

	interrupter.abilities = interrupter.abilities or {};
	interrupter.abilities[spellID] = {
		cooldown = cooldownLeft,
		readyTime = GetTime() + cooldownLeft,
	};

	SexyInterrupter:UpdateInterrupterStatus();

	if UnitName("player") == interrupter.name then
		SexyInterrupter:SendInterrupt(interrupter.name, spellID, cooldownLeft);
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
	if self.db.profile.general.modeincombat and not SexyInterrupter:IsEditingUi() then
		SexyInterrupterAnchor:Hide();
	end
end