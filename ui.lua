local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);
local LibDD = LibStub("LibUIDropDownMenuQuestie-4.0");

-- Declared here (not next to RegisterEditModeCheckbox/Slider further down)
-- because CreateUi()'s EnterEditMode hook, which drains this list, is
-- defined earlier in the file - a local's closures can only capture it if
-- the local is already in lexical scope at the point the closure literal is
-- written, regardless of when either piece of code actually RUNS.
local pendingEditModeResyncs = {};

-- Berechnet die BOTTOMLEFT-Bildschirmkoordinaten, die EditModeExpanded-1.0 für
-- seinen (BOTTOMLEFT-)Ankerpunkt in db.x/db.y erwartet, rein rechnerisch aus
-- der Zielregion (target) - OHNE uns auf frame:GetRect() unseres eigenen,
-- gerade erst erzeugten Fensters zu verlassen. Das ist nötig, weil GetRect()
-- auf einem brandneuen Frame direkt nach SetPoint() unzuverlässig ist (kann
-- noch nil liefern, bevor WoW einen Layout-Durchlauf gemacht hat), während
-- PlayerFrame/UIParent als längst bestehende Frames zuverlässig sofort ein
-- gültiges Rect liefern.
local function ComputeBottomLeft(point, target, relativePoint, x, y, width, height)
	local tLeft, tBottom, tWidth, tHeight = target:GetRect();
	if not (tLeft and tBottom and tWidth and tHeight) then
		return nil, nil;
	end

	-- relativePoint auf der Zielregion, in Bildschirmkoordinaten:
	local relX, relY;
	if relativePoint:find("LEFT") then relX = tLeft;
	elseif relativePoint:find("RIGHT") then relX = tLeft + tWidth;
	else relX = tLeft + tWidth / 2; end
	if relativePoint:find("BOTTOM") then relY = tBottom;
	elseif relativePoint:find("TOP") then relY = tBottom + tHeight;
	else relY = tBottom + tHeight / 2; end

	-- point relativ zur eigenen BOTTOMLEFT-Ecke (0,0 = BOTTOMLEFT):
	local ownX, ownY;
	if point:find("LEFT") then ownX = 0;
	elseif point:find("RIGHT") then ownX = width;
	else ownX = width / 2; end
	if point:find("BOTTOM") then ownY = 0;
	elseif point:find("TOP") then ownY = height;
	else ownY = height / 2; end

	return (relX + x) - ownX, (relY + y) - ownY;
end

-- EditModeExpanded-1.0 moves x/y/settings out of the db table we hand it into
-- a nested per-Edit-Mode-layout table on its first profile init and keeps only
-- that one current - the table we passed in (editModeAnchorDB/MessageDB)
-- silently stops being the live position store. Always go through the
-- library's own live reference when reading or writing position.
local function GetLiveDB(frame, fallback)
	local EME = LibStub("EditModeExpanded-1.0", true);

	return (EME and frame and frame.system and EME.framesDB and EME.framesDB[frame.system]) or fallback;
end

local function GetSpellTextureCompat(spellId)
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(spellId);
	elseif GetSpellTexture then
		return GetSpellTexture(spellId);
	end

	return nil;
end

-- Fixed test data shown on the REAL anchor/message frames (not separate
-- dummy frames) while editing - see UpdateFrames/OnUpdate below. Cached
-- across calls (only regenerated when entering edit mode, or when maxrows
-- changed since the last generation) so the cooldown bars actually count
-- down like the real ones instead of resetting on every options change or
-- OnUpdate tick.
-- Vorlagen, aus denen die Vorschau-Zeilen zyklisch aufgebaut werden - vorher
-- waren das genau 3 feste Zeilen, unabhängig von "Max rows of interrupters"
-- (Standard 5), wodurch der Edit-Mode-Dialog nie zeigte, wie viele Zeilen
-- tatsächlich Platz haben.
local PREVIEW_TEMPLATES = {
	{ name = L["Preview Tank"],    classColor = RAID_CLASS_COLORS["WARRIOR"], role = "TANK",    spellId = nil, cooldown = 0,  readyOffset = 0 },
	{ name = L["Preview Healer"],  classColor = RAID_CLASS_COLORS["PRIEST"],  role = "HEALER",   spellId = nil, cooldown = 15, readyOffset = 4 },
	{ name = L["Preview Damager"], classColor = RAID_CLASS_COLORS["MAGE"],    role = "DAMAGER",  spellId = 2139, cooldown = 24, readyOffset = 18 },
};

local previewRows = nil;

