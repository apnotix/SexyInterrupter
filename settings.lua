local SI = SexyInterrupter;

SI.panel = CreateFrame("Frame", "SexyInterrupterConfig");
SI.panel.name = 'SexyInterrupter';

local button = CreateFrame('Button', 'MyButtonName')
button:SetPoint('CENTER')
button:SetSize(16, 16)
button:SetParent(SI.panel);

InterfaceOptions_AddCategory(SI.panel);