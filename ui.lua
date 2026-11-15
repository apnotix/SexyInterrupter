local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);
local SEM = LibStub("SexyEditMode-1.0");

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

-- Die Position steht in der übergebenen DB-Tabelle (SexyEditMode speichert dort x/y).
local function GetLiveDB(frame, fallback)
	return fallback;
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

-- Look wie SexyQuestHelper und SexyLoot: dunkelbraune Fläche, 2-px-Goldrand, Titelband
-- mit Badge, farbige Etiketten. Schriften: Marcellus (Titel), Inter (Text), beide in
-- media/fonts (SIL OFL) und bei LibSharedMedia angemeldet, damit sie in der Auswahl
-- "Schriftart" erscheinen. Auf Clients ohne westliche Schrift (ru/ko/zh) werden sie
-- nicht angemeldet, LSM:Fetch liefert dann die Standardschrift.
local FONT_DIR = "Interface\\AddOns\\SexyInterrupter\\media\\fonts\\";
local FLAT = "Interface\\Buttons\\WHITE8x8";
local HEAD = 30;           -- Rahmen oben plus Titelband
local CARD = { 0.145, 0.125, 0.10, 1 };      -- Zeilenfläche
local DIVIDER = { 0.21, 0.19, 0.14, 1 };     -- Trennlinie
local BAND = { 0.15, 0.12, 0.07, 0.96 };     -- Titelband
local COOLING = { 0.22, 0.17, 0.08 };        -- Leiste, solange der Cooldown läuft (dunkles Braun)
local TONES = {
	ok = { bg = { 0.082, 0.188, 0.11 }, fg = { 0.48, 0.88, 0.56 } },
	warn = { bg = { 0.227, 0.173, 0.063 }, fg = { 0.94, 0.75, 0.29 } },
	grey = { bg = { 0.16, 0.145, 0.12 }, fg = { 0.66, 0.61, 0.54 } },
	lack = { bg = { 0.231, 0.102, 0.09 }, fg = { 1, 0.6, 0.56 } },
};

if LSM.LOCALE_BIT_western then
	LSM:Register("font", "Marcellus", FONT_DIR .. "Marcellus-Regular.ttf", LSM.LOCALE_BIT_western);
	LSM:Register("font", "Inter", FONT_DIR .. "Inter.ttf", LSM.LOCALE_BIT_western);
end

-- Text ohne Kontur, mit leichtem Schatten (flacher Look)
local function StyleText(fs, font, size)
	fs:SetFont(font, size, "");
	fs:SetShadowColor(0, 0, 0, 1);
	fs:SetShadowOffset(1, -1);
end

local function TitleFont()
	return LSM:Fetch("font", "Marcellus");
end

-- Flache Leistentextur (ohne Glanzverlauf), neuer Standard für die Leisten
LSM:Register("statusbar", "Flat", FLAT);

local function TextFont()
	return LSM:Fetch("font", "Inter");
end

-- Etikett (Pille): Fläche plus Text, p:Set(tone, text) färbt und passt die Breite an.
local function MakePill(parent)
	local p = {};

	p.bg = parent:CreateTexture(nil, "ARTWORK", nil, 5);
	p.text = parent:CreateFontString(nil, "OVERLAY");
	p.text:SetFont(TextFont(), 11, "");
	p.text:SetPoint("CENTER", p.bg, "CENTER", 0, 0);

	function p:Set(tone, text, size)
		local t = TONES[tone];

		self.text:SetFont(TextFont(), size or 11, "");
		self.text:SetText(text);
		self.text:SetTextColor(t.fg[1], t.fg[2], t.fg[3]);
		self.bg:SetColorTexture(t.bg[1], t.bg[2], t.bg[3], 1);

		-- Ist der Text ein "geheimer Wert", laesst sich seine Breite nicht rechnen: dann feste Breite
		local ok, width = pcall(function() return self.text:GetStringWidth() + 14; end);

		self.bg:SetSize(ok and width or 130, (size or 11) + 5);
		self.bg:Show();
		self.text:Show();
	end

	function p:Hide()
		self.bg:Hide();
		self.text:Hide();
	end

	return p;
end

-- Titelband mit Titel (links) und Badge (rechts, frame:SetBadge(text), "" blendet aus).
local function CreateBand(frame, title, bandColor, titleColor)
	local band = frame:CreateTexture(nil, "BACKGROUND", nil, 1);
	local bc = bandColor or BAND;
	local tc = titleColor or { 0.91, 0.76, 0.42 };

	band:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3);
	band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3);
	band:SetHeight(HEAD - 3);
	band:SetColorTexture(bc[1], bc[2], bc[3], bc[4]);
	frame.band = band;

	frame.title = frame:CreateFontString(nil, "OVERLAY");
	frame.title:SetFont(TitleFont(), 14, "");
	frame.title:SetTextColor(tc[1], tc[2], tc[3]);
	frame.title:SetPoint("LEFT", band, "LEFT", 8, 0);
	frame.title:SetText(title);

	local badgeBg = frame:CreateTexture(nil, "ARTWORK");
	badgeBg:SetPoint("RIGHT", band, "RIGHT", -6, 0);
	badgeBg:SetHeight(18);
	badgeBg:SetColorTexture(0.165, 0.14, 0.10, 1);
	local badgeText = frame:CreateFontString(nil, "OVERLAY");
	badgeText:SetFont(TextFont(), 11, "");
	badgeText:SetPoint("CENTER", badgeBg, "CENTER", 0, 0);
	badgeText:SetTextColor(0.78, 0.73, 0.64);

	function frame:SetBadge(text)
		local show = text ~= nil and text ~= "";

		badgeBg:SetShown(show);
		badgeText:SetShown(show);

		if show then
			badgeText:SetText(text);
			badgeBg:SetWidth(badgeText:GetStringWidth() + 18);
		end
	end

	frame:SetBadge("");
end

-- Rahmen wie im SexyQuestHelper-Fenster: Tooltip-Fläche und Tooltip-Rand (12 px, gold gefärbt).
-- Hintergrund- und Randfarbe sind fest (Quest-Look) und nicht einstellbar.
local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
};

local WINDOW_BG = { 0.08, 0.065, 0.05, 0.96 };
local WINDOW_EDGE = { 0.42, 0.34, 0.15, 1 };

local function ApplyBackdrop(frame)
	frame:SetBackdrop(BACKDROP);
	frame:SetBackdropColor(WINDOW_BG[1], WINDOW_BG[2], WINDOW_BG[3], WINDOW_BG[4]);
	frame:SetBackdropBorderColor(WINDOW_EDGE[1], WINDOW_EDGE[2], WINDOW_EDGE[3], WINDOW_EDGE[4]);
end

SexyInterrupter.Look = {
	HEAD = HEAD, CARD = CARD, DIVIDER = DIVIDER, TONES = TONES,
	MakePill = MakePill, CreateBand = CreateBand, TextFont = TextFont, TitleFont = TitleFont, StyleText = StyleText,
};