local function GetPreviewRows(forceRegenerate)
	local maxRows = (SexyInterrupter.db and SexyInterrupter.db.profile.general.maxrows) or 5;

	if forceRegenerate or not previewRows or #previewRows ~= maxRows then
		previewRows = {};

		for i = 1, maxRows do
			local template = PREVIEW_TEMPLATES[((i - 1) % #PREVIEW_TEMPLATES) + 1];

			previewRows[i] = {
				interrupter = {
					name = template.name .. " " .. i,
					classColor = template.classColor,
					role = template.role,
					offline = false, dead = false, afk = false, inrange = true,
				},
				spellId = template.spellId,
				cooldown = template.cooldown,
				readyTime = template.cooldown > 0 and (GetTime() + template.readyOffset) or 0,
			};
		end
	end

	return previewRows;
end

local function GetPreviewMessageText()
	return L["Interrupt now"] .. ' |cFFFF0000' .. L["Preview Target"] .. '|r !!';
end

local function ApplyBackdrop(frame, profile)
	frame:SetBackdrop({
        bgFile = LSM:Fetch("background", profile.ui.window.backgroundtexture),
        edgeFile = LSM:Fetch("border", profile.ui.window.border),
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

	frame:SetBackdropColor(profile.ui.window.background.r, profile.ui.window.background.g, profile.ui.window.background.b, profile.ui.window.background.a);
end

function SexyInterrupter:CreateUi()
	-- Frame: Anchor
	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil);

    -- The old options panel allowed any width (-9999..9999); the Edit Mode
    -- slider only covers 100-400, so bring stored values into that range once.
    self.db.profile.ui.window.width = math.max(100, math.min(400, self.db.profile.ui.window.width))

    f:SetSize(self.db.profile.ui.window.width, 100)
    -- anchorPosition.region ist ein Frame-NAME (String, SavedVariables können
    -- keine Frame-Referenzen speichern) und muss selbst aufgelöst werden -
    -- SetPoint akzeptiert zwar auch einen String, aber wenn der genannte Frame
    -- zum Ladezeitpunkt noch nicht existiert (z. B. "PlayerFrame" ist bei
    -- OnInitialize teils noch nicht erzeugt), bekommt f dadurch gar KEINEN
    -- Anker-Punkt (GetNumPoints() == 0) und bleibt dauerhaft unsichtbar/
    -- unpositionierbar, auch im Edit-Modus. Deshalb hier explizit selbst
    -- auflösen und bei Fehlschlag auf UIParent zurückfallen.
    local anchorRegion = (self.db.profile.ui.anchorPosition.region and _G[self.db.profile.ui.anchorPosition.region]) or UIParent
    f:SetPoint(self.db.profile.ui.anchorPosition.point, anchorRegion, self.db.profile.ui.anchorPosition.relativePoint, self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y)

    -- Bei leerem/frisch zurückgesetztem editModeAnchorDB (kein x/y) hier selbst
    -- die tatsächliche Bildschirmposition aus dem gerade gesetzten Punkt oben
    -- berechnen und eintragen. EditModeExpanded-1.0 soll das eigentlich selbst
    -- beim ersten RegisterFrame-Aufruf tun ("seed from current on-screen rect"),
    -- hat dafür intern aber einen zweiten, unabhängigen Profil-Migrationspfad
    -- (refreshCurrentProfile in der Library), der bei komplett leerem db (auch
    -- ohne defaultX/defaultY) ein ClearAllPoints() ohne nachfolgendes SetPoint
    -- ausführt - das Fenster verliert dadurch dauerhaft jeden Anker-Punkt und
    -- wird unsichtbar/nicht mehr greifbar, auch im Edit-Modus. Indem wir x/y
    -- selbst vorab befüllen, wird dieser Bruch-Pfad gar nicht erst genommen.
    if not (self.db.profile.ui.editModeAnchorDB.x and self.db.profile.ui.editModeAnchorDB.y) then
        self.db.profile.ui.editModeAnchorDB.x, self.db.profile.ui.editModeAnchorDB.y = ComputeBottomLeft(
            self.db.profile.ui.anchorPosition.point, anchorRegion, self.db.profile.ui.anchorPosition.relativePoint,
            self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y,
            self.db.profile.ui.window.width, 100)
        -- Letzter Sicherheitsnetz-Fallback, falls selbst anchorRegion:GetRect()
        -- kein Ergebnis liefert: irgendein gültiger Wert ist immer besser als
        -- nil (siehe Kommentar oben zum ClearAllPoints-Bug).
        if not (self.db.profile.ui.editModeAnchorDB.x and self.db.profile.ui.editModeAnchorDB.y) then
            local screenWidth, screenHeight = UIParent:GetSize()
            self.db.profile.ui.editModeAnchorDB.x = screenWidth - self.db.profile.ui.window.width - 10
            self.db.profile.ui.editModeAnchorDB.y = screenHeight - 110
        end
        -- Markieren, dass DIESER Wert von uns automatisch berechnet wurde (nicht
        -- vom Spieler per Drag gesetzt) - siehe Korrektur-Timer am Ende von
        -- CreateUi(): UIParent hat beim Login/Reload oft noch nicht seine
        -- endgültige Größe, der hier berechnete Wert kann daher leicht daneben
        -- liegen und wird kurz danach mit der dann korrekten Größe nachkorrigiert.
        self.db.profile.ui.editModeAnchorDB.autoSeeded = true
    end

	ApplyBackdrop(f, self.db.profile);
	f:SetBackdropBorderColor(self.db.profile.ui.window.bordercolor.r, self.db.profile.ui.window.bordercolor.g, self.db.profile.ui.window.bordercolor.b, self.db.profile.ui.window.bordercolor.a);
	f:SetScript("OnUpdate", SexyInterrupter.OnUpdate);

    local t = f:CreateTexture()
    t:SetColorTexture(0, 0, 0, 0.2)
    t:SetAllPoints(f);

	-- Frame: InterruptMessage
	local c = CreateFrame("MessageFrame", "SexyInterrupterInterruptNowText", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil);
    c:SetFontObject(BossEmoteNormalHuge);
    c:SetWidth(500);

    local fontPath = c:GetFont();
    c:SetFont(fontPath, 25, "OUTLINE");
    c:SetFadeDuration(0.4);

    -- MessageFrame kennt kein echtes "vertikal zentriert" (kein SetJustifyV
    -- wie bei einer normalen FontString - es ist als Scroll-/Fade-Log für
    -- mehrere Zeilen gedacht, Text wird per SetInsertMode an eine Kante
    -- "angeheftet"). Ein geschätzter fester Höhenwert (z. B. 32) trifft die
    -- tatsächliche Zeilenhöhe dieser Schriftart/-größe nicht exakt, der Text
    -- wirkte dadurch minimal nach oben/unten verschoben statt zentriert.
    -- Robuster Fix: die ECHTE Zeilenhöhe über eine unsichtbare Referenz-
    -- FontString mit exakt demselben Font ausmessen (GetStringHeight), statt
    -- den Wert zu schätzen - dann exakt diese Höhe setzen, sodass gar kein
    -- "totes" Polster mehr existiert, an das der Text angeheftet werden könnte.
    local measureText = c:CreateFontString(nil, "OVERLAY");
    measureText:SetFont(fontPath, 25, "OUTLINE");
    measureText:SetText("Mg");
    local measuredHeight = measureText:GetStringHeight();
    measureText:Hide();

    c:SetHeight(measuredHeight > 0 and measuredHeight or 32);
    c:SetInsertMode("BOTTOM");
    c:SetPoint(self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint, self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y);

    -- Siehe Kommentar bei editModeAnchorDB weiter oben - dasselbe für die
    -- Notification-Position.
    if not (self.db.profile.ui.editModeMessageDB.x and self.db.profile.ui.editModeMessageDB.y) then
        self.db.profile.ui.editModeMessageDB.x, self.db.profile.ui.editModeMessageDB.y = ComputeBottomLeft(
            self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint,
            self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y, 500, c:GetHeight())
        self.db.profile.ui.editModeMessageDB.autoSeeded = true
    end

	-- Hand both frames to Blizzard's real Edit Mode instead of our own custom
	-- drag/lock system - see https://github.com/teelolws/EditModeExpanded.
	-- Register AFTER the SetPoint calls above: EditModeExpanded seeds a
	-- frame's saved position from its CURRENT on-screen rect the first time
	-- it's registered with an empty db, so any position saved under the old
	-- system carries over automatically instead of resetting to a default.
	local EME = LibStub("EditModeExpanded-1.0", true);

	if EME then
		-- BOTTOMLEFT instead of CENTER: the anchor frame's height changes with
		-- the number of interrupter rows shown, so anchoring by CENTER made
		-- the frame visibly drift after a reload (whenever the row count at
		-- that moment differed from when the position was saved). BOTTOMLEFT
		-- keeps the bottom edge fixed regardless of how tall the frame gets.
		EME:RegisterFrame(f, L["Addon name"] .. " " .. L["Window"], self.db.profile.ui.editModeAnchorDB, UIParent, "BOTTOMLEFT", true);
		EME:RegisterFrame(c, L["Addon name"] .. " " .. L["Interrupt now"], self.db.profile.ui.editModeMessageDB, UIParent, "BOTTOMLEFT", true);

		-- "autoSeeded" markiert nur einen von UNS berechneten Default-Wert (siehe
		-- Kommentare weiter oben) und muss geloescht werden, sobald der Spieler
		-- die Position tatsaechlich selbst per Drag setzt - sonst haelt der
		-- Login-Korrekturtimer (2s-Timer unten) den vom Spieler gezogenen Wert
		-- faelschlich weiter fuer "unsere Berechnung" und ueberschreibt ihn bei
		-- jedem /reload wieder mit der Default-Position (Bug: Fenster springt
		-- nach jedem Reload zurueck zum Charakterfenster). Die Library setzt
		-- db.x/db.y in ihrem EIGENEN OnDragStop-Handler auf frame.Selection -
		-- per HookScript haengen wir uns dort mit an, ohne den bestehenden
		-- Handler zu ersetzen.
		if f.Selection then
			f.Selection:HookScript("OnDragStop", function()
				self.db.profile.ui.editModeAnchorDB.autoSeeded = nil
			end)
		end
		if c.Selection then
			c.Selection:HookScript("OnDragStop", function()
				self.db.profile.ui.editModeMessageDB.autoSeeded = nil
			end)
		end

		SexyInterrupter:RegisterEditModeSettings(EME, f, c);

		-- Gegner-Marker-Fenster (marks.lua) registriert sein eigenes Edit-Mode-Frame.
		local markFrame = SexyInterrupter:CreateMarkFrame(EME, SexyInterrupter.EditModeHelpers);

		-- The library's dialog builds its sliders from ITS per-layout db (100
		-- when a value is missing, e.g. after switching to a layout it hasn't
		-- seen). Re-seed from AceDB right before a frame's dialog is built, so
		-- it never shows - or lets the user drag from - a bogus default.
		for _, frame in ipairs({ f, c, markFrame }) do
			local originalSelectSystem = frame.SelectSystem;

			if originalSelectSystem then
				frame.SelectSystem = function(...)
					for _, resync in ipairs(pendingEditModeResyncs) do
						resync();
					end

					return originalSelectSystem(...);
				end
			end
		end
	end

	-- Keep the test-data preview (UpdateFrames() below, driven by
	-- IsEditingUi()) in sync no matter how the user enters/exits Edit Mode -
	-- our own "Open Edit Mode" button, the minimap icon, /si lock, or
	-- Blizzard's own ESC menu / the in-Edit-Mode "Exit" button.
	if EditModeManagerFrame then
		hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
			-- Re-seed every custom checkbox/slider from our real AceDB values
			-- right before the user can open a per-system dialog - see
			-- pendingEditModeResyncs above for why a one-time seed at addon
			-- load isn't enough (per-layout-profile migration inside the
			-- library, and switching Edit Mode layouts entirely).
			for _, resync in ipairs(pendingEditModeResyncs) do
				resync();
			end

			SexyInterrupter:UpdateFrames();
		end);
		hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() SexyInterrupter:UpdateFrames(); end);
	end

	-- Infight only
	if self.db.profile.general.modeincombat then
		SexyInterrupterAnchor:Hide();
	end

	-- Nothing to show yet (no roster data, not editing) - UpdateUI() takes
	-- over from here once there's real data or Edit Mode is opened.
	SexyInterrupterAnchor:Hide();

	-- Korrektur-Durchlauf: UIParent hat beim Login/Reload oft noch nicht seine
	-- endgültige Größe (UI-Skalierung/Auflösung noch nicht final ausgehandelt),
	-- wenn der obige Code läuft - die frisch berechneten Default-Positionen
	-- können dadurch spürbar daneben liegen (beobachtet: UIParent:GetRect()
	-- lieferte beim Login eine deutlich kleinere Breite/Höhe als kurz danach).
	-- Nur "autoSeeded"-Werte (von uns berechnet, nicht vom Spieler per Drag
	-- gesetzt) werden hier neu berechnet und angewendet.
	C_Timer.After(2, function()
		-- Siehe Kommentar bei UpdateUI()'s Wachstumsrichtung-Kompensation:
		-- ClearAllPoints()/SetPoint() nicht während eines laufenden Drags
		-- desselben Frames aufrufen (Kollision mit Blizzards geschützter
		-- Drag-Logik, beobachtet als Client-Absturz).
		local anchorDB = self.db.profile.ui.editModeAnchorDB
		if anchorDB.autoSeeded and not f.isDragging then
			local x, y = ComputeBottomLeft(
				self.db.profile.ui.anchorPosition.point, anchorRegion, self.db.profile.ui.anchorPosition.relativePoint,
				self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y,
				self.db.profile.ui.window.width, 100)
			if x and y then
				anchorDB.x, anchorDB.y = x, y
				local liveDB = GetLiveDB(f, anchorDB)
				liveDB.x, liveDB.y = x, y
				f:ClearAllPoints()
				f:SetPoint(f.EMEanchorPoint or "BOTTOMLEFT", f.EMEanchorTo or UIParent, f.EMEanchorPoint or "BOTTOMLEFT", x, y)
			end
		end

		local messageDB = self.db.profile.ui.editModeMessageDB
		if messageDB.autoSeeded and not c.isDragging then
			local mx, my = ComputeBottomLeft(
				self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint,
				self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y, 500, c:GetHeight())
			if mx and my then
				messageDB.x, messageDB.y = mx, my
				local liveDB = GetLiveDB(c, messageDB)
				liveDB.x, liveDB.y = mx, my
				c:ClearAllPoints()
				c:SetPoint(c.EMEanchorPoint or "BOTTOMLEFT", c.EMEanchorTo or UIParent, c.EMEanchorPoint or "BOTTOMLEFT", mx, my)
			end
		end
	end)
