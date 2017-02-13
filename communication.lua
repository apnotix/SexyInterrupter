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
    	SendAddonMessage("SexyInterrupter", msg, channel);
	end
end

function SexyInterrupter:AddonMessageReceived(...)
	local msg, _, sender, noRealmNameSender = select(3, ...)

    if (strfind(msg, "overrideprio:")) then
        msg = gsub(msg, "overrideprio:", "");

        SexyInterrupter:ReceiveOverridePrioInfos(msg, sender);
    elseif (strfind(msg, "versioninfo:")) then
		msg = gsub(msg, "versioninfo:", "");

		SexyInterrupter:ReceiveVersionInfo(msg, sender);
	end
end

function SexyInterrupter:ReceiveVersionInfo(msg, sender)
	local currentVersion = tonumber(SexyInterrupter.Version);
	local receivedVersion = tonumber(msg);

	if receivedVersion > currentVersion and not SexyInterrupter.newVersionNoticed then
        self:SetNotifyIcon("Interface\\Icons\\achievement_bg_defendxtowers_av")
        self:Notify("SexyInterrupter: " .. L["New Update"], L["An update is available v"] .. receivedVersion .. ". " .. L["Please update to the latest version!"], nil, receivedVersion);

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