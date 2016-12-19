SexyInterrupter = {}
local SI = SexyInterrupter;
local LSM = LibStub("LibSharedMedia-3.0");
local Flasher =  {};
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SI:InitializeSavedVariables()
	if not SI_Globals then
		SI_Globals = {
			interrupters = {};
			numInterrupters = 0;
		}
	end

	if not SI_Data then
		SI_Data = {
			interrupters = {},
			general = {
				notification = {

				}
			},
			ui = {
			}
		}
	else 
		if not SI_Data.general then
			SI_Data.general = {
				notification = {

				}
			}
		end
	end
	
	SI.menu = {
		{
			text = 'SexyInterrupter',
			isTitle = true,
            notCheckable = true
		},
		{
			text = 'Locked',
			checked = SI_Data.ui.lock,
			func = function()
				SI.menu[1].checked = not SI.menu[1].checked;
				SI:LockFrame();
			end
		}
	};

	SI_Data.general.modeincombat = SI_Data.general.modeincombat or false;

	SI_Data.general.interruptmessage = SI_Data.general.interruptmessage or false;
	SI_Data.general.outputchannel = SI_Data.general.outputchannel or 'SAY';

	SI_Data.general.notification.sound = SI_Data.general.notification.sound or true;
	SI_Data.general.notification.flash = SI_Data.general.notification.flash or true;
	SI_Data.general.notification.message = SI_Data.general.notification.message or true;

	SI_Data.ui.lock = SI_Data.ui.lock or true;
	
	SI_Data.ui.anchorPosition = SI_Data.ui.anchorPosition or {
		point = 'CENTER',
		region = nil,
		relativePoint = 'CENTER',
		x = 0,
		y = -300
	};

	SI_Data.ui.messagePosition = SI_Data.ui.messagePosition or {
		point = 'CENTER',
		region = UIParent,
		relativePoint = 'CENTER',
		x = 0,
		y = 80
	};

	SI_Data.ui.barheight = SI_Data.ui.barheight or 25;

	SI_Data.ui.barcolor = SI_Data.ui.barcolor or {
		r = 0.451,
		g = 0.471,
		b = 0.435,
		a = 1
	};

	SI_Data.ui.background = SI_Data.ui.background or {
		r = 0.514,
		g = 0.514,
		b = 0,
		a = 0.453
	};

	SI_Data.ui.border = SI_Data.ui.border or 'None';

	SI_Data.ui.bordercolor = SI_Data.ui.bordercolor or {
		r = 0.3,
		g = 0.3, 
		b = 0.3
	};

	SI_Data.ui.texture = SI_Data.ui.texture or 'BantoBar';

	SI_Data.ui.font = SI_Data.ui.font or 'Accidental Presidency';

	SI_Data.ui.fontsize = SI_Data.ui.fontsize or 13;

	SI_Data.ui.fontcolor = SI_Data.ui.fontcolor or {
		r = 0.514,
		g = 0.514, 
		b = 0
	};
end

function SI:GetInterrupter(name)
	local retVal = nil;

	for cx, value in pairs(SI_Globals.interrupters) do
		if value.fullname == name then
			retVal = value;
			break;
		end
	end

	return retVal;
end

function SI:GetCurrentInterrupters() 
	local interrupters = {};

	for cx, value in pairs(SI_Globals.interrupters) do
		value.pos = cx;

		if value.active then
			tinsert(interrupters, value);	
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

		return retVal;
	end)

	for cx, value in pairs(interrupters) do
		value.sortpos = cx;
	end

	return interrupters;
end

