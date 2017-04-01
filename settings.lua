local SI = SexyInterrupter;
local LSM = LibStub("LibSharedMedia-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SexyInterrupter", false);

SI.Version = GetAddOnMetadata("SexyInterrupter", "Version");

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
    78675, 		-- Druid Solar beam
    96231, 		-- Paladin Rebuke
    116705,  	-- Monk Spear Hand Strike
    106839,		-- Druid Skull Bash
    119910,		-- Warlock Spell Lock
    119911,		-- Warlock Optical Blast
    132409,		-- Warlock Spell Lock
    147362, 	-- Hunter Counter Shot
    171138,		-- Warlock Shadow Lock,
    183752      -- DH Consume Magic
};

-- SI.encounterIds= {
--   -- The Emerald Nightmare
--   [1703] = 1853, -- Nythendra
--   [1744] = 1876, -- Elerethe Renferal
--   [1738] = 1873, -- Il'gynoth, Heart of Corruption
--   [1667] = 1841, -- Ursoc
--   [1704] = 1854, -- Dragons of Nightmare
--   [1750] = 1877, -- Cenarius
--   [1726] = 1864, -- Xavius
--   -- The Nighthold
--   [1706] = 1849, -- Skorpyron,
--   [1725] = 1865, -- Chronomatic Anomaly
--   [1731] = 1867, -- Trilliax,
--   [1751] = 1871, -- Spellblade Aluriel
--   [1762] = 1862, -- Tichondrius
--   [1713] = 1842, -- Krosus
--   [1761] = 1886, -- High Botanist Tel'arn
--   [1732] = 1863, -- Star Augur Etraeus
--   [1743] = 1872, -- Grand Magistrix Elisande
--   [1737] = 1866, -- Gul'dan
--   -- Trial of Valor
--   [1819] = 1958, -- Odyn
--   [1830] = 1962, -- Guarm
--   [1829] = 2008, -- Helya
--   -- Tomb of Sargeras
--   [1862] = 2032, -- Goroth
--   [1867] = 2048, -- Demonic Inquisition
--   [1856] = 2048, -- Harjatan
--   [1861] = 2037, -- Mistress Sasszine
--   [1903] = 2050, -- Sisters of the Moon
--   [1896] = 2054, -- Desolate Host
--   [1897] = 2052, -- Maiden of Vigilance
--   [1873] = 2038, -- Fallen Avatar
--   [1898] = 2051, -- Kiljaeden
-- };

SI.encounterIDs = {
    {
        id = 822,
        name = "Broken Isles",
        encounter = {
            [1790] = "Ana-Mouz",
            [1774] = "Calamir",
            [1789] = "Drugon the Frostblood",
            [1795] = "Flotsam",
            [1770] = "Humongris",
            [1769] = "Levantus",
            [1783] = "Na'zak the Fiend",
            [1749] = "Nithogg",
            [1763] = "Shar'thos",
            [1756] = "The Soultakers",
            [1796] = "Withered J'im"
        }
    }, {
        id = 768,
        name = "The Emerald Nightmare",
        encounter = {
            [1703] = "Nythendra",
            [1744] = "Elerethe Renferal",
            [1738] = "Il'gynoth, Heart of Corruption",
            [1667] = "Ursoc",
            [1704] = "Dragons of Nightmare",
            [1750] = "Cenarius",
            [1726] = "Xavius"
        }
    }, {
        id = 786,
        name = "The Nighthold",
        encounter = {
            [1706] = "Skorpyron",
            [1725] = "Chronomatic Anomaly",
            [1731] = "Trilliax",
            [1751] = "Spellblade Aluriel",
            [1762] = "Tichondrius",
            [1713] = "Krosus",
            [1761] = "High Botanist Tel'arn",
            [1732] = "Star Augur Etraeus",
            [1743] = "Grand Magistrix Elisande",
            [1737] = "Gul'dan"
        }
    }, {
        id = 999,
        name = "Tomb of Sargeras",
        encounter = {
            [1862] = "Goroth",
            [1867] = "Demonic Inquisition",
            [1856] = "Harjatan",
            [1861] = "Mistress Sasszine",
            [1903] = "Sisters of the Moon",
            [1896] = "Desolate Host",
            [1897] = "Maiden of Vigilance",
            [1873] = "Fallen Avatar",
            [1898] = "Kiljaeden"
        }
    }
};

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
    }
};

