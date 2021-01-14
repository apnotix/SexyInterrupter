SexyInterrupter = LibStub("AceAddon-3.0"):NewAddon("SexyInterrupter", 'AceConsole-3.0', 'AceEvent-3.0', 'AceComm-3.0', 'AceSerializer-3.0', 'AceTimer-3.0', 'AceHook-3.0', 'LibNotify-1.0');
local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);
local icon = LibStub("LibDBIcon-1.0", true);

function SexyInterrupter:OnInitialize()
	Mixin(self, BackdropTemplateMixin);
	
	self:InitializeSavedVariables();

	self:InitOptions();
	self:CreateUi();
	self:CreateFlasher('Blue');

	self:RegisterEvents();
	
	C_ChatInfo.RegisterAddonMessagePrefix("SexyInterrupter");

	-- Minimap button.
	self.icon = icon;

	if icon and not icon:IsRegistered("SexyInterrupter") and self.db.profile.general.minimapIcon then
		SexyInterrupter:AddIcon();
	end	

	DEFAULT_CHAT_FRAME:AddMessage('SexyInterrupter ' .. self.Version .. ' loaded', 1, 0.5, 0);  
end

function SexyInterrupter:RegisterEvents()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_LOG_EVENT_UNFILTERED");
    self:RegisterEvent("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_START");
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_START");
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_STOP");
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_STOP");
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "PLAYER_TARGET_CHANGED");
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED");
		
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED");
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "GROUP_ROSTER_UPDATE");
	self:RegisterEvent("PARTY_MEMBER_DISABLE", "PARTY_MEMBER_DISABLE");
	self:RegisterEvent("PARTY_MEMBER_ENABLE", "PARTY_MEMBER_ENABLE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE");

	self:RegisterComm ("SexyInterrupter", "CommReceived");
end

function SexyInterrupter:InitializeSavedVariables()
	if not SI_Globals then
		SI_Globals = {
			formatVersion = 2;
			interrupters = {};
			numInterrupters = 0;
		}
	elseif SI_Globals.formatVersion ~= 2 then
		SI_Globals.interrupters = {};
		SI_Globals.numInterrupters = 0;
		SI_Globals.formatVersion = 2;
	end
end