function SI:CreateUi()
	-- Frame: Anchor
	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent);	

    f:SetSize(200, 100)
    f:SetPoint(SI_Data.ui.anchorPosition.point, SI_Data.ui.anchorPosition.region, SI_Data.ui.anchorPosition.relativePoint, SI_Data.ui.anchorPosition.x, SI_Data.ui.anchorPosition.y)
	f:SetBackdrop({
        bgFile = LSM:Fetch("background", SI_Data.ui.backgroundtexture), 
        edgeFile = LSM:Fetch("border", SI_Data.ui.border),
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = {
			left = 1,
			right = 1,
			top = 1,
			bottom = 1
		}
    });

	f:SetBackdropColor(SI_Data.ui.background.r, SI_Data.ui.background.g, SI_Data.ui.background.b, SI_Data.ui.background.a);
	f:SetScript("OnUpdate", SI.OnUpdate);
	
    local t = f:CreateTexture()
    t:SetTexture(0, 0, 0, 0.2)
    t:SetAllPoints(f);

	-- Frame: InterruptMessage
	local c = CreateFrame("MessageFrame", "SexyInterrupterInterruptNowText");
    c:SetFontObject(BossEmoteNormalHuge);
    c:SetWidth(500);
    c:SetHeight(50);
    c:SetPoint(SI_Data.ui.messagePosition.point, UIParent, SI_Data.ui.messagePosition.relativePoint, SI_Data.ui.messagePosition.x, SI_Data.ui.messagePosition.y);

    local fontPath = c:GetFont();
    c:SetFont(fontPath, 25, "OUTLINE");
    c:SetFadeDuration(0.4);

	-- Frame: RightClickMenu
	CreateFrame("Frame", "SexyInterrupterMenu", SexyInterrupterAnchor, "UIDropDownMenuTemplate");

	-- Infight only
	if SI_Data.general.modeincombat then
		SexyInterrupterAnchor:Hide();
	end

	-- Dummy Anchor Container
	local dummyAnchorFrame = CreateFrame("Frame", "SexyInterrupterDummyAnchorFrame", UIParent);
	dummyAnchorFrame:SetSize(200, (SI_Data.ui.barheight * 5) + 10);
    dummyAnchorFrame:SetPoint(SI_Data.ui.anchorPosition.point, SI_Data.ui.anchorPosition.region, SI_Data.ui.anchorPosition.relativePoint, SI_Data.ui.anchorPosition.x, SI_Data.ui.anchorPosition.y);
	dummyAnchorFrame:SetBackdrop({
        bgFile = LSM:Fetch("background", SI_Data.ui.backgroundtexture), 
        edgeFile = LSM:Fetch("border", SI_Data.ui.border),
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = {
			left = 1,
			right = 1,
			top = 1,
			bottom = 1
		}
    });

	dummyAnchorFrame:SetBackdropColor(SI_Data.ui.background.r, SI_Data.ui.background.g, SI_Data.ui.background.b, SI_Data.ui.background.a);
	dummyAnchorFrame:SetMovable(true);

	dummyAnchorFrame:SetScript("OnMouseDown", function(self, button) 
		SI:OnMouseDown(self, button);
	end);

	dummyAnchorFrame:SetScript("OnMouseUp", function(self, button) 
		SI:OnMouseUp(self, button);
	end);

	local dummyAnchorFrameText = dummyAnchorFrame:CreateFontString("SexyInterrupterDummyAnchorFrameText", nil, "GameFontNormal");
	dummyAnchorFrameText:SetPoint("CENTER", "SexyInterrupterDummyAnchorFrame", "CENTER")
	dummyAnchorFrameText:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE");
	dummyAnchorFrameText:SetText("SexyInterrupter Frame");
	dummyAnchorFrameText:SetSize(200, 12);
	dummyAnchorFrameText:SetTextColor(SI_Data.ui.fontcolor.r, SI_Data.ui.fontcolor.g, SI_Data.ui.fontcolor.b, SI_Data.ui.fontcolor.a);

	dummyAnchorFrame:Hide();

	-- Dummy Message Container
	local dummyMessageFrame = CreateFrame("Frame", "SexyInterrupterDummyMessageFrame", UIParent);
	dummyMessageFrame:SetSize(500, 50);
    dummyMessageFrame:SetPoint(SI_Data.ui.messagePosition.point, UIParent, SI_Data.ui.messagePosition.relativePoint, SI_Data.ui.messagePosition.x, SI_Data.ui.messagePosition.y);
	dummyMessageFrame:SetBackdrop({
        bgFile = LSM:Fetch("background", SI_Data.ui.backgroundtexture), 
        edgeFile = LSM:Fetch("border", SI_Data.ui.border),
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = {
			left = 1,
			right = 1,
			top = 1,
			bottom = 1
		}
    });

	dummyMessageFrame:SetBackdropColor(SI_Data.ui.background.r, SI_Data.ui.background.g, SI_Data.ui.background.b, SI_Data.ui.background.a);
	dummyMessageFrame:SetMovable(true);
	
	dummyMessageFrame:SetScript("OnMouseDown", function(self, button) 
		SI:OnMouseDown(self, button);
	end);

	dummyMessageFrame:SetScript("OnMouseUp", function(self, button) 
		SI:OnMouseUp(self, button);
	end);

	local dummyMessageFrameText = dummyMessageFrame:CreateFontString("SexyInterrupterDummyMessageFrameText", nil, "GameFontNormal");
	dummyMessageFrameText:SetPoint("CENTER", "SexyInterrupterDummyMessageFrame", "CENTER")
	dummyMessageFrameText:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE");
	dummyMessageFrameText:SetText("SexyInterrupter Interrupt Message");
	dummyMessageFrameText:SetSize(500, 12);
	dummyMessageFrameText:SetTextColor(SI_Data.ui.fontcolor.r, SI_Data.ui.fontcolor.g, SI_Data.ui.fontcolor.b, SI_Data.ui.fontcolor.a);

	dummyMessageFrame:Hide();
