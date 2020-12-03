local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

SexyInterrupter.role_icon_tcoords = {
	DAMAGER = {0.3125, 0.63, 0.3125, 0.63},
	HEALER  = {0.3125, 0.63, 0.015625, 0.3125},
	TANK    = {0, 0.296875, 0.3125, 0.63},
	LEADER  = {0, 0.296875, 0.015625, 0.3125},
	NONE    = ""
};

function SexyInterrupter:GetInterrupter(name)
	local retVal = nil;

	for cx, value in pairs(SI_Globals.interrupters) do
		if value.fullname == name then
			retVal = value;
			break;
		end
	end

	return retVal;
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

function SexyInterrupter:GetCurrentInterrupters() 
	local interrupters = {};

	for cx, value in pairs(SI_Globals.interrupters) do
		value.pos = cx;

		if not value.lastseen or value.lastseen < (time() - 1209600) then
			tremove(SI_Globals.interrupters, cx);
		else
			if value.active and value.canInterrupt then
				tinsert(interrupters, value);	
			end
		end
	end

	table.sort(interrupters, function(a,b) 
		local retVal = false;

		if a.offline then
			retVal = false;
		else
			if b.offline then
				retVal = true;
			else
				if not a.inrange then
					retVal = false;
				else
					if not b.inrange then
						retVal = true;
					else
						if a.dead then
							retVal = false
						else 
							if b.dead then
								retVal = true;
							else
								if a.readyTime > 0 then
									if a.readyTime == b.readyTime then
										retVal = (a.overridedprio or a.prio) < (b.overridedprio or b.prio);
									else
										retVal = a.readyTime < b.readyTime;
									end
								else
									if b.readyTime > 0 then
										retVal = true;
									else
										retVal = (a.overridedprio or a.prio) < (b.overridedprio or b.prio);
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

	for cx, value in pairs(interrupters) do
		value.sortpos = cx;
	end
	
	SI_Globals.numInterrupters = table.getn(interrupters);

	return interrupters;
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
		end;	
		
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
		interrupter.active = true;
		interrupter.role = UnitGroupRolesAssigned(unit);

		if not interrupter.classEN then
			interrupter.classEN = englishClass;
		end

		if interrupter.classEN and interrupter.role ~= 'NONE' then
			interrupter.canInterrupt = self.unitCanInterrupt[strlower(interrupter.classEN)][strlower(interrupter.role)];
		else
			interrupter.canInterrupt = true;
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
		
		if UnitInRange(unit) then
			interrupter.inrange = true;
		else
			interrupter.inrange = false;
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
	local msg = L["Interrupted"] .. string.format(" %s's %s!", destName, GetSpellLink(spellId));

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

 function SexyInterrupter:LockFrame()
    self.db.profile.general.lock = not self.db.profile.general.lock;

    if self.db.profile.general.lock then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s.", L["Addon name"], L["Frame locked"]), 1, 0.5, 0);

        SexyInterrupterAnchor:Show();
        SexyInterrupterDummyAnchorFrame:Hide();
        SexyInterrupterDummyMessageFrame:Hide();

        SexyInterrupter:UpdateFrames();
    else 
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s.", L["Addon name"], L["Frame unlocked"]), 1, 0.5, 0);

        SexyInterrupterAnchor:Hide();
        SexyInterrupterDummyAnchorFrame:Show();
        SexyInterrupterDummyMessageFrame:Show();
    end
end

function SexyInterrupter:SaveAnchorPosition()
	SexyInterrupterAnchor:StopMovingOrSizing();

	local a = self.db.profile.ui.anchorPosition;

    a.point, a.region, a.relativePoint, a.x, a.y = SexyInterrupterAnchor:GetPoint();
end

function SexyInterrupter:OnMouseUp(self, button) 
	if button == "RightButton" then
		EasyMenu(SexyInterrupter.menu, SexyInterrupterMenu, "cursor", nil, nil);
	end

	if not SexyInterrupter.db.profile.general.lock then
		local frameName = self:GetName();
		local a;
		
		self:StopMovingOrSizing();

		if frameName == 'SexyInterrupterDummyAnchorFrame' then
			a = SexyInterrupter.db.profile.ui.anchorPosition;
		elseif frameName == 'SexyInterrupterDummyMessageFrame' then
			a = SexyInterrupter.db.profile.ui.messagePosition;
		end

		a.point, a.region, a.relativePoint, a.x, a.y = self:GetPoint();
	end
end

function SexyInterrupter:OnMouseDown(self, button)
	if not SexyInterrupter.db.profile.general.lock then
		self:StartMoving();
	end
end

function SexyInterrupter:ShowInterruptWarning(notInterruptible, startTime, endTime)
	if not notInterruptible and UnitCanAttack('player', 'target') then
		local name, realm = UnitName('player');
		local fullname = name;

		if realm ~= nil then
			fullname = name .. '-' .. realm;
		end

		local interrupter = SexyInterrupter:GetInterrupter(fullname);

		if interrupter.sortpos == 1 then
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
				PlaySoundFile(self.db.profile.notification.soundFile);
			end

			if self.db.profile.notification.flash then
				SexyInterrupterBlueWarningFrame:Show();
			end
		end
	end
end 