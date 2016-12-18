local SI = SexyInterrupter;

function SI:SendAddonMessage(msg)
    local channel;

    if IsPartyLFG() then
        channel = "INSTANCE_CHAT";
    elseif IsInRaid() then
        channel = "RAID";
    elseif IsInGroup() then
        channel = "PARTY";
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
    local fullinfos = { strsplit(';', msg) };
    local infos;
    local interrupter;

    for cx, info in pairs(fullinfos) do
        infos = { strsplit('+', info) };

        interrupter = SI:GetInterrupter(infos[2] and infos[1] .. infos[2] or infos[1]);

        --print('infos[1]', infos[1]);
        --print('infos[2]', infos[2]);
        --print('infos[3]', infos[3]);
        --print('infos[4]', infos[4]);
        --print('interrupter', interrupter);

        if interrupter then
            --print('infos[2] == "true" and true or false', infos[3] == "true" and true or false);
            interrupter.overrideprio = infos[3] == "true" and true or false;
            --print('infos[3] == nil and infos[3] or tonumber(infos[3])', infos[4] == nil and infos[4] or tonumber(infos[4]))
            interrupter.overridedprio = infos[4] == nil and infos[4] or tonumber(infos[4]);
        end
    end
end