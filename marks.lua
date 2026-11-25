-- Gegner-Marker: eigenes Fenster mit den Unitframes aller Gegner, die ein
-- Raid-Symbol tragen (Totenkopf, Kreuz, ...). Zeigt Gesundheit, den laufenden
-- Cast und hebt unterbrechbare Casts hervor. Position/Optionen liegen wie bei
-- den anderen Fenstern im Edit Mode (SexyEditMode-1.0).
local SEM = LibStub("SexyEditMode-1.0");
local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

local ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons";
local function Head(profile)
	return profile.hideHeader and 6 or 30;   -- Kopfzeile ausgeblendet: nur der Rand
end
local HEADER_HEIGHT = 30;  -- Rahmen oben plus Titelband (wie im Interrupter-Fenster)
local PADDING = 6;
local TICK = 0.15;

local SYMBOL_NAMES = {
	L["Star"], L["Circle"], L["Diamond"], L["Triangle"],
	L["Moon"], L["Square"], L["Cross"], L["Skull"],
};

-- Beispieldaten für die Vorschau im Edit Mode.
local PREVIEW = {
	{ index = 8, name = "High Marshal Valdric", pct = 100 },
	{ index = 7, name = "Shadow Priest", pct = 78, cast = { name = "Shadow Bolt", progress = 0.62, interruptible = true } },
	{ index = 6, name = "Blade Dancer", pct = 54 },
	{ index = 4, name = "Thorn Weaver", pct = 100, cast = { name = "Healing Wave", progress = 0.35, interruptible = false } },
	{ index = 5, name = "Cult Summoner", pct = 31 },
};

SexyInterrupter.MarksPreview = PREVIEW;   -- auch für die Vorschau im Einstellungsfenster (samples.lua)

-- "Secret values" (Blizzards Schutz im Kampf) werfen bei Boolean-Tests Fehler.
local function IsSecret(value)
	return issecretvalue and issecretvalue(value);
end

local function SafeBool(value, default)
	if IsSecret(value) then
		return default;
	end

	return value and true or false;
end

-- Fallback für geheime Indizes: Textur und Koordinaten vom Symbol der
-- Blizzard-Namensplakette derselben Einheit übernehmen.
local function CopyNameplateIcon(texture, unit)
	local plate;

	if unit and C_NamePlate then
		-- Für party/raid-Tokens verweigert die API den Aufruf: dann die passende
		-- nameplateN über UnitIsUnit suchen.
		local ok, result = pcall(C_NamePlate.GetNamePlateForUnit, unit);

		if ok then
			plate = result;
		else
			for i = 1, 40 do
				local token = "nameplate" .. i;

				if UnitExists(token) and SafeBool(UnitIsUnit(unit, token), false) then
					plate = C_NamePlate.GetNamePlateForUnit(token);
					break;
				end
			end
		end
	end

	local unitFrame = plate and plate.UnitFrame;
	local source = unitFrame and unitFrame.RaidTargetFrame and unitFrame.RaidTargetFrame.RaidTargetIcon;

	if not source then
		return false;
	end

	return pcall(function()
		texture:SetTexture(source:GetTexture());
		texture:SetTexCoord(source:GetTexCoord());
	end);
end

local function SetIcon(texture, index, unit)
	if IsSecret(index) then
		-- Auf dieser Client-Version liefert GetRaidTargetIndex für Gegner einen
		-- "secret value": nicht rechnen, nur an Blizzards eigene Funktion geben.
		if SetRaidTargetIconTexture then
			local ok, err = pcall(SetRaidTargetIconTexture, texture, index);

			SexyInterrupter.lastIconError = ok and "ok (kein Fehler)" or tostring(err);

			if ok and texture:GetTexture() ~= nil then
				return;
			end
		else
			SexyInterrupter.lastIconError = "SetRaidTargetIconTexture fehlt";
		end

		if not CopyNameplateIcon(texture, unit) then
			texture:SetTexture(nil);
		end

		return;
	end

	local col = (index - 1) % 4;
	local row = math.floor((index - 1) / 4);

	texture:SetTexture(ICON_TEXTURE);
	texture:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25);
end

-- Rahmen (4 Kanten) um einen Frame, z. B. für das aktuelle Ziel. Wird auch vom
-- Interrupter-Fenster (ui.lua) benutzt.
function SexyInterrupter:CreateTargetBorder(frame)
	local border = {};
	local thickness = 2;

	local function Edge(point1, point2, width, height)
		local t = frame:CreateTexture(nil, "OVERLAY", nil, 7);

		t:SetColorTexture(1, 1, 1, 0.95);
		t:SetPoint(point1, frame, point1, 0, 0);
		t:SetPoint(point2, frame, point2, 0, 0);

		if width then t:SetWidth(width); end
		if height then t:SetHeight(height); end

		t:Hide();

		return t;
	end

	border.edges = {
		Edge("TOPLEFT", "TOPRIGHT", nil, thickness),
		Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, thickness),
		Edge("TOPLEFT", "BOTTOMLEFT", thickness, nil),
		Edge("TOPRIGHT", "BOTTOMRIGHT", thickness, nil),
	};

	function border:SetShown(shown)
		for _, edge in ipairs(self.edges) do
			if shown then edge:Show(); else edge:Hide(); end
		end
	end

	return border;
end

local function P()
	return SexyInterrupter.db.profile.marks;
end

-- Abstand zwischen den Zeilen (Einstellung, Standard 0)
local function Gap(profile)
	return profile.rowGap or 0;
end

-- Farben der Zauberleiste: unterbrechbar / nicht unterbrechbar (Einstellungen)
local function CastColor(profile, interruptible)
	local c = interruptible and (profile.castColor or { r = 0.91, g = 0.72, b = 0.23 }) or (profile.castColorLocked or { r = 0.54, g = 0.54, b = 0.54 });

	return c.r, c.g, c.b, 1;
end

local CAST_HEIGHT = 14;   -- Zauberleiste (mit Name und Zeit in der Leiste)

-- Höhe des Kopfteils der Karte (Symbol, Name, Prozent, Gesundheit, Luft): eigene Zeilenhöhe, Standard 40
local function HpHeight(profile)
	return profile.rowHeight or 40;
end

local function CastBarHeight(profile)
	return profile.castBarHeight or CAST_HEIGHT;
end

-- Höhe einer Karte mit Zauberleiste: Kopfteil plus die Zauberleiste und 6 px Luft darunter
local function RowHeight(profile)
	return HpHeight(profile) + (profile.showCast and (CastBarHeight(profile) + 6) or 0);
end

