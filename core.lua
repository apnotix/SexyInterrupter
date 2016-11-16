SexyInterrupter = {}
local SI = SexyInterrupter
SI.interrupters = {};
SI.numInterrupters = 0;

function SI:GetVersion() return '1.0.0' end

function SI:UpdateUI() 
	for i = 1, SI.numInterrupters do
		if (not _G["SexyInterrupterRow" .. i]) then	
			local interrupter = SI.interrupters[i];
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
            f.text:SetTextColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
            f.text:SetText(interrupter.name)
		end
	end
	
	SI:UpdateInterrupterStatus();
end

function SI:UpdateInterrupterStatus()
	for i = 1, SI.numInterrupters do
		local interrupter = SI.interrupters[i];
		local row = _G["SexyInterrupterStatusBar" .. i];
		local rowParent = _G["SexyInterrupterRow" .. i];

		if row then	
			if interrupter.offline then
				rowParent:Hide();
			elseif interrupter.dead then
				row.text:SetTextColor(1, 0, 0, 1);
			elseif interrupter.afk then
				row.text:SetTextColor(1, 1, 0, 1);
			end
			
			row.text:SetText(interrupter.name .. ' - ' .. interrupter.role);
		end
	end
end

function SI:UpdateInterrupters()
	SI.interrupters = {};
	SI.numInterrupters = GetNumGroupMembers();

	for i = 1,GetNumGroupMembers() do
		local unit = "party" .. i
		
		SI.interrupters[i] = {}
		local interrupter = SI.interrupters[i];
		
		if not UnitExists(unit) then	
			unit = 'player'
		end;	
		
		local name, realm = UnitName(unit);
		
		DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: UnitExists name: ' .. name, 1, 0.5, 0);
		
		interrupter.pos = i;
		interrupter.ready = true;
		interrupter.name = name;
		interrupter.realm = realm;
		
		interrupter.role = UnitGroupRolesAssigned(Unit);
		
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
	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: SI_GROUP_ROSTER_UPDATE');
	
	if IsInGroup() then
		SI:UpdateInterrupters();
		SI:UpdateInterrupterStatus();
	end
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

function SI:OnLoad()
	if IsInGroup() then
		DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: in Group');
		SI:UpdateInterrupters();
	end
	
	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter: ' .. SI.numInterrupters);
	
	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent)
	
    f:SetSize(200, 100)
    f:SetPoint('CENTER', nil, 'CENTER', 0, -300)
	
    local t = f:CreateTexture()
    t:SetTexture(0, 0, 0, 0.2)
    t:SetAllPoints(f)
	
	SI:UpdateUI();
	
	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter ' .. SI:GetVersion() .. ' loaded', 1, 0.5, 0);
	
	SIframe:UnregisterEvent("ADDON_LOADED");
	SIframe:RegisterEvent("UNIT_FLAGS");
	SIframe:RegisterEvent("GROUP_ROSTER_UPDATE");
end