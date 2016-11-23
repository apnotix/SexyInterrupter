SexyInterrupter = {}
local SI = SexyInterrupter

function SI:InitializeSavedVariables()
	if (not SI_Globals) then
		SI_Globals = {
			interrupters = {};
			numInterrupters = 0;
		}
	end

	if (not SI_Data) then
		SI_Data = {
			interrupters = {},
			ui = {
				lock = true,
				anchorPosition = {
					point = 'CENTER',
					region = nil,
					relativePoint = 'CENTER',
					x = 0,
					y = -300
				},
				background = {
					r = 0,
					g = 0,
					b = 0,
					a = 0.4
				},
				texture = 'BantoBar',
				font = 'Accidental Presidency',
				fontsize = 13,
				fontcolor = {
					r = 0.3,
					g = 0.3, 
					b = 0.3,
					a = 0.6
				}
			}
		}
	end
end

function SI:GetVersion() return '1.0.0' end

function SI:GetInterrupter(name, realm)
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
	local retVal = {};

	for cx, value in pairs(SI_Globals.interrupters) do
		value.pos = cx;

		if value.active then
			tinsert(retVal, value);	
		end
	end

	return retVal;
end

function SI:UpdateUI() 
	for cx, value in pairs(SI:GetCurrentInterrupters()) do
		if (not _G["SexyInterrupterRow" .. value.pos]) then	
			local interrupter = value;
			local f = CreateFrame("Frame", "SexyInterrupterRow" .. value.pos, SexyInterrupterAnchor)
			
			f:SetSize(20, 20)
			
			if (cx == 1) then
                f:SetPoint("TOPLEFT", SexyInterrupterAnchor, "TOPLEFT", 0, -(cx - 1) * 20)
            else
                f:SetPoint("TOP", _G["SexyInterrupterRow" .. (value.pos - 1)], "BOTTOM")
            end
			
			local t = f:CreateTexture()
            t:SetAllPoints(f)
            t:SetTexture(0, 0, 0, 0.4)
            
            t = f:CreateFontString()
            t:SetPoint("CENTER", "SexyInterrupterRow" .. value.pos, "CENTER")
			t:SetFont("Fonts\\FRIZQT__.TTF", SI_Data.ui.fontsize, "OUTLINE")
            t:SetText(cx);
            t:SetTextColor(SI_Data.ui.fontcolor.r, SI_Data.ui.fontcolor.g, SI_Data.ui.fontcolor.b, SI_Data.ui.fontcolor.a)
        
            f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. value.pos, _G["SexyInterrupterRow" .. value.pos])
            f:SetSize(180, 20)
            f:SetPoint("LEFT", "SexyInterrupterRow" .. value.pos, "RIGHT")
            f:SetOrientation("HORIZONTAL")
            f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            f:SetStatusBarColor(0, 1, 0, 1)
            f:SetFrameLevel(3)
            f:SetMinMaxValues(0, 1)
            f:SetValue(0)
            
            f.text = f:CreateFontString("SexyInterrupterStatusBarText" .. value.pos, nil, "GameFontNormal")
            f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. value.pos, "LEFT", 5, 0)
            f.text:SetSize(180 - 5, 20)
            f.text:SetJustifyH("LEFT")
			f.text:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE")
            f.text:SetText('Dummy')

			f.cooldownText = f:CreateFontString("SexyInterrupterStatusBarCooldownText" .. value.pos, nil, "GameFontNormal")
            f.cooldownText:SetSize(12*3, 12)
            f.cooldownText:SetJustifyH("LEFT")
            f.cooldownText:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. value.pos, "RIGHT", 3, 0)
            f.cooldownText:SetFont(SI_Data.ui.font, SI_Data.ui.fontsize, "OUTLINE")
            f.cooldownText:SetTextColor(SI_Data.ui.fontcolor.r, SI_Data.ui.fontcolor.g, SI_Data.ui.fontcolor.b, SI_Data.ui.fontcolor.a)
		end
	end
end

function SI:UpdateInterrupterStatus()
	for cx, value in pairs(SI_Globals.interrupters) do 
		if _G["SexyInterrupterRow" .. value.pos] then
			_G["SexyInterrupterRow" .. value.pos]:Hide();
		end
	end

	local interrupters = SI:GetCurrentInterrupters();

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
								retVal = a.prio < b.prio;
							else
								retVal = a.readyTime < b.readyTime;
							end
						else
							if b.readyTime > 0 then
								retVal = true;
							else
								retVal = a.prio < b.prio;
							end
						end
					end
				end
			end
		end

		return retVal;
	end)

	for cx, value in pairs(interrupters) do
		--DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: ' .. value.name, 1, 0.5, 0);
		local interrupter = value;
		local row = _G["SexyInterrupterStatusBar" .. value.pos];
		local rowParent = _G["SexyInterrupterRow" .. value.pos];

		if rowParent then
			rowParent:Show();
		end

		if row and rowParent then	
			if interrupter.offline then
				rowParent:Hide();
			elseif interrupter.dead then
				row.text:SetTextColor(1, 0, 0, 1);
			elseif interrupter.afk then
				row.text:SetTextColor(1, 1, 0, 1);
			else 			
            	row.text:SetTextColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
			end

			if interrupter.cooldown > 0 then
				row.cooldownText:SetText(string.format('%.1f', interrupter.cooldown));
				row.cooldownText:Show();

				row:SetMinMaxValues(0, interrupter.cooldown);
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

		local interrupter = SI:GetInterrupter(fullname, realm);

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

			tinsert(SI_Globals.interrupters, interrupter);
		end

		interrupter = SI:GetInterrupter(fullname, realm);

		interrupter.active = true;
		interrupter.role = UnitGroupRolesAssigned(unit);
		
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
end

