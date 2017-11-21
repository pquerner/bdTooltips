local addonName, core = ...

local defaults = {}

defaults[#defaults+1] = {enablett = {
	type = "checkbox",
	value = true,
	label = "Eanble Main Tooltips"
}}
defaults[#defaults+1] = {mott = {
	type = "checkbox",
	value = true,
	label = "Eanble mini name hover tooltips",
	callback = function() configCallback() end
}}

bdCore:addModule("Tooltips", defaults)
local config = bdCore.config.profile['Tooltips']

local configCallback = function()
	if config.mott then
		core.motooltip:Show()
	end
end

local bordersize = bdCore.config.persistent.General.bordersize

local tooltip = CreateFrame('frame',nil)
tooltip:SetFrameStrata("TOOLTIP")
tooltip.text = tooltip:CreateFontString(nil, "OVERLAY")
tooltip.text:SetFont(bdCore.media.font, 11, "THINOUTLINE")

local colors = {}
colors.tapped = {.6,.6,.6}
colors.offline = {.6,.6,.6}
colors.reaction = {}
colors.class = {}

for eclass, color in next, RAID_CLASS_COLORS do
	if not colors.class[eclass] then
		colors.class[eclass] = {color.r, color.g, color.b}
	end
end
for eclass, color in next, FACTION_BAR_COLORS do
	if not colors.reaction[eclass] then
		colors.reaction[eclass] = {color.r, color.g, color.b}
	end
end

local function GetUnitReactionIndex(unit)
	if UnitIsDeadOrGhost(unit) then
		return 7
	elseif UnitIsPlayer(unit) or UnitPlayerControlled(unit) then
		if UnitCanAttack(unit, "player") then
			return UnitCanAttack("player", unit) and 2 or 3
		elseif UnitCanAttack("player", unit) then
			return 4
		elseif UnitIsPVP(unit) and not UnitIsPVPSanctuary(unit) and not UnitIsPVPSanctuary("player") then
			return 5
		else
			return 6
		end
	elseif UnitIsTapDenied(unit) then
		return 1
	else
		local reaction = UnitReaction(unit, "player") or 3
		return (reaction > 5 and 5) or (reaction < 2 and 2) or reaction
	end
end

local function getcolor()
	local reaction = UnitReaction("mouseover", "player") or 5
	
	if UnitIsPlayer("mouseover") then
		local _, class = UnitClass("mouseover")
		local color = RAID_CLASS_COLORS[class]
		return color.r, color.g, color.b
	elseif UnitCanAttack("player", "mouseover") then
		if UnitIsDead("mouseover") then
			return 136/255, 136/255, 136/255
		else
			if reaction<4 then
				return 1, 68/255, 68/255
			elseif reaction==4 then
				return 1, 1, 68/255
			end
		end
	else
		if reaction<4 then
			return 48/255, 113/255, 191/255
		else
			return 1, 1, 1
		end
	end
end

local tooltips = {
	'GameTooltip',
	'ItemRefTooltip',
	'ItemRefShoppingTooltip1',
	'ItemRefShoppingTooltip2',
	'ShoppingTooltip1',
	'ShoppingTooltip2',
	'DropDownList1MenuBackdrop',
	'DropDownList2MenuBackdrop',
	'WorldMapTooltip',
	'WorldMapCompareTooltip1',
	'WorldMapCompareTooltip2',
}

------------------------------------------------------------------------
--	Faster access to fontstrings

for i = 1, #tooltips do
	local frame = _G[tooltips[i]]
	bdCore:StripTextures(frame)
	bdCore:setBackdrop(frame)
	frame:SetScale(1)
end

local function RGBToHex(r, g, b)
	if type(r) ~= 'number' then
		g = r.g
		b = r.b
		r = r.r
	end
	
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format('%02x%02x%02x', r*255, g*255, b*255)
end

local function RGBPercToHex(r, g, b)
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

local function unitColor(unit)
	if (not UnitExists(unit)) then
		return unpack(colors.tapped)
	end
	if UnitIsPlayer(unit) then
		return unpack(colors.class[select(2, UnitClass(unit))])
	elseif UnitIsTapDenied(unit) then
		return unpack(colors.tapped)
	else
		return unpack(colors.reaction[UnitReaction(unit, 'player')])
	end
end

--[[
local function setFirstLine(self)
	local name, unit = self:GetUnit()
	if not unit then return end
	
	local targetstr = "";
	local namestr = "";
	if (UnitExists(unit.."target")) then
		local target = GetUnitName(unit.."target")
		local cname, cclass = UnitClass(unit.."target")
		local targetcolor = RAID_CLASS_COLORS[cclass]
		local hex = RGBPercToHex(targetcolor.r, targetcolor.g, targetcolor.b)
		targetstr = "@|cff"..hex..target.."|r"
	end
	
	local name = GetUnitName(unit, true)
	local cname, cclass = UnitClass(unit)
	local color = RAID_CLASS_COLORS[cclass]
	local hex = RGBPercToHex(color.r, color.g, color.b)
	namestr = "|cff"..hex..name.."|r"
	
	GameTooltipTextLeft1:SetTextColor(1,1,1)
	GameTooltipTextLeft1:SetFormattedText('%s %s', namestr,targetstr)
end--]]

