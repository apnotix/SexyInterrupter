local SI = SexyInterrupter;

local LSM = LibStub("LibSharedMedia-3.0")

function SI:LockFrame()
    SI_Data.ui.lock = not SI_Data.ui.lock;

    if SI_Data.ui.lock then
        DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Frame locked.", 1, 0.5, 0);

        SexyInterrupterAnchor:SetMovable(false);
        SexyInterrupterAnchor:EnableMouse(false);
        SexyInterrupterAnchor:SetScript("OnMouseDown", nil);
        SexyInterrupterAnchor:SetScript("OnMouseUp", nil);
    else 
        DEFAULT_CHAT_FRAME:AddMessage("SexyInterrupter: Frame unlocked.", 1, 0.5, 0);

        SexyInterrupterAnchor:SetMovable(true);
        SexyInterrupterAnchor:EnableMouse(true);
        SexyInterrupterAnchor:SetScript("OnMouseDown", function() SexyInterrupterAnchor:StartMoving() end);
        SexyInterrupterAnchor:SetScript("OnMouseUp", SI.SaveAnchorPosition);
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
                        set = function() 
                            SI:LockFrame();
                        end
                    },
                    texture = {
                        type = "select",
                        name = "Statusbar",
                        dialogControl = 'LSM30_Statusbar',
                        values = LSM:HashTable("statusbar"),
                        order = 1.1,
                        width = "double",
                        get = function() return SI_Data.ui.texture end,
                        set = function(self, opt) SI_Data.ui.texture = opt end
                    },
                    barcolor = {
                        type = "color",
                        name = "Leistenfarbe",
                        hasAlpha = true,
                        order = 3,
                        width = "double",
                        get = function() return helperColourGet(SI_Data.ui.barcolor) end,
                        set = function(self, r, g, b, a) 
                            helperColourSet(SI_Data.ui.barcolor, r, g, b, a);
                        end
                    },
                    border = {
                        name = 'Rahmen',
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
                        order = 4,
                        get = function() return helperColourGet(SI_Data.ui.background) end,
                        set = function(self, r, g, b, a) 
                            helperColourSet(SI_Data.ui.background, r, g, b, a);
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
                        hasAlpha = false,
                        order = 5,
                        get = function() return helperColourGet(SI_Data.ui.fontcolor) end,
                        set = function(self, r, g, b) 
                            helperColourSet(SI_Data.ui.fontcolor, r, g, b);
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