end

function SI:UpdateFrames()
	SexyInterrupterAnchor:SetPoint(SI_Data.ui.anchorPosition.point, SI_Data.ui.anchorPosition.region, SI_Data.ui.anchorPosition.relativePoint, SI_Data.ui.anchorPosition.x, SI_Data.ui.anchorPosition.y);
	SexyInterrupterAnchor:SetBackdropColor(SI_Data.ui.background.r, SI_Data.ui.background.g, SI_Data.ui.background.b, SI_Data.ui.background.a);
	SexyInterrupterAnchor:SetBackdrop({
        bgFile = LSM:Fetch("background", SI_Data.ui.backgroundtexture), 
        edgeFile = LSM:Fetch("border", SI_Data.ui.border),
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = {
			left = 1,
			right = 1,
			top = 1,
			bottom = 1
		}
    });

	for _, child in ipairs({ SexyInterrupterAnchor:GetChildren() }) do
		if string.find(child:GetName(), "SexyInterrupterRow") then
			for _, subchild in ipairs({ child:GetChildren() }) do
				-- TODO: Font, fontcolor

				if string.find(subchild:GetName(), "SexyInterrupterStatusBar") then
					subchild:SetStatusBarTexture(LSM:Fetch("statusbar", SI_Data.ui.texture));
					subchild:SetStatusBarColor(SI_Data.ui.barcolor.r, SI_Data.ui.barcolor.g, SI_Data.ui.barcolor.b, SI_Data.ui.barcolor.a);
				end
			end
		end
	end

	SexyInterrupterInterruptNowText:SetPoint(SI_Data.ui.messagePosition.point, UIParent, SI_Data.ui.messagePosition.relativePoint, SI_Data.ui.messagePosition.x, SI_Data.ui.messagePosition.y);

	SI:UpdateUI();
end

