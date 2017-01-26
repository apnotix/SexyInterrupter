SexyInterrupter = LibStub("AceAddon-3.0"):NewAddon("SexyInterrupter", 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0', 'LibNotify-1.0');
local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

function SexyInterrupter:OnInitialize()
	self:InitOptions();

	self:InitializeSavedVariables();

	self:CreateUi();
	self:UpdateUI();

	self:CreateFlasher('Blue');

	self:RegisterEvent("CHAT_MSG_ADDON", "CHAT_MSG_ADDON");
	self:RegisterEvent("UNIT_FLAGS", "UNIT_FLAGS");
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "GROUP_ROSTER_UPDATE");
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_LOG_EVENT_UNFILTERED");
    self:RegisterEvent("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_START");
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_STOP");
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "PLAYER_TARGET_CHANGED");
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED");

	RegisterAddonMessagePrefix("SexyInterrupter");

	self:SetNotifyIcon("Interface\\Icons\\achievement_bg_defendxtowers_av")
	self:SetNotifyStorage(self.db.profile.versions)
	self:NotifyOnce(self.versions)

	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter ' .. self.Version .. ' loaded', 1, 0.5, 0);  
end

 function SexyInterrupter:InitializeSavedVariables()
	if not SI_Globals then
		SI_Globals = {
			interrupters = {};
			numInterrupters = 0;
		}
	end
end

