local SI = SexyInterrupter;
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SexyInterrupter:SendAddonMessage(msg)
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
    	C_ChatInfo.SendAddonMessage("SexyInterrupter", msg, channel);
	end
end

function SexyInterrupter:AddonMessageReceived(msg, sender)
    if (strfind(msg, "overrideprio:")) then
        msg = gsub(msg, "overrideprio:", "");

        SexyInterrupter:ReceiveOverridePrioInfos(msg, sender);
    elseif (strfind(msg, "versioninfo:")) then
		msg = gsub(msg, "versioninfo:", "");

        SexyInterrupter:ReceiveVersionInfo(msg, sender);
    elseif (strfind(msg, "requesttalents:")) then
        msg = gsub(msg, "requesttalents:", "");

        SexyInterrupter:SendTalents(msg, sender);
    elseif (strfind(msg, "talents:")) then
        msg = gsub(msg, "talents:", "");

		SexyInterrupter:ReceiveTalents(msg, sender);
    elseif (strfind(msg, "interrupt:")) then
        msg = gsub(msg, "interrupt:", "");

		SexyInterrupter:ReceiveInterrupt(msg, sender);
    end
end

function SexyInterrupter:SendTalents(msg, sender)
    local player = UnitName("player");

    if (strfind(msg, player)) then
        local msg = "talents:";

        msg = msg .. player .. ';';

        for talentRow = 1, 7 do
            for talentCol = 1, 3 do
                local _, name, _, sel, _, id = GetTalentInfo(talentRow, talentCol, 1);

                if sel then
                    msg = msg .. tostring(id) .. '+';
                end
            end
        end

        SexyInterrupter:SendAddonMessage(msg:sub(1, -2));
    end
end

function SexyInterrupter:SendInterrupt(player, readyTime)
    local msg = "interrupt:";

    msg = msg .. player .. ';' .. readyTime;

    SexyInterrupter:SendAddonMessage(msg);
end

function SexyInterrupter:ReceiveInterrupt(msg, sender) 
    local infos = { strsplit(';', msg) };
    local interrupter = SexyInterrupter:GetInterrupter(infos[1]);
    
    if interrupter and (interrupter.readyTime == 0 or interrupter.readyTime == nil) then 
        local cooldown = tonumber(infos[2]);

        interrupter.readyTime = cooldown + GetTime();
        interrupter.cooldown = cooldown;

        SexyInterrupter:UpdateInterrupterStatus();
    end
end

function SexyInterrupter:ReceiveTalents(msg, sender)
    local infos = { strsplit(';', msg) };
    local interrupter = SexyInterrupter:GetInterrupter(infos[1]);
    
    if interrupter then    
        interrupter.active = true;    
        interrupter.talents = infos[2];
    end
end

function SexyInterrupter:ReceiveVersionInfo(msg, sender)
	local currentVersion = tonumber(SexyInterrupter.Version);
	local receivedVersion = tonumber(msg);

	if receivedVersion > currentVersion and not SexyInterrupter.newVersionNoticed then
        -- self:SetNotifyIcon("Interface\\Icons\\achievement_bg_defendxtowers_av")
        -- self:Notify("SexyInterrupter: " .. L["New Update"], L["An update is available v"] .. receivedVersion .. ". " .. L["Please update to the latest version!"], nil, receivedVersion);
        DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: ' .. L["An update is available v"] .. receivedVersion .. ". " .. L["Please update to the latest version!"], 1, 0.5, 0);

		SexyInterrupter.newVersionNoticed = true;
	end
end

function SexyInterrupter:ReceiveOverridePrioInfos(msg, sender) 
    local fullinfos = { strsplit(';', msg) };
    local infos;
    local interrupter;
    local name, realm, fullname, overrideprio, overridedprio;

    for cx, info in pairs(fullinfos) do
        infos = { strsplit('+', info) };

        name = infos[1];
        realm = infos[2];
        fullname = infos[3];
        overrideprio = infos[4];
        overridedprio = infos[5];

        interrupter = SexyInterrupter:GetInterrupter(fullname);

        if interrupter then
            interrupter.overrideprio = overrideprio == "true" and true or false;
            interrupter.overridedprio = overridedprio == nil and overridedprio or tonumber(overridedprio);
        end
    end
end