SexyInterrupter = {}
local SI = SexyInterrupter

function SI:InitializeSavedVariables()
	if (not SI_Globals) then
		SI_Globals = {}
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

	SI_Globals.interrupters = {};
	SI_Globals.numInterrupters = 0;
end

function SI:GetVersion() return '1.0.0' end

function SI:UpdateUI() 
	for i = 1, 5 do
		if (not _G["SexyInterrupterRow" .. i]) then	
			local interrupter = SI_Globals.interrupters[i];
			local f = CreateFrame("Frame", "SexyInterrupterRow" .. i, SexyInterrupterAnchor)
			
			f:SetSize(20, 20)
			
			if (i == 1) then
                f:SetPoint("TOPLEFT", SexyInterrupterAnchor, "TOPLEFT", 0, -(i-1) * 20)
            else
                f:SetPoint("TOP", _G["SexyInterrupterRow" .. i-1], "BOTTOM")
            end
			
			local t = f:CreateTexture()
            t:SetAllPoints(f)
            t:SetTexture(0, 0, 0, 0.4)
            
            t = f:CreateFontString()
            t:SetPoint("CENTER", "SexyInterrupterRow" .. i, "CENTER")
			t:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            t:SetText(i)
            t:SetTextColor(1, 1, 1, 1)
        
            f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. i, _G["SexyInterrupterRow" .. i])
            f:SetSize(180, 20)
            f:SetPoint("LEFT", "SexyInterrupterRow" .. i, "RIGHT")
            f:SetOrientation("HORIZONTAL")
            f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            f:SetStatusBarColor(0, 1, 0, 1)
            f:SetFrameLevel(3)
            f:SetMinMaxValues(0, 1)
            f:SetValue(0)
            
            f.text = f:CreateFontString("SexyInterrupterStatusBarText" .. i, nil, "GameFontNormal")
            f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. i, "LEFT", 5, 0)
            f.text:SetSize(180 - 5, 20)
            f.text:SetJustifyH("LEFT")
			f.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            f.text:SetText('Dummy')

			 _G["SexyInterrupterRow" .. i]:Hide();
		end
	end
end

function SI:UpdateInterrupterStatus()
	for i = 1, 5 do 
		if _G["SexyInterrupterRow" .. i] then
			_G["SexyInterrupterRow" .. i]:Hide();
		end
	end

	for i = 1, SI_Globals.numInterrupters do
		local interrupter = SI_Globals.interrupters[i];
		local row = _G["SexyInterrupterStatusBar" .. i];
		local rowParent = _G["SexyInterrupterRow" .. i];

		rowParent:Show();

		if row then	
			if interrupter.offline then
				rowParent:Hide();
			elseif interrupter.dead then
				row.text:SetTextColor(1, 0, 0, 1);
			elseif interrupter.afk then
				row.text:SetTextColor(1, 1, 0, 1);
			else 			
            	row.text:SetTextColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
			end
			
			row.text:SetText(interrupter.name .. '-' .. interrupter.role);
		end
	end
end

function SI:UpdateInterrupters()
	SI_Globals.interrupters = {};
	SI_Globals.numInterrupters = GetNumGroupMembers();

	for i = 1,GetNumGroupMembers() do
		local unit = "party" .. i
		
		SI_Globals.interrupters[i] = {}

		local interrupter = SI_Globals.interrupters[i];
		
		if not UnitExists(unit) then	
			unit = 'player'
		end;	
		
		local name, realm = UnitName(unit);
		
		--DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: UnitExists name: ' .. name, 1, 0.5, 0);
		
		interrupter.pos = i;
		interrupter.ready = true;
		interrupter.name = name;
		interrupter.realm = realm;
		
		interrupter.role = UnitGroupRolesAssigned(unit);
		
		if interrupter.role == 'HEALER' then
			interrupter.prio = 3;
		elseif interrupter.role == 'DAMAGER' then
			interrupter.prio = 2;
		elseif interrupter.role == 'TANK' then
			interrupter.prio = 1;
		end
		
		local class, classFileName = UnitClass(unit)
		local color = RAID_CLASS_COLORS[classFileName]
		
		interrupter.class = class;
		interrupter.classColor = color;
		
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

function SI_UNIT_FLAGS() 
	SI_GROUP_ROSTER_UPDATE();
end

function SI_GROUP_ROSTER_UPDATE()
	--DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: SI_GROUP_ROSTER_UPDATE');
	
	SI:UpdateInterrupters();
	SI:UpdateInterrupterStatus();
end

function SI_OnEvent(self, event, ...)
    if (_G["SI_" .. event]) then
        _G["SI_" .. event](...)
    else
        print("Unhandled event registered by InterruptManager: " .. event)
    end
end

function SI_ADDON_LOADED(...)
    local addonName = ...

    SI:OnLoad()
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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
			left = 5,
			right = 5,
			top = 5,
			bottom = 5
		}
    })

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
end