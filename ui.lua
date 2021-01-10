function SexyInterrupter:CreateUi()
	-- Frame: Anchor
	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil);	

    f:SetSize(self.db.profile.ui.window.width, 100)
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
	local dummyAnchorFrame = CreateFrame("Frame", "SexyInterrupterDummyAnchorFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil);
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
	local dummyMessageFrame = CreateFrame("Frame", "SexyInterrupterDummyMessageFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil);
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
					subchild:SetSize(self.db.profile.ui.window.width - 10, self.db.profile.ui.bars.barheight)
					subchild:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
					subchild:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a);

					if not self.db.profile.ui.bars.showclassicon then
						subchild.classicon:Hide();
					else 
						subchild.classicon:Show();
					end

					subchild.text:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE");
					subchild.cooldownText:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE")
					subchild.cooldownText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
				end
			end
		end
	end

	SexyInterrupterInterruptNowText:SetPoint(self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint, self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y);

	SexyInterrupter:UpdateUI();
	SexyInterrupter:UpdateInterrupterStatus();
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
			
			-- f.nr = f:CreateFontString("SexyInterrupterNrText" .. cx, nil, "GameFontNormal")
			-- f.nr:SetPoint("CENTER", "SexyInterrupterRow" .. cx, "CENTER")
			-- f.nr:SetFont(self.db.profile.ui.font, self.db.profile.ui.fontsize, "OUTLINE")
			-- f.nr:SetText(cx);
			-- f.nr:SetSize(12*3, 12);
			-- f.nr:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
		
			f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. cx, _G["SexyInterrupterRow" .. cx])
			f:SetSize(self.db.profile.ui.window.width - 10, self.db.profile.ui.bars.barheight)
			f:SetPoint("LEFT", "SexyInterrupterRow" .. cx, "LEFT")
			f:SetOrientation("HORIZONTAL")
			f:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
			f:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a)
			f:SetFrameLevel(3)
			f:SetMinMaxValues(0, 100)
			f:SetValue(100)
			
			f.classicon = f:CreateTexture(nil, "OVERLAY");
			f.classicon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
			f.classicon:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", 2, 0);
			f.classicon:SetTexCoord(unpack(self.role_icon_tcoords.DAMAGER));
			f.classicon:SetSize(16, 16);
			
			f.text = f:CreateFontString("SexyInterrupterStatusBarText" .. cx, nil, "GameFontNormal")
			f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", self.db.profile.ui.bars.showclassicon and 25 or 5, 0)
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
		local maxRows = 0;

		for cx, value in pairs(SI_Globals.interrupters) do 
			if value.active and value.canInterrupt and value.offline ~= true then
				maxRows = maxRows + 1;
			end
		end

		if maxRows > self.db.profile.general.maxrows then
			maxRows = self.db.profile.general.maxrows;
		end

		SexyInterrupterAnchor:SetSize(self.db.profile.ui.window.width, (self.db.profile.ui.bars.barheight * maxRows) + 10);

		if not self.db.profile.general.modeincombat then
			SexyInterrupterAnchor:Show();
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

	local currentplayer = SexyInterrupter:GetInterrupter(select(1, UnitName("player")));
	local interrupters = SexyInterrupter:GetCurrentInterrupters();

	for cx, value in pairs(interrupters) do
		local interrupter = value;
		local row = _G["SexyInterrupterStatusBar" .. cx];
		local rowParent = _G["SexyInterrupterRow" .. cx];

		if rowParent and self.db.profile.general.maxrows >= cx then
			rowParent:Show();
		end

		if currentplayer.sortpos > self.db.profile.general.maxrows and self.db.profile.general.maxrows == cx then
			interrupter = currentplayer;

			-- rowParent.nr:SetText(currentplayer.sortpos);
			rowParent:SetAlpha(0.5);
		else 
			-- rowParent.nr:SetText(cx);
			rowParent:SetAlpha(1);
		end

		if row and rowParent then
			row:SetMinMaxValues(0, 100);
			row:SetValue(100);
			row.cooldownText:SetText();

			if self.db.profile.ui.bars.useclasscolor then
				row:SetStatusBarColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
			end

			if interrupter.offline then
				rowParent:Hide();
			elseif interrupter.dead then
				row.text:SetTextColor(1, 0, 0, 1);
			elseif interrupter.afk then
				row.text:SetTextColor(1, 1, 0, 1);
			elseif not interrupter.inrange then
				row.text:SetTextColor(1, 1, 1, 0.3);
			else 		
				if interrupter.classColor and self.db.profile.ui.useclasscolor then
            		row.text:SetTextColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
				else 
					row.text:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, 1);
				end
			end

			if not self.db.profile.ui.bars.showclassicon or not interrupter.role or interrupter.role == 'NONE' then
				row.classicon:Hide();
			else
				row.classicon:SetTexCoord(unpack(self.role_icon_tcoords[interrupter.role]));
			end

			if interrupter.cooldown > 0 then
				row:SetMinMaxValues(0, interrupter.cooldown);
				row.cooldownText:Show();

				if interrupter.readyTime - GetTime() > 0 then
					local readyTime = interrupter.readyTime - GetTime();

					row.cooldownText:SetText(readyTime);
					row:SetValue(readyTime);
				end
			else 
				row.cooldownText:Hide();
			end
			
			row.text:SetText(interrupter.name);
		end
	end
end

function SexyInterrupter:OnUpdate()
	local currentplayer = SexyInterrupter:GetInterrupter(select(1, UnitName("player")));

	for cx, value in pairs(SexyInterrupter:GetCurrentInterrupters()) do
		if currentplayer and currentplayer.sortpos > SexyInterrupter.db.profile.general.maxrows and SexyInterrupter.db.profile.general.maxrows == cx then
			value = currentplayer;
		end

        if value.readyTime > 0 then
			local bar = _G["SexyInterrupterStatusBar" .. cx];

			if bar then			
				if (value.readyTime - GetTime() <= 0) then
					bar.cooldownText:SetText('');
					value.readyTime = 0;
					
					bar:SetMinMaxValues(0, 100);
					bar:SetValue(100);
					return;
				end

				local cooldownText = value.readyTime - GetTime();

				bar:SetValue(cooldownText);
				bar.cooldownText:SetText(string.format('%.1f', cooldownText));
			end
		end
	end
end