end

-- EditModeExpanded-1.0's custom checkbox/slider settings store their own
-- checked/value state in db.settings[<setting type number>][<internalName>]
-- on the library's OWN db table - not in our AceDB fields directly, and not
-- documented (no public getter, no initial-value parameter). The setting-
-- type numbers below (12 = Custom checkbox, 18 = Slider) are the vendored
-- library's own local constants (see lib/EditModeExpanded-1.0/
-- EditModeExpanded-1.0.lua, ENUM_EDITMODEACTIONBARSETTING_CUSTOM/SLIDER) -
-- re-check them if that file is ever re-vendored from a newer upstream
-- version.
--
-- EditModeExpanded also moves that db.settings into a NESTED per-layout-
-- profile table (db.profiles[<name>].settings) the first time the user ever
-- opens Edit Mode, and framesDB[systemID] then points at that nested copy
-- from then on (see the library's refreshCurrentProfile) - so seeding once
-- at CreateUi() time (ADDON_LOADED, before that migration has necessarily
-- happened) only works for a brand-new profile; on every later login the
-- migration already happened in a PRIOR session, so a one-time seed lands on
-- the now-abandoned outer table and is invisible. This is why "Show minimap
-- icon" kept showing unchecked despite the icon being on, and would also
-- desync if the user switches Edit Mode layouts. Fix: re-seed every time
-- Edit Mode is opened (CreateUi's EnterEditMode hook drains
-- pendingEditModeResyncs below), writing through EME.framesDB[frame.system]
-- (the library's own live/current reference for this system, migrated or
-- not) instead of our own db table. onChecked/onUnchecked/onChanged still
-- write back into our own AceDB - the actual, single source of truth the
-- rest of the addon reads, regardless of Edit Mode layout.
local EME_SETTING_TYPE_CUSTOM = 12;
local EME_SETTING_TYPE_SLIDER = 18;

local function RegisterEditModeCheckbox(EME, frame, internalName, label, getFn, setFn)
	local function Resync()
		local liveDB = EME.framesDB and EME.framesDB[frame.system];

		if liveDB then
			liveDB.settings = liveDB.settings or {};
			liveDB.settings[EME_SETTING_TYPE_CUSTOM] = liveDB.settings[EME_SETTING_TYPE_CUSTOM] or {};
			liveDB.settings[EME_SETTING_TYPE_CUSTOM][internalName] = getFn() and 1 or 0;
		end
	end

	Resync();
	tinsert(pendingEditModeResyncs, Resync);

	EME:RegisterCustomCheckbox(frame, label,
		function()
			-- onChecked() has no marker for "automatic re-run" (unlike
			-- onUnchecked(true)), but a real click can only happen while the
			-- library's settings dialog is open - the library hides it before
			-- re-running the callbacks on a profile/layout change. Outside of
			-- that, a stale per-layout value must not overwrite our AceDB.
			if not (EditModeExpandedSystemSettingsDialog and EditModeExpandedSystemSettingsDialog:IsShown()) then
				Resync();
				return;
			end

			setFn(true);
			SexyInterrupter:UpdateFrames();
		end,
		function(isAutomaticInit)
			-- EditModeExpanded-1.0 re-runs every checkbox callback on each profile
			-- init and EDIT_MODE_LAYOUTS_UPDATED using ITS OWN per-layout db, which
			-- is empty for a layout it hasn't seen yet - so it reports "unchecked"
			-- (onUnchecked(true)) for every box and would overwrite our real AceDB
			-- values (e.g. the default "Play sound" = true) with false. Only that
			-- automatic call passes `true`; a real click passes `false`. Push our
			-- AceDB value into the library's db instead of writing it back.
			if isAutomaticInit then
				Resync();
				return;
			end

			setFn(false);
			SexyInterrupter:UpdateFrames();
		end,
		internalName);
end

local function RegisterEditModeSlider(EME, frame, internalName, label, min, max, step, getFn, setFn)
	local function Resync()
		local liveDB = EME.framesDB and EME.framesDB[frame.system];

		if liveDB then
			liveDB.settings = liveDB.settings or {};
			liveDB.settings[EME_SETTING_TYPE_SLIDER] = liveDB.settings[EME_SETTING_TYPE_SLIDER] or {};
			liveDB.settings[EME_SETTING_TYPE_SLIDER][internalName] = getFn();
		end
	end

	Resync();
	tinsert(pendingEditModeResyncs, Resync);

	-- The library also re-runs this callback with ITS per-layout value on every
	-- profile refresh (Edit Mode layout switch / layouts update). Only real
	-- slider input - which requires the library's settings dialog to be open,
	-- it is hidden before the refresh - may change our AceDB value; otherwise
	-- push the AceDB value into the library instead.
	EME:RegisterSlider(frame, label, internalName, function(value)
		if not (EditModeExpandedSystemSettingsDialog and EditModeExpandedSystemSettingsDialog:IsShown()) then
			Resync();
			return;
		end

		setFn(value);
		SexyInterrupter:UpdateFrames();
	end, min, max, step);
end

-- LSM-backed selects (font/statusbar-texture/background-texture/border) have
-- no ready-made Edit Mode widget, but RegisterDropdown hands back a raw
-- dropdown frame built with LibUIDropDownMenu (same fork this addon already
-- uses for the Edit Mode dropdowns, see LibDD above) that we populate ourselves.
-- Each entry gets a real preview: a texture swatch of the media itself for
-- statusbar/background/border, or the entry's own text rendered in that font
-- for font entries - not just a plain name in a list.
local previewFontObjects = {};
local previewFontObjectCount = 0;

local function GetPreviewFontObject(fontPath)
	local fontObject = previewFontObjects[fontPath];

	if not fontObject then
		previewFontObjectCount = previewFontObjectCount + 1;
		fontObject = CreateFont("SexyInterrupterEditModeFontPreview" .. previewFontObjectCount);
		fontObject:SetFont(fontPath, 14, "");
		previewFontObjects[fontPath] = fontObject;
	end

	return fontObject;
end

local function RegisterEditModeMediaDropdown(EME, frame, internalName, label, mediaType, getFn, setFn)
	local dropdown = EME:RegisterDropdown(frame, LibDD, internalName);
	local isFont = (mediaType == "font");
	local isSound = (mediaType == "sound");

	-- Unlike RegisterCustomCheckbox/RegisterSlider/RegisterCustomButton,
	-- RegisterDropdown takes no `name` parameter at all - there's no built-in
	-- label for it, so the dialog row would otherwise just show the current
	-- value with nothing saying what it's for. Add our own label, and move
	-- the dropdown itself to sit to the right of it within the same row.
	local layoutFrame = dropdown:GetParent();

	-- GameFontHighlightMedium is what Blizzard's own EditModeSettingCheckbox/
	-- SliderTemplate use for their .Label (see EditModeTemplates.xml) - not a
	-- guess, matches the native rows exactly instead of eyeballing a font.
	local labelText = layoutFrame:CreateFontString(nil, nil, "GameFontHighlightMedium");
	labelText:SetPoint("LEFT", layoutFrame, "LEFT", 0, 0);
	labelText:SetJustifyH("LEFT");
	labelText:SetWidth(100);
	labelText:SetText(label);

	dropdown:ClearAllPoints();
	dropdown:SetPoint("LEFT", labelText, "RIGHT", 5, -2);

	local function RefreshText()
		LibDD:UIDropDownMenu_SetText(dropdown, getFn());
	end

	LibDD:UIDropDownMenu_Initialize(dropdown, function(self, level)
		local names = {};

		for name in pairs(LSM:HashTable(mediaType)) do
			tinsert(names, name);
		end

		table.sort(names);

		for _, name in ipairs(names) do
			local info = LibDD:UIDropDownMenu_CreateInfo();
			info.text = name;
			info.checked = (name == getFn());

			if isFont then
				info.fontObject = GetPreviewFontObject(LSM:Fetch(mediaType, name));
			elseif not isSound then
				info.icon = LSM:Fetch(mediaType, name);
			end

			info.func = function()
				setFn(name);

				-- Sounds have no visual preview - play the picked one instead.
				if isSound then
					PlaySoundFile(LSM:Fetch(mediaType, name), "Master");
				end

				SexyInterrupter:UpdateFrames();
				RefreshText();
			end

			LibDD:UIDropDownMenu_AddButton(info, level);
		end
	end);

	LibDD:UIDropDownMenu_SetWidth(dropdown, 150);
	RefreshText();
end

-- Wie RegisterEditModeMediaDropdown oben, aber für eine feste, kleine
-- Werteliste (nicht LibSharedMedia) wie z. B. Wachstumsrichtung. options ist
-- eine Liste aus { value = ..., label = "..." }.
local function RegisterEditModeSelectDropdown(EME, frame, internalName, label, options, getFn, setFn)
	local dropdown = EME:RegisterDropdown(frame, LibDD, internalName);
	local layoutFrame = dropdown:GetParent();

	local labelText = layoutFrame:CreateFontString(nil, nil, "GameFontHighlightMedium");
	labelText:SetPoint("LEFT", layoutFrame, "LEFT", 0, 0);
	labelText:SetJustifyH("LEFT");
	labelText:SetWidth(100);
	labelText:SetText(label);

	dropdown:ClearAllPoints();
	dropdown:SetPoint("LEFT", labelText, "RIGHT", 5, -2);

	local function GetCurrentLabel()
		local current = getFn();
		for _, option in ipairs(options) do
			if option.value == current then
				return option.label;
			end
		end
		return "";
	end

	local function RefreshText()
		LibDD:UIDropDownMenu_SetText(dropdown, GetCurrentLabel());
	end

	LibDD:UIDropDownMenu_Initialize(dropdown, function(self, level)
		for _, option in ipairs(options) do
			local info = LibDD:UIDropDownMenu_CreateInfo();
			info.text = option.label;
			info.checked = (option.value == getFn());
			info.func = function()
				setFn(option.value);
				SexyInterrupter:UpdateFrames();
				RefreshText();
			end
			LibDD:UIDropDownMenu_AddButton(info, level);
		end
	end);

	LibDD:UIDropDownMenu_SetWidth(dropdown, 150);
	RefreshText();
end

-- No Edit Mode widget for color pickers either - opens Blizzard's own native
-- ColorPickerFrame (same one the normal AceConfig color swatches use) via a
-- small clickable color swatch (not a full red-bordered button with the
-- label as its face text - stripped down and given its own label instead,
-- to match how the checkbox/dropdown rows look).
local function RegisterEditModeColorButton(EME, frame, label, hasAlpha, getFn, setFn)
	local RefreshSwatch;

	local function refresh()
		if RefreshSwatch then RefreshSwatch(); end
	end

	EME:RegisterCustomButton(frame, label, function()
		local r, g, b, a = getFn();

		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b,
			opacity = hasAlpha and a or nil,
			hasOpacity = hasAlpha,
			swatchFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB();
				setFn(nr, ng, nb, hasAlpha and ColorPickerFrame:GetColorAlpha() or a);
				SexyInterrupter:UpdateFrames();
				refresh();
			end,
			opacityFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB();
				setFn(nr, ng, nb, ColorPickerFrame:GetColorAlpha());
				SexyInterrupter:UpdateFrames();
				refresh();
			end,
			cancelFunc = function(previousValues)
				setFn(previousValues.r, previousValues.g, previousValues.b, hasAlpha and previousValues.a or a);
				SexyInterrupter:UpdateFrames();
				refresh();
			end,
		});
	end);

	-- RegisterCustomButton doesn't hand back the button it just created (only
	-- a getCurrentDB function we don't need here), but it does record it as
	-- the last entry of EME.framesDialogs[frame.system] (a public field of
	-- the library, unlike the internal setting-type numbers above) - that's
	-- our only way to reach the real button and rebuild it into a small
	-- swatch + label instead of a full-size button with text on its face.
	local dialog = EME.framesDialogs and EME.framesDialogs[frame.system];
	local button = dialog and dialog[table.getn(dialog)] and dialog[table.getn(dialog)].settingFrame;

	if button then
		-- Unlike the dropdown, RegisterCustomButton gives this button no
		-- per-row wrapper frame of its own - it's parented directly to the
		-- shared Settings container, and ITS OWN position (button:SetPoint,
		-- reset on every dialog refresh) is what the row-layout system
		-- controls. Anchoring a label to button:GetParent() put every color
		-- row's label at the same spot (the container's own corner), and
		-- moving the button off its assigned anchor broke the row layout
		-- entirely. Fix: leave the button's own position alone, just resize
		-- it to hold both the label and the swatch as its own children.
		button:SetSize(150, 20);
		button.Text:SetText("");

		-- Neither SetAlpha(0) nor :Hide() on GetNormalTexture()/etc actually
		-- removed the red UIPanelButtonTemplate skin - this client's version
		-- of the template apparently doesn't skin it through those texture
		-- slots (could be a NineSlice child frame instead). Don't guess
		-- further: blanket-hide every region and child frame the button has
		-- right now (before adding our own label/swatch below).
		for _, region in ipairs({ button:GetRegions() }) do
			if region.Hide then region:Hide(); end
		end

		for _, child in ipairs({ button:GetChildren() }) do
			child:Hide();
		end

		button:SetScript("OnEnter", nil);
		button:SetScript("OnLeave", nil);

		local labelText = button:CreateFontString(nil, nil, "GameFontHighlightMedium");
		labelText:SetPoint("LEFT", button, "LEFT", 0, 0);
		labelText:SetJustifyH("LEFT");
		labelText:SetWidth(100);
		labelText:SetText(label);

		local swatch = button:CreateTexture(nil, "ARTWORK");
		swatch:SetSize(20, 20);
		swatch:SetPoint("LEFT", labelText, "RIGHT", 5, 0);

		local swatchBorder = button:CreateTexture(nil, "BORDER");
		swatchBorder:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1);
		swatchBorder:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1);
		swatchBorder:SetColorTexture(0, 0, 0, 1);

		RefreshSwatch = function()
			local r, g, b = getFn();
			swatch:SetColorTexture(r, g, b, 1);
		end

		RefreshSwatch();
	end
