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
		icon = "Interface\\AddOns\\SexyInterrupter\\icon.tga",
		text = "SexyInterrupter",
		OnClick = function(self,btn)
		   -- Mit dem Addon SexyEditMode: Linksklick = Einstellungsfenster, Rechtsklick = Edit Mode.
		   -- Ohne: Linksklick = Edit Mode, Rechtsklick = Optionen (wie bisher).
		   local SEM = LibStub("SexyEditMode-1.0", true);
		   local hub = SEM and SEM.OpenHub;

		   if (btn == "RightButton") == (hub and true or false) then
			   SexyInterrupter:LockFrame();
		   elseif hub then
			   SEM:OpenHub("SexyInterrupter");
		   else
			   LibStub("AceConfigDialog-3.0"):Open("SexyInterrupter");
		   end
	   end,
	   OnTooltipShow = function(self)
		   if not self or not self.AddLine then return end
		   self:AddLine("SexyInterrupter");
		   local SEM = LibStub("SexyEditMode-1.0", true);

		   if SEM and SEM.OpenHub then
			   self:AddLine(GetLocale() == "deDE" and "Linksklick: Einstellungen" or "Left click: settings",1,1,1);
			   self:AddLine(GetLocale() == "deDE" and "Rechtsklick: Edit Mode" or "Right click: Edit Mode",1,1,1);
		   else
			   self:AddLine(L["Left click to toggle Frame"],1,1,1);
			   self:AddLine(L["Right click to open settings"],1,1,1);
		   end
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
	if unit == "player" then
		return true;
	end

	-- Weit entfernte Einheiten sind für den Client gar nicht sichtbar.
	local visible = UnitIsVisible(unit);

	if not (issecretvalue and issecretvalue(visible)) and not visible then
		return false;
	end

	-- Genaueste Quelle, falls vorhanden und nicht gesperrt: echte Entfernung
	-- (quadriert, in Metern^2). 30 m ~ typische Interrupt-Reichweite.
	if UnitDistanceSquared then
		local distSq, distOk = UnitDistanceSquared(unit);

		if distSq ~= nil and distOk ~= false and not (issecretvalue and (issecretvalue(distSq) or issecretvalue(distOk))) then
			return distSq <= 30 * 30;
		end
	end

	local inRange, checkedRange = UnitInRange(unit);
	local secret = issecretvalue and (issecretvalue(inRange) or issecretvalue(checkedRange));

	-- Ist checkedRange false (oder der Wert gesperrt), ist inRange wertlos
	-- (immer true): dann stattdessen die Follow-Distanz (~28 m) prüfen.
	if secret or checkedRange == false then
		-- Im Kampf ist CheckInteractDistance eingeschränkt und liefert dort
		-- unzuverlässig false: dann keine Aussage (alter Wert bleibt stehen).
		if CheckInteractDistance and not (InCombatLockdown and InCombatLockdown()) then
			local near = CheckInteractDistance(unit, 4);

			if not (issecretvalue and issecretvalue(near)) and near ~= nil then
				return near and true or false;
			end
		end

		if secret then
			return nil;
		end
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
		-- zweiter Parameter: auch im Pet-Zauberbuch suchen (Spell Lock).
		if IsSpellKnown(spellId) or IsSpellKnown(spellId, true) then
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

-- Kann dieser (fremde) Spieler kicken? Meldet sein Client selbst, ob er einen
-- Interrupt gelernt hat (knowsInterrupt, aus seinem Zauberbuch), gilt das; sonst
-- (ältere Addon-Version) die grobe Klasse+Rolle-Schätzung.
function SexyInterrupter:GuessCanInterrupt(interrupter)
	if type(interrupter.knowsInterrupt) == "boolean" then
		return interrupter.knowsInterrupt;
	end

	return SexyInterrupter:CanClassRoleInterrupt(interrupter.classEN, interrupter.role);
end

-- notification.soundFile holds either a LibSharedMedia sound NAME (what the
-- picker stores) or a raw file path (the default). PlaySoundFile only
-- understands paths, so resolve names first.
local DEFAULT_SOUND_PATH = "Sound\\Spells\\PVPFlagTaken.ogg";