-- Karte "Unterbrich jetzt!" (oberes Mockup): Band mit rotem Rand, Zaubersymbol, Name des
-- Ziels groß, Etiketten für Zaubername und Restzeit. Der Frame selbst bleibt immer
-- sichtbar (Edit-Mode-Auswahl), die Karte (c.panel) wird ein- und ausgeblendet.
local ALERT_W, ALERT_H = 440, HEAD + 96;   -- unten Platz für Zauberbalken und Restzeit-Abzeichen
local ALERT_EDGE = { 0.54, 0.20, 0.15, 1 };
local ALERT_BAND = { 0.18, 0.08, 0.07, 0.96 };

-- Weicher Schein um ein Ziel: neun Texturteile (vier Ecken fest, Kanten und Mitte gedehnt)
-- aus media/glow128.tga, wie die Gewinner-Anzeige in SexyLoot. Liefert ein Objekt mit
-- :SetColor(r, g, b, a). texSize/tc: Kantenlänge der Textur und Eckgröße darin (Pixel),
-- disp: Eckgröße auf dem Bildschirm, out: wie weit der Schein über das Ziel hinausragt.
local GLOW_TEX = "Interface\\AddOns\\SexyInterrupter\\media\\glow128.tga";

local function NineSliceGlow(parent, target, texSize, tc, disp, out)
	local f = tc / texSize;
	local pieces = {};

	local function tex(l, r, t, b)
		local x = parent:CreateTexture(nil, "BACKGROUND");
		x:SetTexture(GLOW_TEX);
		x:SetTexCoord(l, r, t, b);
		pieces[#pieces + 1] = x;
		return x;
	end

	local tl = tex(0, f, 0, f);          tl:SetSize(disp, disp); tl:SetPoint("TOPLEFT", target, "TOPLEFT", -out, out);
	local tr = tex(1 - f, 1, 0, f);      tr:SetSize(disp, disp); tr:SetPoint("TOPRIGHT", target, "TOPRIGHT", out, out);
	local bl = tex(0, f, 1 - f, 1);      bl:SetSize(disp, disp); bl:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -out, -out);
	local br = tex(1 - f, 1, 1 - f, 1);  br:SetSize(disp, disp); br:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", out, -out);
	local top = tex(f, 1 - f, 0, f);     top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT");
	local bot = tex(f, 1 - f, 1 - f, 1); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT");
	local lef = tex(0, f, f, 1 - f);     lef:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); lef:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT");
	local rig = tex(1 - f, 1, f, 1 - f); rig:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rig:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT");
	local mid = tex(f, 1 - f, f, 1 - f); mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT");

	local obj = {};

	function obj:SetColor(r, g, b, a)
		for _, x in ipairs(pieces) do
			x:SetVertexColor(r, g, b, a or 1);
		end
	end

	return obj;
end

