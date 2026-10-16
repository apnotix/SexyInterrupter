-- Gegner-Marker: eigenes Fenster mit den Unitframes aller Gegner, die ein
-- Raid-Symbol tragen (Totenkopf, Kreuz, ...). Zeigt Gesundheit, den laufenden
-- Cast und hebt unterbrechbare Casts hervor. Position/Optionen liegen wie bei
-- den anderen Fenstern im Edit Mode (EditModeExpanded-1.0).
local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

local ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons";
local HEADER_HEIGHT = 5;   -- oberer Innenabstand wie im Interrupter-Fenster
local ROW_GAP = 0;
local PADDING = 5;
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

local CAST_HEIGHT = 4;   -- schmale Cast-Leiste am unteren Rand der Gesundheitsleiste

-- Zeilenhöhe exakt wie im Interrupter-Fenster (Option "Bar height"); die
-- Cast-Leiste liegt als schmaler Streifen INNERHALB der Leiste.
local function RowHeight(profile)
	local barHeight = SexyInterrupter.db.profile.ui.bars.barheight;

	return barHeight;
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
	local rowHeight = RowHeight(profile);
	local key = table.concat({ profile.width, rowHeight, tostring(editing) }, "|");

	if f.clickLayoutKey == key then
		return;
	end

	f.clickLayoutKey = key;

	for index, button in ipairs(f.clickButtons) do
		button:ClearAllPoints();
		button:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -(HEADER_HEIGHT + (index - 1) * (rowHeight + ROW_GAP)));
		button:SetSize(profile.width - 2 * PADDING, rowHeight);
		-- Im Edit Mode dürfen die Buttons das Verschieben des Fensters nicht blockieren.
		button:EnableMouse(not editing and button.clickKey ~= nil);
	end
end

function SexyInterrupter:CreateMarkRow(index)
	local f = self.markFrame;
	local row = CreateFrame("Frame", nil, f);

	-- Wie im Interrupter-Fenster: eine Leiste (Gesundheit) mit Symbol, Name und
	-- Prozent IN der Leiste. Alles liegt auf dem hp-Frame, damit es nicht hinter
	-- der Leiste verschwindet (Kind-Frames liegen über den Regionen des Elternteils).
	row.hp = CreateFrame("StatusBar", nil, row);
	row.hp.bg = row.hp:CreateTexture(nil, "BACKGROUND");
	row.hp.bg:SetAllPoints(row.hp);
	row.hp.bg:SetColorTexture(0, 0, 0, 0.4);

	row.targetBorder = self:CreateTargetBorder(row.hp);

	row.glow = row.hp:CreateTexture(nil, "ARTWORK");
	row.glow:SetAllPoints(row.hp);
	row.glow:SetColorTexture(1, 0.83, 0.3, 0.3);
	row.glow:Hide();

	row.icon = row.hp:CreateTexture(nil, "OVERLAY");

	row.name = row.hp:CreateFontString(nil, "OVERLAY");
	row.name:SetJustifyH("LEFT");
	row.name:SetWordWrap(false);

	row.pct = row.hp:CreateFontString(nil, "OVERLAY");
	row.pct:SetJustifyH("RIGHT");

	row.cast = CreateFrame("StatusBar", nil, row);
	row.cast.bg = row.cast:CreateTexture(nil, "BACKGROUND");
	row.cast.bg:SetAllPoints(row.cast);
	row.cast.bg:SetColorTexture(0, 0, 0, 0.4);

	row.castName = row.cast:CreateFontString(nil, "OVERLAY");
	row.castName:SetJustifyH("RIGHT");

	row.castTime = row.cast:CreateFontString(nil, "OVERLAY");
	row.castTime:SetJustifyH("RIGHT");
	row.castTime:Hide();   -- kein Platz in der schmalen Leiste

	f.rows[index] = row;

	return row;
end

