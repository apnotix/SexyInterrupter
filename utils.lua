local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

SexyInterrupter.role_icon_tcoords = {
	DAMAGER = {0.3125, 0.63, 0.3125, 0.63},
	HEALER  = {0.3125, 0.63, 0.015625, 0.3125},
	TANK    = {0, 0.296875, 0.3125, 0.63},
	LEADER  = {0, 0.296875, 0.015625, 0.3125},
	NONE    = ""
};

function SexyInterrupter:AddIcon()
	local dataobj = LibStub("LibDataBroker-1.1"):NewDataObject("SexyInterrupter", {
		label = "SexyInterrupter",
		type = "launcher",
		icon = "Interface\\Icons\\achievement_bg_defendxtowers_av",
		text = "SexyInterrupter",
		OnClick = function(self,btn)
		   if btn == "RightButton" then
			   LibStub("AceConfigDialog-3.0"):Open("SexyInterrupter");
		   else
			   SexyInterrupter:LockFrame();
		   end
	   end,
	   OnTooltipShow = function(self)
		   if not self or not self.AddLine then return end
		   self:AddLine("SexyInterrupter");
		   self:AddLine(L["Left click to toggle Frame"],1,1,1);
		   self:AddLine(L["Right click to open settings"],1,1,1);
	   end
   })

   self.icon:Register("SexyInterrupter", dataobj, self.db.profile.icon);
end

-- GetSpecializationRole/GetSpecialization/GetSpecializationRoleByID/
-- GetInspectSpecialization are Retail-only (the single-specialization
-- system). World of Warcraft: Forever's beta client is built on the Classic
-- client line (talents are still read via the old per-point GetTalentInfo
-- below), where these globals don't exist at all - calling a nil global
-- throws immediately, so the pre-existing "if not interrupter.role then
-- fall back to UnitGroupRolesAssigned" never even got a chance to run.
-- Guard the calls so that fallback actually triggers instead of erroring.
function SexyInterrupter:GetSpecializationRoleCompat()
	if GetSpecializationRole and GetSpecialization then
		return GetSpecializationRole(GetSpecialization());
	end

	return nil;
end

function SexyInterrupter:GetSpecializationRoleByIDCompat(fullname)
	if GetSpecializationRoleByID and GetInspectSpecialization then
		return GetSpecializationRoleByID(GetInspectSpecialization(fullname));
	end

	return nil;
end

