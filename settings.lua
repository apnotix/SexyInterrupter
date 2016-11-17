local SI = SexyInterrupter;

local LSM = LibStub("LibSharedMedia-3.0")

SI.optionsTable = {
  type = "group",
  args = {
    spellassignment = {
      name = "Zauberzuweisung",
      type = "group",
      args = {
        partymember1_group = {
            name = "Member 1",
            type = "group",
            args = {
                partymember1_name = {
                    name = "Name",
                    type = "input",
                    disabled = true,
                    width = "full"
                },
                partymember1_prio = {
                    name = "Priorität",
                    desc = "Überschreibt die vordefinierte Priorität (1-3)",
                    type = "input",
                    width = "full"
                }
            }
        },             
        partymember2_group = {
            name = "Member 2",
            type = "group",
            args = {
                partymember2_name = {
                    name = "Name",
                    type = "input",
                    disabled = true
                }
            }
        }, 
        partymember3_group = {
            name = "Member 3",
            type = "group",
            args = {    
                partymember3_name = {
                    name = "Name",
                    type = "input",
                    disabled = true
                }
            }
        }, 
        partymember4_group = {
            name = "Member 4",
            type = "group",
            args = {
                partymember4_name = {
                    name = "Name",
                    type = "input",
                    disabled = true
                }
            }
        }, 
        partymember5_group = {
            name = "Member 5",
            type = "group",
            args = {
                partymember5_name = {
                    name = "Name",
                    type = "input",
                    disabled = true
                }
            }
        }        
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
                order = 2
            },
            texture = {
                type = "select",
                name = "Statusbar",
                dialogControl = 'LSM30_Statusbar',
                values = LSM:HashTable("statusbar"),
                order = 1
            },
            background = {
                type = "color",
                name = "Hintergrund",
                hasAlpha = true,
                order = 1
            },
            font = {
                type = "select",
                name = "Font",
                dialogControl = 'LSM30_Font',
                values = LSM:HashTable("font"),
                order = 121,
                width = "full"
            },
            fontsize = {
                type = "range",
                name = "Font size",
                min = 4,
                max = 30,
                step = 1,
                bigStep = 1,
                order = 123,
                width = "full"
            },
            fontColor = {
                type = "color",
                name = "Font color",
                hasAlpha = true,
                order = 123
            }
        }
    }
  }
}

LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyInterrupter", SI.optionsTable, true);
SI.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SexyInterrupter", "SexyInterrupter");