local defaults = {
	profile = {
        versions = {},
		general = {
			modeincombat = false,
            lock = true,
            maxrows = 5		
		},
		ui = {            
			anchorPosition = {
				point = 'CENTER',
				region = nil,
				relativePoint = 'CENTER',
				x = 0,
				y = -300
			},
			messagePosition = {
				point = 'CENTER',
				region = UIParent,
				relativePoint = 'CENTER',
				x = 0,
				y = 80
			},
			font = 'Accidental Presidency',
			fontsize = 13,
			fontcolor = {
				r = 1,
				g = 1, 
				b = 1
			},
			window = {
				lock = true,
				background = {
					r = 0,
					g = 0,
					b = 0,
					a = 0.453
				},
                backgroundtexture = "Solid",
				border = 'NONE',
				bordercolor = {
					r = 0,
					g = 0, 
					b = 0
				},
			},
			bars = {
                showclassicon = true,
				barheight = 25,
				barcolor = {
					r = 0.451,
					g = 0.471,
					b = 0.435,
					a = 1
				},
				texture = 'BantoBar'
			}
		},
		notification = {
			sound = true,
			flash = true,
			message = true,
			interruptmessage = false,
			outputchannel = 'SAY'
		}
	}
}

local function helperColourGet( v )	
	assert( v, "bad code: missing parameter" )
	assert( type( v ) == "table", "bad code: parameter is not a table" )
	
	local f = "%.3f"
	
	local r = tonumber( string.format( f, v.r or 1 ) )
	local g = tonumber( string.format( f, v.g or 1 ) )
	local b = tonumber( string.format( f, v.b or 1 ) )
	local a = tonumber( string.format( f, v.a or 1 ) )
	
	return r, g, b, a
	
end

local function helperColourSet( v, r, g, b, a )	
	assert( v, "bad code: missing parameter" )
	assert( type( v ) == "table", "bad code: parameter is not a table" )
	
	local f = "%.3f"
	
	v.r = tonumber( string.format( f, r or 1 ) )
	v.g = tonumber( string.format( f, g or 1 ) )
	v.b = tonumber( string.format( f, b or 1 ) )
	if a then
		v.a = tonumber( string.format( f, a or 1 ) )
	end
	
end