end

-- Mirrors the settings that already exist in the normal options panel
-- (settings.lua) into Blizzard's real Edit Mode dialog for these two
-- frames, via checkboxes, sliders, LSM-backed dropdowns (font/statusbar-
-- texture/background-texture/border) and native-ColorPicker buttons (bar/
-- background/border/font color). Only the LSM sound picker and the
-- per-player priority-assignment tab (a whole dynamic sub-list, not a
-- single value) have no sane equivalent here and stay in the normal
-- options panel.
-- Für marks.lua (ruft die Registrierungs-Helfer von dort aus auf).
SexyInterrupter.EditModeHelpers = {
	Checkbox = RegisterEditModeCheckbox,
	Slider = RegisterEditModeSlider,
	Select = RegisterEditModeSelectDropdown,
	GetLiveDB = GetLiveDB,
	ComputeBottomLeft = ComputeBottomLeft,
};

function SexyInterrupter:RegisterEditModeSettings(EME, anchorFrame, messageFrame)
	RegisterEditModeCheckbox(EME, anchorFrame, "modeincombat", L["Show in combat only"],
		function() return self.db.profile.general.modeincombat end,
		function(value) self.db.profile.general.modeincombat = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "activeSolo", L["Active when solo"],
		function() return self.db.profile.general.activeSolo end,
		function(value) self.db.profile.general.activeSolo = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "ignoreHealer", L["Ignore healers"],
		function() return self.db.profile.general.ignoreHealer end,
		function(value) self.db.profile.general.ignoreHealer = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "fixedRotation", L["Fixed rotation order"],
		function() return self.db.profile.general.fixedRotation end,
		function(value) self.db.profile.general.fixedRotation = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "highlightOwn", L["Highlight own row"],
		function() return self.db.profile.general.highlightOwn end,
		function(value) self.db.profile.general.highlightOwn = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "minimapIcon", L["Show minimap icon"] or "Show minimap icon",
		function() return self.db.profile.general.minimapIcon end,
		function(value)
			self.db.profile.general.minimapIcon = value;

			-- self.icon is only assigned in OnInitialize AFTER CreateUi(), and the
			-- library may call this callback that early.
			if not self.icon then
				return;
			end

			if not self.icon:IsRegistered("SexyInterrupter") then
				SexyInterrupter:AddIcon();
			end

			if value then
				self.icon:Show("SexyInterrupter");
			else
				self.icon:Hide("SexyInterrupter");
			end
		end);

	RegisterEditModeCheckbox(EME, anchorFrame, "showclassicon", L["Show class icon"],
		function() return self.db.profile.ui.bars.showclassicon end,
		function(value) self.db.profile.ui.bars.showclassicon = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "barsuseclasscolor", L["Bar color by class"],
		function() return self.db.profile.ui.bars.useclasscolor end,
		function(value) self.db.profile.ui.bars.useclasscolor = value; end);

	RegisterEditModeCheckbox(EME, anchorFrame, "textuseclasscolor", L["Text color by class"],
		function() return self.db.profile.ui.useclasscolor end,
		function(value) self.db.profile.ui.useclasscolor = value; end);

	RegisterEditModeSlider(EME, anchorFrame, "maxrows", L["Max rows of interrupters"], 3, 30, 1,
		function() return self.db.profile.general.maxrows end,
		function(value) self.db.profile.general.maxrows = value; end);

	-- Wachstumsrichtung: siehe ausführlicher Kommentar bei SexyInterrupterAnchor:
	-- SetSize() in UpdateUI() - der Anker ist BOTTOMLEFT-verankert (Reload-
	-- Stabilität), wächst also standardmäßig nach oben; diese Option kompensiert
	-- das rechnerisch, damit stattdessen die obere Kante fix bleibt.
	RegisterEditModeSelectDropdown(EME, anchorFrame, "growdirection", L["Grow direction"] or "Grow direction",
		{
			{ value = false, label = L["Downward"] or "Downward" },
			{ value = true,  label = L["Upward"] or "Upward" },
		},
		function() return self.db.profile.ui.window.growUp end,
		function(value) self.db.profile.ui.window.growUp = value; end);

	RegisterEditModeSlider(EME, anchorFrame, "width", L["Width"], 100, 400, 1,
		function() return self.db.profile.ui.window.width end,
		function(value) self.db.profile.ui.window.width = value; end);

	RegisterEditModeSlider(EME, anchorFrame, "barheight", L["Bar height"], 4, 60, 1,
		function() return self.db.profile.ui.bars.barheight end,
		function(value) self.db.profile.ui.bars.barheight = value; end);

	RegisterEditModeSlider(EME, anchorFrame, "fontsize", L["Font size"], 4, 30, 1,
		function() return self.db.profile.ui.fontsize end,
		function(value) self.db.profile.ui.fontsize = value; end);

	RegisterEditModeMediaDropdown(EME, anchorFrame, "font", L["Font art"], "font",
		function() return self.db.profile.ui.font end,
		function(value) self.db.profile.ui.font = value; end);

	RegisterEditModeMediaDropdown(EME, anchorFrame, "bartexture", L["Statusbar"], "statusbar",
		function() return self.db.profile.ui.bars.texture end,
		function(value) self.db.profile.ui.bars.texture = value; end);

	RegisterEditModeMediaDropdown(EME, anchorFrame, "backgroundtexture", L["Background"], "background",
		function() return self.db.profile.ui.window.backgroundtexture end,
		function(value) self.db.profile.ui.window.backgroundtexture = value; end);

	RegisterEditModeMediaDropdown(EME, anchorFrame, "bordertexture", L["Border"], "border",
		function() return self.db.profile.ui.window.border end,
		function(value) self.db.profile.ui.window.border = value; end);

	RegisterEditModeColorButton(EME, anchorFrame, L["Bar color"], true,
		function()
			local c = self.db.profile.ui.bars.barcolor;
			return c.r, c.g, c.b, c.a;
		end,
		function(r, g, b, a)
			local c = self.db.profile.ui.bars.barcolor;
			c.r, c.g, c.b, c.a = r, g, b, a;
		end);

	RegisterEditModeColorButton(EME, anchorFrame, L["Background color"], true,
		function()
			local c = self.db.profile.ui.window.background;
			return c.r, c.g, c.b, c.a;
		end,
		function(r, g, b, a)
			local c = self.db.profile.ui.window.background;
			c.r, c.g, c.b, c.a = r, g, b, a;
		end);

	RegisterEditModeColorButton(EME, anchorFrame, L["Border color"], false,
		function()
			local c = self.db.profile.ui.window.bordercolor;
			return c.r, c.g, c.b, 1;
		end,
		function(r, g, b)
			local c = self.db.profile.ui.window.bordercolor;
			c.r, c.g, c.b = r, g, b;
		end);

	RegisterEditModeColorButton(EME, anchorFrame, L["Font color"], false,
		function()
			local c = self.db.profile.ui.fontcolor;
			return c.r, c.g, c.b, 1;
		end,
		function(r, g, b)
			local c = self.db.profile.ui.fontcolor;
			c.r, c.g, c.b = r, g, b;
		end);

	RegisterEditModeCheckbox(EME, messageFrame, "message", L["Show message"],
		function() return self.db.profile.notification.message end,
		function(value) self.db.profile.notification.message = value; end);

	RegisterEditModeCheckbox(EME, messageFrame, "sound", L["Play sound"],
		function() return self.db.profile.notification.sound end,
		function(value) self.db.profile.notification.sound = value; end);

	-- soundFile may hold a LibSharedMedia NAME (what the picker stores) or a raw
	-- file path (the default) - show the matching name either way.
	RegisterEditModeMediaDropdown(EME, messageFrame, "soundfile", L["Sound file"], "sound",
		function()
			local current = self.db.profile.notification.soundFile;

			for name, path in pairs(LSM:HashTable("sound")) do
				if name == current or path == current then
					return name;
				end
			end

			return current;
		end,
		function(value) self.db.profile.notification.soundFile = value; end);

	RegisterEditModeCheckbox(EME, messageFrame, "flash", L["Flash display"],
		function() return self.db.profile.notification.flash end,
		function(value) self.db.profile.notification.flash = value; end);

	RegisterEditModeCheckbox(EME, messageFrame, "interruptmessage", L["Show chat message"],
		function() return self.db.profile.notification.interruptmessage end,
		function(value) self.db.profile.notification.interruptmessage = value; end);

	local outputChannelOptions = {};

	for _, channel in ipairs({ 'SAY', 'YELL', 'PARTY', 'RAID' }) do
		tinsert(outputChannelOptions, { value = channel, label = SexyInterrupter.outputchannels[channel] });
	end

	RegisterEditModeSelectDropdown(EME, messageFrame, "outputchannel", L["Ouput channel"], outputChannelOptions,
		function() return self.db.profile.notification.outputchannel end,
		function(value) self.db.profile.notification.outputchannel = value; end);