local function whosTargeting(self)
	local name, unit = self:GetUnit()
	if not unit then return end
	
	local targeting = {}
	local num = 0
	
	if IsInRaid() then
		for i = 1, 40 do
			local raider = "raid"..i
			if not UnitExists(raider) then break end
			local name = GetUnitName(raider,false)
			
			if (UnitIsUnit(raider.."target", unit)) then
				num = num + 1
				targeting[name] = name
			end
		end
		
		local str = "";
		for k, v in pairs(targeting) do
			str = str..k", "
		end
		
		GameTooltip:AddLine("Targ: "..str);
	end
end

local hide = {}
hide["Horde"] = true
hide["Alliance"] = true
hide["PvE"] = true
hide["PvP"] = true

function setUnit(self)
	if (self:IsForbidden()) then return end
	local name, unit = self:GetUnit()
	if not unit then return end
	local lines = self:NumLines()
	

	local line = 1;
	name = GetUnitName(unit)
	local guild, rank = GetGuildInfo(unit)
	local race = UnitRace(unit) or ""
	local level = UnitLevel(unit)
	local classification = UnitClassification(unit)
	local creatureType = UnitCreatureType(unit)
	local factionGroup = select(1, UnitFactionGroup(unit))
	local isFriend = UnitIsFriend("player", unit)
	local levelColor = GetQuestDifficultyColor(level)
	local friendColor = {r = 1, g = 1, b = 1}
	
	if (factionGroup == 'Horde' or not isFriend) then
		friendColor = {
			r = 1, 
			g = 0.15,
			b = 0
		}
	else
		friendColor = {
			r = 0, 
			g = 0.55, 
			b = 1
		}
	end
	

	if UnitIsPlayer(unit) then
		GameTooltip:ClearLines();
		local r, g, b = GameTooltip_UnitColor(unit)
		GameTooltip:AddLine(UnitName(unit), r, g, b)
		if (guild) then GameTooltip:AddLine(guild,1,1,1) end
		GameTooltip:AddLine("|cff"..RGBToHex(levelColor)..level.."|r |cff"..RGBToHex(friendColor)..race.."|r")
		local r, g, b = GameTooltip_UnitColor(unit..'target')
		GameTooltip:AddLine(UnitName(unit..'target'), r, g, b)
	else
		for i = 2, lines do
			local line = _G['GameTooltipTextLeft'..i]
			if not line or not line:GetText() then break end
			if (level and line:GetText():find('^'..LEVEL) or (creatureType and line:GetText():find('^'..creatureType))) then
				line:SetFormattedText('|cff%s%s%s|r |cff%s%s|r', RGBToHex(levelColor), level, classification, RGBToHex(friendColor), creatureType or 'Unknown')
			end
			
		end
	end
	
	--whosTargeting(self)
	--]]
	--[[GameTooltipTextLeft1:SetText(name)
	local name, class = UnitClass(name) or UnitClass("mouseover")
	local color = RAID_CLASS_COLORS[class]--]]
	--local targetclassFileName = select(2, UnitClass("mouseover"))
	--color = RAID_CLASS_COLORS[targetclassFileName]
	--[[if (color) then
		GameTooltipTextLeft1:SetTextColor(color.r, color.g, color.b)
	end--]]
	
	if level == -1 then
		level = '??'
		levelColor = {r = 1,g = 0,b = 0}
	end
	
	local linetext = _G['GameTooltipTextLeft'..line]
	
	--left[line]:SetFormattedText("%s%s|r %s%s|r %s%s|r", lhex, level, "|cffddeeaa", race, classHexColors[enClass], class)
	
	--[[if UnitIsPlayer(unit) then		
		if guild then
			GameTooltipTextLeft2:SetFormattedText('<%s>', guild)
			GameTooltipTextLeft3:SetFormattedText('|cff%s%s|r |cff%s%s|r', RGBToHex(levelColor), level, RGBToHex(friendColor), race)
		else
			GameTooltip:AddLine("",1,1,1)
			GameTooltipTextLeft2:SetFormattedText('|cff%s%s|r |cff%s%s|r', RGBToHex(levelColor), level, RGBToHex(friendColor), race)
		end
		
		local r, g, b = GameTooltip_UnitColor(unit..'target')
		GameTooltip:AddLine(UnitName(unit..'target'), r, g, b)

	else
		for i = 2, lines do
			local line = _G['GameTooltipTextLeft'..i]
			if not line or not line:GetText() then break end
			if (level and line:GetText():find('^'..LEVEL) or (creatureType and line:GetText():find('^'..creatureType))) then
				line:SetFormattedText('|cff%s%s%s|r |cff%s%s|r', RGBToHex(levelColor), level, classification, RGBToHex(friendColor), creatureType or 'Unknown')
			end
			
		end
	end--]]
	
	-- Update hp values on the bar
	local hp = UnitHealth(unit)
	local max = UnitHealthMax(unit)
	GameTooltipStatusBar:SetMinMaxValues(0, max)
	GameTooltipStatusBar:SetValue(hp)
	
	-- Set Fonts
	for i = 1, 20 do
		local line = _G['GameTooltipTextLeft'..i]
		if not line then break end
		line:SetFont(bdCore.media.font, 14)
	end
