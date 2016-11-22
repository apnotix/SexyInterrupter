local SI = SexyInterrupter;

local LSM = LibStub("LibSharedMedia-3.0")

function SI:InitOptions() 
    SI.optionsTable = {
        type = "group",
        args = {
            spellassignment = {
                name = "Zauberzuweisung",
                type = "group",
                args = {
                    
                }        
            },
            ui = {
                name = "Aussehen",
                type = "group",
                args = {
                    lock = {
                        type = "toggle",
                        name = "Lock",
                        desc = "Lock this bar to prevent resizing or moving",
                        order = 1,
                        get = function() return SI_Data.ui.lock end,
                        set = function() SI_Data.ui.lock = not SI_Data.ui.lock end
                    },
                    texture = {
                        type = "select",
                        name = "Statusbar",
                        dialogControl = 'LSM30_Statusbar',
                        values = LSM:HashTable("statusbar"),
                        order = 1.1,
                        get = function() return SI_Data.ui.texture end,
                        set = function(self, opt) SI_Data.ui.texture = opt end
                    },
                    border = {
                        type = 'select',
				        dialogControl = 'LSM30_Border',
                        values = LSM:HashTable("border"),
                        order = 1.1,
                        get = function() return SI_Data.ui.border end,
                        set = function(self, key) 
                            SI_Data.ui.border = key;
                        end
                    },
                    backgroundtexture = {
                        type = "select",
                        name = "Hintergrund",
                        dialogControl = "LSM30_Background",
                        values = LSM:HashTable("background"),
                        order = 1.1,
                        get = function() return SI_Data.ui.backgroundtexture end,
                        set = function(self, key) 
                            SI_Data.ui.backgroundtexture = key;
                        end
                    },
                    backgroundcolor = {
                        type = "color",
                        name = "Hintergrundfarbe",
                        hasAlpha = true,
                        order = 1.1,
                        get = function() return SI_Data.ui.background end,
                        set = function(self, r, g, b, a) 
                            SI_Data.ui.background.r = r;
                            SI_Data.ui.background.g = g;
                            SI_Data.ui.background.b = b;
                            SI_Data.ui.background.a = a;
                        end
                    },
                    font = {
                        type = "select",
                        name = "Font",
                        dialogControl = 'LSM30_Font',
                        values = LSM:HashTable("font"),
                        order = 2.1,
                        width = "full",
                        get = function() return SI_Data.ui.font end,
                        set = function(self, opt) SI_Data.ui.font = opt end
                    },
                    fontsize = {
                        type = "range",
                        name = "Font size",
                        min = 4,
                        max = 30,
                        step = 1,
                        bigStep = 1,
                        order = 2.2,
                        width = "full",
                        get = function() return SI_Data.ui.fontsize end,
                        set = function(self, val) SI_Data.ui.fontsize = val end
                    },
                    fontcolor = {
                        type = "color",
                        name = "Font color",
                        hasAlpha = true,
                        order = 2.3,
                        get = function() return SI_Data.ui.fontcolor end,
                        set = function(self, r, g, b, a) 
                            SI_Data.ui.fontcolor.r = r;
                            SI_Data.ui.fontcolor.g = g;
                            SI_Data.ui.fontcolor.b = b;
                            SI_Data.ui.fontcolor.a = a;
                        end
                    }
                }
            }
        }
    }

    for i = 1,GetNumGroupMembers() do
        SI.optionsTable.args.spellassignment.args['partymember_header' .. i] = {
            name = "Spieler " .. i,
            type = "header",
            order = 100 * i,
            width = "full"
        }

        SI.optionsTable.args.spellassignment.args['partymember_name' .. i] = {
            name = "Name",
            type = "input",
            order = 101 * i,
            width = "full",
            disabled = true,
            get = function() return SI_Globals.interrupters[i].name end
        }
        
        SI.optionsTable.args.spellassignment.args['partymember_prio' .. i] = {
            name = "Priorität",
            desc = "Überschreibt die vordefinierte Priorität (1-3)",
            type = "range",
            min = 1,
            max = 3,
            step = 1,
            width = "full",
            order = 101 * i,
            get = function() return SI_Data.interrupters[SI_Globals.interrupters[i].name].prio end,
            set = function(self, val) SI_Data.interrupters[SI_Globals.interrupters[i].name].prio = val end
        }

        SI.optionsTable.args.spellassignment.args['partymember_spells' .. i] = {
            name = "Zauber",
            desc = "Gibt an welche Zauber von diesem Spieler gekickt werden sollen",
            type = "input",
            width = "full",
            order = 102 * i,
            --get = function() return SI_Globals.interrupters[i].prio end,
            --set = function(self, val) SI_Globals.interrupters[i].prio = val end
        }
    end

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyInterrupter", SI.optionsTable, true);
    SI.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SexyInterrupter", "SexyInterrupter");
end