local function CreateAlertCard(addon)
	local c = CreateFrame("Frame", "SexyInterrupterInterruptNowText", UIParent);
	c:SetSize(ALERT_W, ALERT_H);

	local p = CreateFrame("Frame", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil);
	p:SetAllPoints(c);
	p:SetBackdrop(BACKDROP);
	p:SetBackdropColor(0.08, 0.065, 0.05, 0.96);
	p:SetBackdropBorderColor(ALERT_EDGE[1], ALERT_EDGE[2], ALERT_EDGE[3], ALERT_EDGE[4]);
	CreateBand(p, L["Interrupt now"] .. "!", ALERT_BAND, { 1, 0.71, 0.66 });
	p:SetBadge(L["You are up"]);
	p:Hide();
	c.panel = p;

	-- Roter, pulsierender Schein um die Karte (wie bei "Gewinner" in SexyLoot). Der Schein
	-- liegt in einem eigenen Frame über der Karte und ist innen durchsichtig.
	local glow = CreateFrame("Frame", nil, p);
	glow:SetAllPoints(p);
	NineSliceGlow(glow, p, 128, 48, 48, 32):SetColor(1, 0.3, 0.2, 1);

	local pulse = glow:CreateAnimationGroup();
	local fade = pulse:CreateAnimation("Alpha");

	if fade.SetFromAlpha then
		fade:SetFromAlpha(1);
		fade:SetToAlpha(0.45);
	else
		fade:SetChange(-0.55);
	end

	fade:SetDuration(0.9);
	fade:SetSmoothing("IN_OUT");
	pulse:SetLooping("BOUNCE");
	p:SetScript("OnShow", function() pulse:Play(); end);
	p:SetScript("OnHide", function() pulse:Stop(); end);

	-- Zaubersymbol mit Rahmen
	p.iconBorder = p:CreateTexture(nil, "ARTWORK");
	p.iconBorder:SetColorTexture(1, 0.6, 0.53, 1);
	p.icon = p:CreateTexture(nil, "OVERLAY");
	p.icon:SetSize(44, 44);
	p.icon:SetPoint("TOPLEFT", p, "TOPLEFT", 18, -(HEAD + 12));
	p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	p.iconBorder:SetPoint("TOPLEFT", p.icon, "TOPLEFT", -2, 2);
	p.iconBorder:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", 2, -2);

	p.name = p:CreateFontString(nil, "OVERLAY");
	p.name:SetFont(TitleFont(), 26, "");
	p.name:SetTextColor(0.95, 0.92, 0.86);
	p.name:SetJustifyH("LEFT");
	p.name:SetWordWrap(false);
	p.name:SetPoint("TOPLEFT", p.icon, "TOPRIGHT", 14, 2);
	p.name:SetPoint("RIGHT", p, "RIGHT", -16, 0);

	p.spellPill = MakePill(p);
	p.timePill = MakePill(p);
	p.spellPill.bg:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -6);
	p.timePill.bg:SetPoint("LEFT", p.spellPill.bg, "RIGHT", 6, 0);

	-- Kleiner Knopf unten rechts: den Zauber auf die Liste der Instanz setzen oder wieder entfernen
	local mark = CreateFrame("Button", nil, p);
	mark:SetSize(112, 18);
	mark:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 36);
	mark:RegisterForClicks("LeftButtonUp");
	mark.bg = mark:CreateTexture(nil, "BACKGROUND");
	mark.bg:SetAllPoints();
	mark.bg:SetColorTexture(0.165, 0.14, 0.10, 1);
	mark.hl = mark:CreateTexture(nil, "HIGHLIGHT");
	mark.hl:SetAllPoints();
	mark.hl:SetColorTexture(1, 1, 1, 0.12);
	mark.text = mark:CreateFontString(nil, "OVERLAY");
	StyleText(mark.text, LSM:Fetch("font", "Inter") or STANDARD_TEXT_FONT, 10);
	mark.text:SetPoint("CENTER");
	mark.text:SetTextColor(0.91, 0.76, 0.42);
	mark:SetScript("OnClick", function()
		addon:ToggleKicklist(c.cast);
		c:UpdateMark();
	end);
	mark:Hide();
	p.mark = mark;

	function c:UpdateMark()
		local entry = self.cast and addon:GetKicklist(false);
		local muted = entry and entry.spells[self.cast] == false;

		-- nur in Instanzen und mit lesbarem Zaubernamen
		if self.cast and addon:InstanceInfo() and not self.previewing then
			self.panel.mark.text:SetText(muted and L["Report again"] or L["Mute spell"]);
			self.panel.mark:Show();
		else
			self.panel.mark:Hide();
		end
	end

	-- Fortschrittsbalken des Zaubers: die geheimen Zeiten gehen direkt an SetMinMaxValues, der Wert
	-- kommt aus GetTime() - so laesst sich der Fortschritt zeigen, ohne die Zahlen zu lesen
	local bar = CreateFrame("StatusBar", nil, p);
	bar:SetHeight(10);
	bar:SetPoint("LEFT", p, "BOTTOMLEFT", 18, 21);
	bar:SetPoint("RIGHT", p, "BOTTOMRIGHT", -18, 21);
	bar:SetStatusBarTexture(LSM:Fetch("statusbar", "Flat") or "Interface\\Buttons\\WHITE8X8");
	bar:SetStatusBarColor(0.94, 0.75, 0.29, 1);
	bar.bg = bar:CreateTexture(nil, "BACKGROUND");
	bar.bg:SetAllPoints();
	bar.bg:SetColorTexture(0.21, 0.19, 0.14, 1);
	bar:Hide();
	p.bar = bar;

	function c:ShowAlert(targetName, spellName, texture, endTime, seconds, startTime)
		local p = self.panel;
		self.cast = spellName;

		p.name:SetText(targetName or "");

		-- Symbol: auch ein geheimer Wert darf direkt an SetTexture
		local textured = false;

		if texture ~= nil then
			textured = pcall(p.icon.SetTexture, p.icon, texture);
		end

		if not textured then
			p.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
		end

		-- Zaubername als Etikett (auch ein geheimer Name wird angezeigt)
		local named = false;

		if spellName ~= nil then
			named = pcall(p.spellPill.Set, p.spellPill, "lack", spellName, 12);
		end

		if not named then
			p.spellPill:Hide();
		end

		-- Restzeit als Abzeichen ganz hinten am Zauberbalken
		p.timePill.bg:ClearAllPoints();
		p.timePill.bg:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -18, 12.5);

		-- Restzeit als Zahl, wenn sie lesbar ist; sonst nur der Balken
		self.endAt = nil;
		self.hideAt = seconds and (GetTime() + seconds) or nil;
		self.previewing = false;
		self:UpdateMark();

		if endTime ~= nil then
			pcall(function() self.endAt = endTime / 1000; end);
		end

		if self.endAt then
			p.timePill:Set("grey", string.format("%.1f s", math.max(0, self.endAt - GetTime())), 12);
		else
			p.timePill:Hide();
		end

		-- Der Balken reicht bis zum Abzeichen; fehlt die Zeit, geht er bis zum Rand
		p.bar:ClearAllPoints();
		p.bar:SetPoint("LEFT", p, "BOTTOMLEFT", 18, 21);

		if self.endAt then
			p.bar:SetPoint("RIGHT", p.timePill.bg, "LEFT", -6, 0);
		else
			p.bar:SetPoint("RIGHT", p, "BOTTOMRIGHT", -18, 21);
		end

		self.barOn = false;
		p.bar:Hide();

		if startTime ~= nil and endTime ~= nil then
			self.barOn = pcall(p.bar.SetMinMaxValues, p.bar, startTime, endTime);

			if self.barOn then
				p.bar:SetValue(GetTime() * 1000);
				p.bar:Show();
			end
		end

		p:Show();
	end

	function c:ShowPreview()
		local p = self.panel;

		self.endAt, self.hideAt, self.previewing = nil, nil, true;
		self.barOn = false;
		self.cast = nil;
		p.mark:Hide();
		p.name:SetText(L["Preview Target"]);
		p.icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt");
		p.spellPill:Set("lack", L["Preview Spell"], 12);
		p.timePill:Set("grey", "1.8 s", 12);
		p.timePill.bg:ClearAllPoints();
		p.timePill.bg:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -18, 12.5);
		p.bar:ClearAllPoints();
		p.bar:SetPoint("LEFT", p, "BOTTOMLEFT", 18, 21);
		p.bar:SetPoint("RIGHT", p.timePill.bg, "LEFT", -6, 0);
		p.bar:SetMinMaxValues(0, 1);
		p.bar:SetValue(0.6);
		p.bar:Show();
		p:Show();
	end

	function c:HideAlert()
		self.endAt, self.hideAt, self.previewing = nil, nil, false;
		self.panel:Hide();
	end

	-- Restzeit zählen lassen und die Karte nach der Anzeigedauer ausblenden
	c:SetScript("OnUpdate", function(self, elapsed)
		if not self.panel:IsShown() or self.previewing then
			return;
		end

		local now = GetTime();

		if self.hideAt and now >= self.hideAt then
			self:HideAlert();
			return;
		end

		if self.endAt then
			self.panel.timePill:Set("grey", string.format("%.1f s", math.max(0, self.endAt - now)), 12);
		end

		if self.barOn then
			self.panel.bar:SetValue(now * 1000);
		end
	end);

	return c;
end