-- Platz einer Karte im Fenster: Abstand von oben und Höhe. Karten mit Zauber sind höher als solche ohne; die Plätze (und damit die
-- Klickflächen) werden nur außerhalb des Kampfes neu berechnet (UpdateMarkFrame), im Kampf bleiben sie wie zuletzt.
local function SlotBox(f, profile, position)
	if f.slotY and f.slotY[position] then
		return f.slotY[position], f.slotH[position];
	end

	local h = RowHeight(profile);

	return (position - 1) * (h + Gap(profile)), h;
end

-- Klick auf die Zeile = Gegner anvisieren. Secure-Buttons (TargetUnit ist im
-- Kampf geschützt) hängen NICHT an den Zeilen, sondern direkt am Hauptframe mit
-- festen Offsets: Zeilen werden im Kampf ständig angezeigt/versteckt/verschoben,
-- und mit einem Secure-Button als Kind bzw. Anker wäre das dort gesperrt.
-- Position/Größe der Buttons ändern sich nur außerhalb des Kampfes.
function SexyInterrupter:CreateMarkClickButton(index)
	local f = self.markFrame;
	local button = CreateFrame("Button", "SexyInterrupterMarkButton" .. index, f, "SecureActionButtonTemplate");

	button:SetFrameLevel(f:GetFrameLevel() + 20);
	button:SetHighlightTexture("Interface/Buttons/WHITE8X8");
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12);
	-- Je nach CVar ActionButtonUseKeyDown feuert ein Secure-Button beim Drücken
	-- oder Loslassen: beides anmelden.
	button:RegisterForClicks("AnyUp");
	button:SetAttribute("useOnKeyDown", false);
	button:SetAttribute("type", "target");
	button:SetAttribute("type1", "target");

	button:SetScript("OnEnter", function(self)
		local unit = self.clickUnit;

		if unit and UnitExists(unit) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetUnit(unit);
			GameTooltip:Show();
		end
	end);
	button:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	-- Diagnose (/si debug): kommt der Klick an, und was würde er auslösen?
	button:HookScript("PreClick", function(self, mouseButton, down)
		if SexyInterrupter.debug then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("SI click: %s button=%s down=%s type1=%s unit=%s macro=%s",
				self:GetName(), tostring(mouseButton), tostring(down), tostring(self:GetAttribute("type1")),
				tostring(self:GetAttribute("unit")), tostring(self:GetAttribute("macrotext1"))), 0.6, 0.8, 1);
		end
	end);

	f.clickButtons[index] = button;

	return button;
end

-- Buttons über die Zeilen legen (nur außerhalb des Kampfes, nur bei Änderung).
function SexyInterrupter:LayoutMarkClickButtons(editing)
	if InCombatLockdown() then
		return;
	end

	local f = self.markFrame;
	local profile = self.db.profile.marks;
	local boxes = {};

	for index = 1, #f.clickButtons do
		local y, h = SlotBox(f, profile, index);

		boxes[index] = y .. "/" .. h;
	end

	local key = table.concat({ profile.width, tostring(editing), tostring(profile.hideHeader), table.concat(boxes, ",") }, "|");

	if f.clickLayoutKey == key then
		return;
	end

	f.clickLayoutKey = key;

	for index, button in ipairs(f.clickButtons) do
		local y, h = SlotBox(f, profile, index);

		button:ClearAllPoints();
		button:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -(Head(profile) + y));
		button:SetSize(profile.width - 2 * PADDING, h);
		-- Im Edit Mode dürfen die Buttons das Verschieben des Fensters nicht blockieren.
		button:EnableMouse(not editing and button.clickKey ~= nil);
	end
end

-- Karte je Gegner: Streifen in der Farbe des Symbols, oben Symbol, Name und Prozent, darunter die Gesundheit und, solange ein Gegner
-- zaubert, die Zauberleiste mit Zaubername links und Restzeit ganz hinten in der Leiste. Ohne Zauber gibt es keine Zauberleiste und
-- die Karte ist nur so hoch wie der Kopfteil und die Karten darunter rücken nach (außerhalb des Kampfes; im Kampf bleiben die Plätze, weil sich die Klickflächen dort nicht verschieben lassen).
-- Alles liegt auf dem textLayer über den Leisten (Kind-Frames liegen über den Regionen des Elternteils).
local EDGE_COLOR = { 0.227, 0.184, 0.11 };
local EDGE_HOT = { 0.78, 0.6, 0.17 };
local STRIPE_DEFAULT = { 0.91, 0.76, 0.42 };
local SYMBOL_COLORS = {
	{ 1, 0.92, 0.2 }, { 1, 0.55, 0.1 }, { 0.75, 0.3, 0.9 }, { 0.3, 0.8, 0.4 },
	{ 0.78, 0.83, 0.9 }, { 0.27, 0.63, 0.9 }, { 0.9, 0.28, 0.25 }, { 0.95, 0.95, 0.95 },
};
local PAD_Y, LINE_H, ICON_SIZE, GAP_HP, HP_BAR_H, GAP_CAST = 6, 16, 14, 4, 8, 6;

-- Streifen links in der Farbe des Symbols; ein geheimer Index (im Kampf) fällt auf Gold zurück
local function SetStripe(row, index)
	local c = (not IsSecret(index) and type(index) == "number" and SYMBOL_COLORS[index]) or STRIPE_DEFAULT;

	row.stripe:SetColorTexture(c[1], c[2], c[3], 1);
end

-- Rand der Karte: golden bei einem unterbrechbaren Zauber
local function SetCardEdge(row, hot)
	local c = hot and EDGE_HOT or EDGE_COLOR;

	for _, edge in ipairs(row.edges) do
		edge:SetColorTexture(c[1], c[2], c[3], 1);
	end
end

-- Text in der Zauberleiste: hell, auf Gold wie auf Grau und auf dem leeren Rest der Leiste lesbar
local function SetCastTextColor(row, interruptible)
	row.castName:SetTextColor(0.97, 0.94, 0.86, 1);
	row.castTime:SetTextColor(0.97, 0.94, 0.86, 1);
end

