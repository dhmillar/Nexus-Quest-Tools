local dir = "NQT/"
for _, f in ipairs({"Core.lua", "Options.lua", "Quests.lua", "QuestMenu.lua", "Target.lua", "Portrait.lua", "Route.lua"}) do
    assert(loadfile(dir .. f))
end
local events, frames, timerFns, chat, buttons = {}, {}, {}, {}, {}
local Frame = {}
local fallback = function() end
Frame.__index = function(_, k) return Frame[k] or fallback end
function Frame:SetScript(k, f) self.scripts[k] = f end
function Frame:HookScript(k, f) local prior=self.scripts[k];self.scripts[k]=function(...) if prior then prior(...) end;f(...) end end
function Frame:SetPoint(...) self.anchors=rawget(self,"anchors") or {};table.insert(self.anchors,{...}) end
function Frame:ClearAllPoints() self.anchors={} end
function Frame:SetSize(w,h) self.width,self.height=w,h end
function Frame:SetMovable(value) self.movable=value end
function Frame:RegisterForDrag(button) self.dragButton=button end
function Frame:StartMoving() assert(self.movable);self.moving=true end
function Frame:StopMovingOrSizing() self.moving=false end
function Frame:SetUserPlaced(value) self.userPlaced=value end
function Frame:IsShown() return not self.hidden end
function Frame:Hide() local changed=not self.hidden; self.hidden = true; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:Show() self.hidden = false; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:GetName() return self.frameName end
function Frame:GetWidth() return 140 end
function Frame:GetFrameLevel() return 1 end
function Frame:SetText(t) self.labelText = t; if self.buttonFrame then buttons[t] = self end; if rawget(self,"optionOwner") then buttons[t] = self.optionOwner end end
function Frame:SetChecked(v) self.checked = v end
function Frame:GetChecked() return self.checked end
function Frame:RegisterEvent(e) events[e] = self end
function Frame:CreateTexture() return setmetatable({scripts={}}, Frame) end
function Frame:CreateFontString() return setmetatable({scripts={}, optionOwner=self.optionFrame and self or nil}, Frame) end
function CreateFrame(kind, name, parent)
    local f = setmetatable({frameName=name, scripts={}, parent=parent, buttonFrame=(kind=="Button"), optionFrame=(kind=="CheckButton")}, Frame)
    if name then frames[name] = f end
    if type(parent)=="table" then parent.children=rawget(parent,"children") or {};table.insert(parent.children,f) end
    return f
