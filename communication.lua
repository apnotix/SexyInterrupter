local SI = SexyInterrupter;
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SexyInterrupter:SendMessage(prefix, ...)
    local channel;
    local inInstance, instanceType = IsInInstance()

    if instanceType == "pvp" then
        channel = "INSTANCE_CHAT";
    elseif IsInRaid() then
        channel = IsPartyLFG() and "INSTANCE_CHAT" or "RAID";
    elseif IsInGroup() then
        channel = IsPartyLFG() and "INSTANCE_CHAT" or"PARTY";
    end
    
    if channel then
        SexyInterrupter:SendCommMessage("SexyInterrupter", SexyInterrupter:Serialize(prefix, UnitName ("player"), GetRealmName(), ...), channel);
    end
end

function SexyInterrupter:CommReceived(commPrefix, data, channel, source)
    if commPrefix == 'SexyInterrupter' and data ~= nil then
        local prefix, player, realm, arg1, arg2 = select(2, SexyInterrupter:Deserialize(data));

        if prefix == 'versioninfo' then
            SexyInterrupter:ReceiveVersionInfo(player, realm, arg1);
        elseif prefix == 'requestuser' then
            SexyInterrupter:SendUserInformation(player, realm, arg1);
        elseif prefix == 'userinfos' then
            SexyInterrupter:ReceiveUserInformation(player, realm, arg1);
        elseif prefix == 'interrupt' then
            SexyInterrupter:ReceiveInterrupt(player, realm, arg1, arg2);
        end
    end
end

function SexyInterrupter:SendUserInformation(player, realm, target)
    local infos = {};
    local ownName, ownRealm = UnitName("player");
    local ownFullname = ownName;

    if ownRealm then
        ownFullname = ownFullname .. '-' .. ownRealm;
    end

    if ownFullname ~= target then
        return;
    end

    local class, englishClass = UnitClass("player");

    infos.class = class;
    infos.classEN = englishClass;
    infos.role = SexyInterrupter:GetSpecializationRoleCompat();

    if infos.role == nil then        
        infos.role = UnitGroupRolesAssigned("player");
    end

    local talents = '';

    -- GetTalentInfo (the old per-point talent tree API) doesn't exist either
    -- on Forever's beta client, same situation as GetSpecializationRole/
    -- GetSpecialization above - skip it instead of erroring. talents just
    -- stays '' (still non-nil, so the "active" mirror below keeps working);
    -- the only thing lost is the Shadowpriest cooldown-adjustment lookup
    -- (talent 263716) in events.lua, which simply never matches.
    if GetTalentInfo then
        for talentRow = 1, 7 do
            for talentCol = 1, 3 do
                local talentID, name, texture, selected, available = GetTalentInfo(talentRow, talentCol, 1);

                if selected then
                    talents = talents .. '+' .. talentID;
                    break;
                end
            end
        end
    end

    infos.talents = talents;

    SexyInterrupter:SendMessage('userinfos', infos);
end