-- Spielsounds (SOUNDKIT), zusätzlich zu den LibSharedMedia-Tönen; gespeichert als "kit:NAME"
local KIT_NAMES = {
	{ "IG_QUEST_LIST_OPEN", GetLocale() == "deDE" and "Questliste öffnen" or "Quest list open" },
	{ "READY_CHECK", GetLocale() == "deDE" and "Bereitschaftscheck" or "Ready check" },
	{ "RAID_WARNING", GetLocale() == "deDE" and "Schlachtzugswarnung" or "Raid warning" },
	{ "ALARM_CLOCK_WARNING_3", GetLocale() == "deDE" and "Wecker" or "Alarm clock" },
	{ "MAP_PING", GetLocale() == "deDE" and "Kartenping" or "Map ping" },
	{ "UI_QUEST_ROLLING_FORWARD_01", GetLocale() == "deDE" and "Quest abgegeben" or "Quest turned in" },
	{ "TELL_MESSAGE", GetLocale() == "deDE" and "Flüstern" or "Whisper" },
	{ "AUCTION_WINDOW_OPEN", GetLocale() == "deDE" and "Auktionshaus" or "Auction house" },
	{ "UI_EPICLOOT_TOAST", GetLocale() == "deDE" and "Epische Beute" or "Epic loot" },
	{ "IG_PLAYER_INVITE", GetLocale() == "deDE" and "Einladung" or "Invitation" },
};