function SexyInterrupter:CreateUi()
	-- Frame: Anchor
	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent);	

    f:SetSize(200, 100)
    f:SetPoint(self.db.profile.ui.anchorPosition.point, self.db.profile.ui.anchorPosition.region, self.db.profile.ui.anchorPosition.relativePoint, self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y)
	f:SetBackdrop({
        bgFile = LSM:Fetch("background", self.db.profile.ui.window.backgroundtexture), 
        edgeFile = LSM:Fetch("border", self.db.profile.ui.window.border),
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

	f:SetBackdropColor(self.db.profile.ui.window.background.r, self.db.profile.ui.window.background.g, self.db.profile.ui.window.background.b, self.db.profile.ui.window.background.a);
	f:SetBackdropBorderColor(self.db.profile.ui.window.bordercolor.r, self.db.profile.ui.window.bordercolor.g, self.db.profile.ui.window.bordercolor.b, self.db.profile.ui.window.bordercolor.a);
	f:SetScript("OnUpdate", SexyInterrupter.OnUpdate);
	
    local t = f:CreateTexture()
    t:SetTexture(0, 0, 0, 0.2)
    t:SetAllPoints(f);

	-- Frame: InterruptMessage
	local c = CreateFrame("MessageFrame", "SexyInterrupterInterruptNowText");
    c:SetFontObject(BossEmoteNormalHuge);
    c:SetWidth(500);
    c:SetHeight(50);
    c:SetPoint(self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint, self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y);

    local fontPath = c:GetFont();
    c:SetFont(fontPath, 25, "OUTLINE");
    c:SetFadeDuration(0.4);

	-- Frame: RightClickMenu
	CreateFrame("Frame", "SexyInterrupterMenu", SexyInterrupterAnchor, "UIDropDownMenuTemplate");

	-- Infight only
	if self.db.profile.general.modeincombat then
		SexyInterrupterAnchor:Hide();
	end

	-- Dummy Anchor Container
	local dummyAnchorFrame = CreateFrame("Frame", "SexyInterrupterDummyAnchorFrame", UIParent);
	dummyAnchorFrame:SetSize(200, (self.db.profile.ui.bars.barheight * 5) + 10);
    dummyAnchorFrame:SetPoint(self.db.profile.ui.anchorPosition.point, self.db.profile.ui.anchorPosition.region, self.db.profile.ui.anchorPosition.relativePoint, self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y);
	dummyAnchorFrame:SetBackdrop({
        bgFile = LSM:Fetch("background", self.db.profile.ui.window.backgroundtexture), 
        edgeFile = LSM:Fetch("border", self.db.profile.ui.window.border),
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

	dummyAnchorFrame:SetBackdropColor(self.db.profile.ui.window.background.r, self.db.profile.ui.window.background.g, self.db.profile.ui.window.background.b, self.db.profile.ui.window.background.a);
	dummyAnchorFrame:SetMovable(true);

	dummyAnchorFrame:SetScript("OnMouseDown", function(self, button) 
		SexyInterrupter:OnMouseDown(self, button);
	end);

	dummyAnchorFrame:SetScript("OnMouseUp", function(self, button) 
		SexyInterrupter:OnMouseUp(self, button);
	end);

	local dummyAnchorFrameText = dummyAnchorFrame:CreateFontString("SexyInterrupterDummyAnchorFrameText", nil, "GameFontNormal");
	dummyAnchorFrameText:SetPoint("CENTER", "SexyInterrupterDummyAnchorFrame", "CENTER")
	dummyAnchorFrameText:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE");
	dummyAnchorFrameText:SetText("SexyInterrupter Frame");
	dummyAnchorFrameText:SetSize(200, 12);
	dummyAnchorFrameText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a);

	dummyAnchorFrame:Hide();

	-- Dummy Message Container
	local dummyMessageFrame = CreateFrame("Frame", "SexyInterrupterDummyMessageFrame", UIParent);
	dummyMessageFrame:SetSize(500, 50);
    dummyMessageFrame:SetPoint(self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint, self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y);
	dummyMessageFrame:SetBackdrop({
        bgFile = LSM:Fetch("background", self.db.profile.ui.window.backgroundtexture), 
        edgeFile = LSM:Fetch("border", self.db.profile.ui.window.border),
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

	dummyMessageFrame:SetBackdropColor(self.db.profile.ui.window.background.r, self.db.profile.ui.window.background.g, self.db.profile.ui.window.background.b, self.db.profile.ui.window.background.a);
	dummyMessageFrame:SetMovable(true);
	
	dummyMessageFrame:SetScript("OnMouseDown", function(self, button) 
		SexyInterrupter:OnMouseDown(self, button);
	end);

	dummyMessageFrame:SetScript("OnMouseUp", function(self, button) 
		SexyInterrupter:OnMouseUp(self, button);
	end);

	local dummyMessageFrameText = dummyMessageFrame:CreateFontString("SexyInterrupterDummyMessageFrameText", nil, "GameFontNormal");
	dummyMessageFrameText:SetPoint("CENTER", "SexyInterrupterDummyMessageFrame", "CENTER")
	dummyMessageFrameText:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE");
	dummyMessageFrameText:SetText("SexyInterrupter Interrupt Message");
	dummyMessageFrameText:SetSize(500, 12);
	dummyMessageFrameText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a);

	dummyMessageFrame:Hide();
end

function SexyInterrupter:UpdateFrames()
	SexyInterrupterAnchor:SetPoint(self.db.profile.ui.anchorPosition.point, self.db.profile.ui.anchorPosition.region, self.db.profile.ui.anchorPosition.relativePoint, self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y);
	
	SexyInterrupterAnchor:SetBackdrop({
        bgFile = LSM:Fetch("background", self.db.profile.ui.window.backgroundtexture), 
        edgeFile = LSM:Fetch("border", self.db.profile.ui.window.border),
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

	SexyInterrupterAnchor:SetBackdropColor(self.db.profile.ui.window.background.r, self.db.profile.ui.window.background.g, self.db.profile.ui.window.background.b, self.db.profile.ui.window.background.a);
	SexyInterrupterAnchor:SetBackdropBorderColor(self.db.profile.ui.window.bordercolor.r, self.db.profile.ui.window.bordercolor.g, self.db.profile.ui.window.bordercolor.b, self.db.profile.ui.window.bordercolor.a);

	for _, child in ipairs({ SexyInterrupterAnchor:GetChildren() }) do
		if string.find(child:GetName(), "SexyInterrupterRow") then
			for _, subchild in ipairs({ child:GetChildren() }) do
				-- TODO: Font, fontcolor

				if string.find(subchild:GetName(), "SexyInterrupterStatusBar") then
					subchild:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
					subchild:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a);
				end
			end
		end
	end

	SexyInterrupterInterruptNowText:SetPoint(self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint, self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y);

	SexyInterrupter:UpdateUI();
end

function SexyInterrupter:UpdateUI() 
	for cx, value in pairs(self:GetCurrentInterrupters()) do
		if not _G["SexyInterrupterRow" .. cx] then	
			local f = CreateFrame("Frame", "SexyInterrupterRow" .. cx, SexyInterrupterAnchor);
			
			f:SetSize(20, self.db.profile.ui.bars.barheight);
			
			if (cx == 1) then
				f:SetPoint("TOPLEFT", SexyInterrupterAnchor, "TOPLEFT", 5, -(cx - 1) * self.db.profile.ui.bars.barheight - 5)
			else
				f:SetPoint("TOP", _G["SexyInterrupterRow" .. (cx - 1)], "BOTTOM")
			end
			
			local t = f:CreateTexture()
			t:SetAllPoints(f)
			t:SetTexture(0, 0, 0, 0.4)
			
			t = f:CreateFontString("SexyInterrupterNrText" .. cx, nil, "GameFontNormal")
			t:SetPoint("CENTER", "SexyInterrupterRow" .. cx, "CENTER")
			t:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE")
			t:SetText(cx);
			t:SetSize(12*3, 12);
			t:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
		
			f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. cx, _G["SexyInterrupterRow" .. cx])
			f:SetSize(170, 20)
			f:SetPoint("LEFT", "SexyInterrupterRow" .. cx, "RIGHT")
			f:SetOrientation("HORIZONTAL")
			f:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
			f:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a)
			f:SetFrameLevel(3)
			f:SetMinMaxValues(0, 1)
			f:SetValue(0)
			
			f.text = f:CreateFontString("SexyInterrupterStatusBarText" .. cx, nil, "GameFontNormal")
			f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", 5, 0)
			f.text:SetSize(180 - 5, 20)
			f.text:SetJustifyH("LEFT")
			f.text:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE")
			f.text:SetText('Dummy')

			f.cooldownText = f:CreateFontString("SexyInterrupterStatusBarCooldownText" .. cx, nil, "GameFontNormal")
			f.cooldownText:SetSize(12*3, 12)
			f.cooldownText:SetJustifyH("LEFT")
			f.cooldownText:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. cx, "RIGHT", 3, 0)
			f.cooldownText:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE")
			f.cooldownText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
		end
	end

	if SI_Globals.numInterrupters > 0 then
		if UnitInRaid('player') ~= nil then
			SexyInterrupterAnchor:Hide();
		else 
			SexyInterrupterAnchor:SetSize(200, (self.db.profile.ui.bars.barheight * SI_Globals.numInterrupters) + 10);

			if not self.db.profile.general.modeincombat then
				SexyInterrupterAnchor:Show();
			end
		end
	else 
		SexyInterrupterAnchor:Hide();
	end
end

function SexyInterrupter:UpdateInterrupterStatus()
	for cx, value in pairs(SI_Globals.interrupters) do 
		if _G["SexyInterrupterRow" .. cx] then
			_G["SexyInterrupterRow" .. cx]:Hide();
		end
	end

	local interrupters = SexyInterrupter:GetCurrentInterrupters();

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