function SI:UpdateUI() 
	for cx, value in pairs(SI:GetCurrentInterrupters()) do
		if not _G["SexyInterrupterRow" .. cx] then	
			local f = CreateFrame("Frame", "SexyInterrupterRow" .. cx, SexyInterrupterAnchor);
			
			f:SetSize(20, SI_Data.ui.barheight);
			
			if (cx == 1) then
				f:SetPoint("TOPLEFT", SexyInterrupterAnchor, "TOPLEFT", 5, -(cx - 1) * SI_Data.ui.barheight - 5)
			else
				f:SetPoint("TOP", _G["SexyInterrupterRow" .. (cx - 1)], "BOTTOM")
			end
			
			local t = f:CreateTexture()
			t:SetAllPoints(f)
			t:SetTexture(0, 0, 0, 0.4)
			
			t = f:CreateFontString("SexyInterrupterNrText" .. cx, nil, "GameFontNormal")
			t:SetPoint("CENTER", "SexyInterrupterRow" .. cx, "CENTER")
			t:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE")
			t:SetText(cx);
			t:SetSize(12*3, 12);
			t:SetTextColor(SI_Data.ui.fontcolor.r, SI_Data.ui.fontcolor.g, SI_Data.ui.fontcolor.b, SI_Data.ui.fontcolor.a)
		
			f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. cx, _G["SexyInterrupterRow" .. cx])
			f:SetSize(170, 20)
			f:SetPoint("LEFT", "SexyInterrupterRow" .. cx, "RIGHT")
			f:SetOrientation("HORIZONTAL")
			f:SetStatusBarTexture(LSM:Fetch("statusbar", SI_Data.ui.texture));
			f:SetStatusBarColor(SI_Data.ui.barcolor.r, SI_Data.ui.barcolor.g, SI_Data.ui.barcolor.b, SI_Data.ui.barcolor.a)
			f:SetFrameLevel(3)
			f:SetMinMaxValues(0, 1)
			f:SetValue(0)
			
			f.text = f:CreateFontString("SexyInterrupterStatusBarText" .. cx, nil, "GameFontNormal")
			f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", 5, 0)
			f.text:SetSize(180 - 5, 20)
			f.text:SetJustifyH("LEFT")
			f.text:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE")
			f.text:SetText('Dummy')

			f.cooldownText = f:CreateFontString("SexyInterrupterStatusBarCooldownText" .. cx, nil, "GameFontNormal")
			f.cooldownText:SetSize(12*3, 12)
			f.cooldownText:SetJustifyH("LEFT")
			f.cooldownText:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. cx, "RIGHT", 3, 0)
			f.cooldownText:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE")
			f.cooldownText:SetTextColor(SI_Data.ui.fontcolor.r, SI_Data.ui.fontcolor.g, SI_Data.ui.fontcolor.b, SI_Data.ui.fontcolor.a)
		end
	end

	if SI_Globals.numInterrupters > 0 then
		if UnitInRaid('player') ~= nil then
			SexyInterrupterAnchor:Hide();
		else 
			SexyInterrupterAnchor:SetSize(200, (SI_Data.ui.barheight * SI_Globals.numInterrupters) + 10);

			if not SI_Data.general.modeincombat then
				SexyInterrupterAnchor:Show();
			end
		end
	else 
		SexyInterrupterAnchor:Hide();
	end
end

function SI:UpdateInterrupterStatus()
	for cx, value in pairs(SI_Globals.interrupters) do 
		if _G["SexyInterrupterRow" .. cx] then
			_G["SexyInterrupterRow" .. cx]:Hide();
		end
	end

	local interrupters = SI:GetCurrentInterrupters();

	for cx, value in pairs(interrupters) do
		--DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: ' .. value.name, 1, 0.5, 0);
		local interrupter = value;
		local row = _G["SexyInterrupterStatusBar" .. cx];
		local rowParent = _G["SexyInterrupterRow" .. cx];

		if rowParent then
			rowParent:Show();
		end

		if row and rowParent then
			row:SetValue(0);
			row.cooldownText:SetText();

			if interrupter.offline then
				rowParent:Hide();
			elseif interrupter.dead then
				row.text:SetTextColor(1, 0, 0, 1);
			elseif interrupter.afk then
				row.text:SetTextColor(1, 1, 0, 1);
			else 		
				if interrupter.classColor then	
            		row.text:SetTextColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
				end
			end

			if interrupter.cooldown > 0 then
				row:SetMinMaxValues(0, interrupter.cooldown);
				row.cooldownText:Show();

				if interrupter.readyTime - GetTime() > 0 then
					row.cooldownText:SetText(interrupter.readyTime - GetTime());
					row:SetValue(interrupter.readyTime - GetTime());
				end
			else 
				row.cooldownText:Hide();
			end
			
			row.text:SetText(interrupter.name);
		end
	end
end

function SI:UpdateInterrupters()
	SI_Globals.numInterrupters = GetNumGroupMembers();	
	local currentMember = {};

	-- Update active state
	for cx, value in pairs(SI_Globals.interrupters) do
		value.active = false;
	end

	for i = 1, GetNumGroupMembers() do
		local unit = "party" .. i		
		
		if not UnitExists(unit) then	
			unit = 'player'
		end;	
		
		local name, realm = UnitName(unit);
		local fullname = name;

		if realm ~= nil then
			fullname = name .. '-' .. realm;
		end

		local interrupter = SI:GetInterrupter(fullname);

		if interrupter == nil then
			local class, classFileName = UnitClass(unit);
			local color = RAID_CLASS_COLORS[classFileName];

			interrupter = {};
			
			interrupter.name = name;
			interrupter.realm = realm;
			interrupter.fullname = fullname;
			interrupter.class = class;
			interrupter.classColor = color;
			interrupter.cooldown = 0;
			interrupter.readyTime = 0;
			interrupter.overrideprio = false;

			tinsert(SI_Globals.interrupters, interrupter);
		end

		interrupter = SI:GetInterrupter(fullname);

		interrupter.active = true;
		interrupter.role = UnitGroupRolesAssigned(unit);
		
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
	end

	SI:SendAddonMessage("versioninfo:" .. SI.Version);

	if UnitIsGroupLeader("player") then
		SI:SendOverridePrioInfos();
	end