function SI:InterruptUsed(name, cooldown)
	local interrupter = SI:GetInterrupter(name);

	if interrupter then
		DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: SPELL_CAST_SUCCESS ' .. name .. ' cooldown: ' .. cooldown, 1, 0.5, 0);

		interrupter.cooldown = cooldown;
		interrupter.readyTime = GetTime() + cooldown;
	end
end

function SI:OnUpdate()
	for k,v in pairs(SI:GetCurrentInterrupters()) do
        if v.readyTime > 0 then
			local bar = _G["InterruptManagerStatusBar" .. v.pos];

			if bar then			
				if (v.readyTime - GetTime() <= 0) then
					bar.cooldownText:SetText();

					return;
				end

				bar:SetValue(v.readyTime - GetTime());
				bar.cooldownText:SetText(roundString(v.readyTime - GetTime(),1));

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
    local spellId = select(12, ...)
    local spellName = select(13, ...)
	local spells = { 132409, 119911, 116705, 147362, 96231, 106839, 78675, 47528, 2139, 1766, 57994, 119910, 6552, 15487, 171138 };
    
    if (event == "SPELL_CAST_SUCCESS") then
        if (tContains(spells, spellId)) then
			local cooldown = GetSpellBaseCooldown(spellId);

			SI:InterruptUsed(sourceName, cooldown / 1000);

			DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: SPELL_CAST_SUCCESS ' .. sourceName .. ' - ' .. spellId .. ' - ' .. cooldown, 1, 0.5, 0);
            
            -- Announce my interrupt
            --if (sourceGUID == UnitGUID("player") and IMDB.announce) then
            --    IM:AnnounceMyInterrupt(spellName)
            --end
        end
    --elseif (event == "SPELL_INTERRUPT") then
    --    if (tContains(spells, spellId)) then
    --        IM:UnitInterrupted(sourceName, spellId)
	--		DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: SPELL_INTERRUPT' .. sourceName .. ' - ' .. spellId, 1, 0.5, 0);
    --    end
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

		if not interruptImmune then
			DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: Interrupt that shit ' .. startTime .. ' - ' .. endTime, 1, 0.5, 0);
		end
	end
end

function SI_UNIT_SPELLCAST_STOP(...)
    local unit = ...
    
    --if (unit == "target" and IMDB.targetWarn and InterruptManagerText.text == "Interrupt now! (target)") then
    --    InterruptManagerText:SetTimeVisible(0)

	--end
end

local SIframe = CreateFrame("Frame");
SIframe:SetScript("OnEvent", SI_OnEvent);
SIframe:RegisterEvent("ADDON_LOADED");

function SI:SaveAnchorPosition()
	SexyInterrupterAnchor:StopMovingOrSizing();

	local a = SI_Data.ui.anchorPosition;

    a.point, a.region, a.relativePoint, a.x, a.y = SexyInterrupterAnchor:GetPoint();
end

function SI:OnLoad()
	SI:InitializeSavedVariables();

	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent);
	
    f:SetSize(200, 100)
    f:SetPoint(SI_Data.ui.anchorPosition.point, SI_Data.ui.anchorPosition.region, SI_Data.ui.anchorPosition.relativePoint, SI_Data.ui.anchorPosition.x, SI_Data.ui.anchorPosition.y)
	f:SetBackdrop({
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background-Dark',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
			left = 5,
			right = 5,
			top = 5,
			bottom = 5
		}
    });

	f:SetBackdropColor(SI_Data.ui.background.r, SI_Data.ui.background.g, SI_Data.ui.background.b, SI_Data.ui.background.a);

	f:SetScript("OnUpdate", SI.OnUpdate);

	if not SI_Data.ui.lock then
		f:SetMovable(true)
        f:SetScript("OnMouseDown", function() SexyInterrupterAnchor:StartMoving() end)
		f:SetScript("OnMouseUp", SI.SaveAnchorPosition)
	end
	
    local t = f:CreateTexture()
    t:SetTexture(0, 0, 0, 0.2)
    t:SetAllPoints(f)
	
	SI:UpdateUI();
	
	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter ' .. SI:GetVersion() .. ' loaded', 1, 0.5, 0);

	SI:InitOptions();
	
	SIframe:UnregisterEvent("ADDON_LOADED");
	SIframe:RegisterEvent("UNIT_FLAGS");
	SIframe:RegisterEvent("GROUP_ROSTER_UPDATE");
	SIframe:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    SIframe:RegisterEvent("UNIT_SPELLCAST_START");
    SIframe:RegisterEvent("UNIT_SPELLCAST_STOP");
end