-- Zauberleiste und Text nur zeigen, solange gezaubert wird. Eine Karte mit Platz für die Zauberleiste ("full") zeigt sie unter der
-- Gesundheit; eine ohne ("overlay": der Zauber begann im Kampf, wo sich die Plätze nicht mehr ändern) lässt sie die Gesundheit ersetzen.
local function SetCastShown(row, show, profile)
	show = (show and profile.showCast) and true or false;

	local mode = show and (row.slotFull and "full" or "overlay") or "none";

	row.cast:SetShown(show);
	row.castName:SetShown(show and profile.showCastName ~= false);
	row.castTime:SetShown(show);

	if row.castMode ~= mode then
		row.castMode = mode;
		row.cast:ClearAllPoints();

		if mode == "overlay" then
			row.cast:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -(row.hpTop or 26));
			row.cast:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -(row.hpTop or 26));
			row.hp:Hide();
		else
			row.cast:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, PAD_Y);
			row.cast:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, PAD_Y);
			row.hp:Show();
		end

		row.body:SetHeight(mode == "full" and RowHeight(profile) or HpHeight(profile));
	end
end

function SexyInterrupter:CreateMarkRow(index)
	local f = self.markFrame;
	local row = CreateFrame("Frame", nil, f);

	-- Kartengrund, Glanz, Rand und Streifen auf einem Rahmen, dessen Höhe mit der Zauberleiste wechselt
	row.body = CreateFrame("Frame", nil, row);
	row.body:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0);
	row.body:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0);

	row.bg = row.body:CreateTexture(nil, "BACKGROUND");
	row.bg:SetAllPoints(row.body);
	row.bg:SetColorTexture(0.114, 0.094, 0.063, 1);

	-- Hervorhebung unterbrechbarer Zauber über dem Kartengrund
	row.glow = row.body:CreateTexture(nil, "BORDER");
	row.glow:SetAllPoints(row.body);
	row.glow:SetColorTexture(1, 0.83, 0.3, 0.12);
	row.glow:Hide();

	-- Rand: vier Kanten von 1 px
	row.edges = {};

	for i, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local t = row.body:CreateTexture(nil, "ARTWORK");

		t:SetPoint(e[1], row.body, e[1], 0, 0);
		t:SetPoint(e[2], row.body, e[2], 0, 0);

		if e[3] then t:SetHeight(1); else t:SetWidth(1); end

		row.edges[i] = t;
	end

	row.stripe = row.body:CreateTexture(nil, "ARTWORK", nil, 1);
	row.stripe:SetPoint("TOPLEFT", row.body, "TOPLEFT", 0, 0);
	row.stripe:SetPoint("BOTTOMLEFT", row.body, "BOTTOMLEFT", 0, 0);
	row.stripe:SetWidth(3);
	SetStripe(row, nil);
	SetCardEdge(row, false);

	-- Gesundheit unter der Kopfzeile der Karte
	row.hp = CreateFrame("StatusBar", nil, row);
	row.hp.bg = row.hp:CreateTexture(nil, "BACKGROUND");
	row.hp.bg:SetAllPoints(row.hp);
	row.hp.bg:SetColorTexture(0.055, 0.043, 0.03, 1);

	-- Zauberleiste ganz unten; Name und Zeit stehen in der Leiste
	row.cast = CreateFrame("StatusBar", nil, row);
	row.cast.bg = row.cast:CreateTexture(nil, "BACKGROUND");
	row.cast.bg:SetAllPoints(row.cast);
	row.cast.bg:SetColorTexture(0.055, 0.043, 0.03, 1);
	row.cast:Hide();

	row.textLayer = CreateFrame("Frame", nil, row);
	row.textLayer:SetAllPoints(row);
	row.targetBorder = self:CreateTargetBorder(row.body);

	row.icon = row.textLayer:CreateTexture(nil, "OVERLAY");

	row.name = row.textLayer:CreateFontString(nil, "OVERLAY");
	row.name:SetJustifyH("LEFT");
	row.name:SetWordWrap(false);

	row.pct = row.textLayer:CreateFontString(nil, "OVERLAY");
	row.pct:SetJustifyH("RIGHT");

	row.castName = row.textLayer:CreateFontString(nil, "OVERLAY");
	row.castName:SetJustifyH("LEFT");
	row.castName:SetWordWrap(false);
	row.castName:Hide();

	row.castTime = row.textLayer:CreateFontString(nil, "OVERLAY");
	row.castTime:SetJustifyH("RIGHT");
	row.castTime:Hide();

	f.rows[index] = row;

	return row;
end