end

function SexyInterrupter:UpdateFrames()
	local editing = SexyInterrupter:IsEditingUi();

	-- No SetPoint/ClearAllPoints here anymore: EditModeExpanded-1.0 (see
	-- CreateUi) owns positioning these two frames from here on, driven by
	-- Blizzard's real Edit Mode drag UI instead of our own anchor options.
	ApplyBackdrop(SexyInterrupterAnchor, self.db.profile);
	SexyInterrupterAnchor:SetBackdropBorderColor(self.db.profile.ui.window.bordercolor.r, self.db.profile.ui.window.bordercolor.g, self.db.profile.ui.window.bordercolor.b, self.db.profile.ui.window.bordercolor.a);

	for _, child in ipairs({ SexyInterrupterAnchor:GetChildren() }) do
		if child:GetName() and string.find(child:GetName(), "SexyInterrupterRow") then
			for _, subchild in ipairs({ child:GetChildren() }) do
				if string.find(subchild:GetName(), "SexyInterrupterStatusBar") then
					subchild:SetSize(self.db.profile.ui.window.width - 10, self.db.profile.ui.bars.barheight)
					subchild:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
					subchild:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a);

					if not self.db.profile.ui.bars.showclassicon then
						subchild.classicon:Hide();
					else
						subchild.classicon:Show();
					end

					subchild.text:SetFont(LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize, "OUTLINE");
					subchild.cooldownText:SetFont(LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize, "OUTLINE")
					subchild.cooldownText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
				end
			end
		end
	end

	do
		-- Die Vorschau-Nachricht liegt in einem eigenen FontString statt im
		-- MessageFrame: Text im MessageFrame beim Beenden des Edit Mode fuehrte zu
		-- einer ACCESS_VIOLATION (Client-Absturz). Ein FontString wird beim
		-- Schliessen einfach versteckt.
		local msgFrame = SexyInterrupterInterruptNowText;
		if not msgFrame.previewText then
			msgFrame.previewText = msgFrame:CreateFontString(nil, "OVERLAY");
			msgFrame.previewText:SetPoint("CENTER", msgFrame, "CENTER", 0, 0);
			msgFrame.previewText:SetWidth(500);
			msgFrame.previewText:Hide();
		end

		if editing then
			local fontPath = msgFrame:GetFont();
			msgFrame.previewText:SetFont(fontPath, 25, "OUTLINE");
			msgFrame.previewText:SetText(GetPreviewMessageText());
			msgFrame.previewText:Show();
		else
			msgFrame.previewText:Hide();
		end
	end

	local rows = editing and GetPreviewRows() or self:GetCurrentInterrupters();

	SexyInterrupter:UpdateUI(rows);
	SexyInterrupter:UpdateInterrupterStatus(rows, editing);

	if SexyInterrupter.UpdateMarkFrame then
		SexyInterrupter:UpdateMarkFrame();
	end
