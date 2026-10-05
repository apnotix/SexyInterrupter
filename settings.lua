local addonName, addon = ...
local SI = SexyInterrupter;
local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

local function GetSIAddOnMetadata(name, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, result = pcall(C_AddOns.GetAddOnMetadata, name, field)
		if ok then return result end
	end

	if GetAddOnMetadata then
		local ok, result = pcall(GetAddOnMetadata, name, field)
		if ok then return result end
	end

	return nil
end

SI.Version = GetSIAddOnMetadata("SexyInterrupter", "Version") or "3.0.43";

SI.outputchannels = {
    ['SAY'] = 'SAY',    
    ['YELL'] = 'YELL',
    ['PARTY'] = 'PARTY',
    ['RAID'] = 'RAID'
};

SI.interruptSpells = { 
    1766, 		-- Roque Kick
    2139, 		-- Mage Counterspell
    6552, 		-- Warrior Pummel
    15487, 		-- Priest Silence
    31935,		-- Paladin Avenger's Shield
    47528, 		-- DK Mind Freeze
    47476, 		-- DK Strangulate
    57994, 		-- Shaman Wind Shear
    8042,       -- Shaman Earth Shock (Classic/Forever, Rang 1-10)
    8044,
    8045,
    8046,
    10412,
    10413,
    10414,
    25454,
    49230,
    49231,
    78675, 		-- Druid Solar beam
    96231, 		-- Paladin Rebuke
    116705,  	-- Monk Spear Hand Strike
    106839,		-- Druid Skull Bash
    119910,		-- Warlock Spell Lock
    119911,		-- Warlock Optical Blast
    132409,		-- Warlock Spell Lock
    147362, 	-- Hunter Counter Shot
    171138,		-- Warlock Shadow Lock,
    183752,     -- DH Consume Magic
    115750,     -- Paladin Blinding Light
    351338,     -- Evoker Quell
    72,         -- Warrior Shield Bash (Classic/Forever, Rang 1-3)
    1671,
    1672,
    1767,       -- Rogue Kick Rang 2-4 (+ TBC Rang 5)
    1768,
    1769,
    38768,
    6554,       -- Warrior Pummel Rang 2
    19244,      -- Warlock Spell Lock (Felhunter, Rang 1-2)
    19647
};

-- Ränge desselben Zaubers -> eine gemeinsame Familie (eine Zeile pro Spieler).
SI.spellFamily = {};

for _, family in ipairs({
    { 8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454, 49230, 49231 },
    { 72, 1671, 1672 },
    { 1766, 1767, 1768, 1769, 38768 },
    { 6552, 6554 },
    { 19244, 19647 },
    { 119910, 132409 },
}) do
    for _, spellId in ipairs(family) do
        SI.spellFamily[spellId] = family[1];
    end
end

-- Fallback-Abklingzeit (Sekunden), falls GetSpellBaseCooldown für den Zauber
-- nichts liefert (Classic-Client ohne diese Daten).
SI.fallbackCooldowns = {};

for _, spellId in ipairs({ 8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454, 49230, 49231 }) do
    SI.fallbackCooldowns[spellId] = 6;
end

for _, spellId in ipairs({ 72, 1671, 1672 }) do
    SI.fallbackCooldowns[spellId] = 12;
end

for _, spellId in ipairs({ 1766, 1767, 1768, 1769, 38768, 6552, 6554 }) do
    SI.fallbackCooldowns[spellId] = 10;
end

for _, spellId in ipairs({ 19244, 19647 }) do
    SI.fallbackCooldowns[spellId] = 24;
end

-- Set keyed by spell ID for O(1) lookups in the (very frequent) cast events.
SI.interruptSpellSet = {};

for _, spellId in ipairs(SI.interruptSpells) do
    SI.interruptSpellSet[spellId] = true;
end

SI.unitCanInterrupt = {
    priest = {
        healer = false,
        damager = true
    },
    warrior = {
        damager = true,
        tank = true
    },
    shaman = {
        damager = true,
        healer = true
    },
    deathknight = {
        damager = true,
        tank = true
    },
    druid = {
        healer = false,
        damager = true,
        tank = true
    },
    monk = {
        healer = false,
        damager = true,
        tank = true
    },
    paladin = {
        tank = true,
        damager = true
    },
    rogue = {
        damager = true
    },
    mage = {
        damager = true
    },
    hunter = {
        damager = true
    },
    warlock = {
        damager = true
    },
    demonhunter = {
        damager = true,
        tank = true
    },
    evoker = {
        damager = true -- Quell: Devastation/Augmentation; Preservation has no interrupt
    }
};

local defaults = {
	profile = {
        versions = {},
        -- LibDBIcon stores the minimap button position in this table.
        icon = {},
		general = {
			modeincombat = false,
			activeSolo = true,
			ignoreHealer = false,
			fixedRotation = false,
			highlightOwn = true,
            maxrows = 5,
            minimapIcon = true
		},
		ui = {            
			-- Standardposition: links neben dem Blizzard-PlayerFrame (eigene
			-- rechte obere Ecke an dessen linke obere Ecke, kleiner Abstand).
			anchorPosition = {
				point = 'TOPRIGHT',
				region = 'PlayerFrame',
				relativePoint = 'TOPLEFT',
				x = -10,
				y = 0
			},
			-- Standardposition: oben mittig auf dem Bildschirm (wie Boss-Emotes/
			-- Raid-Warnungen), statt in der Bildschirmmitte.
			messagePosition = {
				point = 'TOP',
				relativePoint = 'TOP',
				x = 0,
				y = -150
			},
			-- Position/size storage owned entirely by the EditModeExpanded-1.0
			-- library (see ui.lua's CreateUi) once a frame is registered with
			-- it - anchorPosition/messagePosition above stop being written to
			-- after that point, kept only so an existing saved position isn't
			-- lost/reset for players upgrading from the pre-Edit-Mode version.
			editModeAnchorDB = {},
			editModeMessageDB = {},
			editModeMarksDB = {},
			font = '2002',
			fontsize = 13,
			fontcolor = {
				r = 1,
				g = 1, 
				b = 1,
				a = 1
            },
            useclasscolor = false,
			window = {
				background = {
					r = 0,
					g = 0,
					b = 0,
					a = 0.453
				},
                backgroundtexture = "Solid",
				border = 'Blizzard Tooltip',
				bordercolor = {
					r = 0,
					g = 0, 
					b = 0,
					a = 1
                },
                width = 200,
                -- false = wächst nach unten (obere Kante bleibt fix), true =
                -- wächst nach oben (untere Kante bleibt fix, so hat es sich
                -- bisher automatisch verhalten). "Nach unten" als Standard,
                -- da das eher der Erwartung entspricht (neue Zeilen kommen
                -- unten dazu, wie z. B. bei einer Buff-Liste).
                growUp = false
			},
			bars = {
                showclassicon = true,
                useclasscolor = true,
				barheight = 25,
				barcolor = {
					r = 0.451,
					g = 0.471,
					b = 0.435,
					a = 1
				},
				texture = 'Blizzard'
			}
		},
		marks = {
			enabled = true,
			combatOnly = false,
			showCast = true,
			highlightInterruptible = true,
			maxrows = 8,
			width = 260,
			sort = 'symbol',
			-- Raid-Symbol-Index (1 Stern .. 8 Totenkopf) -> anzeigen
			symbols = { true, true, true, true, true, true, true, true },
		},
		notification = {
            sound = true,
            soundFile = "Sound\\Spells\\PVPFlagTaken.ogg",
			flash = true,
			message = true,
			interruptmessage = true,
			outputchannel = 'SAY'
		}
	}
}

function SexyInterrupter:InitOptions() 
    self.db = LibStub('AceDB-3.0'):New(addonName.."DB", defaults, true);

    SI.optionsTable = {
        type = "group",
        name = L["Addon name"],
        args = {
            lock = {
                type = "execute",
                name = L["Open Edit Mode to reposition"],
                desc = L["Lock this bar to prevent resizing or moving"],
                order = 1,
                func = function()
                    SexyInterrupter:LockFrame();
                end
            },
            assignments = {
                name = L["Assignments"],
                type = "group",
                childGroups = "tab",
                hidden = function()
                    -- "priority" is currently the only child tab, so an empty
                    -- group here would hand AceGUI's TabGroup a zero-tab row
                    -- and crash it with a division by zero (see priority.hidden below)
                    return not IsInGroup();
                end,
                args = {
                    -- raids = {
                    --     name = L["Spell assignment"],
                    --     type = "group",
                    --     --childGroups = "tab",
                    --     args = {
                            
                    --     }
                    -- },
                    priority = {
                        name = L['Priority assignment'],
                        type = "group",
                        hidden = function() 
                            return not IsInGroup();
                        end,
                        args = {
                        
                        }
                    },
                    -- spell = {
                    --     name = L["Spell assignment"],
                    --     type = "group",
                    --     hidden = true,
                    --     args = {
                        
                    --     }        
                    -- },
                }
            },                 
            -- Everything else (general, look, notification incl. sound file and
            -- output channel) lives in the Edit Mode dialog - see
            -- SexyInterrupter:RegisterEditModeSettings in ui.lua.
        }
    }

    SI.optionsTable.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);

    function SexyInterrupter:SendOverridePrioInfos()
        -- Collapse ability-rows back down to unique players (see
        -- UpdateInterrupterSettings above for why).
        local seen = {};
        local msg = "overrideprio:";
        local hits = 0;

        for _, row in pairs(SexyInterrupter:GetCurrentInterrupters()) do
            local interrupter = row.interrupter;

            if not seen[interrupter] then
                seen[interrupter] = true;

                if interrupter.overrideprio then
                    hits = hits + 1;

                    msg = msg .. tostring(interrupter.name) .. '+' .. tostring(interrupter.realm) .. '+' .. tostring(interrupter.fullname) .. '+' .. tostring(interrupter.overrideprio) .. '+' .. tostring(interrupter.overridedprio) .. ';';
                end
            end
        end

        if hits > 0 then
            -- NOTE: SexyInterrupter:SendAddonMessage(...) doesn't exist anywhere
            -- in this codebase (a pre-existing bug); routed through the real
            -- comm channel instead. There's currently no handler for this
            -- 'overrideprio' prefix on the receiving end either (see the
            -- commented-out ReceiveOverridePrioInfos in communication.lua) -
            -- this just stops it from throwing, it doesn't finish the feature.
            SexyInterrupter:SendMessage('overrideprio', msg);
        end
    end

    function SexyInterrupter:UpdateInterrupterSettings()
        -- GetCurrentInterrupters() now returns one row per known ability, not
        -- per player (see utils.lua) - collapse back down to unique players
        -- for the priority-assignment tab, since priority is a per-player
        -- concept, not a per-ability one.
        local seen = {};
        local interrupters = {};

        for _, row in pairs(SexyInterrupter:GetCurrentInterrupters()) do
            if not seen[row.interrupter] then
                seen[row.interrupter] = true;
                tinsert(interrupters, row.interrupter);
            end
        end

        SI.optionsTable.args.assignments.args.priority.args = {};
        -- SI.optionsTable.args.assignments.args.spell.args = {};

        for i, interrupter in pairs(interrupters) do
            SI.optionsTable.args.assignments.args.priority.args['partymember_header' .. i] = {
                name = interrupter.name,
                type = "header",
                order = 100 * i,
                width = "full"
            }

            SI.optionsTable.args.assignments.args.priority.args['partymember_override_prio' .. i] = {
                name = L["Override priority"],
                type = "toggle",
                order = 101 * i,
                get = function() return interrupter.overrideprio end,
                set = function() 
                    interrupter.overrideprio = not interrupter.overrideprio; 
                    
                    if not interrupter.overrideprio then
                        interrupter.overridedprio = nil;
                    end

                    SexyInterrupter:SendOverridePrioInfos();
                end,
                disabled = function() return UnitName('player') ~= interrupter.name and not UnitIsGroupLeader("player") end
            }
            
            SI.optionsTable.args.assignments.args.priority.args['partymember_prio' .. i] = {
                name = L["Priority"],
                desc = L["Overwrite the predefined priority (1-3)"],
                type = "range",
                min = 1,
                max = 3,
                step = 1,
                order = 102 * i,
                get = function() return interrupter.overridedprio or interrupter.prio end,
                set = function(self, val)
                    interrupter.overridedprio = val;
                    
                    SexyInterrupter:SendOverridePrioInfos();
                end,
                disabled = function() return (UnitName('player') ~= interrupter.name and not UnitIsGroupLeader("player")) or not interrupter.overrideprio end
            }

            SI.optionsTable.args.assignments.args.priority.args['partymember_prio_cantoverride' .. i] = {
                name = '|cFFFF0000' .. L["Only the group leader can override the priority"],
                type = "description",
                order = 103 * i,
                hidden = function() return UnitName('player') == interrupter.name or UnitIsGroupLeader("player") end
            }

            -- SI.optionsTable.args.assignments.args.spell.args['partymember_header' .. i] = {
            --     name = interrupter.name,
            --     type = "header",
            --     order = 100 * i,
            --     width = "full"
            -- }

            -- SI.optionsTable.args.assignments.args.spell.args['partymember_spells_icon' .. i] = {
            --     name = "",
            --     type = "execute",
            --     width = "half",
            --     order = 102 * i,
            --     hidden = function() 
            --         return not interrupter.spells;
            --     end,
            --     image = function() 
            --         local _, _, icon = GetSpellInfo(interrupter.spells);
                    
            --         return icon and tostring(icon) or "", 18, 18;
            --     end,
            --     disabled = function() return UnitName('player') ~= interrupter.name and not UnitIsGroupLeader("player") end
            -- }

            -- SI.optionsTable.args.assignments.args.spell.args['partymember_spells' .. i] = {
            --     name = L["Spell"],
            --     desc = L["Spell assignment to the player"],
            --     type = "input",
            --     width = "double",
            --     order = 101 * i,
            --     get = function() 
            --         local name = GetSpellInfo(interrupter.spells);

            --         if name then
            --             return name;
            --         else
            --             return L["Invalid Spell Name/ID/Link"];
            --         end                
            --     end,
            --     set = function(self, val) interrupter.spells = val end,
            --     disabled = function() return UnitName('player') ~= interrupter.name and not UnitIsGroupLeader("player") end
            -- }
        end
        
	    LibStub("AceConfigRegistry-3.0"):NotifyChange("SexyInterrupter");
    end

    -- local instance_idx = 1;
    -- local instance_id = EJ_GetInstanceByIndex(instance_idx, true);

    -- while instance_id do
    --     EJ_SelectInstance(instance_id)
    --     local name = EJ_GetInstanceInfo();

    --     SI.optionsTable.args.assignments.args.raids.args['raid_' .. instance_id] = {
    --         name = name,
    --         type = "group",
    --         args = {

    --         }
    --     };

    --     local encounter_idx = 1;
    --     local encounterName, _, encounterId = EJ_GetEncounterInfoByIndex(encounter_idx);

    --     while encounterName do
    --         SI.optionsTable.args.assignments.args.raids.args['raid_' .. instance_id].args['encounter_' .. encounterId] = {
    --             name = encounterName,
    --             type = "group",
    --             args = {

    --             }
    --         };

    --         SI.optionsTable.args.assignments.args.raids.args['raid_' .. instance_id].args['encounter_' .. encounterId].args.assignment = {
    --             name = "Assignment",
    --             type = "input",
    --             width = "double"
    --         };

    --         encounter_idx = encounter_idx + 1;
    --         encounterName, _, encounterId = EJ_GetEncounterInfoByIndex(encounter_idx);
    --     end

    --     instance_idx = instance_idx + 1;
    --     instance_id = EJ_GetInstanceByIndex(instance_idx, true);            
    -- end

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyInterrupter", SI.optionsTable, true);
    SI.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SexyInterrupter", "SexyInterrupter");

    SLASH_SEXYINTERRUPTER1, SLASH_SEXYINTERRUPTER2 = '/si', '/sexyinterrupter';

    local function handler(msg, editbox)
        if msg == 'lock' then
            SexyInterrupter:LockFrame();
        elseif msg == 'version' then
            DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Version " .. SI.Version, 1, 0.5, 0);
        elseif msg == 'debug' then
            SexyInterrupter.debug = not SexyInterrupter.debug;
            DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Debug " .. (SexyInterrupter.debug and "an" or "aus"), 1, 0.5, 0);
        elseif msg == 'range' then
            -- Rohwerte der Reichweiten-APIs je Gruppenmitglied ausgeben.
            local function S(v)
                if issecretvalue and issecretvalue(v) then return "SECRET"; end
                return tostring(v);
            end

            DEFAULT_CHAT_FRAME:AddMessage("SI range (Kampf: " .. tostring(InCombatLockdown()) .. ")", 1, 0.5, 0);

            for i = 1, math.max(GetNumGroupMembers(), 1) do
                local unit = IsInRaid() and ("raid" .. i) or ("party" .. i);

                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                    local ir, cr = UnitInRange(unit);
                    local ds, dok;

                    if UnitDistanceSquared then ds, dok = UnitDistanceSquared(unit); end

                    DEFAULT_CHAT_FRAME:AddMessage(string.format(
                        "%s: visible=%s UnitInRange=%s/%s interact4=%s distSq=%s/%s",
                        UnitName(unit) or unit, S(UnitIsVisible(unit)), S(ir), S(cr),
                        CheckInteractDistance and S(CheckInteractDistance(unit, 4)) or "n/a",
                        S(ds), S(dok)), 0.6, 0.8, 1);
                end
            end
        elseif msg == 'marks' or msg == 'marks reset' then
            if SexyInterrupter.DebugMarks then
                SexyInterrupter:DebugMarks(msg == 'marks reset');
            else
                DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Gegner-Marker-Fenster ist deaktiviert.", 1, 0.5, 0);
            end
        elseif msg == 'kick' then
            SexyInterrupter:MarkOwnInterrupt();
        else
            LibStub("AceConfigDialog-3.0"):Open("SexyInterrupter");
        end
    end

    SlashCmdList["SEXYINTERRUPTER"] = handler;
end