function SexyInterrupter:InitOptions() 
    self.db = LibStub("AceDB-3.0"):New("SexyInterrupterDB", defaults, true)

    SI.optionsTable = {
        type = "group",
        name = L["Addon name"],
        args = {
            lock = {
                type = "toggle",
                name = L["Lock window"],
                desc = L["Lock this bar to prevent resizing or moving"],
                order = 1,
                get = function() return self.db.profile.general.lock end,
                set = function() 
                    SexyInterrupter:LockFrame();
                end
            },
            assignments = {
                name = L["Assignments"],
                type = "group",
	            childGroups = "tab",
                
                args = {
                    raids = {
                        name = L["Spell assignment"],
                        type = "group",
                        --childGroups = "tab",
                        args = {
                            
                        }
                    },
                    priority = {
                        name = L['Priority assignment'],
                        type = "group",
                        hidden = function() 
                            return not IsInGroup();
                        end,
                        args = {
                        
                        }
                    },
                    spell = {
                        name = L["Spell assignment"],
                        type = "group",
                        hidden = true,
                        args = {
                        
                        }        
                    },
                }
            },                 
            general = {
                name = L["General"],
                type = "group",
                get = function(info) return self.db.profile.general[info[#info]] end,
                set = function(info, value) self.db.profile.general[info[#info]] = value end,
                args = {
                    modeincombat = {
                        type = "toggle",
                        name = L["Show in combat only"],
                        width = "full",
                        order = 1
                    },
                    maxrows = {
                        step = 1,
                        type = "range",
                        name = L["Max rows of interrupters"],
                        width = "full",
                        order = 2,
                        min = 3,
                        max = 30
                    }
                }
            },
            notification = {
                type = "group",
                name = L["Notification"],
                get = function(info) return self.db.profile.notification[info[#info]] end,
                set = function(info, value) self.db.profile.notification[info[#info]] = value end,
                args = {
                    headline_notification = {
                        type = "header",
                        name = L["Notification"],
                        order = 2
                    },
                    sound = {
                        type = "toggle",
                        name = L["Play sound"],
                        order = 3
                    },
                    flash = {
                        type = "toggle",
                        name = L["Flash display"],
                        order = 3
                    },
                    message = {
                        type = "toggle",
                        name = L["Show message"],
                        order = 3
                    },
                    headline_interrupt = {
                        type = "header",
                        name = L["Interrupts"],
                        order = 4
                    },
                    interruptmessage = {
                        type = "toggle",
                        name = L["Show chat message"],
                        order = 5
                    },
                    outputchannel = {
                        type = "select",
                        name = L["Ouput channel"],
                        order = 5,
                        values = function () return SI.outputchannels end,
                        style = "dropdown",
                        disabled = function() return not self.db.profile.notification.interruptmessage end
                    }
                }
            },
            ui = {
                name = L["Look"],
                type = "group",
	            childGroups = "tab",
                get = function(info) return self.db.profile.ui[info[#info]] end,
                set = function(info, value) self.db.profile.ui[info[#info]] = value end,
                args = {                    
                    headline_font = {
                        type = "header",
                        name = L["Font"],
                        order = 4
                    },              
                    font = {
                        type = "select",
                        name = L["Font art"],
                        dialogControl = 'LSM30_Font',
                        values = LSM:HashTable("font"),
                        order = 5
                    },
                    fontsize = {
                        type = "range",
                        name = L["Font size"],
                        min = 4,
                        max = 30,
                        step = 1,
                        bigStep = 1,
                        order = 5
                    },
                    fontcolor = {
                        type = "color",
                        name = L["Font color"],
                        hasAlpha = false,
                        order = 6,
                        get = function() return helperColourGet(self.db.profile.ui.fontcolor) end,
                        set = function(self, r, g, b) 
                            helperColourSet(SexyInterrupter.db.profile.ui.fontcolor, r, g, b);
                            SexyInterrupter:UpdateFrames();
                        end
                    },
                    bars = {
                        name = L["Bars"],
                        type = "group",
                        get = function(info) return self.db.profile.ui.bars[info[#info]] end,
                        set = function(info, value) self.db.profile.ui.bars[info[#info]] = value end,
                        args = {
                            showclassicon = {
                                type = "toggle",
                                name = L["Show class icon"],
                                order = 1
                            },
                            texture = {
                                type = "select",
                                name = L["Statusbar"],
                                dialogControl = 'LSM30_Statusbar',
                                values = LSM:HashTable("statusbar"),
                                order = 2.1
                            },
                            barcolor = {
                                type = "color",
                                name = L["Bar color"],
                                hasAlpha = true,
                                order = 2.1,
                                get = function() return helperColourGet(self.db.profile.ui.bars.barcolor) end,
                                set = function(self, r, g, b, a) 
                                    helperColourSet(SexyInterrupter.db.profile.ui.bars.barcolor, r, g, b, a);
                                    SexyInterrupter:UpdateFrames();
                                end
                            }
                        }
                    },
                    window = {
                        name = L["Window"],
                        type = "group",
                        get = function(info) return self.db.profile.ui.window[info[#info]] end,
                        set = function(info, value) self.db.profile.ui.window[info[#info]] = value; SexyInterrupter:UpdateFrames(); end,
                        args = {
                            headline_frame = {
                                type = "header",
                                name = "Frame",
                                order = 2
                            },
                            backgroundtexture = {
                                type = "select",
                                name = L["Background"],
                                dialogControl = "LSM30_Background",
                                values = LSM:HashTable("background"),
                                order = 2.2,
                                width = "full"
                            },
                            backgroundcolor = {
                                type = "color",
                                name = L["Background color"],
                                hasAlpha = true,
                                order = 2.3,
                                get = function() return helperColourGet(self.db.profile.ui.window.background) end,
                                set = function(self, r, g, b, a) 
                                    helperColourSet(SexyInterrupter.db.profile.ui.window.background, r, g, b, a);
                                    SexyInterrupter:UpdateFrames();
                                end
                            },
                            headline_border = {
                                type = "header",
                                name = L["Border"],
                                order = 3
                            },
                            border = {
                                name = L["Border"],
                                type = "select",
                                dialogControl = 'LSM30_Border',
                                values = LSM:HashTable("border"),
                                order = 3.1,
                                width = "full"
                            },
                            bordercolor = {
                                type = "color",
                                name = L["Border color"],
                                hasAlpha = false,
                                order = 3.2,
                                get = function() return helperColourGet(self.db.profile.ui.window.bordercolor) end,
                                set = function(self, r, g, b, a) 
                                    helperColourSet(SexyInterrupter.db.profile.ui.window.bordercolor, r, g, b, a);
                                    SexyInterrupter:UpdateFrames();
                                end
                            },
                        }
                    }   
                }
            }
        }
    }

    SI.optionsTable.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);

    function SexyInterrupter:SendOverridePrioInfos()
        local interrupters = SexyInterrupter:GetCurrentInterrupters();
        local msg = "overrideprio:";

        for i, interrupter in pairs(interrupters) do
            msg = msg .. tostring(interrupter.name) .. '+' .. tostring(interrupter.realm) .. '+' .. tostring(interrupter.fullname) .. '+' .. tostring(interrupter.overrideprio) .. '+' .. tostring(interrupter.overridedprio) .. ';';
        end

        SexyInterrupter:SendAddonMessage(msg);
    end

    function SexyInterrupter:UpdateInterrupterSettings() 
        local interrupters = SexyInterrupter:GetCurrentInterrupters();

        SI.optionsTable.args.assignments.args.priority.args = {};
        SI.optionsTable.args.assignments.args.spell.args = {};

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

            SI.optionsTable.args.assignments.args.spell.args['partymember_header' .. i] = {
                name = interrupter.name,
                type = "header",
                order = 100 * i,
                width = "full"
            }

            SI.optionsTable.args.assignments.args.spell.args['partymember_spells_icon' .. i] = {
                name = "",
                type = "execute",
                width = "half",
                order = 102 * i,
                hidden = function() 
                    return not interrupter.spells;
                end,
                image = function() 
                    local _, _, icon = GetSpellInfo(interrupter.spells);
                    
                    return icon and tostring(icon) or "", 18, 18;
                end,
                disabled = function() return UnitName('player') ~= interrupter.name and not UnitIsGroupLeader("player") end
            }

            SI.optionsTable.args.assignments.args.spell.args['partymember_spells' .. i] = {
                name = L["Spell"],
                desc = L["Spell assignment to the player"],
                type = "input",
                width = "double",
                order = 101 * i,
                get = function() 
                    local name = GetSpellInfo(interrupter.spells);

                    if name then
                        return name;
                    else
                        return L["Invalid Spell Name/ID/Link"];
                    end                
                end,
                set = function(self, val) interrupter.spells = val end,
                disabled = function() return UnitName('player') ~= interrupter.name and not UnitIsGroupLeader("player") end
            }
        end

        

        -- for i, raid in pairs(SI.encounterIDs) do
        --     SI.optionsTable.args.assignments.args.raids.args['raid_' .. raid.id] = {
        --         name = raid.name,
        --         type = "group",
        --         args = {

        --         }
        --     };

        --     for encounterId in raid.encounter do
        --         local encounterName = raid.encounter[encounterId];

        --         SI.optionsTable.args.assignments.args.raids.args['raid_' .. raid.id].args['encounter_' .. encounterId] = {
        --             name = encounterName,
        --             type = "group",
        --             args = {

        --             }
        --         };

        --         SI.optionsTable.args.assignments.args.raids.args['raid_' .. raid.id].args['encounter_' .. encounterId].args.assignment = {
        --             name = "Assignment",
        --             type = "input",
        --             width = "double"
        --         }
        --     end            
        -- end

        -- local instanceID = EJ_GetCurrentInstance();

        -- for i=1, 25 do
        --     local name, _, encounterID = EJ_GetEncounterInfoByIndex(i, instanceID)

        --     if name then
        --         SI.optionsTable.args.instancebosses.args['boss_' .. encounterID] = {
        --             name = name,
        --             type = "group",
        --             args = {
        --                 bossname = {
        --                     name = "ID",
        --                     type = "input",
        --                     get = function() 
        --                         return tostring(encounterID);
        --                     end, 
        --                     disabled = true
        --                 }
        --             }
        --         };
        --     end
        -- end
        
	    LibStub("AceConfigRegistry-3.0"):NotifyChange("SexyInterrupter");
    end

    local instance_idx = 1;
    local instance_id = EJ_GetInstanceByIndex(instance_idx, true);

    while instance_id do
        EJ_SelectInstance(instance_id)
        local name = EJ_GetInstanceInfo();

        SI.optionsTable.args.assignments.args.raids.args['raid_' .. instance_id] = {
            name = name,
            type = "group",
            args = {

            }
        };

        local encounter_idx = 1;
        local encounterName, _, encounterId = EJ_GetEncounterInfoByIndex(encounter_idx);

        while encounterName do
            SI.optionsTable.args.assignments.args.raids.args['raid_' .. instance_id].args['encounter_' .. encounterId] = {
                name = encounterName,
                type = "group",
                args = {

                }
            };

            SI.optionsTable.args.assignments.args.raids.args['raid_' .. instance_id].args['encounter_' .. encounterId].args.assignment = {
                name = "Assignment",
                type = "input",
                width = "double"
            };

            encounter_idx = encounter_idx + 1;
            encounterName, _, encounterId = EJ_GetEncounterInfoByIndex(encounter_idx);
        end

        instance_idx = instance_idx + 1;
        instance_id = EJ_GetInstanceByIndex(instance_idx, true);            
    end

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyInterrupter", SI.optionsTable, true);
    SI.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SexyInterrupter", "SexyInterrupter");

    SLASH_SEXYINTERRUPTER1, SLASH_SEXYINTERRUPTER2 = '/si', '/sexyinterrupter';

    local function handler(msg, editbox)
        if msg == 'lock' then
            SexyInterrupter:LockFrame();
        elseif msg == 'version' then
            DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Version " .. SI.Version, 1, 0.5, 0);
        else
            LibStub("AceConfigDialog-3.0"):Open("SexyInterrupter");
        end
    end

    SlashCmdList["SEXYINTERRUPTER"] = handler;
end