-- Layout/Schrift/Textur eines Rows an die aktuellen Einstellungen anpassen.
function SexyInterrupter:LayoutMarkRow(row, position)
	local profile = self.db.profile.marks;
	local ui = self.db.profile.ui;
	local rowHeight = RowHeight(profile);
	local barHeight = ui.bars.barheight;
	local font = LSM:Fetch("font", ui.font);
	local fontSize = ui.fontsize;
	local texture = LSM:Fetch("statusbar", ui.bars.texture);
	local barColor = ui.bars.barcolor;
	local fontColor = ui.fontcolor;
	local iconSize = math.min(barHeight - 2, 20);

	-- Nur neu anordnen, wenn sich etwas geändert hat: ein Umlayout alle 0,15 s
	-- (ClearAllPoints/SetPoint) lässt die Maus-Fokus-/Klick-Erkennung des
	-- Secure-Buttons auf der Zeile immer wieder abreißen (Klick kommt nie an).
	local key = table.concat({ position, profile.width, rowHeight, barHeight, tostring(font), fontSize, tostring(texture),
		barColor.r, barColor.g, barColor.b, barColor.a, fontColor.r, fontColor.g, fontColor.b }, "|");

	if row.layoutKey == key then
		return;
	end

	row.layoutKey = key;

	row:ClearAllPoints();
	row:SetPoint("TOPLEFT", self.markFrame, "TOPLEFT", PADDING, -(HEADER_HEIGHT + (position - 1) * (rowHeight + ROW_GAP)));
	row:SetSize(profile.width - 2 * PADDING, rowHeight);

	row.hp:SetStatusBarTexture(texture);
	row.hp:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a);
	row.hp:ClearAllPoints();
	row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0);
	row.hp:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0);
	row.hp:SetHeight(barHeight);

	row.icon:ClearAllPoints();
	row.icon:SetPoint("LEFT", row.hp, "LEFT", 2, 0);
	row.icon:SetSize(iconSize, iconSize);

	row.name:SetFont(font, fontSize, "OUTLINE");
	row.name:SetTextColor(fontColor.r, fontColor.g, fontColor.b, 1);
	row.name:ClearAllPoints();
	row.name:SetPoint("LEFT", row.hp, "LEFT", iconSize + 6, 0);
	row.name:SetPoint("RIGHT", row.castName, "LEFT", -4, 0);
	row.name:SetHeight(fontSize + 2);

	row.pct:SetFont(font, fontSize, "OUTLINE");
	row.pct:SetTextColor(fontColor.r, fontColor.g, fontColor.b, 1);
	row.pct:ClearAllPoints();
	row.pct:SetPoint("RIGHT", row.hp, "RIGHT", -4, 0);

	row.cast:SetStatusBarTexture(texture);
	row.cast:ClearAllPoints();
	row.cast:SetFrameLevel(row.hp:GetFrameLevel() + 2);
	row.cast:SetPoint("BOTTOMLEFT", row.hp, "BOTTOMLEFT", 0, 0);
	row.cast:SetPoint("BOTTOMRIGHT", row.hp, "BOTTOMRIGHT", 0, 0);
	row.cast:SetHeight(CAST_HEIGHT);
	row.castName:SetFont(font, math.max(8, fontSize - 2), "OUTLINE");
	row.castName:SetTextColor(fontColor.r, fontColor.g, fontColor.b, 1);
	row.castName:ClearAllPoints();
	row.castName:SetPoint("RIGHT", row.hp, "RIGHT", -40, 0);
	row.castTime:SetFont(font, 9, "OUTLINE");
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

	if interruptible then
		row.cast:SetStatusBarColor(0.91, 0.72, 0.23, 1);
	else
		row.cast:SetStatusBarColor(0.54, 0.54, 0.54, 1);
	end

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
	row.name:SetText(entry.name);
	row.pct:SetText(entry.pct .. "%");
	row.hp:SetMinMaxValues(0, 100);
	row.hp:SetValue(entry.pct);

	local highlight = false;

	if profile.showCast and entry.cast then
		row.cast:SetMinMaxValues(0, 1);
		row.cast:SetValue(entry.cast.progress);
		row.castName:SetText(entry.cast.name);
		row.castTime:SetText(string.format("%.1f", (1 - entry.cast.progress) * 2));

		if entry.cast.interruptible then
			row.cast:SetStatusBarColor(0.91, 0.72, 0.23, 1);
			highlight = true;
		else
			row.cast:SetStatusBarColor(0.54, 0.54, 0.54, 1);
		end

		row.cast:Show();
	else
		row.cast:Hide();
		row.castName:SetText("");
	end

	return highlight;
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

		local byUnit, placed = {}, {};

		for _, entry in ipairs(entries) do
			byUnit[entry.unit] = entry;
		end

		for i = 1, profile.maxrows do
			local unit = f.slots[i];

			if unit and byUnit[unit] and not placed[unit] then
				placed[unit] = true;
			else
				f.slots[i] = nil;
			end
		end

		for _, entry in ipairs(entries) do
			if not placed[entry.unit] then
				for i = 1, profile.maxrows do
					if not f.slots[i] then
						f.slots[i] = entry.unit;
						placed[entry.unit] = true;
						break;
					end
				end
			end
		end

		for i = 1, profile.maxrows do
			if f.slots[i] then
				slotEntries[i] = byUnit[f.slots[i]];
				last = i;
			end
		end
	end

	local rowHeight = RowHeight(profile);
	local width = profile.width;
	local height = HEADER_HEIGHT + profile.maxrows * (rowHeight + ROW_GAP) + PADDING;

	-- Größe nur bei Änderung setzen (nicht während eines Edit-Mode-Drags anfassen).
	if (f.lastWidth ~= width or f.lastHeight ~= height) and not InCombatLockdown() then
		f:SetSize(width, height);
		f.lastWidth, f.lastHeight = width, height;
	end

	-- Sichtbarer Hintergrund passt sich der Zeilenzahl an; der Frame selbst
	-- behält seine feste Größe (stabile Position/Auswahl im Edit Mode).
	-- Fenster-Optik wie im Interrupter-Fenster (Hintergrund, Rand, Farben aus
	-- den gleichen Optionen); Höhe wächst mit der Zeilenzahl, der Frame selbst
	-- behält seine feste Größe.
	local ui = self.db.profile.ui;
	local window = f.window;
	local windowHeight = HEADER_HEIGHT + last * (rowHeight + ROW_GAP) + PADDING;
	local windowKey = table.concat({ width, windowHeight, tostring(ui.window.backgroundtexture), tostring(ui.window.border),
		ui.window.background.r, ui.window.background.g, ui.window.background.b, ui.window.background.a,
		ui.window.bordercolor.r, ui.window.bordercolor.g, ui.window.bordercolor.b, ui.window.bordercolor.a }, "|");

	if window.styleKey ~= windowKey then
		window.styleKey = windowKey;
		window:SetSize(width, windowHeight);

		if window.SetBackdrop then
			self.EditModeHelpers.ApplyBackdrop(window, self.db.profile);
			window:SetBackdropBorderColor(ui.window.bordercolor.r, ui.window.bordercolor.g, ui.window.bordercolor.b, ui.window.bordercolor.a);
		end
	end


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
			row.targetBorder:SetShown(position == 2);
		else
			SetIcon(row.icon, entry.index, entry.unit);
			row.targetBorder:SetShown(UnitExists("target") and IsSameUnit(entry.unit, "target"));

			if not InCombatLockdown() then
				-- Namensplaketten-Tokens lassen sich auf diesem Client nicht per
				-- Secure-"target" anvisieren: dort stattdessen per Name (Makro).
				local button = f.clickButtons[position];
				local name = UnitName(entry.unit);
				local useMacro = entry.unit:find("^nameplate") and name and not IsSecret(name);
				local key = entry.unit .. "|" .. (useMacro and name or "");

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
				row.cast:Show();
				highlight = interruptible;
			else
				row.cast:Hide();
				row.castName:SetText("");
			end
		end

		if highlight and profile.highlightInterruptible then
			row.glow:Show();
		else
			row.glow:Hide();
		end
		end
	end

	for position = last + 1, #f.rows do
		f.rows[position]:Hide();
	end

	-- Nicht belegte Buttons von ihrem alten Ziel lösen (nur außerhalb des Kampfes).
	if not InCombatLockdown() then
		for position = 1, #f.clickButtons do
			local button = f.clickButtons[position];

			if not slotEntries[position] and button.clickKey ~= nil then
				button:SetAttribute("type1", "target");
				button:SetAttribute("unit", nil);
				button.clickKey, button.clickUnit = nil, nil;
				button:EnableMouse(false);
			end
		end
	end

	f:SetAlpha(1);