end

function SI:InterruptUsed(name, cooldown, spellName)
	local interrupter = SI:GetInterrupter(name);

	if interrupter then
		interrupter.cooldown = cooldown;
		interrupter.readyTime = GetTime() + cooldown;

		SI:UpdateInterrupterStatus();
	end
end

function SI:ShowInterruptMessage(destName, spellId, spellName)
	local output = SI_Data.general.outputchannel;
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

function SI:OnUpdate()
	for cx, value in pairs(SI:GetCurrentInterrupters()) do
        if value.readyTime > 0 then
			local bar = _G["SexyInterrupterStatusBar" .. cx];

			if bar then			
				if (value.readyTime - GetTime() <= 0) then
					bar.cooldownText:SetText('');
					value.readyTime = 0;
					bar:SetValue(0);
					return;
				end

				bar:SetValue(value.readyTime - GetTime());
				bar.cooldownText:SetText(string.format('%.1f', value.readyTime - GetTime()));
			end
		end
	end
end

function SI_UNIT_FLAGS() 
	SI_GROUP_ROSTER_UPDATE();
end

function SI_GROUP_ROSTER_UPDATE()
	SI:UpdateInterrupters();
	SI:UpdateUI();
	SI:UpdateInterrupterStatus();

	SI:UpdateInterrupterSettings();
end

function SI_OnEvent(self, event, ...)
    if (_G["SI_" .. event]) then
        _G["SI_" .. event](...)
    else
        print("Unhandled event registered by InterruptManager: " .. event)
    end
end

function SI_COMBAT_LOG_EVENT_UNFILTERED(...)
	local event = select(2, ...)
    local sourceGUID = select(4, ...)
    local sourceName = select(5, ...)
	local destName = select(9, ...)
    local spellId = select(12, ...)
    local spellName = select(13, ...)
	local spells = { 132409, 119911, 116705, 147362, 96231, 106839, 78675, 47528, 2139, 1766, 57994, 119910, 6552, 15487, 171138 };
    
    if event == "SPELL_CAST_SUCCESS" then
        if (tContains(spells, spellId)) then
			local cooldown = GetSpellBaseCooldown(spellId);

			SI:InterruptUsed(sourceName, cooldown / 1000);
        end
    elseif event == 'SPELL_INTERRUPT' then
		spellId = select(15, ...);
		spellName = select(16, ...);

		if SI_Data.general.interruptmessage and (sourceGUID == UnitGUID('player') or sourceGUID == UnitGUID('pet')) then
			SI:ShowInterruptMessage(destName, spellId, spellName);
		end
	end
end

function SI_ADDON_LOADED(...)
    local addonName = ...

	if addonName == 'SexyInterrupter' then
    	SI:OnLoad()
	end
end

function SI_UNIT_SPELLCAST_START(...)
	local unit = ...
	
	if (unit == "target" and SI_Globals.numInterrupters > 0) then
        local startTime, endTime, _, _, interruptImmune = select(5, UnitCastingInfo("target"));

		if not interruptImmune and UnitCanAttack('player', 'target') then
			local name, realm = UnitName('player');
			local fullname = name;

			if realm ~= nil then
				fullname = name .. '-' .. realm;
			end

			local interrupter = SI:GetInterrupter(fullname);

			if interrupter.sortpos == 1 then
				local timeVisible = 10;

                if (startTime and endTime and endTime/1000 - startTime/1000 < 10) then
                    timeVisible = endTime - startTime
                end

				local tName = UnitName('target');

				if SI_Data.general.notification.message then
					local text = L["Interrupt now"] .. ' |cFFFF0000' .. tName .. '|r !!';
					SexyInterrupterInterruptNowText:AddMessage(text, 1,1,1);
					SexyInterrupterInterruptNowText:SetTimeVisible(timeVisible);
					SexyInterrupterInterruptNowText.text = text;
				end

				if SI_Data.general.notification.sound then
					PlaySoundFile("Sound\\Spells\\PVPFlagTaken.ogg");
				end

				if SI_Data.general.notification.flash then
					SexyInterrupterBlueWarningFrame:Show();
				end
			end
		end
	end