-- Layout/Schrift/Textur eines Rows an die aktuellen Einstellungen anpassen.
function SexyInterrupter:LayoutMarkRow(row, position)
	local profile = self.db.profile.marks;
	local ui = self.db.profile.ui;
	local rowHeight = RowHeight(profile);
	local topHeight = HpHeight(profile);
	local castHeight = CastBarHeight(profile);
	local font = LSM:Fetch("font", ui.font);
	local fontSize = ui.fontsize;
	local texture = LSM:Fetch("statusbar", ui.bars.texture);
	local fontColor = ui.fontcolor;

	-- Nur neu anordnen, wenn sich etwas geändert hat: ein Umlayout alle 0,15 s
	-- (ClearAllPoints/SetPoint) lässt die Maus-Fokus-/Klick-Erkennung des
	-- Secure-Buttons auf der Zeile immer wieder abreißen (Klick kommt nie an).
	local slotY, slotHeight = SlotBox(self.markFrame, profile, position);
	local key = table.concat({ position, slotY, slotHeight, profile.width, rowHeight, topHeight, castHeight, tostring(font), fontSize, tostring(texture),
		fontColor.r, fontColor.g, fontColor.b, tostring(profile.hideHeader), Gap(profile), tostring(profile.showCast),
		tostring(profile.showIcon), tostring(profile.showPct), tostring(profile.showCastName),
		profile.hpColor.r, profile.hpColor.g, profile.hpColor.b, profile.glowColor.r, profile.glowColor.g, profile.glowColor.b, profile.glowAlpha }, "|");

	if row.layoutKey == key then
		return;
	end

	row.layoutKey = key;

	row:ClearAllPoints();
	row:SetPoint("TOPLEFT", self.markFrame, "TOPLEFT", PADDING, -(Head(profile) + slotY));
	row:SetSize(profile.width - 2 * PADDING, slotHeight);
	row.slotFull = slotHeight >= rowHeight - 0.5;
	row.castMode = nil;   -- Zauberleiste und Höhe des Kartengrunds neu setzen (SetCastShown)
	row.body:SetHeight(topHeight);

	row.glow:SetColorTexture(profile.glowColor.r, profile.glowColor.g, profile.glowColor.b, profile.glowAlpha or 0.12);

	-- Kopfzeile: Symbol, Name, Prozent in einer Zeile von 16 px; darunter die Gesundheit
	local iconTop = PAD_Y + (LINE_H - ICON_SIZE) / 2;
	local lineY = PAD_Y + LINE_H / 2;
	local hpTop = PAD_Y + LINE_H + GAP_HP;
	row.hpTop = hpTop;

	row.icon:ClearAllPoints();
	row.icon:SetPoint("TOPLEFT", row.textLayer, "TOPLEFT", 10, -iconTop);
	row.icon:SetSize(ICON_SIZE, ICON_SIZE);
	row.icon:SetShown(profile.showIcon ~= false);
	row.pct:SetShown(profile.showPct ~= false);

	local textFont = math.max(8, fontSize - 2);   -- Name und Prozent etwas kleiner als die Schrift der Interrupter-Liste

	self.Look.StyleText(row.pct, font, textFont);
	row.pct:SetTextColor(fontColor.r, fontColor.g, fontColor.b, 1);
	row.pct:SetWidth(40);
	row.pct:ClearAllPoints();
	row.pct:SetPoint("RIGHT", row.textLayer, "TOPRIGHT", -8, -lineY);

	self.Look.StyleText(row.name, font, textFont);
	row.name:SetTextColor(fontColor.r, fontColor.g, fontColor.b, 1);
	row.name:ClearAllPoints();
	row.name:SetPoint("LEFT", row.textLayer, "TOPLEFT", profile.showIcon ~= false and (10 + ICON_SIZE + 6) or 10, -lineY);
	row.name:SetPoint("RIGHT", row.pct, "LEFT", -4, 0);
	row.name:SetHeight(textFont + 2);

	row.hp:SetStatusBarTexture(texture);
	row.hp:SetStatusBarColor(profile.hpColor.r, profile.hpColor.g, profile.hpColor.b, 1);
	row.hp:ClearAllPoints();
	row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -hpTop);
	row.hp:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -hpTop);
	row.hp:SetHeight(HP_BAR_H);

	-- Zauberleiste unten, Name links und Zeit ganz hinten in der Leiste
	row.cast:SetStatusBarTexture(texture);
	row.cast:SetHeight(castHeight);
	row.cast:SetFrameLevel(row.hp:GetFrameLevel() + 1);
	row.textLayer:SetFrameLevel(row.hp:GetFrameLevel() + 4);

	local castFont = math.max(8, fontSize - 3);

	self.Look.StyleText(row.castTime, font, castFont);
	row.castTime:SetWidth(36);
	row.castTime:ClearAllPoints();
	row.castTime:SetPoint("RIGHT", row.cast, "RIGHT", -5, 0);
	self.Look.StyleText(row.castName, font, castFont);
	row.castName:ClearAllPoints();
	row.castName:SetPoint("LEFT", row.cast, "LEFT", 5, 0);
	row.castName:SetPoint("RIGHT", row.castTime, "LEFT", -4, 0);
	row.castName:SetHeight(castFont + 2);
end

-- Alle angreifbaren Gegner mit Symbol einsammeln: ein Symbol existiert nur
-- einmal, daher dient der Symbol-Index als Schlüssel.
-- Namensplaketten zuerst: deren Token bleiben pro Mob stabil (anders als "target"),
-- und bei Dubletten gewinnt der erste Treffer.
local SCAN_UNITS = {};

for i = 1, 40 do
	tinsert(SCAN_UNITS, "nameplate" .. i);
end

for _, unit in ipairs({ "target", "focus", "mouseover", "boss1", "boss2", "boss3", "boss4", "boss5",
	"targettarget", "focustarget", "mouseovertarget", "pettarget" }) do
	tinsert(SCAN_UNITS, unit);
end

for i = 1, 4 do
	tinsert(SCAN_UNITS, "party" .. i .. "target");
end

-- Ziele der Raid-Mitglieder: nur wenn es einen Raid gibt (siehe CollectMarkedUnits).
local RAID_TARGET_UNITS = {};

for i = 1, 40 do
	tinsert(RAID_TARGET_UNITS, "raid" .. i .. "target");
end

local function IsCasting(unit)
	local ok, casting = pcall(function()
		return UnitCastingInfo(unit) ~= nil or UnitChannelInfo(unit) ~= nil;
	end);

	return ok and casting;
end

local function PlateOf(unit)
	if not C_NamePlate then
		return nil;
	end

	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit);

	return ok and plate or nil;
end

-- Ist es dieselbe Einheit? Reihenfolge: UnitIsUnit, GUID, Namensplakette
-- (jeweils nur, wenn der Wert nicht "secret" ist).
local function IsSameUnit(a, b)
	local same = UnitIsUnit(a, b);

	if not IsSecret(same) then
		return same and true or false;
	end

	local guidA, guidB = UnitGUID(a), UnitGUID(b);

	if guidA and guidB and not IsSecret(guidA) and not IsSecret(guidB) then
		return guidA == guidB;
	end

	local plateA, plateB = PlateOf(a), PlateOf(b);

	return plateA ~= nil and plateA == plateB;
end

-- Tot? Mehrere unabhängige Prüfungen, weil einzelne Werte im Kampf geheim sein
-- können (SafeBool würde dann "lebt" annehmen und die Leiche stehen lassen).
local function IsDeadUnit(unit)
	for _, check in ipairs({ UnitIsDead, UnitIsDeadOrGhost }) do
		local dead = check(unit);

		if not IsSecret(dead) and dead then
			return true;
		end
	end

	local ok, zero = pcall(function()
		return UnitHealth(unit) <= 0;
	end);

	return ok and zero or false;
end

