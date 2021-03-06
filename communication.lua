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
        local prefix, player, realm, message = select(2, SexyInterrupter:Deserialize(data));

        if prefix == 'versioninfo' then
            SexyInterrupter:ReceiveVersionInfo(player, realm, message);
        elseif prefix == 'requestuser' then
            SexyInterrupter:SendUserInformation(player, realm, message);
        elseif prefix == 'userinfos' then
            SexyInterrupter:ReceiveUserInformation(player, realm, message);
        elseif prefix == 'interrupt' then
            SexyInterrupter:ReceiveInterrupt(player, realm, message);
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
    infos.role = GetSpecializationRole(GetSpecialization());

    if infos.role == nil then        
        infos.role = UnitGroupRolesAssigned("player");
    end

    local talents = '';

    for talentRow = 1, 7 do
        for talentCol = 1, 3 do
            local talentID, name, texture, selected, available = GetTalentInfo(talentRow, talentCol, 1);

            if selected then
                talents = talents .. '+' .. talentID;
                break;
            end
        end
    end

    infos.talents = talents;

    SexyInterrupter:SendMessage('userinfos', infos);
end

function SexyInterrupter:ReceiveUserInformation(player, realm, infos)
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
        interrupter.canInterrupt = self.unitCanInterrupt[strlower(interrupter.classEN)][strlower(interrupter.role)];
    else
        interrupter.canInterrupt = true;
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
end

function SexyInterrupter:ReceiveVersionInfo(player, realm, version)
	local currentVersion = tonumber(SexyInterrupter.Version);
	local receivedVersion = tonumber(version);

	if receivedVersion > currentVersion and not SexyInterrupter.newVersionNoticed then
        DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: ' .. L["An update is available v"] .. receivedVersion .. ". " .. L["Please update to the latest version!"], 1, 0.5, 0);

		SexyInterrupter.newVersionNoticed = true;
	end
end

function SexyInterrupter:SendInterrupt(player, cooldown)
    SexyInterrupter:SendMessage('interrupt', cooldown);
end

function SexyInterrupter:ReceiveInterrupt(player, realm, cooldown)
    local interrupter = SexyInterrupter:GetInterrupter(player, realm);
    
    if interrupter and (interrupter.readyTime == 0 or interrupter.readyTime == nil) then 
        cooldown = tonumber(cooldown);

        interrupter.readyTime = cooldown + GetTime();
        interrupter.cooldown = cooldown;

        SexyInterrupter:UpdateInterrupterStatus();
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