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
    local name, realm, fullname, overrideprio, overridedprio;

    for cx, info in pairs(fullinfos) do
        infos = { strsplit('+', info) };

        name = infos[1];
        realm = infos[2];
        fullname = infos[3];
        overrideprio = infos[4];
        overridedprio = infos[5];

        interrupter = SI:GetInterrupter(realm and fullname or name);

        print('name', name);
        print('realm', realm);
        print('fullname', fullname);
        print('overrideprio', overrideprio);
        print('overridedprio', overridedprio);
        print('interrupter', interrupter);

        if interrupter then
            interrupter.overrideprio = overrideprio == "true" and true or false;
            interrupter.overridedprio = overridedprio == nil and overridedprio or tonumber(overridedprio);
        end
    end
end