end

function SexyInterrupter:UpdateUI(rows)
	rows = rows or self:GetCurrentInterrupters();

	for cx, value in pairs(rows) do
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
			t:SetColorTexture(0, 0, 0, 0.4)

			f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. cx, _G["SexyInterrupterRow" .. cx])
			f:SetSize(self.db.profile.ui.window.width - 10, self.db.profile.ui.bars.barheight)
			f:SetPoint("LEFT", "SexyInterrupterRow" .. cx, "LEFT")
			f:SetOrientation("HORIZONTAL")
			f:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
			f:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a)
			f:SetFrameLevel(3)
			f:SetMinMaxValues(0, 100)
			f:SetValue(100)

			-- Role icon (Tank/Healer/Damage Dealer) on the left; the specific
			-- interrupt ability's own icon (once known) on the right, as its
			-- own separate texture - these are two different pieces of
			-- information, not one icon that swaps meaning.
			-- Hervorhebung der eigenen Zeile (Tönung + Akzentstreifen links),
			-- siehe UpdateInterrupterStatus().
			f.highlightBG = f:CreateTexture(nil, "ARTWORK");
			f.highlightBG:SetAllPoints(f);
			f.highlightBG:SetColorTexture(1, 0.82, 0, 0.25);
			f.highlightBG:Hide();

			f.highlightEdge = f:CreateTexture(nil, "OVERLAY");
			f.highlightEdge:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
			f.highlightEdge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
			f.highlightEdge:SetWidth(3);
			f.highlightEdge:SetColorTexture(1, 0.82, 0, 1);
			f.highlightEdge:Hide();

			f.classicon = f:CreateTexture(nil, "OVERLAY");
			f.classicon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
			f.classicon:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", 2, 0);
			f.classicon:SetTexCoord(unpack(self.role_icon_tcoords.DAMAGER));
			f.classicon:SetSize(16, 16);

			f.abilityicon = f:CreateTexture(nil, "OVERLAY");
			f.abilityicon:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. cx, "RIGHT", -2, 0);
			f.abilityicon:SetSize(16, 16);
			f.abilityicon:Hide();

			-- Offline-Symbol an der Stelle des Fähigkeiten-Icons.
			f.offlineicon = f:CreateTexture(nil, "OVERLAY");
			f.offlineicon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon");
			f.offlineicon:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. cx, "RIGHT", -2, 0);
			f.offlineicon:SetSize(16, 16);
			f.offlineicon:Hide();

			-- Texturen können in WoW keine Mausereignisse empfangen (nur
			-- Frames) - für den Tooltip deshalb ein unsichtbarer Frame exakt
			-- über dem Icon. spellId wird beim Update unten aktuell gehalten.
			f.abilityiconHitbox = CreateFrame("Frame", nil, f);
			f.abilityiconHitbox:SetAllPoints(f.abilityicon);
			f.abilityiconHitbox:EnableMouse(true);
			f.abilityiconHitbox:SetScript("OnEnter", function(self)
				if self.spellId then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
					GameTooltip:SetSpellByID(self.spellId);
					GameTooltip:Show();
				end
			end);
			f.abilityiconHitbox:SetScript("OnLeave", function() GameTooltip:Hide(); end);
			f.abilityiconHitbox:Hide();

			f.text = f:CreateFontString("SexyInterrupterStatusBarText" .. cx, nil, "GameFontNormal")
			f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", self.db.profile.ui.bars.showclassicon and 25 or 5, 0)
			f.text:SetSize(180 - 5, 20)
			f.text:SetJustifyH("LEFT")
			f.text:SetFont(LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize, "OUTLINE")
			f.text:SetText('Dummy')

			f.cooldownText = f:CreateFontString("SexyInterrupterStatusBarCooldownText" .. cx, nil, "GameFontNormal")
			f.cooldownText:SetSize(12*3, 12)
			f.cooldownText:SetJustifyH("RIGHT")
			f.cooldownText:SetPoint("RIGHT", f.abilityicon, "LEFT", -3, 0)
			f.cooldownText:SetFont(LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize, "OUTLINE")
			f.cooldownText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
		end
	end

	local editing = SexyInterrupter:IsEditingUi();
	local numRows = editing and #rows or SI_Globals.numInterrupters;

	if editing or numRows > 0 then
		local maxRows = numRows;

		if maxRows > self.db.profile.general.maxrows then
			maxRows = self.db.profile.general.maxrows;
		end

		-- Wachstumsrichtung: der Anker ist bei EditModeExpanded mit BOTTOMLEFT
		-- registriert (siehe RegisterFrame-Aufruf - das ist der einzige
		-- Ankerpunkt, dessen Umrechnung unabhängig von der aktuellen
		-- Fenstergröße ist, siehe Kommentar dort zum Reload-Sprung-Bug). Das
		-- bedeutet aber: ohne Weiteres bleibt beim Größenändern IMMER die
		-- untere Kante fix, das Fenster wächst also immer nach oben. Für
		-- "nach unten wachsen" hier stattdessen die neue Höhe von der
		-- gespeicherten unteren Kante abziehen, sodass rechnerisch die OBERE
		-- Kante fix bleibt (reines Rechnen auf db.y, kein Skalierungsproblem
		-- wie bei rohem GetLeft()/GetTop(), da BOTTOMLEFT->UIParent-BOTTOMLEFT
		-- bei UIParent-Ursprung (0,0) skalierungsunabhängig ist).
		local oldHeight = SexyInterrupterAnchor:GetHeight();
		local newHeight = (self.db.profile.ui.bars.barheight * maxRows) + 10;
		SexyInterrupterAnchor:SetSize(self.db.profile.ui.window.width, newHeight);

		-- WICHTIG: NICHT per ClearAllPoints()/SetPoint() eingreifen, während der
		-- Spieler das Fenster gerade per Maus zieht (frame.isDragging, von
		-- EditModeExpanded/Blizzards geschütztem Drag-Template gesetzt) - diese
		-- Funktion kann jederzeit durch andere Trigger (Gruppen-Update,
		-- Zauber-Events, Einstellungsänderungen) ausgelöst werden, auch mitten
		-- in einem laufenden Drag. Gleichzeitiges Umpositionieren desselben
		-- Frames kollidiert dann mit Blizzards eigener (geschützter) Drag-
		-- Logik - beobachtet als "Access denied"-Fehler mit Client-Absturz beim
		-- Verschieben. Die Kompensation wird einfach beim NÄCHSTEN UpdateUI()
		-- nach Drag-Ende nachgeholt (kein dauerhafter Datenverlust).
		if not self.db.profile.ui.window.growUp and not SexyInterrupterAnchor.isDragging then
			local anchorDB = GetLiveDB(SexyInterrupterAnchor, self.db.profile.ui.editModeAnchorDB);
			if anchorDB.x and anchorDB.y and oldHeight and oldHeight > 0 then
				anchorDB.y = anchorDB.y - (newHeight - oldHeight);
				SexyInterrupterAnchor:ClearAllPoints();
				SexyInterrupterAnchor:SetPoint(SexyInterrupterAnchor.EMEanchorPoint or "BOTTOMLEFT",
					SexyInterrupterAnchor.EMEanchorTo or UIParent,
					SexyInterrupterAnchor.EMEanchorPoint or "BOTTOMLEFT", anchorDB.x, anchorDB.y);
			end
		end

		if editing or not self.db.profile.general.modeincombat then
			SexyInterrupterAnchor:Show();
		end
	else
		SexyInterrupterAnchor:Hide();
	end