function SexyInterrupter:CreateUi()
	-- Frame: Anchor
	local f = CreateFrame("Frame", "SexyInterrupterAnchor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil);

    -- The old options panel allowed any width (-9999..9999); the Edit Mode
    -- slider only covers 100-400, so bring stored values into that range once.
    self.db.profile.ui.window.width = math.max(100, math.min(400, self.db.profile.ui.window.width))

    -- Einmalig pro Profil: Die Oberkante des Fensters bleibt beim Ändern der Zeilenzahl
    -- stehen ("Nach unten wachsen"). Mit der alten Einstellung "Nach oben" saß das Fenster
    -- nach dem Edit Mode (Vorschau mit allen Zeilen) unten im großen Rahmen. Die Option
    -- bleibt im Edit Mode wählbar.
    if not self.db.profile.ui.window.topFixedMigrated then
        self.db.profile.ui.window.growUp = false
        self.db.profile.ui.window.topFixedMigrated = true
    end

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

	ApplyBackdrop(f);
	f:SetScript("OnUpdate", SexyInterrupter.OnUpdate);

	-- Titelband mit Badge ("N bereit", siehe UpdateInterrupterStatus)
	CreateBand(f, L["Interrupts"]);

	-- Frame: InterruptMessage - Karte "Unterbrich jetzt!" (siehe CreateAlertCard)
	local c = CreateAlertCard(self);

    c:SetPoint(self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint, self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y);

    -- Siehe Kommentar bei editModeAnchorDB weiter oben - dasselbe für die
    -- Notification-Position.
    if not (self.db.profile.ui.editModeMessageDB.x and self.db.profile.ui.editModeMessageDB.y) then
        self.db.profile.ui.editModeMessageDB.x, self.db.profile.ui.editModeMessageDB.y = ComputeBottomLeft(
            self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint,
            self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y, ALERT_W, c:GetHeight())
        self.db.profile.ui.editModeMessageDB.autoSeeded = true
    end

	-- Beide Fenster im Edit Mode anmelden (eigene Bibliothek SexyEditMode-1.0). Position,
	-- Größe und Sichtbarkeit speichert sie in editModeAnchorDB/editModeMessageDB (BOTTOMLEFT
	-- von UIParent: die untere Kante bleibt fest, auch wenn sich die Zeilenzahl ändert).
	-- Nach den SetPoint-Aufrufen oben registrieren, damit die berechnete Startposition gilt.
	SEM:Register(f, {
		name = L["Addon name"] .. " " .. L["Window"],
		db = self.db.profile.ui.editModeAnchorDB,
		settings = self:AnchorSettings(),
		onEditMode = function() SexyInterrupter:UpdateFrames(); end,
	});
	SEM:Register(c, {
		name = L["Addon name"] .. " " .. L["Interrupt now"],
		db = self.db.profile.ui.editModeMessageDB,
		settings = self:MessageSettings(),
		visibility = false, -- die Karte blendet sich selbst ein und aus
	});

	-- "autoSeeded" markiert nur einen von UNS berechneten Startwert und muss verschwinden,
	-- sobald der Spieler die Position selbst setzt - sonst überschreibt der Korrektur-Timer
	-- unten sie bei jedem /reload wieder.
	f.Selection:HookScript("OnDragStop", function()
		self.db.profile.ui.editModeAnchorDB.autoSeeded = nil;
	end);
	c.Selection:HookScript("OnDragStop", function()
		self.db.profile.ui.editModeMessageDB.autoSeeded = nil;
	end);

	-- Gegner-Marker-Fenster (marks.lua) meldet sich selbst an.
	-- nil, solange marks.lua nicht in der .toc geladen wird.
	if SexyInterrupter.CreateMarkFrame then
		SexyInterrupter:CreateMarkFrame(SexyInterrupter.EditModeHelpers);
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
		if anchorDB.autoSeeded and not SEM:IsMoving(f) then
			local x, y = ComputeBottomLeft(
				self.db.profile.ui.anchorPosition.point, anchorRegion, self.db.profile.ui.anchorPosition.relativePoint,
				self.db.profile.ui.anchorPosition.x, self.db.profile.ui.anchorPosition.y,
				self.db.profile.ui.window.width, 100)
			if x and y then
				anchorDB.x, anchorDB.y = x, y
					SEM:SetPosition(f, x, y)
			end
		end

		local messageDB = self.db.profile.ui.editModeMessageDB
		if messageDB.autoSeeded and not SEM:IsMoving(c) then
			local mx, my = ComputeBottomLeft(
				self.db.profile.ui.messagePosition.point, UIParent, self.db.profile.ui.messagePosition.relativePoint,
				self.db.profile.ui.messagePosition.x, self.db.profile.ui.messagePosition.y, ALERT_W, c:GetHeight())
			if mx and my then
				messageDB.x, messageDB.y = mx, my
					SEM:SetPosition(c, mx, my)
			end
		end
	end)
end

-- Edit-Mode-Dialog (SexyEditMode-1.0) ------------------------------------------------
-- Die Einstellungen liegen weiter in AceDB (einzige Quelle); der Dialog liest und schreibt
-- sie direkt. Die Helfer bauen die Zeilen-Beschreibungen der Bibliothek.
local function Header(label, id, collapsed)
	return { type = "header", name = label, id = id, collapsed = collapsed };
end

-- Verweis auf ein zugehöriges Fenster (Klick zeigt dessen Einstellungen)
local function Link(label, frameFn)
	return { type = "link", name = label, frame = frameFn };
end

local function Check(label, getFn, setFn)
	return {
		type = "check", name = label,
		get = function() return getFn() and true or false; end,
		set = function(value) setFn(value); SexyInterrupter:UpdateFrames(); end,
	};
end

local function Slider(label, min, max, step, getFn, setFn)
	return {
		type = "slider", name = label, min = min, max = max, step = step,
		get = getFn,
		set = function(value) setFn(value); SexyInterrupter:UpdateFrames(); end,
	};
end

-- options ist eine Liste aus { value = ..., label = "..." } (oder eine Funktion, die sie liefert)
local function Select(label, options, getFn, setFn)
	return {
		type = "select", name = label, options = options,
		get = getFn,
		set = function(value) setFn(value); SexyInterrupter:UpdateFrames(); end,
	};
end