end
Minimap = CreateFrame("Frame")
UIParent = CreateFrame("Frame")
UISpecialFrames, SlashCmdList = {}, {}
DEFAULT_CHAT_FRAME = {AddMessage=function(_, t) chat[#chat+1]=t end}
C_Timer = {NewTicker=function(_,f) timerFns[#timerFns+1]=f end}
InCombatLockdown = function() return false end
AutoTrackDB, AutoTrackCharDB = {autoFocus=false}, {excludedQuests={[78]=true}}
local picked, routeRefresh, routeInit, savedMob = 0,0,0,0
local AT = { SaveSelectedTarget=function() savedMob=savedMob+1; return true end, GetTargetName=function() return "Bloodscalp Hunter" end, InitQuestRoute=function() routeInit=routeInit+1 end, RefreshQuestRoute=function() routeRefresh=routeRefresh+1 end, IsQuestExcluded=function(id) return AutoTrackCharDB.excludedQuests[id] end,
    SetQuestExcluded=function(id,v) AutoTrackCharDB.excludedQuests[id]=v or nil end, PickupTargetMacro=function() picked=picked+1; return true end, InitQuests=function() end, InitTarget=function() end, GetFocusedQuestID=function() end,
             RefreshQuests=function() end, RefreshTargetMacro=function() end, RefreshTargetButton=function() end }
assert(loadfile(dir .. "Core.lua"))("AutoTrack", AT)
assert(loadfile(dir .. "Options.lua"))("AutoTrack", AT)
events.ADDON_LOADED.scripts.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "AutoTrack")
events.PLAYER_LOGIN.scripts.OnEvent(events.PLAYER_LOGIN, "PLAYER_LOGIN")
assert(routeInit == 1)
assert(#chat == 0, table.concat(chat, "; "))
assert(AT.db.enabled == true and AT.db.autoFocus == false and AT.db.showQuestRoute == true and AT.char == AutoTrackCharDB)
local mini, panel = frames.AutoTrackMinimapButton, frames.AutoTrackOptionsFrame
assert(mini and panel and not panel:IsShown())
mini.scripts.OnClick(mini, "LeftButton")
assert(panel:IsShown())
mini.scripts.OnClick(mini, "RightButton")
assert(AT.db.enabled == false)
mini.scripts.OnClick(mini, "RightButton")
assert(AT.db.enabled == true)
SlashCmdList.AUTOTRACK("")
assert(not panel:IsShown())
SlashCmdList.AUTOTRACK("")
assert(panel:IsShown())
assert(SLASH_NEXUSQUESTTOOLSETTINGS1 == "/nqt")
assert(SLASH_AUTOTRACK1 == "/autotrack" and SLASH_AUTOTRACK2 == "/at")
assert(panel:IsShown())
SlashCmdList.NEXUSQUESTTOOLSETTINGS("")
assert(panel:IsShown(), "repeating /nqt must not hide settings")
panel:Hide()
SlashCmdList.NEXUSQUESTTOOLSETTINGS("")
assert(panel:IsShown(), "/nqt must open settings")
SlashCmdList.AUTOTRACK("")
assert(not panel:IsShown(), "legacy toggle must still work")
print("PASS: /nqt opens settings repeatedly, old commands retain behavior")
local function isCentered()
    assert(#panel.anchors==1)
    local point=panel.anchors[1]
    assert(point[1]=="CENTER" and point[2]==UIParent and point[3]=="CENTER" and point[4]==0 and point[5]==0)
end
SlashCmdList.NEXUSQUESTTOOLSETTINGS("")
isCentered()
local titleDrag
for _,child in ipairs(panel.children) do if type(rawget(child,"dragButton"))=="string" then titleDrag=child end end
assert(titleDrag and titleDrag.dragButton=="LeftButton")
titleDrag.scripts.OnDragStart()
assert(panel.moving==true)
panel:ClearAllPoints();panel:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-55)
titleDrag.scripts.OnDragStop()
assert(panel.moving==false and panel.userPlaced==false and panel.anchors[1][1]=="TOPLEFT")
SlashCmdList.NEXUSQUESTTOOLSETTINGS("")
assert(panel.anchors[1][1]=="TOPLEFT","opening an already visible panel is not a new show")
buttons.General.scripts.OnClick()
assert(panel.anchors[1][1]=="TOPLEFT","switching options tabs does not move the window")
titleDrag.scripts.OnDragStart()
assert(panel.moving==true)
panel:Hide()
assert(panel.moving==false,"hide ends the drag")
mini.scripts.OnClick(mini,"LeftButton")
isCentered()
print("PASS: Title-only drag, no recenter while open, hide releases drag, reopening centers")
assert(not buttons["Edit target name"] and not buttons["Save selected mob"])
for _,label in ipairs({"Place recall macro","Place primary macro","Place mouseover Ping","Place secondary marker"}) do
    assert(buttons[label] and buttons[label].scripts.OnClick)
end
print("PASS: Auto Macro only shows the four placement actions")
assert(panel.width==800 and panel.height==592,"larger settings canvas")
local rail=buttons.Classes.parent
assert(rail==buttons.General.parent and rail~=panel and rail.parent==panel,"shared vertical rail")
buttons.Classes.scripts.OnClick()
assert(buttons.Classes.nqtSelected and not buttons.General.nqtSelected)
assert(buttons["Icon only"] and buttons["+ Size"] and buttons["- Size"] and buttons["Reset reminder"])
assert(buttons["Hunter Deadzone"].parent==buttons["Pet Bar"].parent and buttons["Pet Bar"].parent==buttons["Icon only"].parent)
print("PASS: large settings shell, category rail, and all editable reminder controls in Classes")