-- UnitInRange(unit) can return a "secret" boolean (Blizzard's newer combat/
-- protected-info guard, same family as the spellId secrecy noted for
-- UNIT_SPELLCAST_SUCCEEDED in events.lua) that addon code is not allowed to
-- branch on directly - doing so throws "attempt to perform boolean test on a
-- secret boolean value". issecretvalue() is the sanctioned way to detect
-- that case without tainting/erroring. Returns nil (meaning "unknown, leave
-- the previous inrange state alone") instead of a real boolean when secret.
function SexyInterrupter:UnitInRangeCompat(unit)
	local inRange = UnitInRange(unit);

	if issecretvalue and issecretvalue(inRange) then
		return nil;
	end

	return inRange and true or false;
end

-- True if the player actually has at least one of SI.interruptSpells
-- trained (IsSpellKnown), regardless of what the static class+role table in
-- settings.lua guesses is possible for their class/role.
function SexyInterrupter:PlayerKnowsAnyInterruptSpell()
	if not IsSpellKnown then
		return true;
	end

	for _, spellId in pairs(self.interruptSpells) do
		if IsSpellKnown(spellId) then
			return true;
		end
	end

	return false;
end

-- Static "could this class+role ever interrupt" guess. Tolerates unknown
-- classes / missing roles (e.g. a malformed or older-version comm message)
-- instead of indexing nil.
function SexyInterrupter:CanClassRoleInterrupt(classEN, role)
	if not classEN or not role or role == 'NONE' then
		return true;
	end

	local roles = self.unitCanInterrupt[strlower(classEN)];

	if not roles then
		return true;
	end

	return roles[strlower(role)] and true or false;
end

-- notification.soundFile holds either a LibSharedMedia sound NAME (what the
-- picker stores) or a raw file path (the default). PlaySoundFile only
-- understands paths, so resolve names first.
local DEFAULT_SOUND_PATH = "Sound\\Spells\\PVPFlagTaken.ogg";

function SexyInterrupter:ResolveSoundPath(value)
	if not value then
		return DEFAULT_SOUND_PATH;
	end

	return LSM:Fetch("sound", value, true) or value;
end

function SexyInterrupter:GetInterrupter(name, realm)
	local retVal = nil;

	if realm then
		name = name .. '-' .. realm;
	end

	for cx, value in pairs(SI_Globals.interrupters) do
		if value.fullname == name or value.name == name then
			retVal = value;
			break;
		end
	end

	return retVal;
end

-- Resolves the roster entry for a unit token. Entries are keyed by whatever
-- the sender's client called its realm (GetRealmName(), with spaces), while
-- UnitName() on our side returns a normalized realm - so the exact
-- "Name-Realm" lookup can miss for cross-realm players even though the bare
-- name matches. Try the full name first, then fall back to the bare name.
-- Returns (entry|nil, nameKnown, name, realm); nameKnown is false while the
-- unit's name isn't loaded yet.
function SexyInterrupter:GetInterrupterByUnit(unit)
	local name, realm = UnitName(unit);

	if not name or name == UNKNOWNOBJECT then
		return nil, false;
	end

	local interrupter;

	if realm and realm ~= "" then
		interrupter = SexyInterrupter:GetInterrupter(name .. '-' .. realm);
	end

	return interrupter or SexyInterrupter:GetInterrupter(name), true, name, realm;
end

-- Creates/refreshes the local player's own SI_Globals.interrupters entry
-- directly, independent of comm (SendUserInformation/ReceiveUserInformation
-- in communication.lua only run inside a group - a solo player never sends
-- or receives anything there, see SendMessage's channel check) and
-- independent of UpdateInterrupters() (dead code - not called by any loaded
-- file since the events.lua rewrite, see communication.lua's
-- ReceiveUserInformation for the actual live equivalent for OTHER players).
-- Without this, a stale entry from an earlier group session (active=true,
-- canInterrupt=true from before the player ever had an interrupt trained)
-- would keep showing in the bar and triggering the interrupt-now flash/
-- message forever, since nothing ever re-evaluated it once solo.
function SexyInterrupter:UpdateOwnInterrupter()
	local name, realm = UnitName("player");

	-- Always suffix with GetRealmName(), matching exactly what
	-- ReceiveUserInformation's fullname ends up as (it deserializes
	-- GetRealmName() from the comm payload, see SendMessage - never nil).
	-- UnitName("player")'s own realm return is nil/empty for same-realm
	-- units, so using it here (as this used to) produces a DIFFERENT key
	-- ("Name" vs "Name-RealmName") for the exact same character, which
	-- created a second, wrongly-keyed duplicate entry the moment any
	-- 'userinfos' comm message about yourself was processed.
	local fullname = name .. '-' .. GetRealmName();

	local interrupter = SexyInterrupter:GetInterrupter(fullname);

	if interrupter == nil then
		interrupter = {
			name = name,
			realm = GetRealmName(),
			fullname = fullname,
			cooldown = 0,
			readyTime = 0,
			overrideprio = false,
		};

		tinsert(SI_Globals.interrupters, interrupter);
	end

	local class, englishClass = UnitClass("player");

	interrupter.class = class;
	interrupter.classEN = englishClass;
	interrupter.classColor = RAID_CLASS_COLORS[englishClass];
	interrupter.lastseen = time();
	interrupter.active = true;
	interrupter.role = SexyInterrupter:GetSpecializationRoleCompat();

	if not interrupter.role then
		interrupter.role = UnitGroupRolesAssigned("player");
	end

	if interrupter.classEN and interrupter.role ~= 'NONE' then
		interrupter.canInterrupt = SexyInterrupter:CanClassRoleInterrupt(interrupter.classEN, interrupter.role);
	else
		interrupter.canInterrupt = true;
	end

	if interrupter.canInterrupt then
		interrupter.canInterrupt = SexyInterrupter:PlayerKnowsAnyInterruptSpell();
	end

	if interrupter.overrideprio == nil then
		interrupter.overrideprio = false;
	end

	if interrupter.role == 'HEALER' then
		interrupter.prio = 3;
	elseif interrupter.role == 'DAMAGER' then
		interrupter.prio = 2;
	elseif interrupter.role == 'TANK' then
		interrupter.prio = 1;
	end

	interrupter.offline = false;
	interrupter.afk = UnitIsAFK("player") and true or false;
	interrupter.dead = UnitIsDeadOrGhost("player") and true or false;
	interrupter.inrange = true;
end

function SexyInterrupter:GetEntcounterId(targetName)
	local instanceID = EJ_GetCurrentInstance();

	if targetName then 
		for i=1, 25 do
			local name, _, encounterID = EJ_GetEncounterInfoByIndex(i, instanceID)

			if name == targetName then
				return encounterID;
			end
		end
	end

	return 0;
end

-- Returns one row per (player, known interrupt ability) pair - a player with
-- several dynamically-learned interrupt abilities (see UNIT_SPELLCAST_SUCCEEDED
-- in events.lua) gets one row per ability, each with its own icon/cooldown.
-- Players with no ability learned yet still get a single placeholder row so
-- they don't disappear from the rotation before their first known kick.
function SexyInterrupter:GetCurrentInterrupters()
	local rows = {};

	-- Solo gibt es nur den eigenen Eintrag. Alte Gruppenmitglieder aus den
	-- gespeicherten Daten (oder verspätet eingetroffene 'userinfos') dürfen
	-- sonst weiter Zeilen belegen und den Frame aufblähen.
	local solo = not IsInGroup() and not IsInRaid() and not IsPartyLFG();
	local ownFullname = UnitName("player") .. '-' .. GetRealmName();

	local soloDisabled = solo and not self.db.profile.general.activeSolo;

	for cx, interrupter in pairs(SI_Globals.interrupters) do
		interrupter.pos = cx;
		interrupter.sortpos = nil;

		if solo and interrupter.fullname ~= ownFullname then
			interrupter.active = false;
		end

		-- Solo deaktiviert: keine Zeilen -> numInterrupters = 0, wodurch
		-- Anzeige, Warnung, Flash und Sound (alle hängen daran) ruhen.
		if interrupter.active and interrupter.canInterrupt and not soloDisabled then
			local hasAbilities = false;

			if interrupter.abilities then
				for spellId, ability in pairs(interrupter.abilities) do
					hasAbilities = true;

					-- Normalize an expired cooldown to 0 so it sorts as "ready"
					-- (the UI only zeroes its transient row copy).
					if ability.readyTime and ability.readyTime > 0 and ability.readyTime <= GetTime() then
						ability.readyTime = 0;
					end

					tinsert(rows, {
						interrupter = interrupter,
						spellId = spellId,
						cooldown = ability.cooldown,
						readyTime = ability.readyTime,
					});
				end
			end

			if not hasAbilities then
				tinsert(rows, {
					interrupter = interrupter,
					spellId = nil,
					cooldown = interrupter.cooldown or 0,
					readyTime = interrupter.readyTime or 0,
				});
			end
		end
	end

	table.sort(rows, function(a, b)
		local ia, ib = a.interrupter, b.interrupter;
		local retVal = false;

		if ia.offline then
			retVal = false;
		else
			if ib.offline then
				retVal = true;
			else
				if not ia.inrange then
					retVal = false;
				else
					if not ib.inrange then
						retVal = true;
					else
						if ia.dead then
							retVal = false
						else
							if ib.dead then
								retVal = true;
							else
								if a.readyTime > 0 then
									if a.readyTime == b.readyTime then
										retVal = (ia.overridedprio or ia.prio) < (ib.overridedprio or ib.prio);
									else
										retVal = a.readyTime < b.readyTime;
									end
								else
									if b.readyTime > 0 then
										retVal = true;
									else
										retVal = (ia.overridedprio or ia.prio) < (ib.overridedprio or ib.prio);
									end
								end
							end
						end
					end
				end
			end
		end

		return retVal;
	end)

	for cx, row in pairs(rows) do
		row.sortpos = cx;

		-- Mirror the player's best (earliest-ready) row back onto the shared
		-- interrupter object, for code that still reads player-level
		-- sortpos/readyTime/cooldown directly (e.g. ShowInterruptWarning).
		if not row.interrupter.sortpos then
			row.interrupter.sortpos = cx;
			row.interrupter.cooldown = row.cooldown;
			row.interrupter.readyTime = row.readyTime;
		end
	end

	SI_Globals.numInterrupters = table.getn(rows);

	return rows;
end

function SexyInterrupter:UpdateInterrupters()
	local currentMember = {};

	-- Update active state
	for cx, value in pairs(SI_Globals.interrupters) do
		value.active = false;
	end
	
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
		local class, englishClass = UnitClass(unit);			
		local color = RAID_CLASS_COLORS[englishClass];

		
		if interrupter == nil then
			interrupter = {};
			
			interrupter.name = name;
			interrupter.realm = realm;
			interrupter.fullname = fullname;
			interrupter.class = class;
			interrupter.classEN = englishClass;
			interrupter.classColor = color;
			interrupter.cooldown = 0;
			interrupter.readyTime = 0;
			interrupter.overrideprio = false;
			
			tinsert(SI_Globals.interrupters, interrupter);
		end

		interrupter = SexyInterrupter:GetInterrupter(fullname);
				
		interrupter.lastseen = time();
		interrupter.active = interrupter.talents ~= nil;
		
		if unit == 'player' then
			interrupter.active = true;
			interrupter.role = SexyInterrupter:GetSpecializationRoleCompat();
		else
			interrupter.role = SexyInterrupter:GetSpecializationRoleByIDCompat(fullname);
		end

		if not interrupter.role then
			interrupter.role = UnitGroupRolesAssigned(unit);
		end

		if not interrupter.classEN then
			interrupter.classEN = englishClass;
		end

		if interrupter.classEN and interrupter.role ~= 'NONE' then
			interrupter.canInterrupt = SexyInterrupter:CanClassRoleInterrupt(interrupter.classEN, interrupter.role);
		else
			interrupter.canInterrupt = true;
		end

		-- unitCanInterrupt is a static class+role guess ("this class/role
		-- COULD interrupt"), with no idea whether the interrupt spell is
		-- actually trained yet (e.g. a fresh leveling character below the
		-- level where they learn it). We can verify that for real for the
		-- local player via IsSpellKnown - not for teammates (no reliable
		-- spellbook access to other units), so this only tightens the
		-- player's own row; teammates keep showing as placeholders until
		-- their first confirmed kick, as designed.
		if unit == 'player' and interrupter.canInterrupt then
			interrupter.canInterrupt = SexyInterrupter:PlayerKnowsAnyInterruptSpell();
		end

		if interrupter.overrideprio == nil then
			interrupter.overrideprio = false;
		end

		if interrupter.role == 'HEALER' then
			interrupter.prio = 3;
		elseif interrupter.role == 'DAMAGER' then
			interrupter.prio = 2;
		elseif interrupter.role == 'TANK' then
			interrupter.prio = 1;
		end
		
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

		SexyInterrupter:SendAddonMessage("requesttalents:" .. interrupter.fullname);
	end

	SexyInterrupter:SendAddonMessage("versioninfo:" .. SexyInterrupter.Version);

	if UnitIsGroupLeader("player") then
		SexyInterrupter:SendOverridePrioInfos();
	end
end

function SexyInterrupter:ShowInterruptMessage(destName, spellId, spellName)
	local output = self.db.profile.notification.outputchannel;
	local channel;
	local inGroup, inRaid, inPartyLFG = IsInGroup(), IsInRaid(), IsPartyLFG();
	local msg = string.format("%s's \124cff71d5ff\124Hspell:%d:0\124h[%s]\124h\124r %s!", destName, spellId, spellName, L["interrupted"]);

	if not inGroup then return end;

	if output == 'PARTY' then
		SendChatMessage(msg, inPartyLFG and "INSTANCE_CHAT" or "PARTY");
	elseif output == 'RAID' and inRaid then
		SendChatMessage(msg, inPartyLFG and "INSTANCE_CHAT" or "RAID");
	else
		SendChatMessage(msg, output);
	end
end

function SexyInterrupter:CreateFlasher(color)
    local frameImage = "None";

    if color == "Blue" then
        frameImage = "Interface\\FullScreenTextures\\OutofControl";
    elseif color == "Red" then
        frameImage = "Interface\\FullScreenTextures\\LowHealth";
    else
        frameImage = nil;
    end

    local frameName = "SexyInterrupter" .. color .. "WarningFrame";

    if frameImage then
        local flasher = CreateFrame("Frame", frameName)

        flasher:SetToplevel(true)
        flasher:SetFrameStrata("FULLSCREEN_DIALOG")
        flasher:SetAllPoints(UIParent)
        flasher:EnableMouse(false)
        flasher.texture = flasher:CreateTexture(nil, "BACKGROUND")
        flasher.texture:SetTexture(frameImage)
        flasher.texture:SetAllPoints(UIParent)
        flasher.texture:SetBlendMode("ADD")
        flasher:Hide()

        flasher:SetScript("OnShow", function(self)
            self.elapsed = 0;
            self:SetAlpha(0);
        end)
		
        flasher:SetScript("OnUpdate", function(self, elapsed)
            elapsed = self.elapsed + elapsed;
            
            local alpha = elapsed % 0.5;

            if elapsed > 0.2 then
                alpha = 0.5 - alpha
            end

            self:SetAlpha(alpha * 3);
            self.elapsed = elapsed;
        end)
    end
 end

-- true while Blizzard's real Edit Mode is open (SexyInterrupterAnchor/
-- SexyInterrupterInterruptNowText are registered with it via the vendored
-- EditModeExpanded-1.0 library, see ui.lua's CreateUi - it owns all
-- dragging/positioning now). Only used to decide whether to show test data
-- instead of the live roster while the user is repositioning things.
function SexyInterrupter:IsEditingUi()
	return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() or false;
end

-- Opens Blizzard's real Edit Mode (bound to the "Lock window"/"Open Edit
-- Mode to reposition" option, the minimap icon left click, and `/si lock`).
-- Positioning itself is handled entirely by EditModeExpanded-1.0 from here.
function SexyInterrupter:LockFrame()
	if EditModeManagerFrame then
		ShowUIPanel(EditModeManagerFrame);
	end
end

function SexyInterrupter:ShowInterruptWarning(notInterruptible, startTime, endTime)
	-- notInterruptible (from UnitCastingInfo/UnitChannelInfo) can come through
	-- as a "secret" value under the same protected-info guard as spellID
	-- elsewhere - can't be used in a boolean test. When we can't tell, assume
	-- the cast IS interruptible (fail open) so the prompt still fires; the
	-- worst case is one unnecessary "interrupt now" hint, not a missed one.
	if issecretvalue and issecretvalue(notInterruptible) then
		notInterruptible = false;
	end

	-- startTime/endTime (also from UnitCastingInfo/UnitChannelInfo) can be
	-- secret too - not just booleans, any value from those calls apparently.
	-- Can't do arithmetic on a secret number, so drop down to nil (same as
	-- "this client didn't give us a cast length") and let the existing
	-- fallback below use the default timeVisible.
	if issecretvalue and issecretvalue(startTime) then
		startTime = nil;
	end

	if issecretvalue and issecretvalue(endTime) then
		endTime = nil;
	end

	if not notInterruptible and UnitCanAttack('player', 'target') then
		-- Gleicher Bug wie in events.lua's UNIT_SPELLCAST_SUCCEEDED: UnitName()s
		-- Realm-Rückgabe ist für "player" auf diesem Client NICHT zuverlässig
		-- leer (liefert einen internen Token statt nil), wodurch die gebaute
		-- fullname weder mit dem gespeicherten bloßen Namen noch mit dem über
		-- GetRealmName() gebauten "Name-Realm" übereinstimmt - GetInterrupter
		-- lieferte dadurch nil und der Zugriff auf interrupter.sortpos direkt
		-- danach crashte. Erst bloßen Namen probieren, dann GetRealmName()-
		-- Fallback, und (falls beides fehlschlägt) nicht mehr crashen.
		local name = UnitName('player');
		local interrupter = SexyInterrupter:GetInterrupter(name);

		if not interrupter then
			interrupter = SexyInterrupter:GetInterrupter(name .. '-' .. GetRealmName());
		end

		if interrupter and interrupter.sortpos == 1 and (interrupter.readyTime == 0 or interrupter.readyTime == nil) then
			local timeVisible = 10;

			if (startTime and endTime and endTime/1000 - startTime/1000 < 10) then
				timeVisible = endTime - startTime
			end

			local tName = UnitName('target');

			if self.db.profile.notification.message then
				local text = L["Interrupt now"] .. ' |cFFFF0000' .. tName .. '|r !!';
				SexyInterrupterInterruptNowText:AddMessage(text, 1,1,1);
				SexyInterrupterInterruptNowText:SetTimeVisible(timeVisible);
				SexyInterrupterInterruptNowText.text = text;
			end

			if self.db.profile.notification.sound then
				PlaySoundFile(SexyInterrupter:ResolveSoundPath(self.db.profile.notification.soundFile), "Master");
			end

			if self.db.profile.notification.flash then
				SexyInterrupterBlueWarningFrame:Show();
			end
		end
	end
end 
