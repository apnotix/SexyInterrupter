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

function SI:LockFrame()
    SI_Data.ui.lock = not SI_Data.ui.lock;

    if SI_Data.ui.lock then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s.", L["Addon name"], L["Frame locked"]), 1, 0.5, 0);

        SexyInterrupterAnchor:Show();
        SexyInterrupterDummyAnchorFrame:Hide();
        SexyInterrupterDummyMessageFrame:Hide();

        SI:UpdateFrames();
    else 
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s.", L["Addon name"], L["Frame unlocked"]), 1, 0.5, 0);

        SexyInterrupterAnchor:Hide();
        SexyInterrupterDummyAnchorFrame:Show();
        SexyInterrupterDummyMessageFrame:Show();
    end
end

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

function SI:InitOptions() 
    SI.optionsTable = {
        type = "group",
        name = L["Addon name"],
        args = {
            spellassignment = {
                name = L["Spell assignment"],
                type = "group",
                -- hidden = function()
                --     return not UnitIsGroupLeader("player");
                -- end,
                args = {
                   
                }        
            },
            lock = {
                type = "toggle",
                name = L["Lock window"],
                desc = L["Lock this bar to prevent resizing or moving"],
                order = 1,
                get = function() return SI_Data.ui.lock end,
                set = function() 
                    SI:LockFrame();
                end
            },
            ui = {
                name = L["Look"],
                type = "group",
                args = {
                    general = {
                        name = L["General"],
                        type = "group",
                        args = {
                            infightonly = {
                                type = "toggle",
                                name = L["Show in combat only"],
                                width = "full",
                                order = 1,
                                get = function() return SI_Data.general.modeincombat end,
                                set = function() 
                                    SI_Data.general.modeincombat = not SI_Data.general.modeincombat;

                                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s - %s", L["Addon name"], L["Show in combat only"], tostring(SI_Data.general.modeincombat)), 1, 0.5, 0);
                                end
                            },
                            headline_notification = {
                                type = "header",
                                name = L["Notification"],
                                order = 2
                            },
                            notication_sound = {
                                type = "toggle",
                                name = L["Play sound"],
                                order = 3,
                                get = function() return SI_Data.general.notification.sound end,
                                set = function() 
                                    SI_Data.general.notification.sound = not SI_Data.general.notification.sound;

                                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s - %s", L["Addon name"], L["Play sound"], tostring(SI_Data.general.notification.sound)), 1, 0.5, 0);
                                end
                            },
                            notication_flash = {
                                type = "toggle",
                                name = L["Flash display"],
                                order = 3,
                                get = function() return SI_Data.general.notification.flash end,
                                set = function() 
                                    SI_Data.general.notification.flash = not SI_Data.general.notification.flash;

                                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s - %s", L["Addon name"], L["Flash display"], tostring(SI_Data.general.notification.flash)), 1, 0.5, 0);
                                end
                            },
                            notication_message = {
                                type = "toggle",
                                name = L["Show message"],
                                order = 3,
                                get = function() return SI_Data.general.notification.message end,
                                set = function() 
                                    SI_Data.general.notification.message = not SI_Data.general.notification.message;

                                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s - %s", L["Addon name"], L["Show message"], tostring(SI_Data.general.notification.message)), 1, 0.5, 0);
                                end
                            },
                            headline_interrupt = {
                                type = "header",
                                name = L["Interrupts"],
                                order = 4
                            },
                            interrupt_chatmessage = {
                                type = "toggle",
                                name = L["Show chat message"],
                                order = 5,
                                get = function() return SI_Data.general.interruptmessage end,
                                set = function() 
                                    SI_Data.general.interruptmessage = not SI_Data.general.interruptmessage;

                                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s - %s", L["Addon name"], L["Show chat message"], tostring(SI_Data.general.interruptmessage)), 1, 0.5, 0);
                                end
                            },
                            interrupt_channel = {
                                type = "select",
                                name = L["Ouput channel"],
                                order = 5,
                                values = function () return SI.outputchannels end,
                                style = "dropdown",
                                get = function() return SI_Data.general.outputchannel end,
                                set = function(self, opt)
                                    SI_Data.general.outputchannel = opt;

                                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s - %s", L["Addon name"], L["Ouput channel"], SI.outputchannels[opt]), 1, 0.5, 0);
                                end,
                                disabled = function() return not SI_Data.general.interruptmessage end
                            }
                        }
                    },
                    bars = {
                        name = L["Bars"],
                        type = "group",
                        args = {
                            texture = {
                                type = "select",
                                name = L["Statusbar"],
                                dialogControl = 'LSM30_Statusbar',
                                values = LSM:HashTable("statusbar"),
                                order = 2.1,
                                get = function() return SI_Data.ui.texture end,
                                set = function(self, opt) SI_Data.ui.texture = opt end
                            },
                            barcolor = {
                                type = "color",
                                name = L["Bar color"],
                                hasAlpha = true,
                                order = 2.1,
                                get = function() return helperColourGet(SI_Data.ui.barcolor) end,
                                set = function(self, r, g, b, a) 
                                    helperColourSet(SI_Data.ui.barcolor, r, g, b, a);
                                end
                            },
                            headline_font = {
                                type = "header",
                                name = L["Font"],
                                order = 3
                            },                    
                            font = {
                                type = "select",
                                name = L["Font art"],
                                dialogControl = 'LSM30_Font',
                                values = LSM:HashTable("font"),
                                order = 3.1,
                                get = function() return SI_Data.ui.font end,
                                set = function(self, opt) SI_Data.ui.font = opt end
                            },
                            fontsize = {
                                type = "range",
                                name = L["Font size"],
                                min = 4,
                                max = 30,
                                step = 1,
                                bigStep = 1,
                                order = 3.1,
                                get = function() return SI_Data.ui.fontsize end,
                                set = function(self, val) SI_Data.ui.fontsize = val end
                            },
                            fontcolor = {
                                type = "color",
                                name = L["Font color"],
                                hasAlpha = false,
                                order = 3.2,
                                get = function() return helperColourGet(SI_Data.ui.fontcolor) end,
                                set = function(self, r, g, b) 
                                    helperColourSet(SI_Data.ui.fontcolor, r, g, b);
                                end
                            }
                        }
                    },
                    window = {
                        name = L["Window"],
                        type = "group",
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
                                width = "full",
                                get = function() return SI_Data.ui.backgroundtexture end,
                                set = function(self, key) 
                                    SI_Data.ui.backgroundtexture = key;
                                end
                            },
                            backgroundcolor = {
                                type = "color",
                                name = L["Background color"],
                                hasAlpha = true,
                                order = 2.3,
                                get = function() return helperColourGet(SI_Data.ui.background) end,
                                set = function(self, r, g, b, a) 
                                    helperColourSet(SI_Data.ui.background, r, g, b, a);
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
                                width = "full",
                                get = function() return SI_Data.ui.border end,
                                set = function(self, key) 
                                    SI_Data.ui.border = key;
                                end
                            },

                            bordercolor = {
                                type = "color",
                                name = L["Border color"],
                                hasAlpha = false,
                                order = 3.2,
                                get = function() return helperColourGet(SI_Data.ui.bordercolor) end,
                                set = function(self, r, g, b, a) 
                                    helperColourSet(SI_Data.ui.bordercolor, r, g, b, a);
                                end
                            },
                        }
                    }             
                }
            }
        }
    }

    function SI:SendOverridePrioInfos()
        local interrupters = SI:GetCurrentInterrupters();
        local msg = "overrideprio:";

        for i, interrupter in pairs(interrupters) do
            msg = msg .. interrupter.fullname .. '+' .. tostring(interrupter.overrideprio) .. '+' .. tostring(interrupter.overridedprio) .. ';';
        end

        SI:SendAddonMessage(msg);
    end

    function SI:UpdateInterrupterSettings() 
        local interrupters = SI:GetCurrentInterrupters();

        SI.optionsTable.args.spellassignment.args = {};

        for i, interrupter in pairs(interrupters) do
            SI.optionsTable.args.spellassignment.args['partymember_header' .. i] = {
                name = interrupter.name,
                type = "header",
                order = 100 * i,
                width = "full"
            }

            SI.optionsTable.args.spellassignment.args['partymember_override_prio' .. i] = {
                name = L["Override priority"],
                type = "toggle",
                order = 101 * i,
                get = function() return interrupter.overrideprio end,
                set = function() 
                    interrupter.overrideprio = not interrupter.overrideprio; 
                    
                    if not interrupter.overrideprio then
                        interrupter.overridedprio = nil;
                    end
                end
            }
            
            SI.optionsTable.args.spellassignment.args['partymember_prio' .. i] = {
                name = L["Priority"],
                desc = L["Overwrite the predefined priority (1-3)"],
                type = "range",
                min = 1,
                max = 3,
                step = 1,
                order = 102 * i,
                get = function() return interrupter.overridedprio or interrupter.prio end,
                set = function(self, val) interrupter.overridedprio = val end,
                disabled = function() return not interrupter.overrideprio end
            }

            -- SI.optionsTable.args.spellassignment.args['partymember_spells' .. i] = {
            --     name = L["Spell"],
            --     desc = L["Spell assignment to the player"],
            --     type = "input",
            --     width = "full",
            --     order = 103 * i,
            --     --get = function() return SI_Globals.interrupters[i].prio end,
            --     --set = function(self, val) SI_Globals.interrupters[i].prio = val end
            -- }
        end
        
	    LibStub("AceConfigRegistry-3.0"):NotifyChange("SexyInterrupter");
    end

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyInterrupter", SI.optionsTable, true);
    SI.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SexyInterrupter", "SexyInterrupter");

    SLASH_SEXYINTERRUPTER1, SLASH_SEXYINTERRUPTER2 = '/si', '/sexyinterrupter';

    local function handler(msg, editbox)
        if msg == 'lock' then
            SI:LockFrame();
        elseif msg == 'version' then
            DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Version " .. SI.Version, 1, 0.5, 0);
        else
            LibStub("AceConfigDialog-3.0"):Open("SexyInterrupter");
        end
    end

    SlashCmdList["SEXYINTERRUPTER"] = handler;
end