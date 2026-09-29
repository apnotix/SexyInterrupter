local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

local lastVersionBroadcast;
local rosterRetryPending = false;
local rosterRetryCount = 0;
local isRosterRetry = false;
local MAX_ROSTER_RETRIES = 5;

-- GetSpellBaseCooldown can return nil (unknown spell / client without the
-- data) or 0; returns the base cooldown in seconds or nil.
local function GetBaseCooldownSeconds(spellId)
	local cooldownMs = GetSpellBaseCooldown and GetSpellBaseCooldown(spellId);

	if not cooldownMs or cooldownMs <= 0 then
		return nil;
	end

	return cooldownMs / 1000;
end

function SexyInterrupter:GROUP_ROSTER_UPDATE()
	-- Reset everyone first, then re-establish the local player unconditionally
	-- (UpdateOwnInterrupter recomputes canInterrupt for real, including
	-- whether an interrupt spell is actually trained) - solo or grouped.
	-- Previously this only ran the reset/self-update inside the "grouped"
	-- branch, so a stale group-mate entry (or a stale canInterrupt=true for
	-- yourself, from before you'd trained an interrupt) never got cleared
	-- after leaving a group, and the bar/flash kept showing it forever.
	--
	-- Entries are NOT blanket-deactivated up front anymore: that made every
	-- group-mate's bar depend on the name lookup below succeeding again in
	-- this very pass, and it fails whenever a unit's name isn't loaded yet
	-- (loading screens, zone changes) or the realm spelling differs - the
	-- bar then vanished until some later event. Instead, entries are only
	-- deactivated at the end, and only if they are provably not in the group.
	local present = {};
	local unresolved = false;

	-- A real game event (not our own retry timer) starts a fresh retry budget.
	if not isRosterRetry then
		rosterRetryCount = 0;
	end

	isRosterRetry = false;

	SexyInterrupter:UpdateOwnInterrupter();

	present[SexyInterrupter:GetInterrupter(select(1, UnitName("player")) .. '-' .. GetRealmName())] = true;

	if IsInGroup() or IsInRaid() or IsPartyLFG() then
		for i = 1, GetNumGroupMembers() do
			local unit = "party" .. i;

			if IsInRaid() then
				unit = "raid" .. i;
			end
			
			if not UnitExists(unit) then
				-- In a party (not raid) the last slot is the local player, which has
				-- no partyN token. Any OTHER missing token is a member whose unit
				-- isn't loaded yet - can't conclude anything about them.
				if IsInRaid() or i ~= GetNumGroupMembers() then
					unresolved = true;
				end

				unit = 'player';
			end

			local interrupter, nameKnown, name, realm = SexyInterrupter:GetInterrupterByUnit(unit);
			local fullname = name;

			if not nameKnown then
				-- Name not loaded yet: we can't tell who this slot is, so we must
				-- not conclude that anybody has left.
				unresolved = true;
			elseif realm ~= "" and realm ~= nil then
				fullname = name .. '-' .. realm;
			end

			if interrupter ~= nil then
				present[interrupter] = true;

				-- Sofort wieder aktiv setzen: der Spieler ist laut aktueller
				-- Gruppen-Iteration JETZT nachweislich noch in der Gruppe, es
				-- muss nicht auf die asynchrone 'requestuser'-Comm-Antwort
				-- unten gewartet werden. Ohne dies blieb active=false (vom
				-- Reset oben) bis die Antwort eintrifft - sichtbar als kurzes
				-- Verschwinden/Neu-Rendern aller Mitspieler-Balken bei JEDEM
				-- GROUP_ROSTER_UPDATE, u.a. bei jedem Gebietswechsel/Ladebild-
				-- schirm (PLAYER_ENTERING_WORLD loest denselben Handler aus).
				interrupter.active = true;

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

			-- Only ask for the user info of members we don't know yet (and never
			-- for ourselves): a request per member on EVERY roster update, each
			-- answered by a full 'userinfos' broadcast, meant O(n^2) addon traffic
			-- in raids (and on every zone change).
			if nameKnown and unit ~= 'player' and (interrupter == nil or interrupter.talents == nil) then
				SexyInterrupter:SendMessage("requestuser", fullname);
			end
		end

		-- Version info is only worth broadcasting occasionally.
		local now = GetTime();

		if not lastVersionBroadcast or now - lastVersionBroadcast > 30 then
			lastVersionBroadcast = now;
			SexyInterrupter:SendMessage("versioninfo", SexyInterrupter.Version);
		end
	end

	if unresolved and rosterRetryCount < MAX_ROSTER_RETRIES then
		-- Some slot's name wasn't available: keep everybody as they are and
		-- look again shortly instead of guessing (a bounded number of times -
		-- a slot that never resolves must not keep us polling forever or block
		-- removing members who really left).
		if not rosterRetryPending then
			rosterRetryPending = true;

			C_Timer.After(1.5, function()
				rosterRetryPending = false;
				rosterRetryCount = rosterRetryCount + 1;
				isRosterRetry = true;
				SexyInterrupter:GROUP_ROSTER_UPDATE();
			end);
		end
	else
		for _, value in pairs(SI_Globals.interrupters) do
			if not present[value] then
				value.active = false;
			end
		end
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

	local foundSpellId, cooldownLeft, foundDuration;

	for _, spellId in ipairs(self.interruptSpells) do
		local start, duration = GetSpellCooldownCompat(spellId);

		-- Ignore the ~1.5s global cooldown; only a real interrupt cooldown counts.
		if start and start > 0 and duration and duration > 2 then
			-- Remaining time, not the full duration - otherwise running this
			-- some seconds after the kick overstates the cooldown everywhere.
			local remaining = start + duration - GetTime();

			if remaining > 0 then
				foundSpellId = spellId;
				cooldownLeft = remaining;
				foundDuration = duration;
				break;
			end
		end
	end

	if not cooldownLeft then
		DEFAULT_CHAT_FRAME:AddMessage(L["Addon name"] .. ": " .. L["Could not detect an active interrupt cooldown."], 1, 0.5, 0);
		return;
	end

	interrupter.abilities = interrupter.abilities or {};
	interrupter.abilities[foundSpellId] = {
		cooldown = foundDuration,
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
			if self.interruptSpellSet[spellId] then
				local cooldown = GetBaseCooldownSeconds(spellId);
				local interrupter = SexyInterrupter:GetInterrupter(sourceName);

				if interrupter and cooldown then
					local cooldownLeft = cooldown;
					
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
		-- GetSpecializationRoleCompat() fragt (wie ihr Name andeutet, aber wie
		-- es hier vorher NICHT beachtet wurde) immer den EIGENEN Charakter ab,
		-- unabhaengig von unitTarget - fuer den eigenen unitTarget also korrekt,
		-- fuer JEDEN anderen aber falsch (dessen Rolle wurde faelschlich mit der
		-- eigenen ueberschrieben). Nur fuer unitTarget=='player' verwenden, sonst
		-- direkt UnitGroupRolesAssigned(unitTarget) - vorher stand hier ebenfalls
		-- hart "player" statt unitTarget, derselbe Bug ein zweites Mal.
		if unitTarget == 'player' then
			interrupter.role = SexyInterrupter:GetSpecializationRoleCompat();
		else
			interrupter.role = nil;
		end

		if interrupter.role == nil then
			interrupter.role = UnitGroupRolesAssigned(unitTarget);
		end

		if interrupter.classEN and interrupter.role ~= 'NONE' then
			interrupter.canInterrupt = SexyInterrupter:CanClassRoleInterrupt(interrupter.classEN, interrupter.role);
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

		-- Eigene Rollenaenderung an die Gruppe broadcasten - sonst erfahren
		-- Mitspieler davon erst beim naechsten vollstaendigen Roster-Sync
		-- (Gruppe verlassen/beitreten, Gebietswechsel). SendUserInformation()
		-- erwartet einen exakt passenden "target"-Namen (intern per erneutem,
		-- eigenem UnitName("player")-Abgleich) - hier reicht es, direkt dieselbe
		-- 'userinfos'-Nachricht zu bauen und ohne den Zielabgleich zu senden,
		-- da wir bereits wissen dass es um uns selbst geht.
		if unitTarget == 'player' then
			local infos = { class = interrupter.class, classEN = interrupter.classEN, role = interrupter.role, talents = '' };
			SexyInterrupter:SendMessage('userinfos', infos);
		end

		-- Und lokal sofort neu rendern (Sortierung nach Prio haengt von der
		-- Rolle ab).
		SexyInterrupter:UpdateUI();
		SexyInterrupter:UpdateInterrupterStatus();
	end
end

function SexyInterrupter:PARTY_MEMBER_DISABLE(...)
	local event, unitTarget, arg1, arg2, arg3, arg4 = ...;
	local name, realm = UnitName(unitTarget);
	local interrupter = SexyInterrupter:GetInterrupter(name, realm);

	if interrupter ~= nil then
		-- PARTY_MEMBER_DISABLE also fires for members that are merely far away
		-- / in another phase - only treat them as offline if they really are.
		interrupter.offline = not UnitIsConnected(unitTarget);
	end	
end

function SexyInterrupter:PARTY_MEMBER_ENABLE(...)
	local event, unitTarget, arg1, arg2, arg3, arg4 = ...;
	local name, realm = UnitName(unitTarget);
	local interrupter = SexyInterrupter:GetInterrupter(name, realm);

	if interrupter ~= nil then
		interrupter.offline = not UnitIsConnected(unitTarget);
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

	if not self.interruptSpellSet[spellID] then
		return;
	end

	-- We register for every unit; only group members' own unit tokens count.
	-- Otherwise an enemy/NPC with the same name as a group member (via
	-- nameplateN/target/focus) would start and broadcast that member's
	-- cooldown, and a member who is also our target/focus fires twice.
	if unitTarget ~= "player" then
		if not (unitTarget:match("^party%d+$") or unitTarget:match("^raid%d+$")) or UnitIsUnit(unitTarget, "player") then
			return;
		end
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

	local cooldownLeft = GetBaseCooldownSeconds(spellID);

	if not cooldownLeft then
		return;
	end

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