local function CollectMarkedUnits(symbols)
	local list = {};
	-- Ziele von Gruppenmitgliedern haben keine Namensplakette und lassen sich bei
	-- geheimen Werten nicht von Plaketten-Einträgen unterscheiden: nur Rückfall,
	-- wenn sonst nichts gefunden wurde.
	local fallbackList = {};
	local sawDead = false;

	local units = SCAN_UNITS;

	if IsInRaid() then
		units = {};

		for _, unit in ipairs(SCAN_UNITS) do
			tinsert(units, unit);
		end

		for _, unit in ipairs(RAID_TARGET_UNITS) do
			tinsert(units, unit);
		end
	end

	for position, unit in ipairs(units) do
		if UnitExists(unit) and SafeBool(UnitCanAttack("player", unit), true) then
			local dead = IsDeadUnit(unit);
			local index = GetRaidTargetIndex(unit);
			local marked = false;

			-- Boolean-Test kann bei einem "secret value" werfen -> dann nicht markiert.
			pcall(function()
				if index then
					marked = true;
				end
			end);

			-- Mit geheimem Index lässt sich weder in der Symbol-Auswahl nachsehen
			-- noch sortieren: dann wird das Symbol immer angezeigt.
			local allowed = true;

			if marked and not IsSecret(index) then
				allowed = symbols[index];
			end

			-- Toter markierter Mob: nicht anzeigen und der Überbrückung (siehe
			-- UpdateMarkFrame) sagen, dass sie nicht greifen darf.
			if marked and dead then
				sawDead = true;
			end

			if marked and allowed and not dead then
				-- Dieselbe Einheit kann über mehrere Tokens auftauchen (target + nameplate).
				local duplicate = false;
				local isFallback = unit:find("^party%d+target$") or unit:find("^raid%d+target$");
				local targetList = isFallback and fallbackList or list;

				for _, entry in ipairs(targetList) do
					if IsSameUnit(unit, entry.unit) then
						duplicate = true;
						break;
					end

					-- Rückfall-Tokens: ohne verwertbare UnitIsUnit/GUID hilft nur der Name.
					if isFallback then
						local nameA, nameB = UnitName(unit), UnitName(entry.unit);

						if nameA and nameB and not IsSecret(nameA) and not IsSecret(nameB) and nameA == nameB then
							duplicate = true;
							break;
						end
					end
				end

				if not duplicate then
					-- Rang: Totenkopf (8) zuerst; geheime Symbole danach in Suchreihenfolge.
					local rank = IsSecret(index) and (100 + position) or (9 - index);

					tinsert(targetList, { index = index, unit = unit, rank = rank });
				end
			end
		end
	end

	if #list == 0 then
		list = fallbackList;
	end

	table.sort(list, function(a, b) return a.rank < b.rank; end);

	return list, sawDead;
end

-- Liefert interruptible (true/false) oder nil, wenn gerade nichts gecastet wird.
local function UpdateCast(row, unit, profile)
	local name, _, _, startMs, endMs, _, castId, notInterruptible = UnitCastingInfo(unit);
	local channel = false;

	if name == nil then
		name, _, _, startMs, endMs, _, notInterruptible = UnitChannelInfo(unit);
		channel = true;
	end

	if name == nil then
		return nil;
	end

	local interruptible = not SafeBool(notInterruptible, false);

	row.castName:SetText(name);
	SetCastTextColor(row, interruptible);
	SetCastShown(row, true, profile);

	local ok = pcall(function()
		local startTime, endTime = startMs / 1000, endMs / 1000;

		row.cast:SetMinMaxValues(startTime, endTime);
		row.cast:SetValue(channel and (startTime + endTime - GetTime()) or GetTime());
		row.castTime:SetText(string.format("%.1f", math.max(0, endTime - GetTime())));
	end);

	if not ok then
		-- Zeiten im Kampf geschützt: nur Name + volle Leiste.
		row.cast:SetMinMaxValues(0, 1);
		row.cast:SetValue(1);
		row.castTime:SetText("");
	end

	row.cast:SetStatusBarColor(CastColor(profile, interruptible));

	return interruptible;
end

local function UpdateHealth(row, unit)
	local ok = pcall(function()
		row.hp:SetMinMaxValues(0, UnitHealthMax(unit));
		row.hp:SetValue(UnitHealth(unit));
	end);

	if not ok then
		row.hp:SetMinMaxValues(0, 1);
		row.hp:SetValue(1);
	end

	local shown = pcall(function()
		local max = UnitHealthMax(unit);

		if IsSecret(max) or max <= 0 then
			error("secret");
		end

		row.pct:SetText(string.format("%d%%", math.floor(UnitHealth(unit) / max * 100 + 0.5)));
	end);

	if not shown then
		shown = UnitHealthPercent and pcall(function()
			row.pct:SetFormattedText("%d%%", UnitHealthPercent(unit, false, CurveConstants and CurveConstants.ScaleTo100));
		end);
	end

	if not shown then
		row.pct:SetText("");
	end
end

local function FillPreviewRow(row, entry, profile)
	SetIcon(row.icon, entry.index);
	SetStripe(row, entry.index);
	row.name:SetText(entry.name);
	row.pct:SetText(entry.pct .. "%");
	row.hp:SetMinMaxValues(0, 100);
	row.hp:SetValue(entry.pct);

	local highlight = false;

	if profile.showCast and entry.cast then
		row.cast:SetMinMaxValues(0, 1);
		row.cast:SetValue(entry.cast.progress);
		row.castName:SetText(entry.cast.name);
		SetCastTextColor(row, entry.cast.interruptible);
		row.castTime:SetText(string.format("%.1f", (1 - entry.cast.progress) * 2));

		row.cast:SetStatusBarColor(CastColor(profile, entry.cast.interruptible));

		if entry.cast.interruptible then
			highlight = true;
		end

		SetCastShown(row, true, profile);
	else
		row.castName:SetText("");
		row.castTime:SetText("");
		SetCastShown(row, false, profile);
	end

	return highlight;
end

-- Löst Klick-Buttons von ihrem Ziel und schaltet ihre Maus ab (nur außerhalb des
-- Kampfes möglich). keep(position) -> true = Button bleibt belegt.
local function ReleaseClickButtons(f, keep)
	if InCombatLockdown() then
		return;
	end

	for position, button in ipairs(f.clickButtons) do
		if button.clickKey ~= nil and not (keep and keep(position)) then
			button:SetAttribute("type1", "target");
			button:SetAttribute("unit", nil);
			button.clickKey, button.clickUnit = nil, nil;
			button:EnableMouse(false);
		end
	end
end

-- Eindeutiger Schlüssel dessen, worauf ein Button zielt: Token + (bei Namensplaketten)
-- Name + (wenn lesbar) GUID. Gleicher Schlüssel = gleicher Klick-Effekt.
local function EntryKey(unit)
	local name = UnitName(unit);
	local useMacro = unit:find("^nameplate") and name and not IsSecret(name);
	local guid = UnitGUID(unit);

	if guid == nil or IsSecret(guid) then
		guid = "";
	end

	return unit .. "|" .. (useMacro and name or "") .. "|" .. guid, useMacro, name;
end