end

function SexyInterrupter:UpdateInterrupterStatus(rows, editing)
	rows = rows or SexyInterrupter:GetCurrentInterrupters();

	-- Event handlers (new ability learned, incoming interrupt, ...) call this
	-- directly with possibly MORE rows than frames exist yet - the frames are
	-- only created in UpdateUI().
	for cx in pairs(rows) do
		if not _G["SexyInterrupterRow" .. cx] then
			SexyInterrupter:UpdateUI(rows);
			break;
		end
	end

	-- Hide every row frame that could conceivably have been created before
	-- (by count, not by the current roster size - e.g. switching from a full
	-- live roster into the 3-row edit-mode preview must not leave old rows
	-- 4/5 stuck visible).
	local cx = 1;

	while _G["SexyInterrupterRow" .. cx] do
		_G["SexyInterrupterRow" .. cx]:Hide();
		cx = cx + 1;
	end

	local currentplayer = not editing and SexyInterrupter:GetInterrupter(select(1, UnitName("player"))) or nil;

	for cx, currentRow in pairs(rows) do
		local dataRow = currentRow;
		local row = _G["SexyInterrupterStatusBar" .. cx];
		local rowParent = _G["SexyInterrupterRow" .. cx];

		if rowParent and self.db.profile.general.maxrows >= cx then
			rowParent:Show();
		end

		if currentplayer and currentplayer.sortpos and currentplayer.sortpos > self.db.profile.general.maxrows and self.db.profile.general.maxrows == cx then
			-- Always show the local player in the last visible row even if
			-- their best ability sorted further down; keeps their own best
			-- (soonest-ready) ability visible via the mirrored player fields.
			dataRow = { interrupter = currentplayer, spellId = nil, cooldown = currentplayer.cooldown, readyTime = currentplayer.readyTime };

			rowParent:SetAlpha(0.5);
		else
			rowParent:SetAlpha(1);
		end

		local interrupter = dataRow.interrupter;

		-- Out of range: dim the whole row (bar included), not just the name.
		if interrupter.inrange == false then
			rowParent:SetAlpha(0.4);
		end

		if row and rowParent then
			row:SetMinMaxValues(0, 100);
			row:SetValue(100);
			row.cooldownText:SetText();

			local barcolor = self.db.profile.ui.bars.barcolor;
			row:SetStatusBarColor(barcolor.r, barcolor.g, barcolor.b, barcolor.a);

			if self.db.profile.ui.bars.useclasscolor and interrupter.classColor then
				row:SetStatusBarColor(interrupter.classColor.r, interrupter.classColor.g, interrupter.classColor.b, 1)
			end

			if interrupter.offline then
				-- Platz bleibt belegt: ausgegraute Leiste mit Namen und
				-- Offline-Symbol (siehe unten), statt die Zeile zu verstecken.
				row:SetStatusBarColor(0.4, 0.4, 0.4, 1);
				row.text:SetTextColor(0.6, 0.6, 0.6, 1);
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

			if not self.db.profile.ui.bars.showclassicon then
				row.classicon:Hide();
			elseif not interrupter.role or interrupter.role == 'NONE' then
				row.classicon:Hide();
			else
				row.classicon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
				row.classicon:SetTexCoord(unpack(self.role_icon_tcoords[interrupter.role]));
				row.classicon:Show();
			end

			-- Text-Versatz hier bei JEDEM Update neu setzen (nicht nur einmal bei
			-- der Zeilen-Erstellung, siehe f.text:SetPoint weiter oben) - sonst
			-- bleibt der Text hinter dem Class-Icon hängen, wenn "Show class
			-- icon" nachträglich per Edit-Mode-Checkbox umgeschaltet wird.
			row.text:ClearAllPoints();
			row.text:SetPoint("LEFT", row, "LEFT", self.db.profile.ui.bars.showclassicon and 25 or 5, 0);

			if not self.db.profile.ui.bars.showclassicon or not dataRow.spellId then
				row.abilityicon:Hide();
				row.abilityiconHitbox:Hide();
			else
				-- One row per known ability: show that ability's own icon
				-- alongside (not instead of) the role icon.
				local texture = GetSpellTextureCompat(dataRow.spellId);

				if texture then
					row.abilityicon:SetTexture(texture);
					row.abilityicon:SetTexCoord(0, 1, 0, 1);
					row.abilityicon:Show();
					row.abilityiconHitbox.spellId = dataRow.spellId;
					row.abilityiconHitbox:Show();
				else
					row.abilityicon:Hide();
					row.abilityiconHitbox:Hide();
				end
			end

			if dataRow.cooldown > 0 then
				row:SetMinMaxValues(0, dataRow.cooldown);
				row.cooldownText:Show();

				if dataRow.readyTime - GetTime() > 0 then
					local readyTime = dataRow.readyTime - GetTime();

					-- Unformatierte Fließkommazahl (z. B. "15.347293847...")
					-- sprengte das nur 36px breite cooldownText-Feld und wurde
					-- als "15..." abgeschnitten dargestellt. OnUpdate() weiter
					-- unten macht es an der entsprechenden Stelle bereits
					-- richtig (string.format '%.1f') - hier genauso.
					row.cooldownText:SetText(string.format('%.1f', readyTime));
					row:SetValue(readyTime);
				end
			else
				row.cooldownText:Hide();
			end

			row.text:SetText(interrupter.name);

			local isOwn = self.db.profile.general.highlightOwn
				and ((editing and cx == 1) or (not editing and interrupter.name == UnitName("player")));

			if isOwn then
				row.highlightBG:Show();
				row.highlightEdge:Show();
			else
				row.highlightBG:Hide();
				row.highlightEdge:Hide();
			end

			if interrupter.offline then
				row:SetMinMaxValues(0, 100);
				row:SetValue(100);
				row.abilityicon:Hide();
				row.abilityiconHitbox:Hide();
				row.cooldownText:Hide();
				row.offlineicon:Show();
				rowParent:SetAlpha(0.6);
			else
				row.offlineicon:Hide();
			end
		end
	end