end

function SI_UNIT_SPELLCAST_STOP(...)
    local unit = ...
    
    if unit == "target" and SexyInterrupterInterruptNowText:IsVisible() then
        SexyInterrupterInterruptNowText:SetTimeVisible(0);

		SexyInterrupterBlueWarningFrame:Hide();
	end
end

function SI_PLAYER_TARGET_CHANGED()
    if SexyInterrupterInterruptNowText:IsVisible() then
        SexyInterrupterInterruptNowText:SetTimeVisible(0);
		
		SexyInterrupterBlueWarningFrame:Hide();
    end
end

function SI_PLAYER_REGEN_DISABLED() 
	if SI_Data.general.modeincombat then
		SexyInterrupterAnchor:Show();
	end
end

function SI_PLAYER_REGEN_ENABLED() 
	if SI_Data.general.modeincombat then
		SexyInterrupterAnchor:Hide();
	end
end

function SI_CHAT_MSG_ADDON(...)
    local prefix = ...
	local msg, _, sender, noRealmNameSender = select(2, ...);

    if prefix == "SexyInterrupter" and not strfind(sender, UnitName("player")) then
        SI:AddonMessageReceived(...)
    end
end

local SIframe = CreateFrame("Frame");
SIframe:SetScript("OnEvent", SI_OnEvent);
SIframe:RegisterEvent("ADDON_LOADED");

function SI:SaveAnchorPosition()
	SexyInterrupterAnchor:StopMovingOrSizing();

	local a = SI_Data.ui.anchorPosition;

    a.point, a.region, a.relativePoint, a.x, a.y = SexyInterrupterAnchor:GetPoint();
end

function SI:OnMouseUp(self, button) 
	if button == "RightButton" then
		EasyMenu(SI.menu, SexyInterrupterMenu, "cursor", nil, nil);
	end

	if not SI_Data.ui.lock then
		local frameName = self:GetName();
		local a;
		
		self:StopMovingOrSizing();

		if frameName == 'SexyInterrupterDummyAnchorFrame' then
			a = SI_Data.ui.anchorPosition;
		elseif frameName == 'SexyInterrupterDummyMessageFrame' then
			a = SI_Data.ui.messagePosition;
		end

		a.point, a.region, a.relativePoint, a.x, a.y = self:GetPoint();
	end
end

function SI:OnMouseDown(self, button)
	if not SI_Data.ui.lock then
		self:StartMoving();
	end
end

function SI:OnLoad()
	SI:InitializeSavedVariables();

	SI:CreateUi();
	SI:UpdateUI();
	
	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter ' .. SI.Version .. ' loaded', 1, 0.5, 0);

	SI:InitOptions();

	SI:CreateFlasher('Blue');
	
	SIframe:UnregisterEvent("ADDON_LOADED");
	--SIframe:RegisterEvent("PLAYER_ENTERING_WORLD");
	SIframe:RegisterEvent("CHAT_MSG_ADDON");
	SIframe:RegisterEvent("UNIT_FLAGS");
	SIframe:RegisterEvent("GROUP_ROSTER_UPDATE");
	SIframe:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    SIframe:RegisterEvent("UNIT_SPELLCAST_START");
    SIframe:RegisterEvent("UNIT_SPELLCAST_STOP");
	SIframe:RegisterEvent("PLAYER_TARGET_CHANGED");
	SIframe:RegisterEvent("PLAYER_REGEN_DISABLED");
	SIframe:RegisterEvent("PLAYER_REGEN_ENABLED");

	RegisterAddonMessagePrefix("SexyInterrupter");
end

function SI:CreateFlasher(color)
    local frameImage = "None";

    if color == "Blue" then
        frameImage = "Interface\\FullScreenTextures\\OutofControl";
    elseif color == "Red" then
        frameImage = "Interface\\FullScreenTextures\\LowHealth";
    else
        frameImage = nil;
    end

    local frameName = "SexyInterrupter" .. color .. "WarningFrame";

    if not ((Flasher[color]) and (frameImage)) then
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