end

GameTooltip:HookScript('OnTooltipSetUnit', setUnit)
function GameTooltip_UnitColor(unitToken) return unitColor(unitToken) end
--GameTooltip:SetScript('OnUpdate', setFirstLine)

--[[
GameTooltip:HookScript('OnTooltipSetUnit', function(self)
	-- if they are dead
	if strmatch(left[1]:GetText(), CORPSE_TOOLTIP) then
		return left[1]:SetTextColor(0.5, 0.5, 0.5)
	end
	
	-- fuckery to get the right unit
	local name, unit = self:GetUnit()
	if not unit then
		local mouseFocus = GetMouseFocus()
		unit = mouseFocus and mouseFocus:GetAttribute("unit")
	end
	if not unit and UnitExists("mouseover") then
		unit = "mouseover"
	end
	if not unit then
		return self:Hide()
	end
	if unit ~= "mouseover" and UnitIsUnit(unit, "mouseover") then
		unit = "mouseover"
	end
	self.currentUnit = unit
	
	local canAttack = UnitCanAttack(unit, "player") or UnitCanAttack("player", unit)
	local level = UnitIsBattlePet(unit) and UnitBattlePetLevel(unit) or UnitLevel(unit)
	--local lhex = canAttack and GetDifficultyLevelColor(level ~= -1 and level or 500) or "|cffffcc00"
	level = level > 0 and level or "??"
	--local reaction = GetUnitReactionIndex(unit)
	local isPlayer = UnitIsPlayer(unit)
	
	if UnitIsPlayer(unit) then
		local class = select(2,UnitClass(unit))
		if (class) then
			local color = RAID_CLASS_COLORS[class]
			GameTooltipTextLeft1:SetTextColor(color.r,color.g,color.b)
		end
		GameTooltipTextLeft1:SetText(name)
		
		-- Guild
	else
	
	end
	
	
	--print(color)
end)--]]

GameTooltipStatusBar:SetStatusBarTexture(bdCore.media.flat)
GameTooltipStatusBar:SetStatusBarColor(.3, .54, .3)
GameTooltipStatusBar:SetAlpha(0.6)
GameTooltipStatusBar:ClearAllPoints()
GameTooltipStatusBar:SetPoint('BOTTOMRIGHT', GameTooltip, 'BOTTOMRIGHT', -2, 2)
GameTooltipStatusBar:SetPoint('TOPLEFT', GameTooltip, 'BOTTOMLEFT', 2, 6)

--[[
function defaultPosition(self, parent)
	self:SetOwner(parent, "ANCHOR_CURSOR")
	self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -111111, -111111) -- hack to update GameStatusBar instantly.
	self:ClearAllPoints()
end--]]
--hooksecurefunc('GameTooltip_SetDefaultAnchor', defaultPosition)

-- _G["GameTooltip"]:HookScript("OnUpdate", function(self) 
	-- self:ClearAllPoints()
	-- local x, y = GetCursorPosition();
	-- self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x / UIParent:GetEffectiveScale())+80+(self:GetWidth()/2), (y / UIParent:GetEffectiveScale()))
-- end)

--	Modify default position
local tooltipanchor = CreateFrame("frame","bdTooltip",UIParent)
tooltipanchor:SetSize(250, 200)
tooltipanchor:SetPoint("TOPRIGHT", UIParent, "RIGHT", -20, -100)
bdCore:makeMovable(tooltipanchor)

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(self, parent)
	self:SetOwner(parent, "ANCHOR_NONE")
	self:ClearAllPoints()
	self:SetPoint("TOPRIGHT", tooltipanchor)
end)

-- Show unit name at mouse
tooltip:SetScript("OnUpdate", function(self)
	if GetMouseFocus() and GetMouseFocus():IsForbidden() then self:Hide() return end
	if GetMouseFocus() and GetMouseFocus():GetName()~="WorldFrame" then self:Hide() return end
	if not UnitExists("mouseover") then self:Hide() return end
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	self.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y+15)
end)
tooltip:SetScript("OnEvent", function(self)
	if GetMouseFocus():GetName()~="WorldFrame" then return end
	
	local name = UnitName("mouseover")
	local AFK = UnitIsAFK("mouseover")
	local DND = UnitIsDND("mouseover")
	local prefix = ""
	
	if AFK then prefix = "<AFK> " end
	if DND then prefix = "<DND> " end
	
	self.text:SetTextColor(getcolor())
	self.text:SetText(prefix..name)

	self:Show()
end)
tooltip:RegisterEvent("UPDATE_MOUSEOVER_UNIT")