local SI = SexyInterrupter;

function SI:SendAddonMessage(msg)
    local channel;

    if (IsInRaid()) then
        channel = "RAID"
    elseif (IsInGroup()) then
        channel = "PARTY"
    end
    
	if channel then
    	SendAddonMessage("SexyInterrupter", msg, channel);
	end
end

function SI:AddonMessageReceived(...)
	local msg, _, sender, noRealmNameSender = select(2, ...)

    --if (strfind(sender, UnitName("player"))) then return end 

    if (strfind(msg, "overrideprio:")) then
        msg = gsub(msg, "overrideprio:", "");

        SI:ReceiveOverridePrioInfos(msg, sender);
    elseif (strfind(msg, "versioninfo:")) then
		msg = gsub(msg, "versioninfo:", "");

		SI:ReceiveVersionInfo(msg, sender);
	end
end

function SI:ReceiveVersionInfo(msg, sender)
	local currentVersion = tonumber(SI.Version);
	local receivedVersion = tonumber(msg);

	if receivedVersion > currentVersion and not SI.newVersionNoticed then
		DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: An update is available V" .. receivedVersion, 1, 0.5, 0);
		SI.newVersionNoticed = true;
	end
end

function SI:ReceiveOverridePrioInfos(msg, sender) 
    local fullinfos = strsplit(';', msg);
    local infos;
    local interrupter;

    for cx, info in pairs(fullinfos) do
        infos = strsplit('+', info);

        if not strfind(infos[0], UnitName("player")) then
            interrupter = SI:GetInterrupter(infos[0]);
            
            if interrupter then
                interrupter.overrideprio = infos[1];
                interrupter.overridedprio = infos[2];
            end
        end 
    end
end