function SexyInterrupter:UpdateMarkFrame()
	local f = self.markFrame;

	if not f then
		return;
	end

	local profile = self.db.profile.marks;
	local editing = self:IsEditingUi();

	if not editing and (not profile.enabled or (profile.combatOnly and not UnitAffectingCombat("player"))) then
		f:SetAlpha(0);
		ReleaseClickButtons(f);

		return;
	end

	local entries = {};

	if editing then
		for _, entry in ipairs(PREVIEW) do
			tinsert(entries, entry);
		end
	else
		local sawDead;

		entries, sawDead = CollectMarkedUnits(profile.symbols);

		if profile.sort == 'cast' then
			for _, entry in ipairs(entries) do
				entry.casting = IsCasting(entry.unit);
			end

			-- Stabil: Castende nach vorn, sonst Symbol-Reihenfolge behalten.
			local ordered = {};

			for _, entry in ipairs(entries) do
				if entry.casting then tinsert(ordered, entry); end
			end

			for _, entry in ipairs(entries) do
				if not entry.casting then tinsert(ordered, entry); end
			end

			entries = ordered;
		end

		if #entries == 0 then
			-- Kurz überbrücken (z. B. beim Zielwechsel ist das Ziel für einen
			-- Moment keiner Einheit zuordenbar): Anzeige unverändert stehen lassen.
			-- Ausnahme: ein markierter Mob ist gerade gestorben -> sofort ausblenden.
			if sawDead or not (f.lastSeen and GetTime() - f.lastSeen < 3) then
				f.lastSeen = nil;
				f:SetAlpha(0);
				ReleaseClickButtons(f);
			end

			return;
		end

		f.lastSeen = GetTime();
	end

	-- Feste Zeilen-Slots: Secure-Buttons lassen sich im Kampf nicht umbelegen. Wer
	-- einmal in einem Slot steht, bleibt dort (auch wenn andere wegfallen -> Lücke),
	-- sonst würde der Klick auf eine nachgerückte Zeile den falschen/toten Mob
	-- treffen. Außerhalb des Kampfes wird jedes Mal neu und lückenlos sortiert.
	local slotEntries = {};
	local last = 0;

	if editing then
		for i = 1, math.min(#entries, profile.maxrows) do
			slotEntries[i] = entries[i];
			last = i;
		end
	else
		f.slots = f.slots or {};

		if not InCombatLockdown() then
			f.slots = {};
		end

		-- Slots merken den Schlüssel (Token+Name+GUID), nicht nur das Token: wechselt
		-- ein Token im Kampf auf einen anderen Mob, ändert sich der Schlüssel (sofern
		-- die GUID lesbar ist) und der Mob zählt als neu statt eine alte Zeile zu erben.
		local byKey, placed = {}, {};

		for _, entry in ipairs(entries) do
			entry.key, entry.useMacro, entry.name = EntryKey(entry.unit);
			byKey[entry.key] = entry;
		end

		for i = 1, profile.maxrows do
			local key = f.slots[i];

			if key and byKey[key] and not placed[key] then
				placed[key] = true;
			else
				f.slots[i] = nil;
			end
		end

		-- Neue Einträge: im Kampf nur in einen Slot, dessen Button nichts oder genau
		-- diesen Mob anvisiert (Buttons lassen sich im Kampf nicht umbelegen).
		for _, entry in ipairs(entries) do
			if not placed[entry.key] then
				for i = 1, profile.maxrows do
					local button = f.clickButtons[i];
					local compatible = not InCombatLockdown() or not button
						or button.clickKey == nil or button.clickKey == entry.key;

					if not f.slots[i] and compatible then
						f.slots[i] = entry.key;
						placed[entry.key] = true;
						break;
					end
				end
			end
		end

		for i = 1, profile.maxrows do
			if f.slots[i] then
				slotEntries[i] = byKey[f.slots[i]];
				last = i;
			end
		end
	end

	local rowHeight = RowHeight(profile);
	local width = profile.width;

	-- Plätze der Karten: mit Zauber so hoch wie Kopfteil plus Zauberleiste, sonst nur der Kopfteil. Nur außerhalb des Kampfes neu
	-- berechnet (die Klickflächen lassen sich im Kampf nicht verschieben); im Kampf gelten die zuletzt berechneten Plätze.
	if not InCombatLockdown() or not f.slotY then
		local slotY, slotH = {}, {};
		local y = 0;

		for position = 1, profile.maxrows do
			local entry = slotEntries[position];
			local casting = false;

			if entry and profile.showCast then
				if editing then
					casting = entry.cast ~= nil;
				else
					casting = IsCasting(entry.unit) and true or false;
				end
			end

			slotY[position] = y;
			slotH[position] = casting and rowHeight or HpHeight(profile);
			y = y + slotH[position] + Gap(profile);
		end

		f.slotY, f.slotH = slotY, slotH;
	end

	self:LayoutMarkClickButtons(editing);

	-- Der Rahmen (und damit das Rechteck im Verschiebe-Modus) ist so hoch wie die sichtbaren Karten; die Oberkante bleibt stehen
	-- (Position unten links mit Ausgleich, wie bei den anderen Fenstern). Nur bei Änderung, nicht im Kampf (die Klickflächen sind
	-- Kinder des Rahmens) und nicht während eines Verschiebens.
	local visibleHeight = Head(profile) + PADDING;

	if last > 0 then
		local lastY, lastH = SlotBox(f, profile, last);

		visibleHeight = Head(profile) + lastY + lastH + PADDING;
	end

	if (f.lastWidth ~= width or f.lastHeight ~= visibleHeight) and not InCombatLockdown() and not SEM:IsMoving(f) then
		local db = self.db.profile.ui.editModeMarksDB;

		if db and db.x and db.y and f.lastHeight then
			SEM:SetPosition(f, db.x, db.y - (visibleHeight - f.lastHeight));
		end

		f:SetSize(width, visibleHeight);
		f.lastWidth, f.lastHeight = width, visibleHeight;
	end

	-- Sichtbarer Hintergrund passt sich der Zeilenzahl an; der Frame selbst
	-- behält seine feste Größe (stabile Position/Auswahl im Edit Mode).
	-- Fenster-Optik wie im Interrupter-Fenster (Hintergrund, Rand, Farben aus
	-- den gleichen Optionen); Höhe wächst mit der Zeilenzahl, der Frame selbst
	-- behält seine feste Größe.
	local ui = self.db.profile.ui;
	local window = f.window;
	window:SetHeaderShown(not profile.hideHeader);
	local windowHeight = Head(profile) + PADDING;

	if last > 0 then
		local lastY, lastH = SlotBox(f, profile, last);

		windowHeight = Head(profile) + lastY + lastH + PADDING;
	end

	local windowKey = width .. "|" .. windowHeight .. "|" .. tostring(profile.hideHeader) .. "|" .. (profile.opacity or 0.96);

	if window.styleKey ~= windowKey then
		window.styleKey = windowKey;
		window:SetSize(width, windowHeight);

		if window.SetBackdrop then
			self.EditModeHelpers.ApplyBackdrop(window, profile.opacity or self.Look.WINDOW_BG[4]);
		end
	end


	-- Badge im Titelband: Anzahl der angezeigten markierten Gegner
	local shown = 0;

	for position = 1, last do
		if slotEntries[position] then
			shown = shown + 1;
		end
	end

	window:SetBadge((shown > 0 and profile.showBadge ~= false) and string.format(L["%d active"], shown) or "");

	for position = 1, last do
		local entry = slotEntries[position];
		local row = f.rows[position] or self:CreateMarkRow(position);

		if not entry then
			row:Hide();
		else
		self:LayoutMarkRow(row, position);
		row:Show();

		local highlight = false;

		if editing then
			highlight = FillPreviewRow(row, entry, profile);
			row.targetBorder:SetShown(profile.showTarget ~= false and position == 2);
		else
			SetIcon(row.icon, entry.index, entry.unit);
			SetStripe(row, entry.index);
			row.targetBorder:SetShown(profile.showTarget ~= false and UnitExists("target") and IsSameUnit(entry.unit, "target"));

			if not InCombatLockdown() then
				-- Namensplaketten-Tokens lassen sich auf diesem Client nicht per
				-- Secure-"target" anvisieren: dort stattdessen per Name (Makro).
				local button = f.clickButtons[position];
				local key, useMacro, name = entry.key, entry.useMacro, entry.name;

				if button and button.clickKey ~= key then
					if useMacro then
						button:SetAttribute("type1", "macro");
						button:SetAttribute("unit", nil);
						button:SetAttribute("macrotext1", "/targetexact " .. name);
					else
						button:SetAttribute("type1", "target");
						button:SetAttribute("unit", entry.unit);
					end

					button.clickKey = key;
					button.clickUnit = entry.unit;
					button:EnableMouse(true);
				end
			end


			row.name:SetText(UnitName(entry.unit));
			UpdateHealth(row, entry.unit);

			local ok, interruptible = false, nil;

			if profile.showCast then
				ok, interruptible = pcall(UpdateCast, row, entry.unit, profile);
			end

			if ok and interruptible ~= nil then
				SetCastShown(row, true, profile);
				highlight = interruptible;
			else
				row.castName:SetText("");
				row.castTime:SetText("");
				SetCastShown(row, false, profile);
			end
		end

		if highlight and profile.highlightInterruptible then
			row.glow:Show();
		else
			row.glow:Hide();
		end

		SetCardEdge(row, highlight and profile.highlightInterruptible);
		end
	end

	for position = last + 1, #f.rows do
		f.rows[position]:Hide();
	end

	-- Nicht belegte Buttons von ihrem alten Ziel lösen (nur außerhalb des Kampfes).
	ReleaseClickButtons(f, function(position) return slotEntries[position] ~= nil; end);

	f:SetAlpha(1);
end

function SexyInterrupter:CreateMarkFrame(helpers)
	local profile = self.db.profile.marks;
	local ui = self.db.profile.ui;
	local f = CreateFrame("Frame", "SexyInterrupterMarks", UIParent);

	f.rows = {};
	f.clickButtons = {};
	self.markFrame = f;

	local height = Head(profile) + profile.maxrows * (RowHeight(profile) + Gap(profile)) + PADDING;

	f:SetSize(profile.width, height);
	f.lastWidth, f.lastHeight = profile.width, height;

	-- Standardposition: rechts oben, unterhalb der Bildschirmmitte-Oberkante.
	-- x/y vorab selbst eintragen (siehe Kommentar in CreateUi zum
	-- ClearAllPoints-Bruchpfad der Library).
	local db = ui.editModeMarksDB;

	if not (db.x and db.y) then
		local screenWidth, screenHeight = UIParent:GetSize();

		db.x = screenWidth - profile.width - 60;
		db.y = screenHeight - height - 200;
	end

	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y);

	-- Eigener Frame für Hintergrund + Rand (wie SexyInterrupterAnchor), unter den Zeilen.
	f.window = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil);
	f.window:SetFrameLevel(f:GetFrameLevel());
	f.window:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);

	-- Titelband mit Badge ("N aktiv", siehe UpdateMarkFrame)
	self.Look.CreateBand(f.window, L["Enemy marks"]);

	-- Alle Zeilen vorab erzeugen (secure Buttons dürfen nicht im Kampf entstehen).
	for index = 1, 8 do
		self:CreateMarkRow(index);
		self:CreateMarkClickButton(index);
	end

	-- Immer angezeigt, Sichtbarkeit nur über Alpha: Show/Hide eines Frames mit
	-- Secure-Buttons als Kindern ist im Kampf gesperrt - das Fenster erschien
	-- sonst nicht, wenn man im Kampf markierte.
	f:SetAlpha(0);
	f:Show();

	do
		local H = helpers;
		-- Gruppe 1 "Aussehen": alles, was die Vorschau verändert (die Symbole mit Trennlinie); Gruppe 2 "Verhalten"
		local settings = {
			H.Header(L["Look"], "look"),
			H.Slider(L["Width"], 150, 400, 1,
				function() return P().width end,
				function(value) P().width = value; end),
			H.Slider(L["Max rows of marks"], 1, 8, 1,
				function() return P().maxrows end,
				function(value) P().maxrows = value; end),
			H.Slider(L["Row height"], 12, 60, 1,
				function() return P().rowHeight or 40 end,
				function(value) P().rowHeight = value; end),
			H.Slider(L["Row spacing"], 0, 10, 1,
				function() return P().rowGap end,
				function(value) P().rowGap = value; end),
			H.Slider(L["Window opacity"], 30, 100, 2,
				function() return math.floor((P().opacity or 0.96) * 100 + 0.5) end,
				function(value) P().opacity = value / 100; end),
			H.Check(L["Hide header"],
				function() return P().hideHeader end,
				function(value) P().hideHeader = value and true or false; end),
			H.Check(L["Show active counter"],
				function() return P().showBadge ~= false end,
				function(value) P().showBadge = value and true or false; end),
			H.Check(L["Show marker icon"],
				function() return P().showIcon ~= false end,
				function(value) P().showIcon = value and true or false; end),
			H.Check(L["Show health percent"],
				function() return P().showPct ~= false end,
				function(value) P().showPct = value and true or false; end),
			H.Check(L["Show target frame"],
				function() return P().showTarget ~= false end,
				function(value) P().showTarget = value and true or false; end),
			H.Color(L["Health color"], false,
				function() local c = P().hpColor; return c.r, c.g, c.b, 1; end,
				function(r, g, b) local c = P().hpColor; c.r, c.g, c.b = r, g, b; end),
			{ type = "divider", name = L["Cast bar"] },
			H.Check(L["Show cast bars"],
				function() return P().showCast end,
				function(value) P().showCast = value; end),
			H.Slider(L["Cast bar height"], 10, 24, 1,
				function() return P().castBarHeight or 14 end,
				function(value) P().castBarHeight = value; end),
			H.Check(L["Show cast name"],
				function() return P().showCastName ~= false end,
				function(value) P().showCastName = value and true or false; end),
			H.Color(L["Interruptible color"], false,
				function() local c = P().castColor; return c.r, c.g, c.b, 1; end,
				function(r, g, b) local c = P().castColor; c.r, c.g, c.b = r, g, b; end),
			H.Color(L["Not interruptible color"], false,
				function() local c = P().castColorLocked; return c.r, c.g, c.b, 1; end,
				function(r, g, b) local c = P().castColorLocked; c.r, c.g, c.b = r, g, b; end),
			H.Check(L["Highlight interruptible casts"],
				function() return P().highlightInterruptible end,
				function(value) P().highlightInterruptible = value; end),
			H.Color(L["Highlight color"], false,
				function() local c = P().glowColor; return c.r, c.g, c.b, 1; end,
				function(r, g, b) local c = P().glowColor; c.r, c.g, c.b = r, g, b; end),
			H.Slider(L["Highlight strength"], 10, 80, 5,
				function() return math.floor((P().glowAlpha or 0.3) * 100 + 0.5) end,
				function(value) P().glowAlpha = value / 100; end),
			H.Select(L["Marks sort"],
				{
					{ value = 'symbol', label = L["By symbol"] },
					{ value = 'cast', label = L["Casting first"] },
				},
				function() return P().sort end,
				function(value) P().sort = value; end),
			{ type = "divider", name = L["Symbols"] },
		};

		for index = 8, 1, -1 do
			settings[#settings + 1] = H.Check(SYMBOL_NAMES[index],
				function() return P().symbols[index] end,
				function(value) P().symbols[index] = value; end);
		end

		settings[#settings + 1] = H.Header(L["Behavior"], "behavior");
		settings[#settings + 1] = H.Check(L["Show enemy marks"],
			function() return P().enabled end,
			function(value) P().enabled = value; end);
		settings[#settings + 1] = H.Check(L["Marks: show in combat only"],
			function() return P().combatOnly end,
			function(value) P().combatOnly = value; end);
		settings[#settings + 1] = H.Link(L["Interrupts"], function() return SexyInterrupterAnchor; end);

		local behavior = { L["Show enemy marks"], L["Marks: show in combat only"], L["Marks sort"] };

		for index = 1, 8 do
			behavior[#behavior + 1] = SYMBOL_NAMES[index];
		end

		H.MarkBehavior(settings, behavior);

		SEM:Register(f, {
			name = L["Addon name"] .. " " .. L["Enemy marks"],
			addon = "SexyInterrupter", group = "si", groupName = "SexyInterrupter",
			description = (GetLocale() == "deDE" and "Gegner mit Raid-Symbol samt Lebens- und Zauberbalken; ein Klick wählt das Ziel." or "Enemies with a raid marker, with health and cast bars; a click targets them."),
			db = db,
			settings = settings,
			sample = SexyInterrupterSamples and SexyInterrupterSamples.marks,   -- Vorschau im Einstellungsfenster: eigenes Fenster mit eigener Logik (samples.lua)
			visibility = false, -- das Fenster steuert seine Transparenz selbst
		});
	end

	-- Laufende Aktualisierung (Gesundheit/Cast ändern sich dauernd). Eigener
	-- Ticker, da ein versteckter Frame kein OnUpdate bekommt.
	C_Timer.NewTicker(TICK, function()
		SexyInterrupter:UpdateMarkFrame();
	end);

	return f;
end

-- /si marks: Zustand des Fensters und der Einheiten-Suche im Chat ausgeben.
-- /si marks reset: Fenster in die Bildschirmmitte setzen (falls außerhalb des Bildschirms).
function SexyInterrupter:DebugMarks(reset)
	local function Say(text)
		DEFAULT_CHAT_FRAME:AddMessage("SI marks: " .. text, 1, 0.5, 0);
	end

	local f = self.markFrame;

	if not f then
		Say("Fenster wurde nicht erzeugt (CreateMarkFrame lief nicht).");
		return;
	end

	if reset then
		local db = self.db.profile.ui.editModeMarksDB;
		local screenWidth, screenHeight = UIParent:GetSize();

		db.x = (screenWidth - f:GetWidth()) / 2;
		db.y = (screenHeight - f:GetHeight()) / 2;

		SEM:SetPosition(f, db.x, db.y);
		Say("Position zurückgesetzt.");
	end

	local p = self.db.profile.marks;
	local left, bottom, width, height = f:GetRect();

	Say(string.format("enabled=%s combatOnly=%s shown=%s editing=%s rect=%s/%s %sx%s UIParent=%sx%s",
		tostring(p.enabled), tostring(p.combatOnly), tostring(f:IsShown()), tostring(self:IsEditingUi()),
		tostring(left), tostring(bottom), tostring(width), tostring(height),
		tostring(UIParent:GetWidth()), tostring(UIParent:GetHeight())));

	local count = 0;

	for _, unit in ipairs(SCAN_UNITS) do
		if UnitExists(unit) then
			local index = GetRaidTargetIndex(unit);

			if index then
				count = count + 1;
				local function V(value)
					return IsSecret(value) and "SECRET" or tostring(value);
				end

				Say(string.format("%s: Symbol=%s canAttack=%s isDead=%s deadOrGhost=%s health=%s healthMax=%s Kampf=%s", unit,
					V(index), V(UnitCanAttack("player", unit)), V(UnitIsDead(unit)), V(UnitIsDeadOrGhost(unit)),
					V(UnitHealth(unit)), V(UnitHealthMax(unit)), tostring(InCombatLockdown())));
			end
		end
	end

	do
		local function Secrecy(v) return IsSecret(v) and "SECRET" or "offen"; end
		Say(string.format("Secrecy: UnitIsUnit=%s GUID=%s Name=%s",
			Secrecy(UnitIsUnit("target", "nameplate1")), Secrecy(UnitGUID("target")), Secrecy(UnitName("target"))));
	end

	for index, button in ipairs(f.clickButtons) do
		if button.clickUnit then
			Say(string.format("Button %d: unit=%s Kampf=%s", index, tostring(button.clickUnit), tostring(InCombatLockdown())));
		end
	end

	Say("Icon-Test: " .. tostring(self.lastIconError));

	if count == 0 then
		Say("keine Einheit mit Symbol gefunden (target/focus/mouseover/boss/nameplates).");
	end
end