-- Auswahl aus LibSharedMedia (Schrift, Statusbar, Sound); Sounds spielen beim Wählen kurz
local function MediaSelect(label, mediaType, getFn, setFn)
	local function Options()
		local names = {};

		for name in pairs(LSM:HashTable(mediaType)) do
			tinsert(names, name);
		end

		table.sort(names);

		local list = {};

		for _, name in ipairs(names) do
			list[#list + 1] = { value = name, label = name };
		end

		return list;
	end

	return {
		type = "select", name = label, options = Options,
		get = getFn,
		set = function(value)
			setFn(value);

			if mediaType == "sound" then
				PlaySoundFile(LSM:Fetch(mediaType, value), "Master");
			end

			SexyInterrupter:UpdateFrames();
		end,
	};
end

local function Color(label, hasAlpha, getFn, setFn)
	return {
		type = "color", name = label, hasAlpha = hasAlpha,
		get = getFn,
		set = function(r, g, b, a) setFn(r, g, b, a); SexyInterrupter:UpdateFrames(); end,
	};
end

-- Für marks.lua
SexyInterrupter.EditModeHelpers = {
	Header = Header,
	Link = Link,
	Check = Check,
	Slider = Slider,
	Select = Select,
	GetLiveDB = GetLiveDB,
	ComputeBottomLeft = ComputeBottomLeft,
	ApplyBackdrop = ApplyBackdrop,
};

-- Einstellungen des Fensters "Interrupts"
function SexyInterrupter:AnchorSettings()
	local profile = self.db.profile;

	return {
		Link(L["Interrupt now"], function() return SexyInterrupterInterruptNowText; end),
		Link(L["Enemy marks"], function() return SexyInterrupter.markFrame; end),
		Header(L["Behavior"], "behavior"),
		Check(L["Show in combat only"],
			function() return profile.general.modeincombat end,
			function(value) profile.general.modeincombat = value; end),
		Check(L["Active when solo"],
			function() return profile.general.activeSolo end,
			function(value) profile.general.activeSolo = value; end),
		Check(L["Ignore healers"],
			function() return profile.general.ignoreHealer end,
			function(value) profile.general.ignoreHealer = value; end),
		Check(L["Fixed rotation order"],
			function() return profile.general.fixedRotation end,
			function(value) profile.general.fixedRotation = value; end),
		Check(L["Highlight own row"],
			function() return profile.general.highlightOwn end,
			function(value) profile.general.highlightOwn = value; end),
		Check(L["Show minimap icon"] or "Show minimap icon",
			function() return profile.general.minimapIcon end,
			function(value)
				profile.general.minimapIcon = value;

				-- self.icon wird erst in OnInitialize nach CreateUi() gesetzt
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
			end),
		Slider(L["Max rows of interrupters"], 3, 30, 1,
			function() return profile.general.maxrows end,
			function(value) profile.general.maxrows = value; end),

		Header(L["Look"], "look", true),
		-- Wachstumsrichtung: siehe Kommentar bei SexyInterrupterAnchor:SetSize() in UpdateUI() -
		-- der Anker sitzt mit der unteren Kante fest; "Nach unten" hält rechnerisch die obere Kante.
		Select(L["Grow direction"] or "Grow direction",
			{
				{ value = false, label = L["Downward"] or "Downward" },
				{ value = true,  label = L["Upward"] or "Upward" },
			},
			function() return profile.ui.window.growUp end,
			function(value) profile.ui.window.growUp = value; end),
		Slider(L["Width"], 100, 400, 1,
			function() return profile.ui.window.width end,
			function(value) profile.ui.window.width = value; end),
		Slider(L["Bar height"], 4, 60, 1,
			function() return profile.ui.bars.barheight end,
			function(value) profile.ui.bars.barheight = value; end),
		Check(L["Show class icon"],
			function() return profile.ui.bars.showclassicon end,
			function(value) profile.ui.bars.showclassicon = value; end),
		Check(L["Bar color by class"],
			function() return profile.ui.bars.useclasscolor end,
			function(value) profile.ui.bars.useclasscolor = value; end),
		Check(L["Text color by class"],
			function() return profile.ui.useclasscolor end,
			function(value) profile.ui.useclasscolor = value; end),
		MediaSelect(L["Statusbar"], "statusbar",
			function() return profile.ui.bars.texture end,
			function(value) profile.ui.bars.texture = value; end),
		Color(L["Bar color"], true,
			function()
				local c = profile.ui.bars.barcolor;
				return c.r, c.g, c.b, c.a;
			end,
			function(r, g, b, a)
				local c = profile.ui.bars.barcolor;
				c.r, c.g, c.b, c.a = r, g, b, a;
			end),

		Header(L["Text"], "text", true),
		MediaSelect(L["Font art"], "font",
			function() return profile.ui.font end,
			function(value) profile.ui.font = value; end),
		Slider(L["Font size"], 4, 30, 1,
			function() return profile.ui.fontsize end,
			function(value) profile.ui.fontsize = value; end),
		Color(L["Font color"], false,
			function()
				local c = profile.ui.fontcolor;
				return c.r, c.g, c.b, 1;
			end,
			function(r, g, b)
				local c = profile.ui.fontcolor;
				c.r, c.g, c.b = r, g, b;
			end),
	};
end

-- Zeilen der Zauberliste: je Instanz ein einklappbarer Abschnitt mit einem Haken je Zauber
function SexyInterrupter:KicklistSpecs()
	local profile = self.db.profile;
	local instances = {};

	for id, entry in pairs(profile.kicklist) do
		instances[#instances + 1] = { id = id, name = entry.name or tostring(id), entry = entry };
	end

	table.sort(instances, function(a, b) return a.name < b.name; end);

	local list = {};

	for _, inst in ipairs(instances) do
		local spells, count = {}, 0;

		for spell in pairs(inst.entry.spells) do
			spells[#spells + 1] = spell;
			count = count + 1;
		end

		table.sort(spells);

		local header = Header(inst.name .. " (" .. count .. ")", "kl" .. inst.id, true);
		header.key = "klh" .. inst.id;
		list[#list + 1] = header;

		for _, spell in ipairs(spells) do
			local row = {
				type = "check", name = spell, key = "kls" .. inst.id .. ":" .. spell,
				get = function() return inst.entry.spells[spell] ~= false; end,
				set = function(value) inst.entry.spells[spell] = value and true or false; end,
			};
			list[#list + 1] = row;
		end

		list[#list + 1] = { type = "button", name = L["Clear the list of this instance"], key = "klc" .. inst.id,
			onClick = function()
				wipe(inst.entry.spells);
				SEM:RebuildDialog();
			end };
	end

	return list;
end

-- Einstellungen der Karte "Unterbrich jetzt"
function SexyInterrupter:MessageSettings()
	local profile = self.db.profile;
	local outputChannelOptions = {};

	for _, channel in ipairs({ 'SAY', 'YELL', 'PARTY', 'RAID' }) do
		tinsert(outputChannelOptions, { value = channel, label = SexyInterrupter.outputchannels[channel] });
	end

	local list = {
		Link(L["Interrupts"], function() return SexyInterrupterAnchor; end),
		Header(L["Notification"], "notification"),
		Check(L["Show message"],
			function() return profile.notification.message end,
			function(value) profile.notification.message = value; end),
		Check(L["Play sound"],
			function() return profile.notification.sound end,
			function(value) profile.notification.sound = value; end),
		-- soundFile kann einen LibSharedMedia-NAMEN (Auswahl) oder einen Dateipfad (Standard) enthalten
		MediaSelect(L["Sound file"], "sound",
			function()
				local current = profile.notification.soundFile;

				for name, path in pairs(LSM:HashTable("sound")) do
					if name == current or path == current then
						return name;
					end
				end

				return current;
			end,
			function(value) profile.notification.soundFile = value; end),
		Color(L["Flash color"], false,
			function()
				local c = profile.notification.flashcolor;
				return c.r, c.g, c.b, 1;
			end,
			function(r, g, b)
				local c = profile.notification.flashcolor;
				c.r, c.g, c.b = r, g, b;
				SexyInterrupter:ApplyFlashColor();
			end),
		{ type = "button", name = L["Test flash"], onClick = function()
			local flasher = SexyInterrupterBlueWarningFrame;

			if flasher then
				flasher:Show();
				C_Timer.After(1.5, function() flasher:Hide(); end);
			end
		end },
		Check(L["Flash display"],
			function() return profile.notification.flash end,
			function(value)
				profile.notification.flash = value;

				-- Läuft gerade ein Flash, beim Abschalten sofort beenden.
				if not value and SexyInterrupterBlueWarningFrame then
					SexyInterrupterBlueWarningFrame:Hide();
				end
			end),
		Check(L["Show chat message"],
			function() return profile.notification.interruptmessage end,
			function(value) profile.notification.interruptmessage = value; end),
		Select(L["Ouput channel"], outputChannelOptions,
			function() return profile.notification.outputchannel end,
			function(value) profile.notification.outputchannel = value; end),
	};

	-- Sprachausgabe: nur, wenn der Client Text-zu-Sprache kennt
	if C_VoiceChat and C_VoiceChat.SpeakText then
		local function VoiceOptions()
			local list = {};

			if C_VoiceChat.GetTtsVoices then
				for _, voice in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
					list[#list + 1] = { value = voice.voiceID, label = voice.name };
				end
			end

			return list;
		end

		local function CurrentVoice()
			local id = profile.notification.ttsVoice;

			if not id and C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum.TtsVoiceType then
				id = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard);
			end

			return id;
		end

		local speech = {
			Header(L["Speech"], "speech", true),
			Check(L["Speak when it is your turn"],
				function() return profile.notification.tts end,
				function(value) profile.notification.tts = value; end),
			Select(L["Spoken text"],
				{
					{ value = 'phrase', label = L["Phrase"] },
					{ value = 'spell', label = L["Spell name"] },
					{ value = 'both', label = L["Phrase and spell name"] },
				},
				function() return profile.notification.ttsText end,
				function(value) profile.notification.ttsText = value; end),
			Select(L["Voice"], VoiceOptions, CurrentVoice,
				function(value) profile.notification.ttsVoice = value; end),
			Slider(L["Speech speed"], -10, 10, 1,
				function() return profile.notification.ttsRate end,
				function(value) profile.notification.ttsRate = value; end),
			Slider(L["Speech volume"], 0, 100, 5,
				function() return profile.notification.ttsVolume end,
				function(value) profile.notification.ttsVolume = value; end),
			{ type = "button", name = L["Test speech"], onClick = function()
				SexyInterrupter:Speak(L["Preview Spell"], true);
			end },
		};

		for _, spec in ipairs(speech) do
			list[#list + 1] = spec;
		end
	end

	-- Zauberliste je Instanz: jeder Zauber, den dein Ziel in einer Instanz wirkt, steht angehakt in der Liste.
	-- Nimmst du den Haken weg, wird er dort nicht mehr gemeldet (wenn die Option an ist).
	list[#list + 1] = Header(L["Spell list per instance"], "kicklist", true);
	list[#list + 1] = Check(L["Respect the spell list in instances"],
		function() return profile.notification.kickListOnly end,
		function(value) profile.notification.kickListOnly = value; end);
	list[#list + 1] = { type = "edit", name = L["Add your own spell (current instance)"],
		onSubmit = function(text) SexyInterrupter:AddKickSpell(text); end };
	list[#list + 1] = { type = "dynamic", build = function() return SexyInterrupter:KicklistSpecs(); end };

	return list;
end

function SexyInterrupter:UpdateFrames()
	local editing = SexyInterrupter:IsEditingUi();

	-- No SetPoint/ClearAllPoints here anymore: EditModeExpanded-1.0 (see
	-- CreateUi) owns positioning these two frames from here on, driven by
	-- Blizzard's real Edit Mode drag UI instead of our own anchor options.
	ApplyBackdrop(SexyInterrupterAnchor);

	for _, child in ipairs({ SexyInterrupterAnchor:GetChildren() }) do
		if child:GetName() and string.find(child:GetName(), "SexyInterrupterRow") then
			for _, subchild in ipairs({ child:GetChildren() }) do
				if subchild:GetName() and string.find(subchild:GetName(), "SexyInterrupterStatusBar") then
					subchild:SetSize(self.db.profile.ui.window.width - 12, self.db.profile.ui.bars.barheight)
					subchild:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
					subchild:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a);

					if not self.db.profile.ui.bars.showclassicon then
						subchild.classicon:Hide();
					else
						subchild.classicon:Show();
					end

					StyleText(subchild.text, LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize);
					StyleText(subchild.cooldownText, LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize)
					local iconSize = math.max(12, math.min(20, self.db.profile.ui.bars.barheight - 8));
					subchild.classicon:SetSize(iconSize, iconSize);
					subchild.abilityicon:SetSize(iconSize, iconSize);
					subchild.offlineicon:SetSize(iconSize, iconSize);
					subchild.cooldownText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)
				end
			end
		end
	end

	do
		-- Im Edit Mode zeigt die Karte "Unterbrich jetzt!" Beispieldaten, danach
		-- verschwindet sie wieder (eine echte Meldung läuft über ShowAlert).
		local card = SexyInterrupterInterruptNowText;

		if editing then
			card:ShowPreview();
		elseif card.previewing then
			card:HideAlert();
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
			f.rowIndex = cx;

			f:SetSize(20, self.db.profile.ui.bars.barheight);

			if (cx == 1) then
				-- unter dem Titelband (HEAD) und dem 2-px-Rand
				f:SetPoint("TOPLEFT", SexyInterrupterAnchor, "TOPLEFT", 6, -(HEAD + 2))
			else
				f:SetPoint("TOP", _G["SexyInterrupterRow" .. (cx - 1)], "BOTTOM")
			end

			local t = f:CreateTexture()
			t:SetAllPoints(f)
			t:SetColorTexture(CARD[1], CARD[2], CARD[3], CARD[4])

			f = CreateFrame("StatusBar", "SexyInterrupterStatusBar" .. cx, _G["SexyInterrupterRow" .. cx])
			f:SetSize(self.db.profile.ui.window.width - 12, self.db.profile.ui.bars.barheight)
			f:SetPoint("LEFT", "SexyInterrupterRow" .. cx, "LEFT")
			f:SetOrientation("HORIZONTAL")
			f:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.ui.bars.texture));
			f:SetStatusBarColor(self.db.profile.ui.bars.barcolor.r, self.db.profile.ui.bars.barcolor.g, self.db.profile.ui.bars.barcolor.b, self.db.profile.ui.bars.barcolor.a)
			f:SetFrameLevel(3)
			f:SetMinMaxValues(0, 100)
			f:SetValue(100)

			-- Karte unter der Leiste, damit der Rest hinter dem Cooldown-Füllstand
			-- nicht durchscheint, plus Trennlinie
			f.cardBg = f:CreateTexture(nil, "BACKGROUND")
			f.cardBg:SetAllPoints(f)
			f.cardBg:SetColorTexture(CARD[1], CARD[2], CARD[3], CARD[4])
			-- 1-px-Rahmen um die Leiste (Farbe: Randfarbe des Fensters, gedimmt), siehe
			-- UpdateInterrupterStatus()
			f.edges = {};
			for _, spec in ipairs({
				{ "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
				{ "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
			}) do
				local e = f:CreateTexture(nil, "OVERLAY", nil, -2);
				e:SetPoint(spec[1], f, spec[1], 0, 0);
				e:SetPoint(spec[2], f, spec[2], 0, 0);

				if spec[3] then
					e:SetWidth(spec[3]);
				else
					e:SetHeight(spec[4]);
				end

				f.edges[#f.edges + 1] = e;
			end

			-- Role icon (Tank/Healer/Damage Dealer) on the left; the specific
			-- interrupt ability's own icon (once known) on the right, as its
			-- own separate texture - these are two different pieces of
			-- information, not one icon that swaps meaning.
			-- Hervorhebung der eigenen Zeile (goldene Tönung),
			-- siehe UpdateInterrupterStatus().
			f.highlightBG = f:CreateTexture(nil, "ARTWORK");
			f.highlightBG:SetAllPoints(f);
			f.highlightBG:SetColorTexture(1, 0.82, 0, 0.25);
			f.highlightBG:Hide();

			local iconSize = math.max(12, math.min(20, self.db.profile.ui.bars.barheight - 8));
			f.classicon = f:CreateTexture(nil, "OVERLAY");
			f.classicon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
			f.classicon:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", 8, 0);
			f.classicon:SetTexCoord(unpack(self.role_icon_tcoords.DAMAGER));
			f.classicon:SetSize(iconSize, iconSize);

			f.abilityicon = f:CreateTexture(nil, "OVERLAY");
			f.abilityicon:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. cx, "RIGHT", -6, 0);
			f.abilityicon:SetSize(iconSize, iconSize);
			f.abilityicon:Hide();

			-- Rahmen um das Fähigkeiten-Icon (Randfarbe des Fensters), folgt dem Icon beim
			-- Ein- und Ausblenden (siehe UpdateInterrupterStatus)
			f.abilityborder = f:CreateTexture(nil, "OVERLAY", nil, -1);
			f.abilityborder:SetPoint("TOPLEFT", f.abilityicon, "TOPLEFT", -2, 2);
			f.abilityborder:SetPoint("BOTTOMRIGHT", f.abilityicon, "BOTTOMRIGHT", 2, -2);
			f.abilityborder:SetColorTexture(0.42, 0.34, 0.15, 1);
			f.abilityborder:Hide();

			-- Offline-Symbol an der Stelle des Fähigkeiten-Icons.
			f.offlineicon = f:CreateTexture(nil, "OVERLAY");
			f.offlineicon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon");
			f.offlineicon:SetPoint("RIGHT", "SexyInterrupterStatusBar" .. cx, "RIGHT", -6, 0);
			f.offlineicon:SetSize(iconSize, iconSize);
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
			f.text:SetPoint("LEFT", "SexyInterrupterStatusBar" .. cx, "LEFT", self.db.profile.ui.bars.showclassicon and 31 or 8, 0)
			f.text:SetHeight(20)
			f.text:SetJustifyH("LEFT")
			StyleText(f.text, LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize)
			f.text:SetText('Dummy')

			f.cooldownText = f:CreateFontString("SexyInterrupterStatusBarCooldownText" .. cx, nil, "GameFontNormal")
			f.cooldownText:SetSize(12*3, 12)
			f.cooldownText:SetJustifyH("RIGHT")
			f.cooldownText:SetPoint("RIGHT", f.abilityicon, "LEFT", -3, 0)
			StyleText(f.cooldownText, LSM:Fetch("font", self.db.profile.ui.font), self.db.profile.ui.fontsize)
			f.cooldownText:SetTextColor(self.db.profile.ui.fontcolor.r, self.db.profile.ui.fontcolor.g, self.db.profile.ui.fontcolor.b, self.db.profile.ui.fontcolor.a)

			-- Status-Etikett (nächster / bereit / tot / offline) an der Stelle der
			-- Cooldown-Zahl, siehe UpdateInterrupterStatus().
			f.pill = MakePill(f)
			f.pill.bg:SetPoint("RIGHT", f.abilityicon, "LEFT", -3, 0)
			f.pill:Hide()
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
		-- Höhe, auf die sich die gespeicherte Position (db.y = untere Kante) bezieht. Sie wird
		-- NUR weitergeschaltet, wenn die Kompensation unten wirklich gelaufen ist. Früher wurde
		-- stattdessen die aktuelle Fensterhöhe als "alt" genommen: lief die Kompensation nicht
		-- (Drag, Kampf), blieb die Höhe geändert und die Position sprang dauerhaft. Sie wird
		-- im Profil gespeichert, damit auch nach /reload die richtige Basis gilt.
		local window = self.db.profile.ui.window;
		local oldHeight = window.anchoredHeight;
		-- Titelband plus Rand oben (HEAD + 2), 6 px unten
		local newHeight = (self.db.profile.ui.bars.barheight * maxRows) + HEAD + 2 + 6;
		-- Ohne gespeicherte Basis (erster Start mit dieser Version) nichts verschieben
		oldHeight = oldHeight or newHeight;
		-- Im Kampf nicht anfassen: an den Zeilen hängen Secure-Buttons (Klick auf
		-- Spieler), Größe/Anker dieser Frames sind im Kampf gesperrt (ADDON_ACTION_BLOCKED).
		-- Die Anpassung wird beim nächsten UpdateUI() nach dem Kampf nachgeholt.
		if not InCombatLockdown() then
			SexyInterrupterAnchor:SetSize(self.db.profile.ui.window.width, newHeight);
		end

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
		if not SEM:IsMoving(SexyInterrupterAnchor) and not InCombatLockdown() then
			if window.growUp then
				-- Untere Kante bleibt fix: keine Kompensation, nur die Basis mitführen
				window.anchoredHeight = newHeight;
			else
				local anchorDB = self.db.profile.ui.editModeAnchorDB;

				if anchorDB.x and anchorDB.y and oldHeight and oldHeight > 0 then
						SEM:SetPosition(SexyInterrupterAnchor, anchorDB.x, anchorDB.y - (newHeight - oldHeight));
				end

				window.anchoredHeight = newHeight;
			end
		end

		if editing or not self.db.profile.general.modeincombat then
			SexyInterrupterAnchor:Show();
		end
	else
		SexyInterrupterAnchor:Hide();
	end
end

-- Unit-Token (player/partyN/raidN) zu einem Spieler-Eintrag ermitteln.
local function FindUnitToken(interrupter)
	if not interrupter or not interrupter.name then
		return nil;
	end

	if UnitName("player") == interrupter.name then
		return "player";
	end

	local prefix = IsInRaid() and "raid" or "party";

	for i = 1, GetNumGroupMembers() do
		local unit = prefix .. i;

		if UnitExists(unit) and UnitName(unit) == interrupter.name then
			return unit;
		end
	end

	return nil;
end

-- Klick auf eine Zeile = diesen Spieler anvisieren. Secure-Button, daher nur
-- außerhalb des Kampfes erzeugbar bzw. umkonfigurierbar; fehlende Buttons und
-- Ziele werden beim nächsten Update nachgeholt.
function SexyInterrupter:UpdateRowClick(rowParent, interrupter)
	if InCombatLockdown() then
		return;
	end

	if not rowParent.click then
		local click = CreateFrame("Button", nil, rowParent, "SecureActionButtonTemplate");

		-- rowParent selbst ist nur 20px breit - die sichtbare Zeile ist die Leiste.
		click:SetAllPoints(_G["SexyInterrupterStatusBar" .. rowParent.rowIndex] or rowParent);
		click:SetHighlightTexture("Interface/Buttons/WHITE8X8");
		click:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12);
		-- Unter dem Fähigkeiten-Icon-Hitbox (Tooltip), aber über der Leiste.
		click:SetFrameLevel(3);
		click:RegisterForClicks("AnyDown", "AnyUp");
		click:SetAttribute("type", "target");
		click:SetAttribute("type1", "target");
		click:SetScript("OnEnter", function(self)
			local unit = rowParent.clickUnit;

			if unit and UnitExists(unit) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetUnit(unit);
				GameTooltip:Show();
			end
		end);
		click:SetScript("OnLeave", function() GameTooltip:Hide(); end);
		rowParent.click = click;
	end

	local unit = interrupter and FindUnitToken(interrupter) or nil;

	if rowParent.clickUnit ~= unit then
		rowParent.click:SetAttribute("unit", unit);
		rowParent.clickUnit = unit;
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
	local readyCount = 0;

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

		if rowParent then
			self:UpdateRowClick(rowParent, not editing and interrupter or nil);
		end

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
			-- Ohne Rollen-Symbol (z. B. solo, Rolle "NONE") beginnt der Name ganz links, ohne Platzhalter
			row.text:SetPoint("LEFT", row, "LEFT", row.classicon:IsShown() and 31 or 8, 0);
			-- Der Name endet vor Etikett bzw. Cooldown-Zahl und Zaubericon (statt fester Breite).
			row.text:SetPoint("RIGHT", row.abilityicon, "LEFT", -64, 0);

			if not self.db.profile.ui.bars.showclassicon or not dataRow.spellId then
				row.abilityicon:Hide(); row.abilityborder:Hide();
				row.abilityiconHitbox:Hide();
			else
				-- One row per known ability: show that ability's own icon
				-- alongside (not instead of) the role icon.
				local texture = GetSpellTextureCompat(dataRow.spellId);

				if texture then
					row.abilityicon:SetTexture(texture);
					row.abilityicon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
					row.abilityicon:Show(); row.abilityborder:Show();
					row.abilityiconHitbox.spellId = dataRow.spellId;
					row.abilityiconHitbox:Show();
				else
					row.abilityicon:Hide(); row.abilityborder:Hide();
					row.abilityiconHitbox:Hide();
				end
			end

			if dataRow.cooldown > 0 then
				row:SetMinMaxValues(0, dataRow.cooldown);
				row.cooldownText:Show();

				if dataRow.readyTime - GetTime() > 0 then
					local readyTime = dataRow.readyTime - GetTime();

					-- Läuft der Cooldown, färbt sich die Leiste bernsteinfarben (außer bei
					-- Klassenfarben oder offline); bereit zeigt wieder die Leistenfarbe.
					if not (self.db.profile.ui.bars.useclasscolor and interrupter.classColor) and not interrupter.offline then
						row:SetStatusBarColor(COOLING[1], COOLING[2], COOLING[3], 1);
					end

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

			-- Rahmen um Leiste und Fähigkeiten-Icon in der Randfarbe des Fensters
			for _, edge in ipairs(row.edges) do
				edge:SetColorTexture(WINDOW_EDGE[1] * 0.65, WINDOW_EDGE[2] * 0.65, WINDOW_EDGE[3] * 0.65, 1);
			end
			row.abilityborder:SetColorTexture(WINDOW_EDGE[1], WINDOW_EDGE[2], WINDOW_EDGE[3], 1);

			-- Status-Etikett: offline oder tot; läuft der Cooldown, steht stattdessen die Zahl.
			local pillSize = math.max(8, self.db.profile.ui.fontsize - 2);
			local cooling = dataRow.cooldown > 0 and dataRow.readyTime - GetTime() > 0;

			if interrupter.offline then
				row.pill:Set("grey", L["offline"], pillSize);
			elseif interrupter.dead then
				row.pill:Set("lack", L["dead"], pillSize);
			elseif cooling then
				row.pill:Hide();
			else
				-- bereit: kein Etikett, die volle Leiste zeigt es schon
				row.pill:Hide();

				if cx <= self.db.profile.general.maxrows then
					readyCount = readyCount + 1;
				end
			end

			local isOwn = self.db.profile.general.highlightOwn
				and ((editing and cx == 1) or (not editing and interrupter.name == UnitName("player")));

			if isOwn then
				row.highlightBG:Show();
			else
				row.highlightBG:Hide();
			end

			if interrupter.offline then
				row:SetMinMaxValues(0, 100);
				row:SetValue(100);
				row.abilityicon:Hide(); row.abilityborder:Hide();
				row.abilityiconHitbox:Hide();
				row.cooldownText:Hide();
				row.offlineicon:Show();
				rowParent:SetAlpha(0.6);
			else
				row.offlineicon:Hide();
			end
		end
	end

	-- Badge im Titelband: Anzahl der bereiten Unterbrechungen
	SexyInterrupterAnchor:SetBadge(readyCount > 0 and string.format(L["%d ready"], readyCount) or "");
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

	-- Rahmen um die Zeile des aktuell anvisierten Spielers.
	local rowIndex = 1;

	while _G["SexyInterrupterRow" .. rowIndex] do
		local rowParent = _G["SexyInterrupterRow" .. rowIndex];

		if not rowParent.targetBorder and SexyInterrupter.CreateTargetBorder then
			rowParent.targetBorder = SexyInterrupter:CreateTargetBorder(_G["SexyInterrupterStatusBar" .. rowIndex] or rowParent);
		end

		if rowParent.targetBorder then
			local isTarget = false;

			if rowParent:IsShown() and rowParent.clickUnit and UnitExists("target") then
				local same = UnitIsUnit(rowParent.clickUnit, "target");

				isTarget = not (issecretvalue and issecretvalue(same)) and same and true or false;
			end

			rowParent.targetBorder:SetShown(isTarget);
		end

		rowIndex = rowIndex + 1;
	end

	local editing = SexyInterrupter:IsEditingUi();
	local rows = editing and GetPreviewRows() or SexyInterrupter:GetCurrentInterrupters();
	local currentplayer = not editing and SexyInterrupter:GetInterrupter(select(1, UnitName("player"))) or nil;
	local now = GetTime();
	local transitioned = false;   -- ein Cooldown ist abgelaufen: Farbe und Etikett neu setzen

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
				transitioned = true;
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
					transitioned = true;

					bar:SetMinMaxValues(0, 100);
					bar:SetValue(100);
				else
					bar:SetValue(remaining);
					bar.cooldownText:SetText(string.format('%.1f', remaining));
				end
			end
		end
	end

	if transitioned then
		SexyInterrupter:UpdateInterrupterStatus(rows, editing);
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