function SexyInterrupter:SoundKitOptions()
	local list = {};

	for _, kit in ipairs(KIT_NAMES) do
		if SOUNDKIT and SOUNDKIT[kit[1]] then
			list[#list + 1] = { value = "kit:" .. kit[1], label = kit[2] };
		end
	end

	return list;
end

-- Spielt den gewählten Alarmton: Spielsound ("kit:NAME") oder LibSharedMedia-Name bzw. Dateipfad
function SexyInterrupter:PlayAlertSound(value)
	if type(value) == "string" and value:sub(1, 4) == "kit:" then
		local id = SOUNDKIT and SOUNDKIT[value:sub(5)];

		if id then
			PlaySound(id, "Master");
			return;
		end

		value = nil; -- unbekannt: Standardton
	end

	PlaySoundFile(self:ResolveSoundPath(value), "Master");
end

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

	-- Doppelte Einträge für den eigenen Spieler (z. B. "Name" und
	-- "Name-Realm" aus älteren Versionen/gespeicherten Daten) entfernen und
	-- deren gelernte Fähigkeiten übernehmen. Lookups finden immer nur den
	-- ersten Treffer, ein zweiter aktiver Eintrag blieb sonst als eigene
	-- Zeile stehen.
	for i = #SI_Globals.interrupters, 1, -1 do
		local other = SI_Globals.interrupters[i];

		if other ~= interrupter then
			local otherBase = (other.name or other.fullname or ""):match("^([^%-]+)");

			if otherBase == name then
				for spellId, ability in pairs(other.abilities or {}) do
					interrupter.abilities = interrupter.abilities or {};
					interrupter.abilities[spellId] = interrupter.abilities[spellId] or ability;
				end

				tremove(SI_Globals.interrupters, i);
			end
		end
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
		local ignored = self.db.profile.general.ignoreHealer and interrupter.role == 'HEALER';

		if interrupter.active and interrupter.canInterrupt and not soloDisabled and not ignored then
			local hasAbilities = false;

			if interrupter.abilities then
				-- Ränge desselben Zaubers (z. B. Pummel Rang 1/2) sind eine
				-- Fähigkeit: pro Familie nur die zuletzt benutzte.
				local byFamily = {};

				for spellId, ability in pairs(interrupter.abilities) do
					hasAbilities = true;

					-- Normalize an expired cooldown to 0 so it sorts as "ready"
					-- (the UI only zeroes its transient row copy).
					if ability.readyTime and ability.readyTime > 0 and ability.readyTime <= GetTime() then
						ability.readyTime = 0;
					end

					local family = self.spellFamily[spellId] or spellId;
					local existing = byFamily[family];

					if not existing or (ability.readyTime or 0) > (existing.readyTime or 0) then
						byFamily[family] = {
							interrupter = interrupter,
							spellId = spellId,
							cooldown = ability.cooldown,
							readyTime = ability.readyTime,
						};
					end
				end

				for _, row in pairs(byFamily) do
					tinsert(rows, row);
				end
			end

			if not hasAbilities then
				-- Noch kein Kick gesehen: das Symbol kommt aus der Klasse (assumed), der Cooldown ist unbekannt (bereit)
				local assumed = interrupter.classEN and self.defaultInterrupt and self.defaultInterrupt[strlower(interrupter.classEN)];

				tinsert(rows, {
					interrupter = interrupter,
					spellId = assumed or nil,
					assumed = assumed and true or nil,
					cooldown = interrupter.cooldown or 0,
					readyTime = interrupter.readyTime or 0,
				});
			end
		end
	end

	-- Fester Rotationsmodus: statt "wer ist am längsten bereit" gilt eine feste
	-- Spielerreihenfolge (Prio, dann Name - auf allen Clients identisch). Wer
	-- zuletzt gekickt hat, rutscht ans Ende; der Nächste in der Reihe ist
	-- oben. Bereite Spieler gehen vor Spielern mit Cooldown (sonst würde die
	-- Rotation stehen, wenn der "Nächste" gerade keinen Kick hat), innerhalb
	-- der beiden Gruppen entscheidet die Reihenfolge.
	local fixedCompare;

	if self.db.profile.general.fixedRotation then
		local order, count = {}, 0;

		for _, row in ipairs(rows) do
			if not order[row.interrupter] then
				count = count + 1;
				order[row.interrupter] = count;
			end
		end

		local players = {};

		for interrupter in pairs(order) do
			tinsert(players, interrupter);
		end

		table.sort(players, function(a, b)
			local pa, pb = a.overridedprio or a.prio or 9, b.overridedprio or b.prio or 9;

			if pa ~= pb then
				return pa < pb;
			end

			return (a.fullname or a.name or "") < (b.fullname or b.name or "");
		end);

		local index = {};

		for i, interrupter in ipairs(players) do
			index[interrupter] = i;
		end

		local kickerIndex = SexyInterrupter.lastKicker and index[SexyInterrupter.lastKicker] or 0;

		local function Rank(interrupter)
			return (index[interrupter] - kickerIndex - 1) % #players;
		end

		local function Class(interrupter)
			if interrupter.offline then return 3; end
			if not interrupter.inrange then return 2; end
			if interrupter.dead then return 1; end

			return 0;
		end

		fixedCompare = function(a, b)
			local ia, ib = a.interrupter, b.interrupter;
			local ca, cb = Class(ia), Class(ib);

			if ca ~= cb then
				return ca < cb;
			end

			local ra, rb = a.readyTime > 0, b.readyTime > 0;

			if ra ~= rb then
				return rb;
			end

			if ia ~= ib then
				return Rank(ia) < Rank(ib);
			end

			if a.readyTime ~= b.readyTime then
				return a.readyTime < b.readyTime;
			end

			return (a.spellId or 0) < (b.spellId or 0);
		end
	end

	table.sort(rows, fixedCompare or function(a, b)
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
			interrupter.canInterrupt = SexyInterrupter:GuessCanInterrupt(interrupter);
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

-- Farbe des Bildschirm-Blitzes: Die Blizzard-Textur ist von sich aus blau; entsaettigt und mit der gewaehlten
-- Farbe eingefaerbt wird daraus jede Farbe.
function SexyInterrupter:ApplyFlashColor()
	local flasher = SexyInterrupterBlueWarningFrame;

	if not (flasher and flasher.texture and self.db) then
		return;
	end

	local c = self.db.profile.notification.flashcolor or { r = 0.3, g = 0.5, b = 1 };

	flasher.texture:SetDesaturated(true);
	flasher.texture:SetVertexColor(c.r, c.g, c.b);
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
        SexyInterrupter:ApplyFlashColor()

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
-- SexyEditMode-1.0 library, see ui.lua's CreateUi - it owns all
-- dragging/positioning now). Only used to decide whether to show test data
-- instead of the live roster while the user is repositioning things.
function SexyInterrupter:IsEditingUi()
	-- Zustand der Bibliothek, nicht Blizzards Flag: Die Bibliothek ruft UpdateFrames() schon beim
	-- Betreten/Verlassen auf, und dann muss die Abfrage bereits den neuen Zustand liefern.
	local SEM = LibStub("SexyEditMode-1.0", true);

	-- hubPreview: Die Vorschau im Einstellungsfenster zeigt die echten Fenster mit den Beispieldaten des Edit Mode
	if self.hubPreview then
		return true;
	end

	return SEM:IsEditing("SexyInterrupter");
end

-- Starts or ends the own move mode of SexyEditMode-1.0 (bound to the "Lock window"/"Open Edit
-- Mode to reposition" option, the minimap icon and `/si lock`), only for the windows of this addon.
function SexyInterrupter:LockFrame()
	LibStub("SexyEditMode-1.0"):ToggleEditMode("SexyInterrupter");
end

-- Instanz, in der du gerade bist (Dungeon oder Raid): Id und Name, sonst nil
function SexyInterrupter:InstanceInfo()
	local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo();

	if instanceID and (instanceType == "party" or instanceType == "raid") then
		return instanceID, name;
	end
end

-- Alle Zauberlisten pro Instanz: [Instanz-ID] = { name, spells }. Sie liegen im Account-Teil der Datenbank (db.global) und gelten für
-- alle Charaktere und Profile. Listen, die noch im Profil stehen (frühere Fassung, auch aus einem gewechselten oder importierten
-- Profil), werden hier übernommen: neue Zauber kommen hinzu, bestehende Einstellungen im Account bleiben.
function SexyInterrupter:Kicklists()
	local lists = self.db.global.kicklist;
	local old = rawget(self.db.profile, "kicklist");

	if type(old) == "table" then
		for id, entry in pairs(old) do
			if type(entry) == "table" then
				local target = lists[id];

				if not target then
					lists[id] = entry;
				else
					target.spells = target.spells or {};

					for spell, on in pairs(entry.spells or {}) do
						if target.spells[spell] == nil then target.spells[spell] = on; end
					end
				end
			end
		end

		self.db.profile.kicklist = nil;
	end

	return lists;
end

-- Liste der wichtigen Zauber dieser Instanz (create = true legt sie an)
function SexyInterrupter:GetKicklist(create)
	local id, name = self:InstanceInfo();

	if not id then
		return nil;
	end

	local lists = self:Kicklists();
	local entry = lists[id];

	if not entry and create then
		entry = { name = name, spells = {} };
		lists[id] = entry;
	end

	return entry, name;
end

-- Soll dieser Zauber gemeldet werden? Immer, ausser die Option "Zauberliste beachten" ist an, du bist in einer
-- Instanz und der Zauber ist dort abgehakt (stumm geschaltet). Neue Zauber gelten als gemeldet. Ist der Zaubername
-- nicht lesbar (geheimer Wert), wird gemeldet.
function SexyInterrupter:IsImportantCast(castName)
	if not self.db.profile.notification.kickListOnly then
		return true;
	end

	local entry = self:GetKicklist(false);

	if not entry or not castName then
		return true;
	end

	return entry.spells[castName] ~= false;
end

local function Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: " .. text, 1, 0.5, 0);
end

-- Ist der Zauber ein Heilzauber? Liefert true / false, oder nil, wenn es sich nicht feststellen laesst (Zauber-ID
-- geheim oder unbekannt, keine Beschreibung und keine passende Abfrage). Zweiter Rueckgabewert: die benutzte Methode
-- ("Beschreibung" oder "freundlich"), fuer /si debug.
-- 1. Beschreibungstext des Zaubers nach Heil-Woertern durchsuchen (deutsch und englisch).
-- 2. Sonst C_Spell.IsSpellHelpful: zielt der Zauber auf Verbuendete, ist es bei Gegnern praktisch immer eine Heilung/Staerkung.
local healCache = {};

function SexyInterrupter:IsHealingSpell(spellId)
	if spellId ~= nil and issecretvalue and issecretvalue(spellId) then
		-- Geheime ID: lesen und rechnen geht nicht, aber manche Abfragen nehmen sie an und liefern einen offenen
		-- Wahrheitswert. Probieren; sonst nicht feststellbar.
		local helpful = (C_Spell and C_Spell.IsSpellHelpful) or IsHelpfulSpell;

		if helpful then
			local ok, value = pcall(helpful, spellId);

			if ok and value ~= nil then
				if not issecretvalue(value) then
					return value and true or false, "freundlich (geheime ID)";
				end

				-- Geheimer Wahrheitswert: er laesst sich nicht abfragen, wohl aber an Anzeigen weiterreichen
				-- (SetAlphaFromBoolean). Erst probieren, ob die Transparenz lesbar bleibt; sonst als dritter Wert zurueck.
				SexyInterrupter.healProbe = SexyInterrupter.healProbe or CreateFrame("Frame");
				local probe = SexyInterrupter.healProbe;

				if probe.SetAlphaFromBoolean then
					pcall(probe.SetAlphaFromBoolean, probe, value, 1, 0);
					local a = probe:GetAlpha();

					if type(a) == "number" and not issecretvalue(a) then
						return a > 0.5, "freundlich (geheime ID, ueber Transparenz)";
					end
				end

				return nil, "ID geheim (Wert nur fuer die Anzeige)", value;
			end
		end

		return nil, "ID geheim";
	end

	if type(spellId) ~= "number" then
		return nil;
	end

	local cached = healCache[spellId];

	if cached then
		return cached[1], cached[2];
	end

	local result, method;
	local getDesc = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription;

	if getDesc then
		local ok, desc = pcall(getDesc, spellId);

		if ok and type(desc) == "string" and desc ~= "" and not (issecretvalue and issecretvalue(desc)) then
			local lower = strlower(desc);

			result = (strfind(lower, "heal", 1, true) or strfind(lower, "heil", 1, true) or (strfind(lower, "restore", 1, true) or strfind(lower, "stellt", 1, true)) and (strfind(lower, "health", 1, true) or strfind(lower, "gesundheit", 1, true))) and true or false;
			method = "Beschreibung";
		end
	end

	if result == nil then
		local helpful = (C_Spell and C_Spell.IsSpellHelpful) or IsHelpfulSpell;

		if helpful then
			local ok, value = pcall(helpful, spellId);

			if ok and value ~= nil and not (issecretvalue and issecretvalue(value)) then
				result = value and true or false;
				method = "freundlich";
			end
		end
	end

	-- Beschreibungen laden manchmal erst nach dem ersten Abruf: nur feste Ergebnisse merken
	if result ~= nil then
		healCache[spellId] = { result, method };
	end

	return result, method;
end

-- Zauber der Instanz stumm schalten (false) oder wieder melden (true)
function SexyInterrupter:ToggleKicklist(castName)
	if not castName then
		return;
	end

	local entry, name = self:GetKicklist(true);

	if not entry then
		Say(L["Only possible inside an instance."]);
		return;
	end

	if entry.spells[castName] == false then
		entry.spells[castName] = true;
		Say(L["%s is reported again in %s."]:format(castName, name));
	else
		entry.spells[castName] = false;
		Say(L["%s is not reported in %s anymore."]:format(castName, name));
	end
end

-- Zauber merken, den dein Ziel in dieser Instanz wirkt (neue Zauber stehen angehakt in der Liste)
function SexyInterrupter:LearnCast(castName)
	if not castName then
		return;
	end

	local entry = self:GetKicklist(true);

	if entry and entry.spells[castName] == nil then
		entry.spells[castName] = true;
	end
end

-- Eigenen Zauber (Name) zur Liste der aktuellen Instanz hinzufuegen
function SexyInterrupter:AddKickSpell(castName)
	local entry, name = self:GetKicklist(true);

	if not entry then
		Say(L["Only possible inside an instance."]);
		return;
	end

	entry.spells[castName] = true;
	Say(L["%s added to the list for %s."]:format(castName, name));
end

function SexyInterrupter:PrintKicklist()
	local entry, name = self:GetKicklist(false);

	if not name and not entry then
		local id, instanceName = self:InstanceInfo();

		if not id then
			Say(L["Only possible inside an instance."]);
			return;
		end

		name = instanceName;
	end

	local names = {};

	if entry then
		for spell, on in pairs(entry.spells) do
			names[#names + 1] = (on == false and "(-) " or "") .. spell;
		end
	end

	table.sort(names);

	if #names == 0 then
		Say(L["The list for %s is empty."]:format(name or "?"));
	else
		Say(L["List for %s: %s"]:format(name or "?", table.concat(names, ", ")));
	end
end

function SexyInterrupter:ClearKicklist()
	local entry, name = self:GetKicklist(false);

	if entry then
		wipe(entry.spells);
		Say(L["List for %s cleared."]:format(name or "?"));
	else
		Say(L["Only possible inside an instance."]);
	end
end

-- Sprachausgabe (Text-zu-Sprache), nur wenn der Client sie kennt
local lastSpoken = 0;

function SexyInterrupter:Speak(castName, force)
	local n = self.db.profile.notification;

	if not (force or n.tts) or not (C_VoiceChat and C_VoiceChat.SpeakText) then
		return;
	end

	-- nicht mehrfach hintereinander (jeder Cast, jede Zielwahl loest sonst erneut aus)
	if not force and GetTime() - lastSpoken < 2 then
		return;
	end

	lastSpoken = GetTime();

	local phrase = (n.ttsPhrase and n.ttsPhrase ~= "") and n.ttsPhrase or L["Interrupt!"];
	local text = phrase;

	if n.ttsText == "spell" and castName then
		text = castName;
	elseif n.ttsText == "both" and castName then
		text = phrase .. " " .. castName;
	end

	local voice = n.ttsVoice;

	if not voice and C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum.TtsVoiceType then
		voice = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard);
	end

	-- Alle Clients nutzen jetzt dieselbe Schnittstelle: SpeakText(voiceID, text, rate, volume, allowOverlappedSpeech).
	-- Der frühere Parameter "destination" gibt es nicht mehr, mit ihm verrutschten Tempo und Lautstärke.
	local ok, err = pcall(C_VoiceChat.SpeakText, voice or 0, text, n.ttsRate or 0, n.ttsVolume or 100, false);

	if not ok then
		DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: " .. tostring(err), 1, 0.3, 0.3);
	end
end

function SexyInterrupter:ShowInterruptWarning(notInterruptible, startTime, endTime, castName, castTexture, castSpellId)
	-- notInterruptible (from UnitCastingInfo/UnitChannelInfo) can come through
	-- as a "secret" value under the same protected-info guard as spellID
	-- elsewhere - can't be used in a boolean test. When we can't tell, assume
	-- the cast IS interruptible (fail open) so the prompt still fires; the
	-- worst case is one unnecessary "interrupt now" hint, not a missed one.
	local lockedSecret, lockedValue = false, notInterruptible;

	if issecretvalue and issecretvalue(notInterruptible) then
		-- Geheimer Wert: lesen geht nicht. Karte und Blitz folgen ihm unten ueber SetAlphaFromBoolean (bei "nicht
		-- unterbrechbar" bleiben sie unsichtbar); Ton und Sprache koennen ihm nicht folgen und bleiben aus.
		lockedSecret = true;
		notInterruptible = false;
	end

	-- Merken, dass dieser Zauber gesperrt war: wird er mitten im Wirken unterbrechbar, kommt der Hinweis nachtraeglich
	-- (UNIT_SPELLCAST_INTERRUPTIBLE)
	self.castLocked = (not lockedSecret) and notInterruptible and true or false;

	-- Name, Symbol und Zeiten des Zaubers koennen im Kampf "geheime Werte" sein. Rechnen und Vergleichen geht
	-- damit nicht, wohl aber das Weiterreichen an Anzeigefunktionen (SetText, SetTexture, SetMinMaxValues).
	-- Darum bleiben sie erhalten (frueher wurden sie weggeworfen, und die Karte zeigte weder Zaubername noch
	-- Symbol noch Zeit). Wo gerechnet wird, steht ein pcall; Liste und Sprache nutzen nur den lesbaren Namen.
	local readableName = castName;

	if issecretvalue and issecretvalue(readableName) then
		readableName = nil;
	end

	if not notInterruptible and UnitCanAttack('player', 'target') then
		-- Zauber in der Instanz-Liste vermerken (Name nur, wenn lesbar)
		self:LearnCast(readableName);

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

		if self.debug then
			-- zeigt, warum (k)ein Hinweis kommt: nur wer in der Liste oben steht und bereit ist, bekommt ihn
			DEFAULT_CHAT_FRAME:AddMessage(string.format("SI debug: Zauber am Ziel: Platz=%s bereit=%s", interrupter and tostring(interrupter.sortpos) or "?",
				tostring(interrupter ~= nil and (interrupter.readyTime == 0 or interrupter.readyTime == nil))), 0.6, 0.8, 1);
		end

		if interrupter and interrupter.sortpos == 1 and (interrupter.readyTime == 0 or interrupter.readyTime == nil) then
			local timeVisible = 10;
			local castLength;

			-- Anzeigedauer = Zauberlänge in Sekunden (startTime/endTime sind Millisekunden); ist sie nicht lesbar,
			-- bleibt es bei den 10 Sekunden
			if startTime ~= nil and endTime ~= nil then
				pcall(function()
					local length = (endTime - startTime) / 1000;
					castLength = length;

					if length < 10 then
						timeVisible = length;
					end
				end);
			end

			-- Nur Zauber der Liste melden (Option, in Instanzen)? Dann bleibt alles andere still.
			if not self:IsImportantCast(readableName) then
				return;
			end

			-- "Nur Heilzauber melden": ist sicher, dass es keine Heilung ist, bleibt es still; nicht feststellbar (geheime Werte,
			-- keine Abfrage): wie bisher melden
			local hideBySecret;

			if self.db.profile.notification.healOnly then
				local heal, method, secretHeal = self:IsHealingSpell(castSpellId);
				hideBySecret = secretHeal;

				if self.debug then
					DEFAULT_CHAT_FRAME:AddMessage(string.format("SI debug: Heilzauber? spell=%s -> %s (%s)", readableName or "?",
						tostring(heal), method or "nicht feststellbar"), 0.6, 0.8, 1);
				end

				if heal == false then
					return;
				end
			end

			-- Zu kurze Zauber lassen sich nicht rechtzeitig kicken; allein nervt ein Mob, der schnell hintereinander
			-- zaubert, mit jedem Hinweis: dort gilt eine Pause zwischen zwei Hinweisen.
			local cfg = self.db.profile.notification;
			local now = GetTime();

			if castLength and (cfg.minCast or 0) > 0 and castLength < cfg.minCast then
				return;
			end

			local solo = not IsInGroup() and not IsInRaid() and not IsPartyLFG();

			if solo and (cfg.soloGap or 0) > 0 and self.lastAlertAt and now - self.lastAlertAt < cfg.soloGap then
				return;
			end

			self.lastAlertAt = now;

			local tName = UnitName('target');

			-- "Nur Heilzauber" bei geheimer ID: ob es eine Heilung ist, wissen nur die Anzeigen (Karte, Blitz) - Ton und Sprache
			-- koennen dem nicht folgen und bleiben deshalb aus
			-- (Option "Ton auch bei unbekannter Zauberart": Ton und Sprache kommen dann bei jedem Zauber, nur die Anzeigen bleiben gefiltert)
			local silent = (hideBySecret ~= nil and not cfg.soundUnknown) or lockedSecret;

			if not silent then
				self:Speak(readableName);
			end

			if self.db.profile.notification.message then
				SexyInterrupterInterruptNowText:ShowAlert(tName, castName, castTexture, endTime, timeVisible, startTime);

				-- "Nur Heilzauber" bei geheimer Zauber-ID: die Karte wird ueber den geheimen Wert ein- oder ausgeblendet
				local card = SexyInterrupterInterruptNowText;
				card:SetAlpha(1);

				-- Zauber nicht unterbrechbar (geheimer Wert): die ganze Karte bleibt unsichtbar
				if lockedSecret and card.SetAlphaFromBoolean then
					pcall(card.SetAlphaFromBoolean, card, lockedValue, 0, 1);
				end

				local panel = SexyInterrupterInterruptNowText.panel;

				if panel then
					panel:SetAlpha(1);

					if hideBySecret ~= nil and panel.SetAlphaFromBoolean then
						pcall(panel.SetAlphaFromBoolean, panel, hideBySecret, 1, 0);
					end
				end
			end

			if self.db.profile.notification.sound and not silent then
				SexyInterrupter:PlayAlertSound(self.db.profile.notification.soundFile);
			end

			if self.db.profile.notification.flash then
				SexyInterrupterBlueWarningFrame:Show();
				SexyInterrupterBlueWarningFrame:SetAlpha(1);

				if lockedSecret and SexyInterrupterBlueWarningFrame.SetAlphaFromBoolean then
					-- nicht unterbrechbar (geheim): kein Blitz; hat Vorrang vor "Nur Heilzauber"
					pcall(SexyInterrupterBlueWarningFrame.SetAlphaFromBoolean, SexyInterrupterBlueWarningFrame, lockedValue, 0, 1);
				elseif hideBySecret ~= nil and SexyInterrupterBlueWarningFrame.SetAlphaFromBoolean then
					pcall(SexyInterrupterBlueWarningFrame.SetAlphaFromBoolean, SexyInterrupterBlueWarningFrame, hideBySecret, 1, 0);
				end
			end
		end
	end
end 

-- /si probe: Diagnose-Logging, ob sich markierte Gegner (Symbol, Tot-Status,
-- Gesundheit) im Kampf auslesen lassen. Gibt jede Sekunde den Zustand aller
-- markierten Einheiten im Chat aus und meldet, wenn eine verschwindet.
local PROBE_UNITS = { "target", "focus", "mouseover", "targettarget", "party1target", "party2target", "party3target", "party4target" };

for i = 1, 40 do
	tinsert(PROBE_UNITS, "nameplate" .. i);
end

local probeFrame;
local probeSeen = {};

local function ProbeSay(text)
	DEFAULT_CHAT_FRAME:AddMessage("SI probe: " .. text, 0.6, 1, 0.6);
end

local function Probe(value)
	if issecretvalue and issecretvalue(value) then
		return "SECRET";
	end

	return tostring(value);
end

local function ProbeScan()
	local combat = tostring(InCombatLockdown());
	local nowMarked = {};

	for _, unit in ipairs(PROBE_UNITS) do
		if UnitExists(unit) then
			local index = GetRaidTargetIndex(unit);
			local marked = false;

			pcall(function()
				if index then
					marked = true;
				end
			end);

			if marked then
				local percent = "n/a";

				if UnitHealthPercent then
					local ok, result = pcall(UnitHealthPercent, unit, false, CurveConstants and CurveConstants.ScaleTo100);

					percent = ok and Probe(result) or "Fehler";
				end

				local line = string.format("%s '%s' sym=%s isDead=%s deadOrGhost=%s hp=%s/%s hp%%=%s canAttack=%s Kampf=%s",
					unit, Probe(UnitName(unit)), Probe(index), Probe(UnitIsDead(unit)), Probe(UnitIsDeadOrGhost(unit)),
					Probe(UnitHealth(unit)), Probe(UnitHealthMax(unit)), percent, Probe(UnitCanAttack("player", unit)), combat);

				nowMarked[unit] = line;
				ProbeSay(line);
			end
		end
	end

	for unit, line in pairs(probeSeen) do
		if not nowMarked[unit] then
			ProbeSay("VERSCHWUNDEN: " .. unit .. " (zuletzt: " .. line .. ")");
		end
	end

	probeSeen = nowMarked;
end

function SexyInterrupter:ToggleProbe()
	if probeFrame and probeFrame.active then
		probeFrame.active = false;
		probeFrame:UnregisterAllEvents();
		probeFrame:SetScript("OnUpdate", nil);
		ProbeSay("aus");
		return;
	end

	if not probeFrame then
		probeFrame = CreateFrame("Frame");
		probeFrame:SetScript("OnEvent", function(_, event, arg1)
			ProbeSay("Event " .. event .. " " .. Probe(arg1));
		end);
	end

	probeFrame.active = true;
	probeFrame.elapsed = 0;
	probeSeen = {};

	for _, event in ipairs({ "RAID_TARGET_UPDATE", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PARTY_KILL" }) do
		pcall(probeFrame.RegisterEvent, probeFrame, event);
	end

	probeFrame:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed;

		if self.elapsed >= 1 then
			self.elapsed = 0;
			ProbeScan();
		end
	end);

	ProbeSay("an - markiere einen Gegner, kämpfe und töte ihn; danach /si probe zum Beenden und die Zeilen im Chat prüfen.");
end
