-- Vorschau im Einstellungsfenster (SexyEditMode-Hub): ein eigenes Fenster mit eigener Logik, kein Abbild des echten.
-- Die Liste zeichnet sich selbst wie das echte Fenster (gleiche Farben, Rahmen, Symbole, Schrift) mit ausgedachten Spielern,
-- sortiert sie wie die echte Liste und lässt die Balken und Zeiten laufend herunterzählen (eigener OnUpdate). Einstellungen
-- (Breite, Balkenhöhe, Zeilenzahl, Farben, Klassensymbol, Heiler ignorieren, feste Reihenfolge, Kopfzeile) wirken sofort.
-- Klickbereiche springen zur passenden Einstellung (jump = Name der Einstellung).

local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);
local LSM = LibStub("LibSharedMedia-3.0");
local S = {};
SexyInterrupterSamples = S;

local CYCLE = 40;   -- Sekunden, dann beginnt der Ablauf von vorn
local PRIO = { TANK = 1, DAMAGER = 2, HEALER = 3 };
-- Name, Klasse, Rolle, Zauber-Symbol, Abklingzeit, Sekunden bis bereit
local PEOPLE = {
	{ "Brom",    "WARRIOR",     "TANK",    "Interface\\Icons\\Ability_Warrior_PunishingBlow", 15, 0 },
	{ "Kael",    "MAGE",        "DAMAGER", "Interface\\Icons\\Spell_Frost_IceShock",          24, 0 },
	{ "Mira",    "SHAMAN",      "DAMAGER", "Interface\\Icons\\Spell_Nature_Cyclone",          12, 5 },
	{ "Selene",  "PRIEST",      "HEALER",  "Interface\\Icons\\Spell_Shadow_ImpPhaseShift",    45, 8 },
	{ "Thessa",  "ROGUE",       "DAMAGER", "Interface\\Icons\\Ability_Kick",                  15, 11 },
	{ "Garrick", "DRUID",       "TANK",    "Interface\\Icons\\Ability_Druid_Bash",            15, 14 },
	{ "Torvin",  "HUNTER",      "DAMAGER", "Interface\\Icons\\Ability_Hunter_ChimeraShot2",   24, 17 },
	{ "Lyra",    "WARLOCK",     "DAMAGER", "Interface\\Icons\\Spell_Shadow_MindRot",          24, 20 },
	{ "Dunkan",  "PALADIN",     "TANK",    "Interface\\Icons\\Spell_Holy_Rebuke",             15, 23 },
	{ "Nyx",     "SHAMAN",      "DAMAGER", "Interface\\Icons\\Spell_Nature_EarthShock",       12, 26 },
};

local function Cfg()
	local p = SexyInterrupter.db and SexyInterrupter.db.profile;

	return p;
end

-- Zeilenabstand, Deckkraft u. a. kommen aus den Einstellungen (wie im echten Fenster)
local function RowGap() return Cfg().ui.window.rowgap or 3; end

local function MakeRow(w, i)
	local Look = SexyInterrupter.Look;
	local r = CreateFrame("Frame", nil, w);
	r.card = r:CreateTexture(nil, "BACKGROUND");
	r.card:SetAllPoints();
	r.card:SetColorTexture(Look.CARD[1], Look.CARD[2], Look.CARD[3], Look.CARD[4]);   -- Deckkraft siehe ApplyRow

	r.bar = CreateFrame("StatusBar", nil, r);
	r.bar:SetPoint("TOPLEFT");
	r.bar:SetMinMaxValues(0, 100);
	r.bar:SetValue(100);
	r.bar:SetFrameLevel(r:GetFrameLevel() + 1);
	r.bar:SetStatusBarTexture(LSM:Fetch("statusbar", "Sexy") or "Interface\\Buttons\\WHITE8X8");

	r.highlight = r.bar:CreateTexture(nil, "ARTWORK");
	r.highlight:SetAllPoints();
	r.highlight:SetColorTexture(1, 0.82, 0, 0.25);
	r.highlight:Hide();

	r.role = r.bar:CreateTexture(nil, "OVERLAY");
	r.role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
	r.abilityBorder = r.bar:CreateTexture(nil, "OVERLAY", nil, -1);
	r.ability = r.bar:CreateTexture(nil, "OVERLAY");
	r.ability:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	r.name = r.bar:CreateFontString(nil, "OVERLAY");
	r.cd = r.bar:CreateFontString(nil, "OVERLAY");
	r.cd:SetJustifyH("RIGHT");
	r.cd:SetSize(36, 12);

	-- Rahmen und runde Ecken wie im echten Fenster
	local SEM = LibStub("SexyEditMode-1.0", true);

	if SEM and SEM.ShineBar then
		SEM:ShineBar(r.bar, { radius = 5, surround = Look.CARD, texture = false, gloss = false });
	end

	return r;
end

-- Spieler (neu) aufstellen; readyAt ist der Zeitpunkt, an dem der Kick wieder bereit ist
local function Reset(c)
	local gen = Cfg().general;
	local now = GetTime();

	c.t0 = now;
	c.people = {};

	for _, p in ipairs(PEOPLE) do
		if not (gen.ignoreHealer and p[3] == "HEALER") then
			c.people[#c.people + 1] = {
				name = p[1], class = p[2], role = p[3], icon = p[4], cd = p[5],
				readyAt = p[6] > 0 and (now + p[6]) or 0,
			};
		end
	end
end