function SexyInterrupter:ReceiveUserInformation(player, realm, infos)
    -- Comm payloads come from other clients (possibly other addon versions or
    -- garbled) - never index into something that isn't the expected shape.
    if type(player) ~= "string" or type(infos) ~= "table" then
        return;
    end

    local interrupter = SexyInterrupter:GetInterrupter(player, realm);
    local interrupterExists = true;

    if interrupter == nil then
        interrupterExists = false;

        interrupter = {};
    end

    interrupter.class = infos.class;
    interrupter.classEN = infos.classEN;
    interrupter.role = infos.role;
    interrupter.talents = infos.talents;

    -- UpdateInterrupters() (utils.lua) ist der einzige Code, der inrange für
    -- ANDERE Spieler per UnitInRangeCompat() setzt, wird aber laut eigenem
    -- Kommentar in core.lua nirgends mehr aufgerufen (toter Code seit dem
    -- events.lua-Rewrite). Ohne diese Zeile bleibt interrupter.inrange
    -- dauerhaft nil (= falsy), wodurch ui.lua's "not interrupter.inrange"-
    -- Zweig IMMER greift und der Name-Text permanent mit 30% Alpha (statt der
    -- eigentlichen fontcolor/Klassenfarbe) gezeichnet wird - sichtbar als
    -- bräunlich wirkender, mit dem Leisten-Hintergrund verschmelzender Text.
    -- Wie bei UpdateOwnInterrupter() (dort ebenfalls immer true, keine echte
    -- Prüfung) einfach als "in Reichweite" annehmen statt fälschlich zu dimmen.
    -- Nur für neue Einträge: ein bereits bekannter Wert (von OnUpdate per
    -- UnitInRange gepflegt) darf nicht bei jeder 'userinfos'-Nachricht auf
    -- "in Reichweite" zurückspringen - das ließ entfernte Spieler kurz in
    -- voller Farbe aufflackern.
    if interrupter.inrange == nil then
        interrupter.inrange = true;
    end

    interrupter.active = true;
    interrupter.cooldown = 0;
    interrupter.readyTime = 0;
    
    interrupter.classColor = RAID_CLASS_COLORS[interrupter.classEN];
    interrupter.name = player;
    interrupter.realm = realm;
    interrupter.fullname = player;

    if interrupter.realm then
        interrupter.fullname = player .. '-' .. realm;
    end

    if interrupter.classEN and interrupter.role ~= 'NONE' then
        interrupter.canInterrupt = SexyInterrupter:CanClassRoleInterrupt(interrupter.classEN, interrupter.role);
    else
        interrupter.canInterrupt = true;
    end

    -- This class/role guess is the best we can do for OTHER players (their
    -- spellbook isn't queryable). But if this 'userinfos' broadcast turns
    -- out to be about the LOCAL player (e.g. a comm loopback on this client
    -- - GetCurrentInterrupters/UpdateOwnInterrupter already know better via
    -- IsSpellKnown), don't let this overwrite that with the cruder guess.
    --
    -- Compare the RAW `player` name (exactly as UnitName("player") returns
    -- it, unsuffixed) instead of the locally-built `interrupter.fullname` -
    -- that fullname was just built as `player .. '-' .. realm` above using
    -- the DESERIALIZED realm (always GetRealmName(), never nil/empty, see
    -- SendMessage). UpdateOwnInterrupter(), meanwhile, builds its own
    -- fullname from UnitName("player")'s realm return, which IS nil/empty
    -- for same-realm units. Comparing the suffixed fullname strings against
    -- each other silently mismatches for same-realm players ("Name" vs
    -- "Name-RealmName") even though it's the exact same person - which is
    -- exactly why this check previously failed to catch a real self-loopback
    -- (and left a second, wrongly-keyed duplicate entry with the cruder
    -- canInterrupt guess sitting in SI_Globals.interrupters, still shown as
    -- its own bar even though the correctly-keyed entry was fixed).
    if player == UnitName("player") then
        interrupter.canInterrupt = SexyInterrupter:PlayerKnowsAnyInterruptSpell();
    end

    if interrupter.role == 'HEALER' then
        interrupter.prio = 3;
    elseif interrupter.role == 'DAMAGER' then
        interrupter.prio = 2;
    elseif interrupter.role == 'TANK' then
        interrupter.prio = 1;
    end

    if interrupterExists == false then
        tinsert(SI_Globals.interrupters, interrupter);
    end

    SexyInterrupter:UpdateUI();
	SexyInterrupter:UpdateInterrupterStatus();
	SexyInterrupter:UpdateInterrupterSettings();
end

-- tonumber("3.0.1") is nil (more than one ".", not a valid Lua number
-- literal) - since SI.Version moved from a plain integer ("3") to a
-- dotted release version, comparing via tonumber() silently turned both
-- sides into nil and crashed on the "nil > nil" comparison below. Compare
-- dot-separated numeric parts instead, left to right.
local function VersionIsNewer(a, b)
	if not a or not b then
		return false;
	end

	local partsA, partsB = {}, {};

	for part in a:gmatch("%d+") do tinsert(partsA, tonumber(part)); end
	for part in b:gmatch("%d+") do tinsert(partsB, tonumber(part)); end

	for i = 1, math.max(table.getn(partsA), table.getn(partsB)) do
		local x, y = partsA[i] or 0, partsB[i] or 0;

		if x ~= y then
			return x > y;
		end
	end

	return false;
end

function SexyInterrupter:ReceiveVersionInfo(player, realm, version)
	if VersionIsNewer(version, SexyInterrupter.Version) and not SexyInterrupter.newVersionNoticed then
        DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: ' .. L["An update is available v"] .. version .. ". " .. L["Please update to the latest version!"], 1, 0.5, 0);

		SexyInterrupter.newVersionNoticed = true;
	end
end

function SexyInterrupter:SendInterrupt(player, spellId, cooldown)
    SexyInterrupter:SendMessage('interrupt', spellId, cooldown);
end

function SexyInterrupter:ReceiveInterrupt(player, realm, spellId, cooldown)
    local interrupter = SexyInterrupter:GetInterrupter(player, realm);

    if interrupter then
        spellId = tonumber(spellId);
        cooldown = tonumber(cooldown);

        -- Plausibilitätsprüfung: kein bekannter Interrupt hat annähernd eine
        -- so lange Abklingzeit - eine (aus welchem Grund auch immer) korrupt
        -- übertragene riesige Zahl (z. B. 13719s statt 12s beobachtet) wurde
        -- ohne diese Prüfung sonst dauerhaft als "readyTime" gespeichert und
        -- blockierte durch die "nicht überschreiben, wenn noch nicht
        -- abgelaufen"-Sperre unten stundenlang JEDE weitere, korrekte
        -- Aktualisierung - der Cooldown blieb für den Rest der Session hängen.
        local MAX_PLAUSIBLE_COOLDOWN = 180;

        if not spellId or not cooldown or cooldown <= 0 or cooldown > MAX_PLAUSIBLE_COOLDOWN then
            return;
        end

        local existing = interrupter.abilities and interrupter.abilities[spellId];

        -- Gleiche Plausibilitätsprüfung auch auf einen bereits gespeicherten
        -- (evtl. selbst schon korrupten) Wert anwenden, statt ihm blind zu
        -- vertrauen - sonst bleibt ein einmal falsch gesetzter Wert für immer
        -- "frischer" als jedes künftige echte Update und blockiert es weiter.
        local existingIsPlausible = existing and existing.readyTime
            and (existing.readyTime - GetTime()) <= MAX_PLAUSIBLE_COOLDOWN;

        -- Same "don't overwrite a fresher cooldown" guard the old single-ability
        -- code had, just scoped per ability now instead of per player. An
        -- already EXPIRED readyTime (in the past, but never reset to 0 in the
        -- stored ability) must not count as "still running", otherwise every
        -- kick after the first one from that player would be ignored.
        if not existing or not existing.readyTime or existing.readyTime <= GetTime() or not existingIsPlausible then
            interrupter.abilities = interrupter.abilities or {};
            interrupter.abilities[spellId] = {
                cooldown = cooldown,
                readyTime = cooldown + GetTime(),
            };

            SexyInterrupter:UpdateInterrupterStatus();
        end
    end
end





-- function SexyInterrupter:ReceiveOverridePrioInfos(msg, sender) 
--     local fullinfos = { strsplit(';', msg) };
--     local infos;
--     local interrupter;
--     local name, realm, fullname, overrideprio, overridedprio;

--     for cx, info in pairs(fullinfos) do
--         infos = { strsplit('+', info) };

--         name = infos[1];
--         realm = infos[2];
--         fullname = infos[3];
--         overrideprio = infos[4];
--         overridedprio = infos[5];

--         interrupter = SexyInterrupter:GetInterrupter(fullname);

--         if interrupter then
--             interrupter.overrideprio = overrideprio == "true" and true or false;
--             interrupter.overridedprio = overridedprio == nil and overridedprio or tonumber(overridedprio);
--         end
--     end
-- end