end

-- Runs as the anchor frame's OnUpdate script (self = the frame). Throttled:
-- rebuilding + sorting the roster every rendered frame is wasted work for a
-- countdown text with one decimal.
local ON_UPDATE_INTERVAL = 0.1;

function SexyInterrupter:OnUpdate(elapsed)
	self.siElapsed = (self.siElapsed or 0) + (elapsed or 0);

	if self.siElapsed < ON_UPDATE_INTERVAL then
		return;
	end

	self.siElapsed = 0;

	local editing = SexyInterrupter:IsEditingUi();
	local rows = editing and GetPreviewRows() or SexyInterrupter:GetCurrentInterrupters();
	local currentplayer = not editing and SexyInterrupter:GetInterrupter(select(1, UnitName("player"))) or nil;
	local now = GetTime();

	for cx, value in pairs(rows) do
		if currentplayer and currentplayer.sortpos and currentplayer.sortpos > SexyInterrupter.db.profile.general.maxrows and SexyInterrupter.db.profile.general.maxrows == cx then
			value = currentplayer;
		end

		if value.readyTime == 0 then
			-- GetCurrentInterrupters() normalisiert einen abgelaufenen Cooldown
			-- schon vorher auf 0, der Zweig unten sieht ihn dann nie mehr ablaufen:
			-- der letzte Wert (z. B. "0.0") blieb stehen und die Leiste leer.
			local bar = _G["SexyInterrupterStatusBar" .. cx];
			local text = bar and bar.cooldownText:GetText();

			if text and text ~= '' then
				bar.cooldownText:SetText('');
				bar:SetMinMaxValues(0, 100);
				bar:SetValue(100);
			end
		elseif value.readyTime > 0 and not (value.interrupter and value.interrupter.offline) then
			local bar = _G["SexyInterrupterStatusBar" .. cx];

			if bar then
				local remaining = value.readyTime - now;

				-- No early return anymore: it skipped every remaining row and the
				-- range refresh below for the whole frame.
				if remaining <= 0 then
					bar.cooldownText:SetText('');
					value.readyTime = 0;

					bar:SetMinMaxValues(0, 100);
					bar:SetValue(100);
				else
					bar:SetValue(remaining);
					bar.cooldownText:SetText(string.format('%.1f', remaining));
				end
			end
		end
	end

	if not editing then
		local rangeChanged = false;

		for i = 1, GetNumGroupMembers() do
			local unit = "party" .. i;

			if IsInRaid() then
				unit = "raid" .. i;
			end

			if not UnitExists(unit) then
				unit = 'player';
			end

			local interrupter = SexyInterrupter:GetInterrupterByUnit(unit);

			if interrupter ~= nil then
				local inRange = SexyInterrupter:UnitInRangeCompat(unit);

				if inRange ~= nil and interrupter.inrange ~= inRange then
					interrupter.inrange = inRange;
					rangeChanged = true;
				end

				-- Tot/Offline/AFK ebenfalls laufend nachführen: GROUP_ROSTER_UPDATE
				-- feuert beim Wiederbeleben nicht, der Name blieb sonst rot.
				-- Die Unit-Abfragen können "secret"-Booleans liefern (z.B. im Kampf);
				-- ein Boolean-Test darauf wirft einen Fehler -> dann den alten Wert behalten.
				local function Safe(value, old)
					if issecretvalue and issecretvalue(value) then
						return old;
					end
					return value and true or false;
				end

				local dead = Safe(UnitIsDeadOrGhost(unit), interrupter.dead);
				local connected = Safe(UnitIsConnected(unit), not interrupter.offline);
				local offline = not connected;
				local afk = Safe(UnitIsAFK(unit), interrupter.afk);

				if interrupter.dead ~= dead or interrupter.offline ~= offline or interrupter.afk ~= afk then
					interrupter.dead = dead;
					interrupter.offline = offline;
					interrupter.afk = afk;
					rangeChanged = true;
				end
			end
		end

		if GetNumGroupMembers() == 0 then
			local own = SexyInterrupter:GetInterrupterByUnit("player");
			local deadRaw = UnitIsDeadOrGhost("player");
			local dead;
			if issecretvalue and issecretvalue(deadRaw) then
				dead = own and own.dead;
			else
				dead = deadRaw and true or false;
			end

			if own and own.dead ~= dead then
				own.dead = dead;
				rangeChanged = true;
			end
		end

		-- The flag alone changes nothing on screen (the row colours are only
		-- applied while rendering) - re-render when someone crossed the range
		-- boundary, otherwise the dimming never showed up.
		if rangeChanged then
			SexyInterrupter:UpdateInterrupterStatus();
		end
	end
end