-- Reihenfolge wie die echte Liste
local function Sorted(c, now)
	local fixed = Cfg().general.fixedRotation;
	local list = {};

	for _, e in ipairs(c.people) do list[#list + 1] = e; end

	table.sort(list, function(x, y)
		local rx, ry = math.max(x.readyAt - now, 0), math.max(y.readyAt - now, 0);
		local px, py = PRIO[x.role] or 9, PRIO[y.role] or 9;

		if fixed then
			if (rx == 0) ~= (ry == 0) then return rx == 0; end
			if px ~= py then return px < py; end
			return x.name < y.name;
		end

		if rx ~= ry then return rx < ry; end
		if px ~= py then return px < py; end
		return x.name < y.name;
	end);

	return list;
end

-- Statische Eigenschaften einer Zeile (Größe, Schrift, Symbole, Farben) für den Spieler e an Platz i
local function ApplyRow(c, i, e)
	local p = Cfg();
	local ui, bars = p.ui, p.ui.bars;
	local Look = SexyInterrupter.Look;
	local w = c.win;
	local r = w.rows[i];
	local W, h = ui.window.width, bars.barheight;
	local y = c.top + (i - 1) * (h + RowGap());
	local iconSize = math.max(12, math.min(20, h - 8));

	r.card:SetColorTexture(Look.CARD[1], Look.CARD[2], Look.CARD[3], ui.window.opacity or Look.CARD[4]);
	r:ClearAllPoints();
	r:SetPoint("TOPLEFT", w, "TOPLEFT", 6, -y);
	r:SetSize(W - 12, h);
	r.bar:SetSize(W - 12, h);
	r.bar:SetStatusBarTexture(LSM:Fetch("statusbar", bars.texture) or "Interface\\Buttons\\WHITE8X8");

	-- Klassensymbol und Name
	local showRole = bars.showclassicon and e.role;
	r.role:ClearAllPoints();
	r.role:SetPoint("LEFT", r.bar, "LEFT", 8, 0);
	r.role:SetSize(iconSize, iconSize);
	local tc = SexyInterrupter.role_icon_tcoords and SexyInterrupter.role_icon_tcoords[e.role];
	if tc then r.role:SetTexCoord(unpack(tc)); end
	r.role:SetShown(showRole and tc and true or false);

	local outline = ui.outline ~= false and "OUTLINE" or "";
	r.name:SetFont(LSM:Fetch("font", ui.font) or STANDARD_TEXT_FONT, ui.fontsize, outline);
	r.name:SetShadowColor(0, 0, 0, 1);
	r.name:SetShadowOffset(1, -1);
	r.name:ClearAllPoints();
	r.name:SetPoint("LEFT", r.bar, "LEFT", r.role:IsShown() and 31 or 8, 0);
	r.name:SetText(e.name);
	local class = RAID_CLASS_COLORS[e.class];

	if ui.useclasscolor and class then
		r.name:SetTextColor(SexyInterrupter.SoftClassColor(class));
	else
		r.name:SetTextColor(ui.fontcolor.r, ui.fontcolor.g, ui.fontcolor.b, 1);
	end

	-- Fähigkeit rechts mit Rahmen, Zeit davor
	r.ability:ClearAllPoints();
	r.ability:SetPoint("RIGHT", r.bar, "RIGHT", -6, 0);
	r.ability:SetSize(iconSize, iconSize);
	r.ability:SetTexture(e.icon);
	r.ability:SetShown(bars.showabilityicon ~= false);
	r.abilityBorder:ClearAllPoints();
	r.abilityBorder:SetPoint("TOPLEFT", r.ability, "TOPLEFT", -2, 2);
	r.abilityBorder:SetPoint("BOTTOMRIGHT", r.ability, "BOTTOMRIGHT", 2, -2);
	r.abilityBorder:SetColorTexture(Look.WINDOW_EDGE[1], Look.WINDOW_EDGE[2], Look.WINDOW_EDGE[3], 1);
	r.abilityBorder:SetShown(bars.showabilityicon ~= false);
	r.cd:SetFont(LSM:Fetch("font", ui.font) or STANDARD_TEXT_FONT, ui.fontsize, outline);
	r.cd.show = bars.showcooldown ~= false;
	if r.bar.sxCorners then r.bar.sxCorners:SetShown(not ui.window.square); end
	r.cd:ClearAllPoints();
	r.cd:SetPoint("RIGHT", r.ability, "LEFT", -3, 0);
	r.cd:SetTextColor(ui.fontcolor.r, ui.fontcolor.g, ui.fontcolor.b, 1);

	r.highlight:SetShown(p.general.highlightOwn and i == 1);
	r.entry = e;
	r:Show();
end

-- Dynamische Eigenschaften (Füllstand, Farbe, Zeit) jedes Bild
local function Tick(c)
	local w = c.win;
	if not (w and w:IsVisible() and c.order) then return; end

	local p = Cfg();
	local bars = p.ui.bars;
	local Look = SexyInterrupter.Look;
	local now = GetTime();

	-- nach dem Ablauf von vorn
	if now - c.t0 > CYCLE then
		Reset(c);
		c.order = nil;
		S.Redraw();
		return;
	end

	-- Reihenfolge ändert sich (jemand wird bereit): Zeilen neu belegen
	if now - (c.sorted or 0) > 0.2 then
		c.sorted = now;
		local order = Sorted(c, now);
		local changed = not c.order or #order ~= #c.order;

		for i, e in ipairs(order) do
			if not c.order or c.order[i] ~= e then changed = true; end
		end

		if changed then
			c.order = order;
			local n = math.min(#order, p.general.maxrows or 5);

			for i = 1, #w.rows do
				if i <= n then ApplyRow(c, i, order[i]); else w.rows[i]:Hide(); end
			end

			S.Redraw();
		end
	end

	local barcolor = bars.barcolor;

	for i, r in ipairs(w.rows) do
		local e = r.entry;

		if r:IsShown() and e then
			local remaining = math.max(e.readyAt - now, 0);

			if e.cd > 0 and remaining > 0 then
				r.bar:SetMinMaxValues(0, e.cd);
				r.bar:SetValue(remaining);
				-- wie im echten Fenster: mit Klassenfarbe bleibt die Leiste in der Klassenfarbe, sonst wird sie braun, solange der Kick abklingt
				local class = RAID_CLASS_COLORS[e.class];

				if bars.useclasscolor and class then
					r.bar:SetStatusBarColor(SexyInterrupter.SoftClassColor(class));
				else
					r.bar:SetStatusBarColor(Look.COOLING[1], Look.COOLING[2], Look.COOLING[3], 1);
				end

				r.cd:SetText(string.format("%.1f", remaining));
				r.cd:SetShown(r.cd.show);
			else
				r.bar:SetMinMaxValues(0, 100);
				r.bar:SetValue(100);
				local class = RAID_CLASS_COLORS[e.class];

				if bars.useclasscolor and class then
					r.bar:SetStatusBarColor(SexyInterrupter.SoftClassColor(class));
				else
					r.bar:SetStatusBarColor(barcolor.r, barcolor.g, barcolor.b, barcolor.a);
				end

				r.cd:Hide();
			end
		end
	end
end

-- Hub neu zeichnen lassen (Größe und Klickbereiche folgen dem Inhalt)
function S.Redraw()
	local SEM = LibStub("SexyEditMode-1.0", true);
	if SEM and SEM.RedrawSample then SEM:RedrawSample(); end
end

-- Aufruf des Hubs bei jeder Änderung: Einstellungen anwenden, Größe und Klickbereiche liefern
function S.list(host, c)
	local p = Cfg();
	if not p then return nil; end

	local Look = SexyInterrupter.Look;
	local ui, bars, gen = p.ui, p.ui.bars, p.general;

	if not c.win then
		local w = CreateFrame("Frame", nil, host, BackdropTemplateMixin and "BackdropTemplate" or nil);
		w:SetBackdrop(Look.BACKDROP);
		w:SetBackdropColor(Look.WINDOW_BG[1], Look.WINDOW_BG[2], Look.WINDOW_BG[3], ui.window.opacity or Look.WINDOW_BG[4]);
		w:SetBackdropBorderColor(Look.WINDOW_EDGE[1], Look.WINDOW_EDGE[2], Look.WINDOW_EDGE[3], Look.WINDOW_EDGE[4]);
		w:SetPoint("TOPLEFT", host, "TOPLEFT");
		Look.CreateBand(w, L["Interrupts"]);
		w.rows = {};

		for i = 1, 12 do w.rows[i] = MakeRow(w, i); end

		c.win = w;
		w:SetScript("OnUpdate", function() Tick(c); end);
		Reset(c);
	end

	local w = c.win;
	w:SetBackdropColor(Look.WINDOW_BG[1], Look.WINDOW_BG[2], Look.WINDOW_BG[3], ui.window.opacity or Look.WINDOW_BG[4]);
	w.band:SetColorTexture(0.15, 0.12, 0.07, ui.window.opacity or 0.96);

	-- Kopfzeile und Abstand nach oben (wie SexyInterrupter:ListTopPad)
	local hide = ui.window.hideHeader and true or false;
	w:SetHeaderShown(not hide);
	c.top = hide and 6 or (Look.HEAD + 2);

	-- Ignorier-Einstellung geändert: Spieler neu aufstellen
	if c.ignoreHealer ~= (gen.ignoreHealer and true or false) then
		c.ignoreHealer = gen.ignoreHealer and true or false;
		Reset(c);
		c.order = nil;
	end

	local now = GetTime();
	local order = c.order or Sorted(c, now);
	c.order = order;
	local n = math.min(#order, gen.maxrows or 5);

	for i = 1, #w.rows do
		if i <= n then ApplyRow(c, i, order[i]); else w.rows[i]:Hide(); end
	end

	local W, h = ui.window.width, bars.barheight;
	local gap = RowGap();
	local H = c.top + n * (h + gap) - gap + 6;
	w:SetSize(W, H);
	w:SetBadge(ui.window.showBadge ~= false and string.format(L["%d ready"], 2) or "");
	Tick(c);

	local head = hide and 6 or Look.HEAD;
	local iconSize = math.max(12, math.min(20, h - 8));

	-- Klickbereiche: später genannte liegen oben
	local rowsH = n * (h + gap) - gap;
	local parts = {
		{ name = L["Window"], x = 0, y = 0, w = W, h = H, jump = "_pos" },
		{ name = L["Window opacity"], x = 0, y = 0, w = 6, h = H, jump = L["Window opacity"] },
		{ name = L["Window opacity"], x = W - 6, y = 0, w = 6, h = H, jump = L["Window opacity"] },
		{ name = L["Hide header"], x = 0, y = 0, w = W, h = head, jump = L["Hide header"] },
	};

	if not hide and ui.window.showBadge ~= false then
		parts[#parts + 1] = { name = L["Show ready counter"], x = W - 96, y = 3, w = 90, h = head - 6, jump = L["Show ready counter"] };
	end

	parts[#parts + 1] = { name = L["Bar height"], x = 6, y = c.top, w = W - 12, h = rowsH, jump = L["Bar height"] };

	for i = 1, n - 1 do
		parts[#parts + 1] = { name = L["Row spacing"], x = 6, y = c.top + i * (h + gap) - gap - 2, w = W - 12, h = gap + 4, jump = L["Row spacing"] };
	end

	parts[#parts + 1] = { name = L["Show role icon"], x = 8, y = c.top, w = iconSize + 8, h = rowsH, jump = L["Show role icon"] };
	parts[#parts + 1] = { name = L["Font size"], x = 8 + iconSize + 8, y = c.top, w = 90, h = rowsH, jump = L["Font size"] };

	if bars.showcooldown ~= false then
		parts[#parts + 1] = { name = L["Show cooldown number"], x = W - 12 - iconSize - 42, y = c.top, w = 38, h = rowsH, jump = L["Show cooldown number"] };
	end

	parts[#parts + 1] = { name = L["Show spell icon"], x = W - 12 - iconSize - 2, y = c.top, w = iconSize + 6, h = rowsH, jump = L["Show spell icon"] };
	parts[#parts + 1] = { name = L["Square bars"], x = 6, y = c.top, w = 9, h = 9, jump = L["Square bars"] };
	parts[#parts + 1] = { name = L["Max rows of interrupters"], x = 6, y = H - 8, w = W - 12, h = 8, jump = L["Max rows of interrupters"] };

	return { w = W, h = H, parts = parts };
end

-- "Interrupt now" -------------------------------------------------------------------------------------------------------
-- Eigene Karte wie die echte (Band mit rotem Rand, pulsierender Schein, Zaubersymbol, Name, Etiketten, Zauberbalken mit
-- Restzeit). Der Zauber "wirkt" in Schleife: Balken und Zeit laufen herunter, danach kurze Pause.

local CAST_TIME, CAST_CYCLE = 2.5, 4;

function S.card(host, c)
	local p = Cfg();
	if not p then return nil; end

	local Look = SexyInterrupter.Look;
	local A = Look.ALERT;

	if not c.win then
		local w = CreateFrame("Frame", nil, host, BackdropTemplateMixin and "BackdropTemplate" or nil);
		w:SetBackdrop(Look.BACKDROP);
		w:SetBackdropColor(Look.WINDOW_BG[1], Look.WINDOW_BG[2], Look.WINDOW_BG[3], Look.WINDOW_BG[4]);
		w:SetBackdropBorderColor(A.EDGE[1], A.EDGE[2], A.EDGE[3], A.EDGE[4]);
		w:SetPoint("TOPLEFT", host, "TOPLEFT");
		Look.CreateBand(w, L["Interrupt now"] .. "!", A.BAND, { 1, 0.71, 0.66 });

		-- roter, pulsierender Schein
		local glow = CreateFrame("Frame", nil, w);
		glow:SetAllPoints(w);
		w.glowObj = A.NineSliceGlow(glow, w, 128, 48, 48, 32);
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
		pulse:Play();
		w.glow, w.pulse = glow, pulse;

		w.iconBorder = w:CreateTexture(nil, "ARTWORK");
		w.iconBorder:SetColorTexture(1, 0.6, 0.53, 1);
		w.icon = w:CreateTexture(nil, "OVERLAY");
		w.icon:SetSize(44, 44);
		w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
		w.icon:SetTexture("Interface\Icons\Spell_Shadow_ShadowBolt");
		w.iconBorder:SetPoint("TOPLEFT", w.icon, "TOPLEFT", -2, 2);
		w.iconBorder:SetPoint("BOTTOMRIGHT", w.icon, "BOTTOMRIGHT", 2, -2);

		w.name = w:CreateFontString(nil, "OVERLAY");
		w.name:SetFont(Look.TitleFont(), 26, "");
		w.name:SetTextColor(0.95, 0.92, 0.86);
		w.name:SetJustifyH("LEFT");
		w.name:SetWordWrap(false);
		w.name:SetPoint("TOPLEFT", w.icon, "TOPRIGHT", 14, 2);
		w.name:SetPoint("RIGHT", w, "RIGHT", -16, 0);
		w.name:SetText(L["Preview Target"]);

		w.spellPill = Look.MakePill(w);
		w.timePill = Look.MakePill(w);
		w.spellPill.bg:SetPoint("TOPLEFT", w.name, "BOTTOMLEFT", 0, -6);
		w.spellPill:Set("lack", L["Preview Spell"], 12);
		w.timePill.bg:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -18, 12.5);
		w.timePill:Set("grey", string.format("%.1f s", CAST_TIME), 12);

		local bar = CreateFrame("StatusBar", nil, w);
		bar:SetHeight(10);
		bar:SetPoint("LEFT", w, "BOTTOMLEFT", 18, 21);
		bar:SetPoint("RIGHT", w.timePill.bg, "LEFT", -6, 0);
		bar:SetStatusBarTexture(LSM:Fetch("statusbar", "Flat") or "Interface\Buttons\WHITE8X8");
		bar:SetStatusBarColor(0.94, 0.75, 0.29, 1);
		bar:SetMinMaxValues(0, CAST_TIME);
		bar.bg = bar:CreateTexture(nil, "BACKGROUND");
		bar.bg:SetAllPoints();
		bar.bg:SetColorTexture(0.21, 0.19, 0.14, 1);
		w.bar = bar;

		local SEM = LibStub("SexyEditMode-1.0", true);
		if SEM and SEM.ShineBar then SEM:ShineBar(bar); end

		c.t0 = GetTime();
		local shown = -1;

		w:SetScript("OnUpdate", function()
			local t = (GetTime() - c.t0) % CAST_CYCLE;
			local remaining = math.max(CAST_TIME - t, 0);

			bar:SetValue(math.min(t, CAST_TIME));

			-- Zeit nur alle 0,1 s neu schreiben
			local tenth = math.floor(remaining * 10);

			if tenth ~= shown and c.showTime ~= false then
				shown = tenth;
				w.timePill:Set("grey", string.format("%.1f s", remaining), 12);
			end
		end);

		c.win = w;
	end

	local w = c.win;
	local n = p.notification;
	local hide = n.hideHeader and true or false;
	local top = hide and 6 or Look.HEAD;

	w:SetHeaderShown(not hide);
	w:SetBadge(n.showBadge ~= false and L["You are up"] or "");
	w.glow:SetShown(n.glow ~= false);
	w.glowObj:SetColor(n.glowcolor.r, n.glowcolor.g, n.glowcolor.b, 1);

	local size = n.iconSize or 44;
	w.icon:SetSize(size, size);
	w.icon:ClearAllPoints();
	w.icon:SetPoint("TOPLEFT", w, "TOPLEFT", 18, -(top + 12));
	w.name:SetFont(Look.TitleFont(), n.nameSize or 26, "");

	-- Etiketten und Zauberbalken nach Einstellung (der Balken reicht bis zur Zeit oder bis zum Rand)
	w.spellPill.bg:SetShown(n.showSpell ~= false);
	w.spellPill.text:SetShown(n.showSpell ~= false);
	c.showTime = n.showTime ~= false;
	w.timePill.bg:SetShown(c.showTime);
	w.timePill.text:SetShown(c.showTime);
	w.bar:SetShown(n.showBar ~= false);
	w.bar:ClearAllPoints();
	w.bar:SetPoint("LEFT", w, "BOTTOMLEFT", 18, 21);

	if c.showTime then
		w.bar:SetPoint("RIGHT", w.timePill.bg, "LEFT", -6, 0);
	else
		w.bar:SetPoint("RIGHT", w, "BOTTOMRIGHT", -18, 21);
	end

	local W, H = A.Width(), top + A.Body();
	w:SetSize(W, H);

	-- Klickbereiche: später genannte liegen oben
	local nameX = 18 + size + 14;
	local nameH = (n.nameSize or 26) + 6;
	local pillH = 17;
	local timeW = w.timePill.bg:GetWidth();
	local parts = {
		{ name = L["Window"], x = 0, y = 0, w = W, h = H, jump = "_pos" },
		{ name = L["Glow"], x = 0, y = 0, w = W, h = 8, jump = L["Glow"] },
		{ name = L["Glow"], x = 0, y = H - 8, w = W, h = 8, jump = L["Glow"] },
		{ name = L["Card width"], x = W - 8, y = 8, w = 8, h = H - 16, jump = L["Card width"] },
		{ name = L["Hide header"], x = 0, y = 0, w = W, h = top, jump = L["Hide header"] },
	};

	if not hide and n.showBadge ~= false then
		parts[#parts + 1] = { name = L["Show badge"], x = W - 110, y = 3, w = 104, h = top - 6, jump = L["Show badge"] };
	end

	parts[#parts + 1] = { name = L["Icon size"], x = 16, y = top + 10, w = size + 4, h = size + 4, jump = L["Icon size"] };
	parts[#parts + 1] = { name = L["Name size"], x = nameX, y = top + 10, w = W - nameX - 16, h = nameH, jump = L["Name size"] };

	if n.showSpell ~= false then
		parts[#parts + 1] = { name = L["Show spell label"], x = nameX, y = top + 10 + nameH + 2, w = w.spellPill.bg:GetWidth(), h = pillH, jump = L["Show spell label"] };
	end

	if c.showTime then
		parts[#parts + 1] = { name = L["Show time label"], x = W - 18 - timeW, y = H - 12.5 - pillH, w = timeW, h = pillH, jump = L["Show time label"] };
	end

	if n.showBar ~= false then
		local right = c.showTime and (W - 18 - timeW - 6) or (W - 18);
		parts[#parts + 1] = { name = L["Show cast bar"], x = 18, y = H - 26, w = right - 18, h = 10, jump = L["Show cast bar"] };
	end

	return { w = W, h = H, parts = parts };
end

-- Gegner-Markierungen ---------------------------------------------------------------------------------------------------
-- Eigenes Fenster wie das echte (Band, Karten mit Farbstreifen, Symbol, Name, Prozent, Gesundheit und Zauberleiste mit Name und
-- Zeit, goldener Rand und Glanz bei unterbrechbaren Zaubern, weißer Rahmen um das Ziel). Die Gesundheit sinkt laufend, die Zauber laufen in Schleife; Breite,
-- Zeilen, Kopfzeile, Zauberleisten, Hervorhebung, Sortierung und die Symbolauswahl wirken sofort.

local MARK_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons";
local MARK_PADDING, CAST_H = 6, 14;
local PAD_Y, LINE_H, ICON_SIZE, GAP_HP, HP_BAR_H = 6, 16, 14, 4, 8;
local EDGE_COLOR, EDGE_HOT = { 0.227, 0.184, 0.11 }, { 0.78, 0.6, 0.17 };
local SYMBOL_COLORS = {
	{ 1, 0.92, 0.2 }, { 1, 0.55, 0.1 }, { 0.75, 0.3, 0.9 }, { 0.3, 0.8, 0.4 },
	{ 0.78, 0.83, 0.9 }, { 0.27, 0.63, 0.9 }, { 0.9, 0.28, 0.25 }, { 0.95, 0.95, 0.95 },
};

local function SymbolName(index)
	local names = { L["Star"], L["Circle"], L["Diamond"], L["Triangle"], L["Moon"], L["Square"], L["Cross"], L["Skull"] };

	return names[index];
end

local function MakeMarkRow(w)
	local r = CreateFrame("Frame", nil, w);
	r.body = CreateFrame("Frame", nil, r);   -- Kartengrund: so hoch wie der Kopfteil, mit Zauber bis unter die Zauberleiste
	r.body:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0);
	r.body:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0);
	r.bg = r.body:CreateTexture(nil, "BACKGROUND");
	r.bg:SetAllPoints(r.body);
	r.bg:SetColorTexture(0.114, 0.094, 0.063, 1);
	r.glow = r.body:CreateTexture(nil, "BORDER");
	r.glow:SetAllPoints(r.body);
	r.glow:SetColorTexture(1, 0.83, 0.3, 0.12);
	r.glow:Hide();
	r.edges = {};

	for k, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local t = r.body:CreateTexture(nil, "ARTWORK");

		t:SetPoint(e[1], r.body, e[1], 0, 0);
		t:SetPoint(e[2], r.body, e[2], 0, 0);

		if e[3] then t:SetHeight(1); else t:SetWidth(1); end

		r.edges[k] = t;
	end

	r.stripe = r.body:CreateTexture(nil, "ARTWORK", nil, 1);
	r.stripe:SetPoint("TOPLEFT", r.body, "TOPLEFT", 0, 0);
	r.stripe:SetPoint("BOTTOMLEFT", r.body, "BOTTOMLEFT", 0, 0);
	r.stripe:SetWidth(3);
	r.hp = CreateFrame("StatusBar", nil, r);
	r.hp.bg = r.hp:CreateTexture(nil, "BACKGROUND");
	r.hp.bg:SetAllPoints(r.hp);
	r.hp.bg:SetColorTexture(0.055, 0.043, 0.03, 1);
	r.cast = CreateFrame("StatusBar", nil, r);
	r.cast.bg = r.cast:CreateTexture(nil, "BACKGROUND");
	r.cast.bg:SetAllPoints(r.cast);
	r.cast.bg:SetColorTexture(0.055, 0.043, 0.03, 1);
	r.cast:SetFrameLevel(r.hp:GetFrameLevel() + 1);
	r.textLayer = CreateFrame("Frame", nil, r);
	r.textLayer:SetAllPoints(r);
	r.textLayer:SetFrameLevel(r.hp:GetFrameLevel() + 4);
	r.targetBorder = SexyInterrupter:CreateTargetBorder(r.body);
	r.icon = r.textLayer:CreateTexture(nil, "OVERLAY");
	r.icon:SetTexture(MARK_ICONS);
	r.name = r.textLayer:CreateFontString(nil, "OVERLAY");
	r.name:SetJustifyH("LEFT");
	r.name:SetWordWrap(false);
	r.pct = r.textLayer:CreateFontString(nil, "OVERLAY");
	r.pct:SetJustifyH("RIGHT");
	r.castName = r.textLayer:CreateFontString(nil, "OVERLAY");
	r.castName:SetJustifyH("LEFT");
	r.castName:SetWordWrap(false);
	r.castTime = r.textLayer:CreateFontString(nil, "OVERLAY");
	r.castTime:SetJustifyH("RIGHT");

	return r;
end

-- Die sichtbaren Einträge: Symbolauswahl, Sortierung, Zeilenzahl
local function MarkEntries(m)
	local list = {};

	for _, e in ipairs(SexyInterrupter.MarksPreview) do
		if m.symbols[e.index] then list[#list + 1] = e; end
	end

	table.sort(list, function(a, b)
		if m.sort == "cast" and (a.cast ~= nil) ~= (b.cast ~= nil) then return a.cast ~= nil; end

		return a.index > b.index;
	end);

	local out = {};

	for i = 1, math.min(#list, m.maxrows or 5) do out[i] = list[i]; end

	return out;
end

-- Gesundheit und Zauber laufen jedes Bild
local function TickMarks(c)
	local w = c.win;

	if not (w and w:IsVisible() and c.entries) then return; end

	local t = GetTime() - c.t0;
	local m = Cfg().marks;

	for i, r in ipairs(w.rows) do
		local e = c.entries[i];

		if r:IsShown() and e then
			local pct = math.max(3, e.pct - ((t * 2.5) % 60));

			r.hp:SetValue(pct);
			r.pct:SetText(string.format("%d%%", math.floor(pct + 0.5)));

			if m.showCast and e.cast then
				local progress = ((t + i * 0.7) % 3) / 3;

				r.cast:SetValue(progress);
				r.castTime:SetText(string.format("%.1f", (1 - progress) * 2));
			end
		end
	end
end

function S.marks(host, c)
	local p = Cfg();
	if not p then return nil; end

	local Look = SexyInterrupter.Look;
	local m, ui = p.marks, p.ui;

	if not c.win then
		local w = CreateFrame("Frame", nil, host, BackdropTemplateMixin and "BackdropTemplate" or nil);
		w:SetBackdrop(Look.BACKDROP);
		w:SetBackdropColor(Look.WINDOW_BG[1], Look.WINDOW_BG[2], Look.WINDOW_BG[3], Look.WINDOW_BG[4]);
		w:SetBackdropBorderColor(Look.WINDOW_EDGE[1], Look.WINDOW_EDGE[2], Look.WINDOW_EDGE[3], Look.WINDOW_EDGE[4]);
		w:SetPoint("TOPLEFT", host, "TOPLEFT");
		Look.CreateBand(w, L["Enemy marks"]);
		w.rows = {};

		for i = 1, 8 do w.rows[i] = MakeMarkRow(w); end

		c.win, c.t0 = w, GetTime();
		w:SetScript("OnUpdate", function() TickMarks(c); end);
	end

	local w = c.win;
	local hide = m.hideHeader and true or false;
	local head = hide and 6 or Look.HEAD;
	local rowH = m.rowHeight or 40;
	local gap = m.rowGap or 0;
	local castH = m.castBarHeight or CAST_H;
	local slot = rowH + (m.showCast and (castH + 6) or 0);   -- Kopfteil der Karte plus Zauberleiste und Luft darunter
	local width = m.width;

	c.entries = MarkEntries(m);

	-- Plätze der Karten: mit Zauber so hoch wie Kopfteil plus Zauberleiste, sonst nur der Kopfteil (wie im echten Fenster)
	local ys, hs = {}, {};

	do
		local y = 0;

		for i, e in ipairs(c.entries) do
			hs[i] = (m.showCast and e.cast) and slot or rowH;
			ys[i] = y;
			y = y + hs[i] + gap;
		end
	end

	local n = #c.entries;
	local font = LSM:Fetch("font", ui.font) or STANDARD_TEXT_FONT;
	local texture = LSM:Fetch("statusbar", ui.bars.texture) or "Interface\\Buttons\\WHITE8X8";
	local fc = ui.fontcolor;
	local iconSize = ICON_SIZE;

	w:SetHeaderShown(not hide);
	w:SetBadge((n > 0 and m.showBadge ~= false) and string.format(L["%d active"], n) or "");
	w:SetBackdropColor(Look.WINDOW_BG[1], Look.WINDOW_BG[2], Look.WINDOW_BG[3], m.opacity or Look.WINDOW_BG[4]);
	w.band:SetColorTexture(0.15, 0.12, 0.07, m.opacity or 0.96);

	for i, r in ipairs(w.rows) do
		local e = c.entries[i];

		if not e then
			r:Hide();
		else
			r:ClearAllPoints();
			r:SetPoint("TOPLEFT", w, "TOPLEFT", MARK_PADDING, -(head + ys[i]));
			r:SetSize(width - 2 * MARK_PADDING, hs[i]);
			r.glow:SetColorTexture(m.glowColor.r, m.glowColor.g, m.glowColor.b, m.glowAlpha or 0.12);

			local sc = SYMBOL_COLORS[e.index] or { 0.91, 0.76, 0.42 };

			r.stripe:SetColorTexture(sc[1], sc[2], sc[3], 1);

			local cast = m.showCast and e.cast;
			local hot = cast and cast.interruptible and m.highlightInterruptible and true or false;
			local ec = hot and EDGE_HOT or EDGE_COLOR;

			for _, edge in ipairs(r.edges) do edge:SetColorTexture(ec[1], ec[2], ec[3], 1); end

			-- ohne Zauber endet der Kartengrund unter dem Kopfteil
			r.body:SetHeight(hs[i]);

			local iconTop = PAD_Y + (LINE_H - ICON_SIZE) / 2;
			local lineY = PAD_Y + LINE_H / 2;
			local hpTop = PAD_Y + LINE_H + GAP_HP;

			local col, row = (e.index - 1) % 4, math.floor((e.index - 1) / 4);
			r.icon:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25);
			r.icon:ClearAllPoints();
			r.icon:SetPoint("TOPLEFT", r.textLayer, "TOPLEFT", 10, -iconTop);
			r.icon:SetSize(iconSize, iconSize);
			r.icon:SetShown(m.showIcon ~= false);
			r.pct:SetShown(m.showPct ~= false);

			local textFont = math.max(8, ui.fontsize - 2);

			Look.StyleText(r.pct, font, textFont);
			r.pct:SetTextColor(fc.r, fc.g, fc.b, 1);
			r.pct:SetWidth(40);
			r.pct:ClearAllPoints();
			r.pct:SetPoint("RIGHT", r.textLayer, "TOPRIGHT", -8, -lineY);

			Look.StyleText(r.name, font, textFont);
			r.name:SetTextColor(fc.r, fc.g, fc.b, 1);
			r.name:SetText(e.name);
			r.name:ClearAllPoints();
			r.name:SetPoint("LEFT", r.textLayer, "TOPLEFT", m.showIcon ~= false and (10 + iconSize + 6) or 10, -lineY);
			r.name:SetPoint("RIGHT", r.pct, "LEFT", -4, 0);
			r.name:SetHeight(textFont + 2);

			r.hp:SetStatusBarTexture(texture);
			r.hp:SetStatusBarColor(m.hpColor.r, m.hpColor.g, m.hpColor.b, 1);
			r.hp:SetMinMaxValues(0, 100);
			r.hp:ClearAllPoints();
			r.hp:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -hpTop);
			r.hp:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -hpTop);
			r.hp:SetHeight(HP_BAR_H);

			r.cast:SetStatusBarTexture(texture);
			r.cast:SetMinMaxValues(0, 1);
			r.cast:ClearAllPoints();
			r.cast:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 10, PAD_Y);
			r.cast:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -8, PAD_Y);
			r.cast:SetHeight(castH);

			local castFont = math.max(8, ui.fontsize - 3);

			Look.StyleText(r.castTime, font, castFont);
			r.castTime:SetWidth(36);
			r.castTime:ClearAllPoints();
			r.castTime:SetPoint("RIGHT", r.cast, "RIGHT", -5, 0);
			Look.StyleText(r.castName, font, castFont);
			r.castName:ClearAllPoints();
			r.castName:SetPoint("LEFT", r.cast, "LEFT", 5, 0);
			r.castName:SetPoint("RIGHT", r.castTime, "LEFT", -4, 0);
			r.castName:SetTextColor(0.97, 0.94, 0.86, 1);
			r.castTime:SetTextColor(0.97, 0.94, 0.86, 1);

			-- Zauberleiste nur, solange gezaubert wird
			r.cast:SetShown(cast and true or false);
			r.castName:SetShown(cast and m.showCastName ~= false and true or false);
			r.castTime:SetShown(cast and true or false);

			if cast then
				local cc = cast.interruptible and m.castColor or m.castColorLocked;

				r.cast:SetStatusBarColor(cc.r, cc.g, cc.b, 1);
				r.castName:SetText(cast.name);
			else
				r.castName:SetText("");
				r.castTime:SetText("");
			end

			r.glow:SetShown(cast and cast.interruptible and m.highlightInterruptible and true or false);
			r.targetBorder:SetShown(m.showTarget ~= false and i == 2);
			r:Show();
		end
	end

	local rowsH = n > 0 and (ys[n] + hs[n]) or 0;
	local H = head + rowsH + MARK_PADDING;
	w:SetSize(width, H);
	TickMarks(c);

	-- Klickbereiche: später genannte liegen oben
	local parts = {
		{ name = L["Window"], x = 0, y = 0, w = width, h = H, jump = "_pos" },
		{ name = L["Window opacity"], x = 0, y = 0, w = 5, h = H, jump = L["Window opacity"] },
		{ name = L["Width"], x = width - 6, y = 0, w = 6, h = H, jump = L["Width"] },
		{ name = L["Hide header"], x = 0, y = 0, w = width, h = head, jump = L["Hide header"] },
		{ name = L["Max rows of marks"], x = MARK_PADDING, y = head + rowsH, w = width - 2 * MARK_PADDING, h = MARK_PADDING, jump = L["Max rows of marks"] },
	};

	if not hide and n > 0 and m.showBadge ~= false then
		parts[#parts + 1] = { name = L["Show active counter"], x = width - 96, y = 3, w = 90, h = head - 6, jump = L["Show active counter"] };
	end

	for i = 1, n do
		local e = c.entries[i];
		local top = head + ys[i];
		local cardH = hs[i];
		local inner = width - 2 * MARK_PADDING;

		parts[#parts + 1] = { name = L["Row height"], x = MARK_PADDING, y = top, w = inner, h = cardH, jump = L["Row height"] };

		if i < n and gap > 0 then
			parts[#parts + 1] = { name = L["Row spacing"], x = MARK_PADDING, y = top + cardH, w = inner, h = gap, jump = L["Row spacing"] };
		end

		parts[#parts + 1] = { name = L["Health color"], x = MARK_PADDING + 10, y = top + PAD_Y + LINE_H + GAP_HP, w = inner - 18, h = HP_BAR_H, jump = L["Health color"] };
		parts[#parts + 1] = { name = L["Marks sort"], x = MARK_PADDING + 10 + iconSize + 6, y = top + PAD_Y, w = math.min(110, inner * 0.4), h = LINE_H, jump = L["Marks sort"] };

		if m.showPct ~= false then
			parts[#parts + 1] = { name = L["Show health percent"], x = width - MARK_PADDING - 8 - 40, y = top + PAD_Y, w = 40, h = LINE_H, jump = L["Show health percent"] };
		end

		if m.highlightInterruptible and m.showCast and e.cast and e.cast.interruptible then
			parts[#parts + 1] = { name = L["Highlight color"], x = MARK_PADDING, y = top, w = inner, h = 3, jump = L["Highlight color"] };
		end

		if m.showIcon ~= false then
			parts[#parts + 1] = { name = SymbolName(e.index), x = MARK_PADDING + 10, y = top + PAD_Y + (LINE_H - iconSize) / 2, w = iconSize, h = iconSize, jump = SymbolName(e.index) };
		end

		if m.showCast and e.cast then
			parts[#parts + 1] = { name = L["Cast bar height"], x = MARK_PADDING + 10, y = top + cardH - PAD_Y - castH, w = inner - 18, h = castH, jump = L["Cast bar height"] };

			if m.showCastName ~= false then
				parts[#parts + 1] = { name = L["Show cast name"], x = MARK_PADDING + 15, y = top + cardH - PAD_Y - castH, w = 80, h = castH, jump = L["Show cast name"] };
			end
		end

		if m.showTarget ~= false and i == 2 then
			parts[#parts + 1] = { name = L["Show target frame"], x = MARK_PADDING, y = top, w = 3, h = rowH, jump = L["Show target frame"] };
		end
	end

	return { w = width, h = H, parts = parts };
end