end

function SexyInterrupter:CreateMarkFrame(EME, helpers)
	local profile = self.db.profile.marks;
	local ui = self.db.profile.ui;
	local f = CreateFrame("Frame", "SexyInterrupterMarks", UIParent);

	f.rows = {};
	f.clickButtons = {};
	self.markFrame = f;

	local height = HEADER_HEIGHT + profile.maxrows * (RowHeight(profile) + ROW_GAP) + PADDING;

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

	local tint = f.window:CreateTexture();
	tint:SetColorTexture(0, 0, 0, 0.2);
	tint:SetAllPoints(f.window);

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

	if EME then
		EME:RegisterFrame(f, L["Addon name"] .. " " .. L["Enemy marks"], db, UIParent, "BOTTOMLEFT", true);

		helpers.Checkbox(EME, f, "marksenabled", L["Show enemy marks"],
			function() return P().enabled end,
			function(value) P().enabled = value; end);

		helpers.Checkbox(EME, f, "markscombatonly", L["Marks: show in combat only"],
			function() return P().combatOnly end,
			function(value) P().combatOnly = value; end);

		helpers.Checkbox(EME, f, "marksshowcast", L["Show cast bars"],
			function() return P().showCast end,
			function(value) P().showCast = value; end);

		helpers.Checkbox(EME, f, "markshighlight", L["Highlight interruptible casts"],
			function() return P().highlightInterruptible end,
			function(value) P().highlightInterruptible = value; end);

		helpers.Slider(EME, f, "marksmaxrows", L["Max rows of marks"], 1, 8, 1,
			function() return P().maxrows end,
			function(value) P().maxrows = value; end);

		helpers.Slider(EME, f, "markswidth", L["Width"], 150, 400, 1,
			function() return P().width end,
			function(value) P().width = value; end);

		helpers.Select(EME, f, "markssort", L["Marks sort"],
			{
				{ value = 'symbol', label = L["By symbol"] },
				{ value = 'cast', label = L["Casting first"] },
			},
			function() return P().sort end,
			function(value) P().sort = value; end);

		for index = 8, 1, -1 do
			helpers.Checkbox(EME, f, "markssymbol" .. index, SYMBOL_NAMES[index],
				function() return P().symbols[index] end,
				function(value) P().symbols[index] = value; end);
		end
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

		local liveDB = self.EditModeHelpers.GetLiveDB(f, db);
		liveDB.x, liveDB.y = db.x, db.y;

		f:ClearAllPoints();
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y);
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
