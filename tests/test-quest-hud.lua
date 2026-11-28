local AT={db={enabled=true,questHUDEnabled=true,questHUDWidth=414,questHUDHeight=395,
    questHUDX=-276,questHUDY=-255,questHUDTheme=1,questHUDRailOpen=false},char={zoneQuestOrigins={ [12]=1 }}}
local entries={
 {isHeader=true,title="Stranglethorn Vale"},
 {questID=11,title="A flight to Duskwood"}, {questID=15,title="No NPC metadata"},
 {isHeader=true,title="Trade Skills"},
 {questID=12,title="Acquired in Stranglethorn"},{questID=13,title="Only in Duskwood"},
 {questID=14,title="Uncertain"},{questID=16,title="Only local POI"},{questID=17,title="Hidden",isHidden=true}
}
local dest={[11]=2,[12]=2,[13]=2,[17]=1}
local map=1
local names={"Stranglethorn Vale","Duskwood"}
C_Map={
 GetBestMapForUnit=function() return map end,
 GetMapInfo=function(i)
    if names[i] then return {mapType=3,name=names[i]} end
    if i==88 then return {mapType=5,parentMapID=1,name="Cave floor"} end
 end
}
C_QuestLog={
 GetNumQuestLogEntries=function() return #entries end,GetInfo=function(i) return entries[i] end,
 ReadyForTurnIn=function(q) return q==16 end,
 GetNextWaypoint=function(q) return dest[q],.5,.5 end,
 GetQuestsOnMap=function(z) return z==1 and {{questID=16,x=.3,y=.4}} or {} end,
 GetQuestObjectives=function(q)
   if q==12 then return {{text="Collect evidence: 2/5",finished=false},{text="Defias slain: 3/3",finished=true}} end
   return {{text="Collect evidence: 2/5",finished=false}}
 end,
}
function GetQuestLogSpecialItemInfo(index)
 if entries[index].questID==12 then return "|Hitem:123|h[Quest Flare]|h",987,3 end
end
function AT.GetQuestOrderPosition(q) if q==12 then return 1 end end
local objs,textures={},{}
local function object()
    local o={shown=true,w=250,h=100,child={},scripts={}}
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:SetShown(v) self.shown=v end
    function o:IsShown() return self.shown end
    function o:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function o:SetScript(k,v) self.scripts[k]=v end
    function o:SetText(v)
        self.text=v
        if self.kind=="EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function o:GetText() return self.text end
    function o:SetPoint(...) self.anchor={...}; self.points=self.points or {}; self.points[self.anchor[1]]=self.anchor end
    function o:SetTexture(v) self.texture=v end
    function o:SetFrameLevel(v) self.level=v end
    function o:GetFrameLevel() return self.level or 2 end
    function o:SetTextColor(...) self.textColor={...} end
    function o:SetFont(...) self.appliedFont={...} end
    function o:SetSize(w,h) self.w,self.h=w,h end
    function o:GetWidth() return self.w end
    function o:SetWidth(w) self.w=w end
    function o:GetUnboundedStringWidth() return #(self.text or "")*((self.appliedFont and self.appliedFont[2]) or 10)*.57 end
    function o:GetHeight() return self.h end
    function o:SetHeight(h) self.h=h end
    function o:GetFont() return unpack(self.appliedFont or {}) end
    function o:SetVerticalScroll(v) self.scroll=v end
    function o:GetVerticalScroll() return self.scroll or 0 end
    function o:EnableMouseWheel(v) self.wheel=v end
    local noop=function() end
    for _,k in ipairs({"SetAllPoints","SetFrameStrata","SetMovable","SetResizable","SetClampedToScreen","SetResizeBounds",
       "RegisterForClicks","RegisterForDrag","RegisterEvent","EnableMouse","SetColorTexture","SetJustifyH",
       "SetWordWrap","SetTexCoord","ClearAllPoints","SetAlpha","SetScrollChild","SetAutoFocus","SetMaxLetters","SetFontObject","SetTextInsets","SetVertexColor"}) do o[k]=noop end
    function o:ClearFocus() self.focused=false end
    function o:HasFocus() return self.focused==true end
    function o:GetParent() return self.parent end
    function o:IsMouseOver() return self.mouseOver==true or (self.mouseOver==nil and self.kind~="EditBox" and self.kind~="Frame") end
    function o:SetFocus() self.focused=true end
    function o:CreateTexture() local a=object();a.parent=self;textures[#textures+1]=a;return a end
    function o:SetAtlas(atlas) self.atlas=atlas end
    function o:CreateFontString() local f=object();self.child[#self.child+1]=f;return f end
    return o
end
UIParent=object()
function CreateFrame(kind,_,parent,template)
 local o=object(); o.kind=kind;o.parent=parent;o.template=template;objs[#objs+1]=o;return o
end
local header
local function clickHeader()
    header.scripts.OnMouseDown(header,"LeftButton")
    header.scripts.OnMouseUp(header,"LeftButton")
end
local toolbarLabels={Map=true,Minimal=true,["In Progress"]=true,Completed=true,Zones=true,["+"]=true,["-"]=true}
local function find(value)
 if header and toolbarLabels[value] then
    for _,o in ipairs(objs) do
        if o.parent==header.parent and o.label and o.label.text==value and not o.shown then clickHeader();break end
    end
 end
 for _,o in ipairs(objs) do for _,label in ipairs(o.child) do if label.text==value and o.shown then return o end end end
end
local queued,selected,excluded,ctrl,opened
function AT.ToggleQuestTrackingOrder(q) queued=q;return true end
function AT.ToggleQuestExcluded(q) excluded=q;return true end
C_SuperTrack={SetSuperTrackedQuestID=function(q) selected=q end,GetSuperTrackedQuestID=function() return selected end}
function QuestMapFrame_OpenToQuestDetails(q) opened=q end
function IsControlKeyDown() return ctrl end
assert(loadfile("NQT/DungeonCatalog.lua"))("NQT",AT)
assert(loadfile("NQT/QuestHUD.lua"))("NQT",AT)
do
    local fresh,savedMap,invalid={},{questHUDTheme=1,questHUDThemeSchema=2},{questHUDTheme=99,questHUDThemeSchema=2}
    AT.NormalizeQuestHUDTheme(fresh);AT.NormalizeQuestHUDTheme(savedMap);AT.NormalizeQuestHUDTheme(invalid)
    assert(fresh.questHUDTheme==2 and fresh.questHUDThemeSchema==2 and savedMap.questHUDTheme==1 and invalid.questHUDTheme==2)
end
for i=1,6 do
    local migrated={questHUDTheme=i}
    AT.NormalizeQuestHUDTheme(migrated)
    assert(migrated.questHUDTheme==(i==6 and 2 or 1) and migrated.questHUDThemeSchema==2)
    migrated.questHUDTheme=2
    AT.NormalizeQuestHUDTheme(migrated)
    assert(migrated.questHUDTheme==2,"new Questie preference must persist")
end
local result=AT.BuildQuestHUDModel(1,names[1])
assert(result.zones[1].rows[11].kind=="category" and result.zones[1].rows[12].kind=="recorded")
assert(result.zones[1].rows[15] and result.zones[1].rows[16] and not result.zones[1].rows[13])
assert(result.zones[2].rows[11] and result.zones[2].rows[12] and result.zones[2].rows[13])
assert(not result.rows[17] and not result.zones[1].rows[14])
local copiedTargets,verifiedLink
AT.SetRankQuestItemTargets=function(rows,scroll,verification)
    copiedTargets=rows
    if rows and find("Acquired in Stranglethorn") then
        local row=find("Acquired in Stranglethorn")
        if row.item.link then verifiedLink=verification(row.qid,row.item.rankQuestIndex) end
    end
end
local areaTick
local boot={}
C_Timer={NewTicker=function(_,fn) areaTick=fn end,After=function(delay,fn)
    boot[#boot+1]={delay,fn}
end}
AT.InitQuestHUD()
local startupWatcher
for _,f in ipairs(objs) do if f.scripts.OnEvent then startupWatcher=f end end
assert(startupWatcher and not objs[1]:IsShown() and #boot==1)
startupWatcher.scripts.OnEvent(startupWatcher,"PLAYER_ENTERING_WORLD")
startupWatcher.scripts.OnEvent(startupWatcher,"QUEST_LOG_UPDATE")
AT.RefreshQuestHUD()
assert(not objs[1]:IsShown() and #boot==1,"login calls must not show partial layout or add redundant redraws")
local first=table.remove(boot,1)
first[2]()
assert(objs[1]:IsShown() and #boot==0,"one initial publication, no delayed repeat flashes")
startupWatcher.scripts.OnEvent(startupWatcher,"QUEST_DATA_LOAD_RESULT")
assert(#boot==1)
local later=table.remove(boot,1)
later[2]()
assert(objs[1]:IsShown() and #boot==0,"late data still refreshes")
C_Timer.After=nil
print("PASS startup events coalesce into one laid-out HUD, late quest data still refreshes")
do
    local initialEntries=entries
    local initialNavigation,initialSample=AT.GetQuestNavigationID,AT.SampleQuestAreas
    local active,near=105,{[102]="near",[104]="inside"}
    entries={
        {isHeader=true,title="Stranglethorn Vale"},
        {questID=101,title="General low",level=6},{questID=102,title="Near high",level=28},
        {questID=103,title="General high",level=31},{questID=104,title="Near low",level=18},
        {questID=105,title="Tracked high",level=50},{questID=106,title="Unknown level"}
    }
    AT.GetQuestNavigationID=function()return active end
    AT.SampleQuestAreas=function(ids)
        local r={}
        for q in pairs(ids) do r[q]=near[q] or "outside" end
        return r
    end
    local function order(...)
        local shown={}
        for _,b in ipairs(objs) do
            if b.shown and b.qid and b.circle and b.anchor and b.anchor[5] and b.qid>=101 then shown[#shown+1]=b end
        end
        table.sort(shown,function(a,b)return a.anchor[5]>b.anchor[5] end)
        local ids={}
        for i,b in ipairs(shown) do ids[i]=b.qid end
        assert(table.concat(ids,",")==table.concat({...},","),table.concat(ids,","))
    end
    AT.RefreshQuestHUD()
    order(105,104,102,101,103,106)
    near={[103]="near"};areaTick()
    order(105,103,101,104,102,106)
    active=102;AT.RefreshQuestHUD()
    order(102,103,101,104,105,106)
    entries=initialEntries
    AT.GetQuestNavigationID,AT.SampleQuestAreas=initialNavigation,initialSample
    AT.RefreshQuestHUD()
    print("PASS Rank Quest tracked first, nearby leveled next, remote level order, unknown last and movement reshuffle")
end
for _,o in ipairs(objs) do if o.scripts.OnDragStart and o.scripts.OnMouseUp then header=o;break end end
do
    AT.RefreshQuestHUD()
    local body=assert(header).parent
    local panel=body.parent
    local watcher,search,glass,widgets,party=nil,nil,nil,{},nil
    for _,o in ipairs(objs) do
        if o.scripts.OnEvent then watcher=o end
        if o.parent==body and o.kind=="EditBox" then search=o end
        if o.parent==body and o.icon and o.icon.texture and o.icon.texture:find("PartyPerson",1,true) then party=o end
        if o.parent==body and o.icon and o.points and o.points.TOPRIGHT and o.points.TOPRIGHT[5]==-35 then glass=o end
        if o.parent==body and o.label and (toolbarLabels[o.label.text] ) then widgets[#widgets+1]=o end
    end
    assert(watcher and search and glass and party and #widgets>=5)
    local oldTheme,oldFont=AT.db.questHUDTheme,AT.db.questHUDFontOffset
    local title=header.child[1]
    local minimize=assert(find("−"))
    local function state(open)
        assert(minimize.shown,"minimize stays visible")
        assert(title:GetText()=="Rank Quest")
        assert(title.appliedFont[2]==(open and 10 or 18)+AT.db.questHUDFontOffset)
        for _,o in ipairs(widgets) do assert(o.shown==open) end
        assert(party.shown==open)
        assert(search.points.TOPLEFT[5]==(open and -82 or -60))
    end
    local function mouse(target)
        GetMouseFoci=function() return {target} end
        watcher.scripts.OnEvent(watcher,"GLOBAL_MOUSE_DOWN","LeftButton")
    end
    header.mouseOver=true
    local priorTip=GameTooltip
    GameTooltip={
        SetOwner=function(self,owner) self.owner=owner end,
        SetText=function(self,caption) self.caption=caption end,
        IsOwned=function(self,owner) return self.owner==owner end,
        Show=function(self) self.shown=true end,
        Hide=function(self) self.shown=false;self.owner=nil end,
    }
    for _,theme in ipairs({1,2}) do
        AT.db.questHUDTheme=theme;AT.db.questHUDFontOffset=5;AT.RefreshQuestHUD()
        state(false)
        header.scripts.OnEnter(header)
        assert(GameTooltip.shown and GameTooltip.caption=="Click to show Settings")
        header.scripts.OnLeave(header);assert(not GameTooltip.shown)
        header.scripts.OnEnter(header)
        clickHeader(); state(true)
        assert(not GameTooltip.shown)
        header.scripts.OnEnter(header);assert(not GameTooltip.shown)
        assert(header:GetWidth()<panel:GetWidth(),"expanded title hit area must leave toolbar space")
        for _,button in ipairs(widgets) do
            assert(button:GetFrameLevel()>header:GetFrameLevel(),"every toolbar control must be above the header")
            mouse(button); state(true)
        end
        mouse(party); state(true)
        header.scripts.OnMouseUp(header,"LeftButton");state(true)
        body.mouseOver=true
        mouse(UIParent);state(true)
        mouse(nil);state(true)
        -- Exercise an actual font-control click after a world/root focus result.
        local smaller
        for _,button in ipairs(widgets) do
            if button.label.text=="-" and button:GetWidth()==22 then smaller=button;break end
        end
        assert(smaller)
        smaller.scripts.OnClick(smaller)
        assert(AT.db.questHUDFontOffset==4)
        state(true)
        body.mouseOver=false
        mouse(find("Acquired in Stranglethorn"));state(true)
        glass.scripts.OnClick(glass)
        search:SetText("dusk")
        mouse(CreateFrame("Button",nil,UIParent))
        state(false)
        assert(search.shown and not search.focused and search:GetText()=="dusk")
        search.scripts.OnEscapePressed(search)
        assert(glass.shown and not search.shown)
        clickHeader(); state(true); mouse(nil); state(false)
        clickHeader(); state(true); clickHeader(); state(false)
        AT.db.rankQuestLocked=true
        header.scripts.OnMouseDown(header,"LeftButton")
        header.scripts.OnDragStart(header)
        header.scripts.OnMouseUp(header,"LeftButton")
        state(false)
        AT.db.rankQuestLocked=nil
    end
    state(false)
    minimize.scripts.OnClick(minimize)
    assert(AT.db.questHUDCollapsed and not body.shown)
    assert(find("Rank Quest  +")).scripts.OnClick(assert(find("Rank Quest  +")))
    assert(not AT.db.questHUDCollapsed and body.shown)
    state(false)
    GetMouseFoci=nil
    GameTooltip=priorTip
    header.mouseOver=true
    AT.db.questHUDTheme,AT.db.questHUDFontOffset=oldTheme,oldFont
    AT.RefreshQuestHUD()
    print("PASS compact title and toolbar in both themes, title click, click inside, outside/world dismissal, drag and search preservation")
end
do
    local getObjectives=C_QuestLog.GetQuestObjectives
    local originalPack=AT.ObservedQuestDrops
    AT.ObservedQuestDrops={items={[70]={{20,1,8},{21,3,10}},[71]={{23,1,1}}}}
    C_QuestLog.GetQuestObjectives=function(q)
        if q==12 then return {
            {type="item",itemID=70,text="Evidence: 2/5"},
            {type="item",text="Gather |Hitem:71:0|h[Cloth]|h 1/5"},
            {type="item",text="Duplicate: 0/2"},
            {type="monster",text="Evidence: 0/1"},
            {type="item",itemID=700,text="Unknown: 0/1"},
        } end
        return getObjectives(q)
    end
    for style=1,2 do
        AT.db.questHUDTheme=style
        AT.db.rankQuestDropRates=nil
        AT.RefreshQuestHUD()
        local row=assert(find("Acquired in Stranglethorn"))
        assert(row.objectives[1].text:find("13%\226\128\14730%",1,true))
        assert(row.objectives[2].text:find("(100%)",1,true))
        for i=3,5 do assert(not row.objectives[i].text:find("%%%)")) end
        AT.db.rankQuestDropRates=false;AT.RefreshQuestHUD()
        assert(not row.objectives[1].text:find("%%%)"))
        AT.db.rankQuestDropRates=true;AT.RefreshQuestHUD()
        assert(row.objectives[1].text:find("%%%)"))
    end
    AT.ObservedQuestDrops=originalPack
    AT.RefreshQuestHUD()
    assert(not find("Acquired in Stranglethorn").objectives[1].text:find("%%%)"))
    assert(loadfile("NQT/EverlootDrops.lua"))("NQT",AT)
    assert(AT.ObservedQuestDrops.items[783][1][6]==1,"standalone pack includes object loot")
    local fresh=assert(AT.ObservedQuestDrops.items[729][1])
    assert(fresh[1]==4154 and fresh[2]==11 and fresh[3]==23 and fresh[4]>=3 and fresh[5]==3)
    AT.ObservedQuestDrops.items[990001]={{88,3,7,3,2,1}}
    local oldItem,oldFacts=C_Item,AT.ForeverQuestFacts
    AT.ForeverQuestFacts={[12]={0,0,{730,3}}}
    local itemNameCalls=0
    C_Item={GetItemNameByID=function(x) itemNameCalls=itemNameCalls+1;if x==730 then return "Murloc Eye" end end}
    C_QuestLog.GetQuestObjectives=function(q)
        if q==12 then return {
            {type="item",itemID=730,text="Eye with id: 0/3"},
            {type="item",text="0/3: Murloc Eye"},
            {type="item",text="Missing: 0/3"},
            {type="monster",text="Murloc Eye: 0/3"}, {type="item",itemID=990001,text="Object fixture: 0/3"}
        } end
        return getObjectives(q)
    end
    AT.RefreshQuestHUD()
    assert(itemNameCalls<30,"unknown labels must not trigger a catalog-wide native API loop")
    local offline=assert(find("Acquired in Stranglethorn"))
    assert(offline.objectives[1].text:find("(46%)",1,true))
    assert(offline.objectives[2].text:find("(46%)",1,true))
    assert(offline.objectives[5].text:find("(43%)",1,true) and not offline.objectives[5].text:find("~",1,true))
    assert(not offline.objectives[3].text:find("%%%)") and not offline.objectives[4].text:find("%%%)"))
    AT.db.rankQuestDropRates=false;AT.RefreshQuestHUD()
    assert(not offline.objectives[1].text:find("%%%)"))
    do
        local packed={}
        assert(loadfile("NQT/ForeverQuestFacts.lua"))("NQT",packed)
        local sample=assert(packed.ForeverQuestDropSamples[99130][286215])
        assert(sample[1][1]==113 and sample[1][2]==4248)
        local previous=AT.ForeverQuestDropSamples
        local previousWindow=AT.ForeverSoloQuestWindowSamples
        local windowSample=assert(packed.ForeverSoloQuestWindowSamples[83][1019])
        assert(windowSample[1][1]==474 and windowSample[1][2]==13 and windowSample[1][3]==21)
        AT.ForeverSoloQuestWindowSamples={[12]={[286215]=windowSample}}
        AT.ForeverQuestDropSamples={[12]={[286215]=sample}}
        local priorObjectives=C_QuestLog.GetQuestObjectives
        C_QuestLog.GetQuestObjectives=function(q)
            if q==11 or q==12 then return {{type="item",itemID=286215,text="Fixture item: 0/1"}} end
            return priorObjectives(q)
        end
        AT.db.rankQuestDropRates=true;AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text=="Fixture item: 0/1 (43%)", tostring(find("Acquired in Stranglethorn").objectives[1].text))
        assert(find("A flight to Duskwood").objectives[1].text=="Fixture item: 0/1",
            "never borrow a sample from another quest that uses the same item")
        local priorGroup=IsInGroup
        local priorGroupPack=AT.ForeverGroupedQuestDropSamples
        local intermediate=assert(packed.ForeverGroupedQuestDropSamples[654])
        assert(intermediate[9437][1][1]==5419 and intermediate[9437][1][2]==17 and intermediate[9437][1][3]==20)
        assert(intermediate[9439][1][1]==5426 and intermediate[9442][1][1]==5423)
        assert(not intermediate[9438] and not intermediate[9440] and not intermediate[9441],
            "do not transfer raw Tanaris sample odds to a different processed item ID")
        local groupedSample=assert(packed.ForeverGroupedQuestDropSamples[447][3254])
        AT.ForeverGroupedQuestDropSamples={[12]={[286215]=groupedSample}}
        IsInGroup=function() return true end
        AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text=="Fixture item: 0/1 (35%)")
        assert(find("A flight to Duskwood").objectives[1].text=="Fixture item: 0/1")
        IsInGroup=function() return false end
        AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text=="Fixture item: 0/1 (43%)")
        AT.db.rankQuestDropRates=false;AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text=="Fixture item: 0/1")
        IsInGroup=priorGroup
        AT.ForeverGroupedQuestDropSamples=priorGroupPack
        AT.db.rankQuestDropRates=true
        AT.ForeverQuestDropSamples=nil
        IsInGroup=function() return false end
        AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text=="Fixture item: 0/1 (62%)")
        assert(find("A flight to Duskwood").objectives[1].text=="Fixture item: 0/1")
        IsInGroup=function() return true end
        AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text=="Fixture item: 0/1","solo window sample is not group odds")
        IsInGroup=priorGroup
        AT.ForeverSoloQuestWindowSamples=previousWindow
        AT.ForeverQuestDropSamples=previous
        C_QuestLog.GetQuestObjectives=priorObjectives
    end
    print("PASS Questie-off objective renders observed drop estimates for numeric IDs and exact client names; toggle and unknowns")
    AT.db.rankQuestDropRates=true
    AT.ObservedQuestDrops.items[990002]={{89,2,5,3,2,0}}
    local reads=0
    LibQuestieDB=setmetatable({},{__index=function() reads=reads+1; error("QuestieDB read") end})
    C_QuestLog.GetQuestObjectives=function(q)
        if q==12 then return {{type="item",text="Only Provider Knows: 0/1"}} end
        return getObjectives(q)
    end
    AT.RefreshQuestHUD()
    assert(not find("Acquired in Stranglethorn").objectives[1].text:find("%%%)") and reads==0)
    LibQuestieDB=nil
    do
        local packed={}
        assert(loadfile("NQT/ForeverQuestFacts.lua"))("NQT",packed)
        assert(packed.ForeverQuestItemNames[1019]=="Red Linen Bandana")
        local facts,names,windows,oldLocale,group=AT.ForeverQuestFacts,AT.ForeverQuestItemNames,AT.ForeverSoloQuestWindowSamples,GetLocale,IsInGroup
        AT.ForeverQuestFacts={[12]={0,0,{1019,6},{730,6}}}
        AT.ForeverQuestItemNames=packed.ForeverQuestItemNames
        AT.ForeverSoloQuestWindowSamples={[12]={[1019]=packed.ForeverSoloQuestWindowSamples[83][1019]}}
        C_Item={GetItemNameByID=function() return nil end}
        GetLocale=function()return "enUS" end
        IsInGroup=function()return false end
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 then return {{type="item",numRequired=6,text="Red Linen Bandana: 0/6"},
                {type="item",numRequired=6,text="Different Item: 0/6"}} end
            return getObjectives(q)
        end
        AT.RefreshQuestHUD()
        local row=find("Acquired in Stranglethorn")
        assert(row.objectives[1].text:find("(62%)",1,true),"actual published sample works with cold cache and two same-count item objectives")
        assert(not row.objectives[2].text:find("%%"),"never borrow a percentage for a different item")
        GetLocale=function()return "frFR" end
        AT.RefreshQuestHUD()
        assert(not find("Acquired in Stranglethorn").objectives[1].text:find("%%"),"English fallback cannot match another locale")
        AT.ForeverQuestFacts,AT.ForeverQuestItemNames,AT.ForeverSoloQuestWindowSamples,GetLocale,IsInGroup=facts,names,windows,oldLocale,group
    end
    do
        local packed={}
        assert(loadfile("NQT/ForeverQuestFacts.lua"))("NQT",packed)
        local early=packed.ForeverEarlyDropSamples
        assert(early[94680][1][1]==265745 and early[94680][1][3]==6 and early[94680][1][4]==15)
        assert(not early[95121],"no mixed hotfix data")
        local expected={{596,3915,595,5,19},{2418,8009,4844,3,15},{2862,9237,5249,8,16},{2862,9237,5253,5,15}}
        for _,record in ipairs(expected) do
            local q,item,npc,drops,loots=unpack(record)
            local matched,typed
            for _,r in ipairs(early[q] or {}) do
                if r[1]==item and r[2]==npc then matched=r[3]==drops and r[4]==loots and r[5]==2 and r[7]==1 end
            end
            for i=3,#packed.ForeverQuestFacts[q] do if packed.ForeverQuestFacts[q][i][1]==item then typed=true end end
            assert(matched and typed,"verified party sample stays with its typed quest item")
        end
        for _,r in ipairs({{2822,8973,5292,8,27,2,71091},{2822,8973,5295,7,16,2,71091},{2973,9369,5278,16,32,2,71037},{2974,9460,7725,12,26,2,71037},{2974,9460,7726,13,24,2,71037},{7730,18961,5247,22,22,2,71037},{1419,6166,2729,58,92,2,70959},{2258,7846,2729,14,92,2,70959},{572,3863,687,20,58,2,70959},{95773,270305,262397,20,57,2,70959},{1108,5797,2893,13,45,2,70959},{2258,7848,2735,7,33,2,70959},{710,4626,2735,6,22,2,70959},{1108,5797,2894,7,19,2,70959},{47,773,475,11,23,3,70938},{60,772,475,6,19,2,70938},{47,773,40,6,18,3,70938},{60,772,40,4,14,2,70938},{91775,248001,40,4,11,2,70938},{556,3714,2271,17,47,2,70888},{557,3715,2359,10,22,2,70888},{556,3714,2272,5,16,2,70888},{189,1519,588,3,11,2,70888},{189,1519,701,4,11,2,70888}}) do
            local q,item,npc,drops,loots,contributors,build=unpack(r)
            local found,typed
            for _,x in ipairs(early[q] or {}) do
                if x[1]==item and x[2]==npc then
                    found=x[3]==drops and x[4]==loots and x[5]==contributors and x[6]==build and x[7]==1
                end
            end
            for i=3,#packed.ForeverQuestFacts[q] do if packed.ForeverQuestFacts[q][i][1]==item then typed=true end end
            assert(found and typed,"exact quest and item, correctly scoped sample")
        end
        local prevEarly,comp,solo,group=AT.ForeverEarlyDropSamples,AT.ForeverRivergladesDropComparison,AT.ForeverQuestDropSamples,IsInGroup
        AT.ForeverEarlyDropSamples={[12]=early[94680]}
        AT.ForeverRivergladesDropComparison={[12]=true}
        AT.ForeverQuestDropSamples={[12]=packed.ForeverQuestDropSamples[93788]}
        IsInGroup=function()return true end
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 then return {
                {type="item",itemID=265745,text="Twilight Missive: 0/3"},
                {type="item",itemID=263972,text="Woodworker's Axe: 0/10"},
            } end
            return getObjectives(q)
        end
        AT.RefreshQuestHUD()
        local r=find("Acquired in Stranglethorn")
        assert(r.objectives[1].text:find("40%, party sample: 15 loots",1,true))
        assert(r.objectives[2].text:find("solo: 30%",1,true),"party must not mislabel solo rate")
        IsInGroup=function()return false end
        AT.RefreshQuestHUD()
        r=find("Acquired in Stranglethorn")
        assert(r.objectives[1].text:find("40%, party sample: 15 loots",1,true),"show the comparison as a party sample, not solo odds")
        assert(r.objectives[2].text:find("(30%)",1,true))
        local refs=AT.ForeverReportedQuestDropReferences
        AT.ForeverReportedQuestDropReferences={[12]=packed.ForeverReportedQuestDropReferences[94829]}
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 or q==11 then return {{type="item",itemID=266148,text="Farmers' Mementos: 0/5"}} end
            return getObjectives(q)
        end
        AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text:find("(9%)",1,true))
        assert(not find("A flight to Duskwood").objectives[1].text:find("reported",1,true))
        AT.ForeverReportedQuestDropReferences=refs

        local windows=packed.ForeverPublicDropWindows
        assert(windows and windows[96109] and windows[96109][266888])
        local oldPublic=AT.ForeverPublicDropWindows
        AT.ForeverPublicDropWindows={[12]={[266888]={[0]={.625,.7272727272}}}}
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 or q==11 then return {{type="item",itemID=266888,text="Collection: 0/5"}} end
            return getObjectives(q)
        end
        IsInGroup=function()return false end
        AT.RefreshQuestHUD()
        assert(find("Acquired in Stranglethorn").objectives[1].text:find("63%",1,true))
        assert(find("Acquired in Stranglethorn").objectives[1].text:find("73%",1,true))
        assert(not find("A flight to Duskwood").objectives[1].text:find("63%",1,true))
        IsInGroup=function()return true end
        AT.RefreshQuestHUD()
        assert(not find("Acquired in Stranglethorn").objectives[1].text:find("63%",1,true),"do not show solo samples as party rates")
        AT.ForeverPublicDropWindows=oldPublic

        local classic={}
        assert(loadfile("NQT/ClassicQuestDropReferences.lua"))("NQT",classic)
        assert(classic.ClassicQuestDropReferences[2870][9248][1]==100)
        assert(classic.ClassicQuestDropReferences[22][723][2]>37)
        local prevClassic=AT.ClassicQuestDropReferences
        AT.ClassicQuestDropReferences={[12]={[990005]={42.9,42.9}}}
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 or q==11 then return {{type="item",itemID=990005,text="Test sample "..q..": 0/5"}} end
            return getObjectives(q)
        end
        local function text12()
            AT.RefreshQuestHUD()
            return find("Acquired in Stranglethorn").objectives[1].text
        end
        assert(text12():find("(43%)",1,true),"unconfigured users see Classic fallback")
        assert(not find("A flight to Duskwood").objectives[1].text:find("43%",1,true),"do not cross quest IDs")
        AT.db.rankQuestLegacyDropRates=false
        assert(not text12():find("43%",1,true),"Classic setting off")
        AT.db.rankQuestLegacyDropRates=true
        AT.db.rankQuestDropRates=false
        assert(not text12():find("43%",1,true),"master off")
        AT.db.rankQuestDropRates=nil
        AT.ForeverPublicDropWindows={[12]={[990005]={[1]={.19,.19}}}}
        assert(text12():find("(19%)",1,true),"Forever measurement wins")
        AT.ForeverPublicDropWindows=oldPublic
        AT.ClassicQuestDropReferences=prevClassic
        AT.db.rankQuestLegacyDropRates=nil


        AT.ForeverEarlyDropSamples={[12]=early[596]}
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 or q==11 then return {{type="item",itemID=3915,text="Bloody Bone Necklace: 0/25"}} end
            return getObjectives(q)
        end
        for _,grouped in ipairs({true,false}) do
            IsInGroup=function() return grouped end
            AT.RefreshQuestHUD()
            assert(find("Acquired in Stranglethorn").objectives[1].text:find("27%, party sample: 19 loots",1,true))
            assert(not find("A flight to Duskwood").objectives[1].text:find("27%",1,true))
        end
        AT.ForeverEarlyDropSamples,AT.ForeverRivergladesDropComparison,AT.ForeverQuestDropSamples,IsInGroup=prevEarly,comp,solo,group
    end
    C_Item,AT.ForeverQuestFacts=oldItem,oldFacts
    C_QuestLog.GetQuestObjectives=getObjectives
    AT.db.questHUDTheme=1;AT.db.rankQuestDropRates=nil;AT.RefreshQuestHUD()
    local testRow=find("Acquired in Stranglethorn"); for i=#testRow.objectives,3,-1 do testRow.objectives[i]=nil end
    print("PASS actual Rank Quest rows both themes, current amount kept, bundled rates, range/partial coverage, exact linked item, ambiguous/non-item/absent excluded, toggle")
end
do
    local priorDB,priorLocale,priorObjectives=AT.NQTDB,GetLocale,C_QuestLog.GetQuestObjectives
    local priorObject=AT.GetQuestLootObjectName
    GetLocale=function()return "enUS" end
    local source={NQTDB={NamedObjectPickups={[12]={[999371]={{629472,"Admiral's Treasure Chest"},{629473,"Admiral's Treasure Chest"}}}}}}
    assert(loadfile("NQT/QuestMobs.lua"))("NQT",source)
    AT.GetQuestLootObjectName=source.GetQuestLootObjectName
    C_QuestLog.GetQuestObjectives=function(q)
        if q==12 or q==11 then return {{type="item",itemID=999371,text="Lamora's Loot: 0/1"}} end
        return priorObjectives(q)
    end
    AT.RefreshQuestHUD()
    local a,other=find("Acquired in Stranglethorn"),find("A flight to Duskwood")
    assert(a.objectives[1].text:find("Loot: Admiral's Treasure Chest",1,true))
    assert(not a.objectives[1].text:find("%%") and not other.objectives[1].text:find("Treasure Chest",1,true),
        "no inferred rate or cross-quest label: "..a.objectives[1].text.." / "..other.objectives[1].text)
    GetLocale=function()return "koKR" end
    AT.RefreshQuestHUD()
    assert(not a.objectives[1].text:find("Treasure Chest",1,true),"no unlocalized source label")
    AT.NQTDB,GetLocale,C_QuestLog.GetQuestObjectives=priorDB,priorLocale,priorObjectives
    AT.GetQuestLootObjectName=priorObject
    AT.RefreshQuestHUD()
    print("PASS exact named object loot sources on matching Rank Quest rows without percentages")
end
local hud=objs[1]
assert(hud.shown and find("Acquired in Stranglethorn") and find("A flight to Duskwood") and not find("Only in Duskwood"))
local row=find("Acquired in Stranglethorn")
do
    local objectiveAPI,locale,click= C_QuestLog.GetQuestObjectives,GetLocale,AT.SetQuestMobTarget
    local pack,mobs,enabled=AT.ObservedQuestDrops,AT.QuestMobData,AT.db.rankQuestDropRates
    GetLocale=function() return "enUS" end
    AT.QuestMobData={creatures={[10]={"Test Raptor",20,22,"normal"},[11]={"Second Named Mob",25,25,"elite"}},
        killLabels={},questMobs={[12]={10}},dropMobs={[9001]={10,11}},questItems={[12]={9001}}}
    assert(loadfile("NQT/QuestMobs.lua"))("NQT",AT)
    AT.ObservedQuestDrops={dates={"fixture"},items={[9001]={{10,2,5,3,1,0},{11,2,5,3,1,1}}}}
    local chosen
    AT.SetQuestMobTarget=function(name) chosen=name;return true end
    AT.db.rankQuestDropRates=false
    C_QuestLog.GetQuestObjectives=function(q)
        if q==12 then return {{type="item",itemID=9001,text="Quest item: 0/5"},
            {type="monster",text="Test Raptors slain: 0/2"},
            {type="monster",text="Rescue Test Raptor: 0/1"},
            {type="monster",text="Unknown Beasts slain: 0/3"}} end
        return objectiveAPI(q)
    end
    AT.RefreshQuestHUD()
    local view=assert(find("Acquired in Stranglethorn"))
    assert(view.objectives[1].text:match("^Quest item"),"no leading objective dash")
    assert(view.objectives[2].text:find("Test Raptors slain",1,true))
    local hits=view.objectiveMobHits
    assert(hits[1].mobName=="Second Named Mob" and hits[2].mobName=="Test Raptor" and hits[3].npcObjective==3 and hits[3].npcID==10)
    local itemColor=table.concat(view.objectives[1].textColor,",")
    local killColor=table.concat(view.objectives[2].textColor,",")
    assert(hits[1].anchor[4]==view.objectives[1].anchor[2] and hits[1].anchor[5]==view.objectives[1].anchor[3])
    assert(hits[1].w<view.objectives[1].w,"short labels do not capture clicks across empty space")
    local beforeOpen=opened
    local icons=view.objectiveMobIcons
    assert(icons[1].mobName=="Second Named Mob" and icons[2].mobName=="Test Raptor")
    assert(icons[1]:GetWidth()==18 and icons[2]:GetHeight()==18)
    assert(view.objectives[1].anchor[2]-(icons[2].anchor[4]+18)>=7 and icons[2].anchor[5]==icons[1].anchor[5],"portrait and text are separated")
    local nativePortrait=SetPortraitTextureFromCreatureDisplayID
    SetPortraitTextureFromCreatureDisplayID=function(texture,display) texture:SetTexture("display:"..display) end
    AT.GetQuestMobDisplayID=function(name) if name=="Second Named Mob" then return 42 end end
    AT.RefreshQuestHUD()
    icons[1].scripts.OnEnter(icons[1])
    local tip
    for _,o in ipairs(objs) do if o.owner==icons[1] and o.portrait then tip=o end end
    assert(tip and tip.shown and tip.mob.text=="Second Named Mob")
    assert(tip.portrait.w==48 and tip.portrait.h==48 and tip.portrait.texture=="display:42")
    assert(icons[1].w==18 and tip.portrait.anchor[4]<tip.mob.anchor[4])
    AT.RefreshQuestHUD();assert(tip.shown,"unchanged draw does not dismiss the hover")
    icons[1].scripts.OnLeave(icons[1]);assert(not tip.shown)
    hits[1].scripts.OnEnter(hits[1])
    assert(tip.shown and tip.owner==hits[1] and tip.mob.text=="Second Named Mob" and tip.portrait.texture=="display:42")
    assert(tip.instruction.text=="Click to set Auto Macro")
    local oldLive,oldName,oldCan,oldPlayer=SetPortraitTexture,UnitName,UnitCanAttack,UnitIsPlayer
    local targetName="Second Named Mob"
    UnitName=function(u) if u=="target" then return targetName end end
    UnitCanAttack=function(_,u) return u=="target" end
    UnitIsPlayer=function() return false end
    SetPortraitTexture=function(texture,unit) assert(unit=="target");texture:SetTexture("live:"..targetName) end
    local oldSecret=issecretvalue
    local renders=0
    local liveTexture=SetPortraitTexture
    SetPortraitTexture=function(...) renders=renders+1;return liveTexture(...) end
    issecretvalue=function(v) return v==targetName end
    AT.RefreshRankQuestMobPortraits()
    assert(renders==0 and tip.shown and tip.portrait.texture=="display:42","hidden target name must not reach the portrait API")
    issecretvalue=function(v) return v==false end
    AT.RefreshRankQuestMobPortraits()
    assert(renders==0,"hidden player flag must not reach the portrait API")
    issecretvalue=function(v) return v==true end
    AT.RefreshRankQuestMobPortraits()
    assert(renders==0,"hidden hostility flag must not reach the portrait API")
    issecretvalue=oldSecret
    AT.RefreshRankQuestMobPortraits()
    assert(icons[1].image.texture=="live:Second Named Mob" and tip.portrait.texture=="live:Second Named Mob")
    targetName="Unrelated mob";AT.RefreshRankQuestMobPortraits()
    assert(icons[1].image.texture=="live:Second Named Mob" and not tostring(icons[2].image.texture):find("Unrelated",1,true))
    SetPortraitTexture,UnitName,UnitCanAttack,UnitIsPlayer=oldLive,oldName,oldCan,oldPlayer
    hits[1].scripts.OnClick(hits[1],"LeftButton")
    assert(chosen=="Second Named Mob" and not tip.shown and opened==beforeOpen)
    hits[2].scripts.OnEnter(hits[2])
    assert(tip.shown and tip.owner==hits[2] and tip.mob.text=="Test Raptor")
    hits[2].scripts.OnClick(hits[2],"LeftButton")
    assert(chosen=="Test Raptor" and not tip.shown and opened==beforeOpen)
    assert(table.concat(view.objectives[1].textColor,",")==itemColor and table.concat(view.objectives[2].textColor,",")==killColor)
    SetPortraitTextureFromCreatureDisplayID=nativePortrait
    icons[1].scripts.OnClick(icons[1],"LeftButton")
    assert(chosen=="Second Named Mob" and opened==beforeOpen)
    assert(icons[3].mobName=="Test Raptor" and icons[3]:GetWidth()==18 and view.objectives[2].anchor[2]-(icons[3].anchor[4]+18)>=7);icons[3].scripts.OnClick(icons[3]);assert(chosen=="Test Raptor" and opened==beforeOpen);assert(icons[4].mobName=="Test Raptor" and icons[4].npcObjective==3 and not icons[5],"known rescue NPC gets a portrait; unknown kill does not"); chosen=nil; icons[4].scripts.OnClick(icons[4]); hits[3].scripts.OnClick(hits[3],"LeftButton"); assert(not chosen,"NPC actions must not change Auto Macro")
    do
        local oldObjectives,oldVendor=C_QuestLog.GetQuestObjectives,AT.GetQuestObjectiveVendor
        AT.GetQuestObjectiveVendor=function(q,item) if q==12 and item==9001 then return "Known Vendor",77,123 end end
        C_QuestLog.GetQuestObjectives=function(q)
            if q==12 then return {{type="item",itemID=9001,text="Quest item: 0/5"}} end
            return oldObjectives(q)
        end
        AT.RefreshQuestHUD()
        assert(view.objectives[1].text=="(NPC)  Quest item: 0/5")
        assert(icons[1].vendorItem==9001 and icons[1].mobName=="Known Vendor" and icons[1].displayID==123)
        assert(hits[1].vendorItem==9001 and hits[1].anchor[4]==icons[1].anchor[4])
        assert(hits[1].w>view.objectives[1].w,"vendor hit covers the portrait, NPC tag and whole objective")
        chosen=nil;icons[1].scripts.OnClick(icons[1]);hits[1].scripts.OnClick(hits[1],"LeftButton")
        assert(not chosen,"vendor fallback never saves into Auto Macro")
        C_QuestLog.GetQuestObjectives,AT.GetQuestObjectiveVendor=oldObjectives,oldVendor
        AT.RefreshQuestHUD()
        assert(not icons[1].vendorItem and not hits[1].vendorItem,"recycled mob row does not keep vendor data")
    end
    local beforeMenu,dropMobNames=MenuUtil,AT.GetQuestDropMobNames
    local menu={}
    MenuUtil={CreateContextMenu=function(owner,f)
        f(owner,{CreateButton=function(_,label,fn) menu[label]=fn end})
    end}
    AT.GetQuestDropMobNames=function(i)
        if i==9001 then return {"Mob A","Mob B","Mob C","Mob D","Mob E","Mob F"} end
        if i==9002 then return {"Second item mob"} end
    end
    local prev=C_QuestLog.GetQuestObjectives
    C_QuestLog.GetQuestObjectives=function(q)
        local objectives=prev(q)
        if q==12 then table.insert(objectives,2,{type="item",itemID=9002,text="Second item: 0/2"}) end
        return objectives
    end
    AT.RefreshQuestHUD()
    local overflow
    for _,icon in ipairs(icons) do if icon.shown and icon.overflow then overflow=icon end end
    assert(overflow and overflow:GetHeight()==18 and #overflow.overflow==3)
    hits[1].scripts.OnClick(hits[1],"LeftButton");assert(chosen=="Mob A")
    hits[2].scripts.OnClick(hits[2],"LeftButton");assert(chosen=="Second item mob")
    hits[3].scripts.OnClick(hits[3],"LeftButton");assert(chosen=="Test Raptor")
    AT.db.questHUDTheme=2;AT.RefreshQuestHUD()
    assert(hits[2].shown and hits[2].mobName=="Second item mob")
    AT.db.questHUDTheme=1;AT.RefreshQuestHUD()
    AT.char.rankQuestMinimized={[12]=true};AT.RefreshQuestHUD()
    assert(not hits[1].shown and hits[1].mobName==nil)
    hits[1].scripts.OnClick(hits[1],"LeftButton");assert(chosen=="Test Raptor")
    AT.char.rankQuestMinimized=nil;AT.RefreshQuestHUD()
    overflow.scripts.OnClick(overflow)
    assert(menu["Mob F"]);menu["Mob F"]();assert(chosen=="Mob F")
    assert(view.objectives[2].text:find("Second item",1,true) and view.objectives[3].text:find("Test Raptors slain",1,true))
    assert(icons[5].mobName=="Second item mob" and icons[5].anchor[5]<icons[1].anchor[5])
    MenuUtil,AT.GetQuestDropMobNames=beforeMenu,dropMobNames
    GetLocale=function()return "frFR" end;AT.RefreshQuestHUD()
    assert(not icons[1].shown and not icons[2].shown and not icons[3].shown)
    assert(not hits[1].shown and not hits[2].shown and not hits[3].shown)
    C_QuestLog.GetQuestObjectives,GetLocale,AT.SetQuestMobTarget=objectiveAPI,locale,click
    AT.ObservedQuestDrops,AT.QuestMobData,AT.db.rankQuestDropRates=pack,mobs,enabled
    AT.GetQuestKillMobName,AT.GetQuestDropMobNames,AT.GetKnownQuestDropItem,AT.GetQuestMobProfile,AT.GetQuestMobDisplayID=nil,nil,nil,nil,nil
    AT.RefreshQuestHUD()
    print("PASS compact clickable portraits for drops and kills, overflow, text and tooltip actions, unchanged color, and no false rescue icons")
end
row.titleHit.scripts.OnClick(row.titleHit,"LeftButton"); assert(opened==12 and not selected)
ctrl=true;row.titleHit.scripts.OnClick(row.titleHit,"LeftButton"); assert(queued==12)

do
    local function node()
        local n={entries={}}
        function n:CreateButton(label,click)
            local b=node();b.click=click
            self.entries[label]=b
            return b
        end
        function n:CreateTitle(t) self.title=t end
        function n:CreateDivider() end
        function n:SetEnabled(v) self.enabled=v end
        return n
    end
    local openedMenu,owner,popup
    MenuUtil={CreateContextMenu=function(o,build) owner=o;openedMenu=node();build(o,openedMenu) end}
    StaticPopupDialogs={}
    StaticPopup_Show=function(key,arg1,_,data)
        popup={key=key,name=arg1,data=data,def=StaticPopupDialogs[key]}
        return popup
    end
    StaticPopup_Hide=function() popup=nil end
    local offered,inCombat,prior,staged=12,false,13,13
    local blockedStage,abandoned,shared,chat,excludedValue,order,pin
    InCombatLockdown=function() return inCombat end
    IsInGroup=function() return true end
    C_QuestLog.GetLogIndexForQuestID=function(id)
        for i,info in ipairs(entries) do if info.questID==id then return i end end
    end
    C_QuestLog.IsOnQuest=function(id) return id==12 or id==13 end
    C_QuestLog.IsPushableQuest=function(id) return id==12 end
    C_QuestLog.GetQuestLink=function(id) return "quest:"..id end
    C_QuestLog.CanAbandonQuest=function(id) return offered==id end
    C_QuestLog.GetSelectedQuest=function() return prior end
    C_QuestLog.SetSelectedQuest=function(id) prior=id end
    C_QuestLog.GetAbandonQuest=function() return staged end
    C_QuestLog.SetAbandonQuest=function() if not blockedStage then staged=prior end end
    C_QuestLog.AbandonQuest=function() abandoned=staged end
    QuestLogPushQuest=function() shared=prior end
    ChatFrame_OpenChat=function(value) chat=value end
    AT.GetTrackingOrderCount=function() return order and 1 or 0 end
    AT.IsQuestExcluded=function() return excludedValue end
    local orderPos=AT.GetQuestOrderPosition
    AT.GetQuestOrderPosition=function(id) return id==12 and order and 1 or nil end
    AT.ToggleQuestTrackingOrder=function(id) assert(id==12);order=not order;return true,order and "added" or "removed",1 end
    AT.ResetTrackingOrder=function() order=nil end
    AT.ToggleQuestExcluded=function(id) excluded=id;excludedValue=not excludedValue end
    AT.GetQuestHUDManualFocus=function() return pin end
    AT.ToggleQuestHUDManualFocus=function(id) if pin==id then pin=nil else pin=id end end
    assert(loadfile("NQT/QuestMenu.lua"))("NQT",AT)
    local function menu()
        row=find("Acquired in Stranglethorn")
        row.scripts.OnClick(row,"RightButton")
        assert(owner==row and openedMenu.title and openedMenu.entries)
        return openedMenu.entries
    end
    local m=menu()
    assert(not excluded and not popup and prior==13 and staged==13)
    m["Focus Quest"].click();assert(pin==12)
    menu()["Unfocus"].click();assert(not pin)
    menu()["Minimize Quest"].click();assert(AT.char.rankQuestMinimized[12])
    menu()["Maximize Quest"].click();assert(not AT.char.rankQuestMinimized[12])
    menu()["Lock Tracker"].click();assert(AT.db.rankQuestLocked)
    menu()["Unlock Tracker"].click();assert(not AT.db.rankQuestLocked)
    menu()["Link Quest to chat"].click();assert(chat=="quest:12")
    menu()["Share Quest"].click();assert(shared==12 and prior==13)
    menu()["Add to Tracking Order"].click()
    assert(menu()["Remove from Tracking Order"])
    menu()["Reset Tracking Order"].click();assert(not order)
    menu()["Nexus Quest Tools: Exclude this quest"].click();assert(excluded==12 and excludedValue)
    menu()["Nexus Quest Tools: Include quest again"].click();assert(not excludedValue)

    menu()["Abandon Quest"].click()
    assert(popup.name=="Acquired in Stranglethorn" and popup.data.id==12 and not abandoned and staged==13)
    popup.def.OnCancel(nil,popup.data);popup.def.OnAccept(nil,popup.data);assert(not abandoned)
    menu()["Abandon Quest"].click()
    local removed=popup
    AT.InvalidateRankQuestAbandon(12)
    removed.def.OnAccept(nil,removed.data);assert(not abandoned)
    menu()["Abandon Quest"].click();inCombat=true
    popup.def.OnAccept(nil,popup.data);assert(not abandoned)
    assert(menu()["Abandon Quest"].enabled==false)
    inCombat=false
    menu()["Abandon Quest"].click()
    blockedStage=true;popup.def.OnAccept(nil,popup.data);assert(not abandoned and prior==13 and staged==13)
    blockedStage=false
    menu()["Abandon Quest"].click()
    popup.def.OnAccept(nil,popup.data);assert(abandoned==12 and prior==13)
    offered=false;assert(not menu()["Abandon Quest"])
    AT.db.questHUDTheme=2;AT.RefreshQuestHUD()
    local minimal=menu()
    assert(minimal["Add to Tracking Order"] and minimal["Untrack Quest"])
    minimal["Untrack Quest"].click();assert(excludedValue)
    menu()["Nexus Quest Tools: Include quest again"].click();assert(not excludedValue)
    AT.db.questHUDTheme=1;AT.RefreshQuestHUD()

    local before=menu()
    assert(before["Show on Map"] and before["Wowhead URL"] and not before["Hide Icons"])
    local openedBefore=opened
    C_QuestLog.IsOnQuest=function() return false end
    before["Show on Map"].click();assert(opened==openedBefore,"stale menu cannot act on a removed quest")
    row.partyOnly=true;openedMenu=nil
    row.scripts.OnClick(row,"RightButton");assert(not openedMenu)
    row.partyOnly=false
    AT.GetQuestOrderPosition=orderPos
    AT.ToggleQuestTrackingOrder=function(q) queued=q;return true end
    AT.ToggleQuestExcluded=function(q) excluded=q;return true end
    AT.GetQuestHUDManualFocus=nil;AT.ToggleQuestHUDManualFocus=nil
    C_QuestLog.GetLogIndexForQuestID=nil;C_QuestLog.IsOnQuest=nil
    C_QuestLog.IsPushableQuest=nil;C_QuestLog.GetQuestLink=nil
    C_QuestLog.CanAbandonQuest=nil;C_QuestLog.GetSelectedQuest=nil;C_QuestLog.SetSelectedQuest=nil
    C_QuestLog.GetAbandonQuest=nil;C_QuestLog.SetAbandonQuest=nil;C_QuestLog.AbandonQuest=nil
    InCombatLockdown=nil;IsInGroup=nil;QuestLogPushQuest=nil;ChatFrame_OpenChat=nil
    MenuUtil=nil;Questie=nil;QuestieLoader=nil
    AT.RefreshQuestHUD(); row=find("Acquired in Stranglethorn")
    print("PASS Rank Quest right-click: native actions, ordering, explicit confirmation, stale target, combat and party-only safety")
end

local function openZones()
    local z=assert(find("Zones"));z.scripts.OnClick(z)
end
openZones()
local rail=find("Duskwood"); assert(rail and rail.kind=="Button")
assert(verifiedLink and verifiedLink:match("item:123") and copiedTargets)
assert(row.item.shown and row.item.link:match("item:123") and row.item.icon.texture==987 and row.item.count.text=="3")
do
    local oldIndex,oldOn,oldSpecial,oldItem=C_QuestLog.GetLogIndexForQuestID,C_QuestLog.IsOnQuest,GetQuestLogSpecialItemInfo,C_Item
    C_QuestLog.GetLogIndexForQuestID=function()return 0 end
    C_QuestLog.IsOnQuest=function(q)return q==12 end
    GetQuestLogSpecialItemInfo=function(i) if entries[i].questID==12 then return "item:123" end end
    AT.ForeverObservedQuestUses={[12]={{1570,100},{1571,101},{1572,102},{1573,103}}}
    C_Item={GetItemIconByID=function(i)return i+10 end,
        GetItemCount=function(i)return i==1573 and 0 or 1 end,
        GetItemSpell=function(i)return "Tool",i==1572 and 999 or (i-1470) end}
    AT.RefreshQuestHUD()
    local qrow=assert(find("Acquired in Stranglethorn"))
    assert(qrow.item.icon.texture==133 and qrow.item.link=="item:123","zero index and uncached icon fallback")
    assert(qrow.itemTiles[2].link=="item:1570" and qrow.itemTiles[3].link=="item:1571")
    assert(not qrow.itemTiles[4],"wrong spell and absent bag item cannot create buttons")
    local usePack={}
    assert(loadfile("NQT/ForeverQuestFacts.lua"))("NQT",usePack)
    local use=assert(usePack.ForeverProvidedQuestUses[717][1])
    assert(use[1]==4640 and use[2]==4982)
    AT.ForeverProvidedQuestUses={[12]={use,{1570,100}},[11]={use}}
    local nativeSpell=C_Item.GetItemSpell
    C_Item.GetItemSpell=function(i) if i==4640 then return "Quest Use",4982 end return nativeSpell(i) end
    AT.RefreshQuestHUD()
    assert(qrow.itemTiles[4].link=="item:4640" and not qrow.itemTiles[5],"additional supplied item, deduplicated")
    local instruction=assert(usePack.ForeverInstructedQuestUses[4005][1])
    assert(instruction[1]==11169 and instruction[2]==13978)
    AT.ForeverInstructedQuestUses={[12]={instruction}}
    C_Item.GetItemSpell=function(i)
        if i==11169 then return "Quest Use",13978 end
        if i==4640 then return "Quest Use",4982 end
        return nativeSpell(i)
    end
    AT.RefreshQuestHUD()
    assert(qrow.itemTiles[5].shown and qrow.itemTiles[5].link=="item:11169")
    AT.ForeverInstructedQuestUses=nil
    local oldCount=C_Item.GetItemCount
    C_Item.GetItemCount=function(i,...) if i==4640 then return 0 end return oldCount(i,...) end
    AT.RefreshQuestHUD()
    assert(not qrow.itemTiles[4].shown,"supplied item disappears after leaving the bag")
    AT.ForeverProvidedQuestUses=nil
    AT.ForeverObservedQuestUses=nil


    -- Two different Khan gems use the same spell. Reuse real shipped rows
    -- under the fixture's quest ID so this exercises actual tile selection.
    local oldDB,gemDB,priorBags=AT.NQTDB,{},C_Container
    assert(loadfile("NQT/NQTDB.lua"))("NQT",gemDB)
    local primary=assert(usePack.ForeverObservedQuestUses[7067][1])
    local alternate=assert(gemDB.NQTDB.QuestUses[7067][1])
    assert(primary[1]==17765 and alternate[1]==17761 and alternate[2]==21957)
    AT.ForeverObservedQuestUses={[12]={primary}}
    AT.NQTDB={QuestUses={[12]={alternate}}}
    C_Container=nil
    GetQuestLogSpecialItemInfo=function()end
    local havePrimary,haveAlternate,rightSpell=false,true,true
    C_Item={GetItemIconByID=function()return 133 end,
        GetItemCount=function(i) return (i==17765 and havePrimary or i==17761 and haveAlternate) and 1 or 0 end,
        GetItemSpell=function(i) return "Gem",i==17761 and not rightSpell and 999999 or 21957 end}
    AT.RefreshQuestHUD()
    assert(qrow.item.shown and qrow.item.link=="item:17761","alternate exact gem works with no native special item")
    havePrimary=true
    AT.RefreshQuestHUD()
    assert(qrow.item.shown and qrow.item.link=="item:17765" and qrow.itemTiles[2].link=="item:17761")
    rightSpell=false
    AT.RefreshQuestHUD()
    assert(qrow.item.shown and not qrow.itemTiles[2].shown,"unknown alternate runtime spell is not clickable")
    AT.NQTDB,AT.ForeverObservedQuestUses,C_Container=oldDB,nil,priorBags
    print("PASS Rank Quest uses either confirmed possessed Khan gem and rejects a wrong spell")

    -- Another character has no native special-item button or bundled entry.
    -- Repair cold spell metadata and show only a game-linked, usable held item.
    local oldBags=C_Container
    local warm,held,requests,scans=false,true,0,0
    GetQuestLogSpecialItemInfo=function()end
    C_QuestLog.IsOnQuest=nil
    C_Container={
        GetContainerNumSlots=function(b) scans=scans+1; return b==0 and 4 or 0 end,
        GetContainerItemQuestInfo=function(_,s) return {
            questID=s==4 and 11 or 12,isQuestItem=true,isActive=s~=3,
        } end,
        GetContainerItemID=function(_,s) if s~=1 or held then return 9100+s end end,
    }
    C_Item={
        GetItemCount=function()return 1 end,
        GetItemSpell=function(i) if i==9101 and warm or i==9103 or i==9104 then return "Use",501 end end,
        RequestLoadItemDataByID=function(i) if i==9101 then requests=requests+1 end end,
    }
    startupWatcher.scripts.OnEvent(startupWatcher,"BAG_UPDATE_DELAYED")
    AT.RefreshQuestHUD()
    assert(not qrow.item.shown and requests==1)
    local before=scans
    AT.RefreshQuestHUD()
    assert(scans==before,"one live inventory scan per invalidation")
    warm=true
    startupWatcher.scripts.OnEvent(startupWatcher,"ITEM_DATA_LOAD_RESULT",9101,true)
    AT.RefreshQuestHUD()
    assert(qrow.item.shown and qrow.item.link=="item:9101")
    assert(not qrow.itemTiles[2].shown,"do not show ordinary collection loot, unaccepted starters, or another quest's item")
    held=false
    startupWatcher.scripts.OnEvent(startupWatcher,"BAG_UPDATE_DELAYED")
    AT.RefreshQuestHUD()
    assert(not qrow.item.shown and requests==1)
    C_Container=oldBags
    startupWatcher.scripts.OnEvent(startupWatcher,"BAG_UPDATE_DELAYED")
    print("PASS live quest item fallback, cold-cache redraw, ownership and one scan per bag invalidation")

    C_QuestLog.GetLogIndexForQuestID,C_QuestLog.IsOnQuest,GetQuestLogSpecialItemInfo,C_Item=oldIndex,oldOn,oldSpecial,oldItem
    AT.RefreshQuestHUD()
end
assert(row.objectives[1].text:find("2/5",1,true) and row.objectives[2].text:find("3/3",1,true))
for i=3,#row.objectives do assert(not row.objectives[i].shown) end

rail.scripts.OnClick(rail)
assert(find("Only in Duskwood"))
map=88;AT.RefreshQuestHUD()
assert(find("Only in Duskwood"),"same parent zone preserves browse")
map=2; AT.RefreshQuestHUD()
assert(find("Only in Duskwood"))
openZones()
local stv=find("Stranglethorn Vale")
assert(stv and stv.kind=="Button");stv.scripts.OnClick(stv)
assert(not find("Only in Duskwood"))
map=1;AT.RefreshQuestHUD(); assert(not find("Only in Duskwood"))
AT.db.questHUDFontOffset=0
local plus,minus=find("+"),find("-");assert(plus and minus)
local qrow=find("Acquired in Stranglethorn")
local before=qrow.h
plus.scripts.OnClick(plus)
assert(AT.db.questHUDFontOffset==1 and qrow.child[1].appliedFont[2]==11 and qrow.item.count.appliedFont[2]==11 and qrow.objectives[2].appliedFont[2]==11)
assert(qrow.h>before and plus.label.appliedFont[2]==11)
minus.scripts.OnClick(minus)
assert(AT.db.questHUDFontOffset==0 and qrow.child[1].appliedFont[2]==10)
local watch
for _,o in ipairs(objs) do if o.scripts.OnEvent then watch=o end end
assert(watch);watch.scripts.OnEvent(watch,"QUEST_ACCEPTED",90);assert(AT.char.zoneQuestOrigins[90]==1)
watch.scripts.OnEvent(watch,"QUEST_TURNED_IN",90);assert(not AT.char.zoneQuestOrigins[90])
local color=find("Map"); assert(color)
entries[5].level=26
function GetQuestDifficultyColor(n) assert(n==26+math.max(0,AT.db.questHUDFontOffset or 0));return {r=1,g=.82,b=.05} end
Enum={RelativeContentDifficulty={Difficult=3}}
C_PlayerInfo={GetContentDifficultyQuestForPlayer=function(q) assert(q==12);return 3 end}
function HaveQuestData(q) return q==12 end
AT.RefreshQuestHUD()
for i,theme in ipairs({"Map","Minimal"}) do
    assert(AT.db.questHUDTheme==i and find(theme)==color)
    assert(find("Rank Quest"),"both themes must say Rank Quest")
    local leveled=find("[26] Acquired in Stranglethorn")
    assert(leveled and leveled.child[1].textColor[2]==.49)
    assert(leveled.badge.text=="#1" and leveled.badge.anchor[1]=="TOPLEFT"
        and leveled.badge.anchor[2]<leveled.title.anchor[2],"order must appear left of title on both themes")
    local atlas={}
    for _,tex in ipairs(textures) do if tex.shown and tex.atlas and tex.atlas~="common-search-magnifyingglass" then atlas[tex.atlas]=true end end
    if theme=="Map" then
        assert(atlas["QuestLog-main-background"] and atlas["questlog-frame"] and atlas["questlog-frame-filigree"])
    else
        assert(not next(atlas),"Questie uses its transparent look, not the native atlas")
      assert(leveled.child[1].appliedFont[2]==10)
      local menu=find("Zones");assert(menu)
      local railFrame=rail.parent.parent.parent
      assert(not railFrame.shown)
      menu.scripts.OnClick(menu)
      assert(railFrame.shown and railFrame.anchor[2]==menu,"popup must originate at top Zones button")
      rail.scripts.OnClick(rail)
      assert(not railFrame.shown and find("Only in Duskwood"))
      AT.BrowseQuestHUD(nil)
    end
    color.scripts.OnClick(color)
end
assert(AT.db.questHUDTheme==1)
function HaveQuestData() return false end
AT.RefreshQuestHUD()
assert(find("[26] Acquired in Stranglethorn").child[1].textColor[2]==.82,"fallback is only used without native cached quest difficulty")
local status=find("In Progress");assert(status and not find("Roomy") and not find("Compact"))
local compactHeight=row.h
AT.db.questHUDCompact=false;AT.RefreshQuestHUD()
assert(row.h==compactHeight,"legacy Roomy setting cannot change density")
row=find("[26] Acquired in Stranglethorn");assert(row.objectives[2].shown)

AT.db.questHUDEnabled=false;AT.RefreshQuestHUD();assert(not hud.shown)
watch.scripts.OnEvent(watch,"QUEST_ACCEPTED",91);assert(not AT.char.zoneQuestOrigins[91])
print("PASS HUD model and real entry points: local/origin/outgoing/destination/POI/unknown, tabs, zone reset, submap, clicks, theme/density, opt-out")


-- All Zones is a real rail control in both themes and reads unique quest IDs.
AT.db.questHUDEnabled=true
AT.RefreshQuestHUD()
local oldReady=C_QuestLog.ReadyForTurnIn
C_QuestLog.ReadyForTurnIn=function(id) return id==13 or oldReady(id) end
AT.RefreshQuestHUD()
local navBefore=AT.GetQuestNavigationID and AT.GetQuestNavigationID()
for _,style in ipairs({"Map","Minimal"}) do
    openZones()
    local here,all=find("Current Zone"),find("All Zones")
    assert(here and all and here.parent==all.parent and here.anchor[5]-all.anchor[5]==26+math.max(0,AT.db.questHUDFontOffset or 0))
    assert(all.parent.shown)
    all.scripts.OnClick(all)
    assert(find("All Zones") and find("Uncertain") and not find("Only in Duskwood") and not find("Hidden"),style.." title:"..tostring((find("All Zones"))).." uncertain:"..tostring((find("Uncertain"))).." dusk:"..tostring((find("Only in Duskwood"))).." hidden:"..tostring((find("Hidden"))))
    local duplicates=0
    for _,o in ipairs(objs) do if o.shown and o.qid==11 then duplicates=duplicates+1 end end
    assert(duplicates==1,"one quest across multiple zones must render once")
    local status=find("In Progress");status.scripts.OnClick(status)
    assert(find("Only in Duskwood") and not find("Uncertain"),"All Zones honors Completed")
    status.scripts.OnClick(status)
    map=2;AT.RefreshQuestHUD();assert(find("All Zones") and find("Uncertain"))
    openZones()
    here.scripts.OnClick(here)
    assert(not find("All Zones") and not find("Uncertain"))
    map=1;AT.RefreshQuestHUD()
    local theme=find(style);theme.scripts.OnClick(theme)
end
C_QuestLog.ReadyForTurnIn=oldReady
AT.RefreshQuestHUD()
assert(not AT.GetQuestNavigationID or AT.GetQuestNavigationID()==navBefore)
AT.db.questHUDEnabled=false;AT.RefreshQuestHUD()
print("PASS All Zones sits below Current Zone, shows deduplicated cross-zone and unassigned rows, respects status and stays selected while traveling")
do
    local search
    for _,o in ipairs(objs) do if o.kind=="EditBox" then search=o;break end end
    find("Zones")
    assert(search and search.points.TOPLEFT[4]==13 and search.points.TOPRIGHT[4]==-13)
    assert(search.points.TOPLEFT[5]==-82 and search.points.TOPRIGHT[5]==-82)
    local oldTheme,oldFont=AT.db.questHUDTheme,AT.db.questHUDFontOffset
    local wasEnabled=AT.db.questHUDEnabled;AT.db.questHUDEnabled=true
    GameFontNormalLarge={GetFont=function() return "Test Map Font",16,"" end}
    -- Force a different cached style before checking both themes.
    AT.db.questHUDFontOffset=4;AT.RefreshQuestHUD()
    for _,theme in ipairs({1,2}) do
        for _,offset in ipairs({-2,0,5}) do
            AT.db.questHUDTheme=theme;AT.db.questHUDFontOffset=offset;AT.RefreshQuestHUD()
            local points=(theme==1 and 16 or 12)+offset
            assert(search.appliedFont[2]==points and search.child[1].appliedFont[2]==points,table.concat({theme,offset,points,search.appliedFont[2],search.child[1].appliedFont[2],tostring(AT.db.questHUDCollapsed),AT.db.questHUDTheme,AT.db.questHUDFontOffset,search.autoTrackFontStyle,tostring(AT.db.questHUDEnabled),tostring(AT.db.enabled)},","))
            assert(search.h>=28 and search.h>=points+12)
        end
    end
    GameFontNormalLarge=nil
    AT.db.questHUDTheme=oldTheme;AT.db.questHUDFontOffset=oldFont;AT.db.questHUDEnabled=wasEnabled;AT.RefreshQuestHUD()
    print("PASS search field and hint match the section title in both themes across the font-size range")
    -- Ensure a case-insensitive partial search can find remote/log-wide rows,
    -- while matching multiple keywords across the title and the zone bucket.
    local originalEnabled=AT.db.questHUDEnabled; AT.db.questHUDEnabled=true
    AT.RefreshQuestHUD()
    AT.BrowseQuestHUD(nil)
    local nav=C_SuperTrack.GetSuperTrackedQuestID()
    find("Zones")
    local toggle,clear
    for _,o in ipairs(objs) do
        if o.icon and o.anchor and o.anchor[5]==-57 then toggle=o end
        if o.kind=="Button" and o.parent==search then clear=o end
    end
    assert(toggle and clear and toggle.shown and not search.shown and not clear.shown)
    local heading=find("Stranglethorn Vale")
    local title; for _, f in ipairs(assert(heading).child) do if f:GetText()=="Stranglethorn Vale" then title=f end end; assert(title)
    local body=search.parent
    local panel=body.parent
    local count,scroll
    for _,o in ipairs(objs) do
        if o.parent==body then
            for _,f in ipairs(o.child) do
                if f.points and f.points.TOPLEFT and f.points.TOPLEFT[5]==-82 then count=f end
            end
            if o.kind=="ScrollFrame" and o.points and o.points.TOPLEFT and o.points.TOPLEFT[5]==-102 then scroll=o end
        end
    end
    -- The count itself is a font string created on the body.
    for _,f in ipairs(body.child) do
        if f.points and f.points.TOPLEFT and f.points.TOPLEFT[5]==-82 then count=f end
    end
    assert(count and scroll)
    local originalWidth,originalTheme,originalFont=panel:GetWidth(),AT.db.questHUDTheme,AT.db.questHUDFontOffset
    for _,theme in ipairs({1,2}) do
        AT.db.questHUDTheme=theme
        AT.db.questHUDFontOffset=5
        for _,width in ipairs({358,414,630}) do
            panel:SetWidth(width); AT.RefreshQuestHUD()
            assert(title:GetWidth()==width-26-toggle:GetWidth()-6)
            assert(13+title:GetWidth()+6==width-13-toggle:GetWidth())
            assert(title:GetUnboundedStringWidth()<=title:GetWidth(),"Stranglethorn Vale must fit at minimum width and largest test font")
            toggle.scripts.OnClick(toggle)
            assert(search.shown and search.focused and not toggle.shown and not clear.shown)
            assert(title:GetText()=="Stranglethorn Vale" and title:GetWidth()==width-26)
            assert(82+search:GetHeight()+6 == -count.points.TOPLEFT[5])
            assert(-scroll.points.TOPLEFT[5] == 102+search:GetHeight()+6)
            search.scripts.OnEscapePressed(search)
            assert(not search.shown and toggle.shown and count.points.TOPLEFT[5]==-82 and scroll.points.TOPLEFT[5]==-102)
        end
    end
    panel:SetWidth(originalWidth)
    AT.db.questHUDTheme,AT.db.questHUDFontOffset=originalTheme,originalFont
    AT.RefreshQuestHUD()
    AT.db.questHUDEnabled=originalEnabled
    print("PASS area heading uses available width; search and quest rows never overlap at minimum, default, or maximum HUD width")
    toggle.scripts.OnClick(toggle)
    assert(search.shown and search.focused and not toggle.shown and not clear.shown)
    AT.db.questHUDEnabled=true
    local nativeGetCount=C_QuestLog.GetNumQuestLogEntries
    C_QuestLog.GetNumQuestLogEntries=function() return #entries,20 end
    AT.RefreshQuestHUD()
    search:SetText("never-matches-any-quest")
    assert(find("0/20 Quests"),"no matches should keep the full native quest count")
    search:SetText("dusk")
    assert(search.shown and clear.shown and find("Search Results"))
    search:SetText("only in duskwood")
    assert(count:GetText()=="1/20 Quests",count:GetText())
    local branch=assert(find("-  Duskwood"))
    branch.scripts.OnClick(branch)
    assert(count:GetText()=="0/20 Quests",count:GetText())
    branch.scripts.OnClick(branch)
    assert(count:GetText()=="1/20 Quests",count:GetText())
    search:SetText("dusk")
    C_QuestLog.GetNumQuestLogEntries=nativeGetCount
    AT.RefreshQuestHUD()
    AT.db.questHUDEnabled=originalEnabled
    GetMouseFoci=function() return {search} end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(search.focused,"click on the search box must retain focus")
    GetMouseFoci=function() return {clear} end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(search.focused,"click on the clear child is not an outside click (its own action clears)")
    GetMouseFoci=function() return {find("Only in Duskwood")} end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","RightButton")
    assert(not search.focused and search.shown and search:GetText()=="dusk" and find("Search Results"))
    search:SetFocus()
    GetMouseFoci=function() return {} end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(not search.focused and search.shown and search:GetText()=="dusk" and find("Search Results"),
        "even a click on the world (no UI focus) releases the typing focus, not the filtered result")
    search:SetFocus()
    assert(search.focused and search:GetText()=="dusk","clicking back may refocus without replacing the query")
    GetMouseFoci=nil
    search.scripts.OnEnterPressed(search)
    AT.RefreshQuestHUD()
    assert(search.shown and not search.focused and clear.shown)
    AT.BrowseQuestHUD(nil)
    assert(search.shown and search:GetText()=="dusk" and find("Search Results"))
    clear.scripts.OnClick(clear)
    assert(not search.shown and toggle.shown and not clear.shown and not find("Search Results"))
    toggle.scripts.OnClick(toggle)
    search:SetText("d"); search:SetText("")
    assert(not search.shown and toggle.shown and not clear.shown and not search.focused)
    toggle.scripts.OnClick(toggle)
    GetMouseFoci=function() return {} end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(not search.focused and not search.shown and toggle.shown,"click-away collapses only empty search")
    GetMouseFoci=nil
    -- Some clicks remove focus before the global mouse event arrives.
    toggle.scripts.OnClick(toggle)
    search.focused=false
    GetMouseFoci=function() return {} end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(not search.shown and toggle.shown,"outside click must close even when focus has already gone")
    GetMouseFoci=nil
    toggle.scripts.OnClick(toggle)
    GetMouseFocus=function() return search end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(search.shown and search.focused,"legacy focus API preserves clicks in the box")
    GetMouseFocus=function() return toggle end
    watch.scripts.OnEvent(watch,"GLOBAL_MOUSE_DOWN","LeftButton")
    assert(not search.shown and toggle.shown,"legacy focus API detects outside clicks")
    GetMouseFocus=nil
    toggle.scripts.OnClick(toggle)
    search.focused=false
    search.scripts.OnEditFocusLost(search)
    assert(not search.shown and toggle.shown,"native focus loss must close empty search")
    toggle.scripts.OnClick(toggle)
    search:SetText("dusk")
    search.focused=false
    search.scripts.OnEditFocusLost(search)
    assert(search.shown and search:GetText()=="dusk" and find("Search Results"),"native focus loss must preserve the query")
    clear.scripts.OnClick(clear)
    toggle.scripts.OnClick(toggle)
    search.scripts.OnEnterPressed(search)
    assert(not search.shown and toggle.shown,"Enter on a blank field also closes it")
    print("PASS search click-away (before/after blur, modern/legacy), native focus loss, text preservation, inside/clear child and refocus")
    toggle.scripts.OnClick(toggle)
    search:SetText("dUsK")
    assert(find("Search Results") and find("Only in Duskwood"))
    local dusk=assert(find("-  Duskwood"))
    assert(tonumber(dusk.total.text)>=2,"search uses matching area for cross-zone quests")
    dusk.scripts.OnClick(dusk)
    assert(find("+  Duskwood") and not find("Only in Duskwood"))
    AT.RefreshQuestHUD()
    assert(find("+  Duskwood") and not find("A flight to Duskwood"),"collapse persists through refresh")
    dusk.scripts.OnClick(dusk)
    assert(find("-  Duskwood") and find("Only in Duskwood"))
    search:SetText("duskwood ONLY")
    assert(find("Only in Duskwood") and not find("A flight to Duskwood"))
    search:SetText("Unknown phrase that is not held")
    assert(find("No matching quests."))
    search.scripts.OnEscapePressed(search)
    assert(not find("Search Results") and not find("Only in Duskwood"))
    assert(C_SuperTrack.GetSuperTrackedQuestID()==nav)
    print("PASS live whole-log search: partial words, case, tokens, remote quests, empty state, Escape and no tracking changes")
    AT.db.questHUDEnabled=true
    AT.db.questHUDCollapsed=true
    AT.RefreshQuestHUD()
    assert(AT.SearchRankQuestItem(13))
    assert(search:GetText()=="Only in Duskwood" and search.shown and not search.focused)
    assert(not AT.db.questHUDCollapsed and find("Only in Duskwood") and not find("A flight to Duskwood"))
    local exactBranch=assert(find("-  Duskwood"))
    exactBranch.scripts.OnClick(exactBranch)
    assert(not find("Only in Duskwood") and find("+  Duskwood"))
    assert(AT.SearchRankQuestItem(13) and find("Only in Duskwood"))
    local flightID
    for _,q in ipairs(entries) do if q.title=="A flight to Duskwood" then flightID=q.questID end end
    assert(flightID and AT.SearchRankQuestItem({[13]=true,[flightID]=true,[99999]=true},"Test shared quest item"))
    assert(search:GetText()=="Test shared quest item" and not search.focused)
    assert(find("Only in Duskwood") and find("A flight to Duskwood") and not find("Quest #99999"))
    search:SetText("dusk")
    assert(find("A flight to Duskwood"),"typing replaces the exact bag-item filter")
    clear.scripts.OnClick(clear)
    assert(not search.shown and C_SuperTrack.GetSuperTrackedQuestID()==nav)
    AT.db.questHUDEnabled=false
    assert(not AT.SearchRankQuestItem(13),"never enable a disabled HUD")
    AT.db.questHUDEnabled=true
    AT.RefreshQuestHUD()
    print("PASS item lookup expands Rank Quest, filters exact quest across zones, releases focus and allows normal search afterward")
end

AT.db.questHUDEnabled=true
for i=1,18 do
    entries[#entries+1]={questID=100+i,title="Overflow quest "..i}
    dest[100+i]=1
    entries[#entries+1]={questID=200+i,title="Remote quest "..i}
    dest[200+i]=i+2
    names[i+2]="Remote zone "..i
end
AT.RefreshQuestHUD()
do
local qscroll,rscroll
for _,o in ipairs(objs) do
    if o.kind=="ScrollFrame" then
        assert(o.template==nil and o.wheel and o.scripts.OnMouseWheel and not o.ScrollBar)
        if not rscroll then rscroll=o else qscroll=o end
    end
end
assert(qscroll and rscroll)
local function checkWheel(scroll)
    scroll.h=95
    assert(scroll.contentHeight>scroll.h)
    scroll.scripts.OnMouseWheel(scroll,-1)
    assert(scroll:GetVerticalScroll()>0)
    scroll.scripts.OnMouseWheel(scroll,-100)
    assert(scroll:GetVerticalScroll()==scroll.contentHeight-scroll.h,"can reach the last row")
    scroll.scripts.OnMouseWheel(scroll,100)
    assert(scroll:GetVerticalScroll()==0)
end
AT.IsRankQuestItemLayoutLocked=function() return true end
qscroll:SetVerticalScroll(12)
qscroll.scripts.OnMouseWheel(qscroll,-1)
assert(qscroll:GetVerticalScroll()==12,"combat cannot scroll out from under a bound item")
AT.BrowseQuestHUD(nil)
assert(qscroll:GetVerticalScroll()==12,"scope changes cannot move the combat layout")
assert(not AT.SearchRankQuestItem(12),"bag search cannot recycle combat quest rows")
AT.IsRankQuestItemLayoutLocked=nil
checkWheel(qscroll)
openZones()
local popup=rscroll.parent
local dropdownBaseHeight=hud:GetHeight()
local dropdownInset=-popup.anchor[5]+popup.anchor[2]:GetHeight()-popup.anchor[2].anchor[5]
assert(rscroll.contentHeight>rscroll:GetHeight())
assert(dropdownInset+popup:GetHeight()==dropdownBaseHeight-3,"overflow reaches the bottom of the log")
local tallHeight=rscroll:GetHeight()
hud:SetHeight(700);hud.scripts.OnSizeChanged();AT.RefreshQuestHUD()
assert(rscroll:GetHeight()>tallHeight and dropdownInset+popup:GetHeight()==697)
checkWheel(rscroll)
hud:SetHeight(dropdownBaseHeight);AT.RefreshQuestHUD()
color.scripts.OnClick(color)
local menu=find("Zones");menu.scripts.OnClick(menu)
checkWheel(rscroll)
qscroll.scripts.OnMouseWheel(qscroll,-100)
for i=#entries,9,-1 do entries[i]=nil end
AT.RefreshQuestHUD()
assert(qscroll:GetVerticalScroll()==math.max(0,qscroll.contentHeight-qscroll.h))
assert(rscroll:GetHeight()==rscroll.contentHeight and rscroll:GetVerticalScroll()==0)
rscroll.scripts.OnMouseWheel(rscroll,-100)
assert(rscroll:GetVerticalScroll()==0 and dropdownInset+popup:GetHeight()<hud:GetHeight()-3,"short list ends after its last row")
print("PASS scrollbar-free list and dropdown; dropdown grows with a resized log, stops at last row, and clamps when content shrinks")
end
-- Exercise the real tracker/HUD interaction, not a stubbed hide predicate.
AT.db.autoFocus=false
AT.db.hideCompleted=true
AT.char.excludedQuests={}
local ready,gameComplete={[16]=true},{}
local nativeWatch={[16]=true,[12]=true,[11]=true}
local removeCount={}
C_QuestLog.ReadyForTurnIn=function(q) return ready[q] end
C_QuestLog.IsComplete=function(q) return gameComplete[q] end
C_QuestLog.IsOnQuest=function(q)
    for _,entry in ipairs(entries) do if entry.questID==q then return true end end
    return false
end
C_QuestLog.GetQuestWatchType=function(q) return nativeWatch[q] and 1 end
C_QuestLog.GetNumQuestWatches=function()
    local n=0;for _ in pairs(nativeWatch) do n=n+1 end;return n
end
C_QuestLog.GetQuestIDForQuestWatchIndex=function(index)
    local ids={};for q in pairs(nativeWatch) do ids[#ids+1]=q end;table.sort(ids);return ids[index]
end
C_QuestLog.RemoveQuestWatch=function(q)
    nativeWatch[q]=nil; removeCount[q]=(removeCount[q] or 0)+1
end
assert(loadfile("NQT/Quests.lua"))("NQT",AT)
AT.RefreshQuests()
AT.BrowseQuestHUD(nil)
AT.RefreshQuestHUD()
assert(not nativeWatch[16] and removeCount[16]==1,"stock watch filtered by native ReadyForTurnIn")
assert(not find("Only local POI"),"ready-to-turn-in HUD row hidden even though it remains in quest log")
assert(find("No NPC metadata") and not nativeWatch[15],"unfinished and unwatched quests still appear")
ready[12]=true; AT.char.excludedQuests[12]=true
gameComplete[11]=1
AT.RefreshQuests()
watch.scripts.OnEvent(watch,"QUEST_COMPLETE")
assert(nativeWatch[12] and not find("[26] Acquired in Stranglethorn"),"completion exclusion keeps watch; status still separates rows")
assert(not nativeWatch[11] and not find("A flight to Duskwood"),"legacy completion signal also hides outgoing quest")
AT.db.hideCompleted=false;AT.RefreshQuestHUD()
assert(not find("Only local POI") and not find("A flight to Duskwood"),"status view is independent of native watch suppression")
status.scripts.OnClick(status)
assert(find("Completed")==status and find("Only local POI") and find("A flight to Duskwood"))
assert(find("[26] Acquired in Stranglethorn") and not find("No NPC metadata"))
status.scripts.OnClick(status)
print("PASS actual tracking/HUD completion: watch removed, HUD visibility, opt-out/exclusions and legacy completion; queue left")
-- Mock the Forever stock per-module topology and its post-layout show.
AT.db.enabled=true
AT.db.questHUDEnabled=true
AT.db.questHUDCollapsed=false
local inCombat,inEdit=false,false
function InCombatLockdown() return inCombat end
EditModeManagerFrame={IsEditModeActive=function() return inEdit end}
local function stock(height,shown)
    local w={height=height,shown=shown,hooks={},alpha=.78}
    function w:IsShown() return self.shown end
    function w:GetAlpha() return self.alpha end
    function w:SetAlpha(a) self.alpha=a end
    function w:Hide() assert(not inCombat,"must defer in combat");self.shown=false end
    function w:Show()
        assert(not inCombat,"must defer in combat")
        self.shown=true
        if self.hooks.OnShow then self.hooks.OnShow() end
    end
    function w:GetContentsHeight() return self.height end
    function w:HookScript(e,f) self.hooks[e]=f end
    return w
end
local scheduled={}
C_Timer={After=function(_,f) scheduled[#scheduled+1]=f end}
local function drain()
    local turns=0
    while #scheduled>0 and turns<20 do local f=table.remove(scheduled,1);f();turns=turns+1 end
    assert(#scheduled==0,"avoid native update loops")
end
function hooksecurefunc(o,key,fn)
    local orig=o[key];o[key]=function(...) orig(...); fn(...) end
end
QuestObjectiveTracker=stock(140,true)
ObjectiveTrackerFrame=stock(160,true)
local achievement=stock(0,false)
ObjectiveTrackerFrame.modules={QuestObjectiveTracker,achievement}
function ObjectiveTrackerFrame:Update()
    if QuestObjectiveTracker.height>0 then
        QuestObjectiveTracker.shown=true
        if QuestObjectiveTracker.hooks.OnShow then QuestObjectiveTracker.hooks.OnShow() end
    end
    self.shown=true
    if self.hooks.OnShow then self.hooks.OnShow() end
end
local bQuestie=stock(200,true)
AT.RefreshQuestHUD()
assert(not ObjectiveTrackerFrame.shown and not QuestObjectiveTracker.shown and bQuestie.shown)
assert(ObjectiveTrackerFrame:GetAlpha()==0 and QuestObjectiveTracker:GetAlpha()==0 and bQuestie:GetAlpha()==.78)
ObjectiveTrackerFrame:Update()
assert(QuestObjectiveTracker:GetAlpha()==0 and ObjectiveTrackerFrame:GetAlpha()==0,"the same layout frame must stay transparent before callbacks")
QuestObjectiveTracker:SetAlpha(.57)
assert(QuestObjectiveTracker:GetAlpha()==0,"native fade requests cannot reintroduce a flash")
drain()
ObjectiveTrackerFrame:Update();drain()
assert(not ObjectiveTrackerFrame.shown and not QuestObjectiveTracker.shown)
achievement.height=40
ObjectiveTrackerFrame:Update();drain()
assert(ObjectiveTrackerFrame.shown and not QuestObjectiveTracker.shown and ObjectiveTrackerFrame:GetAlpha()==.78,"other native content keeps its container")
AT.db.questHUDCollapsed=true;AT.RefreshQuestHUD()
assert(not QuestObjectiveTracker.shown,"collapsed AT HUD remains active")
inCombat=true;AT.db.questHUDEnabled=false;AT.RefreshQuestHUD()
assert(not QuestObjectiveTracker.shown)
inCombat=false;watch.scripts.OnEvent(watch,"PLAYER_REGEN_ENABLED");drain()
assert(QuestObjectiveTracker.shown and ObjectiveTrackerFrame.shown and QuestObjectiveTracker:GetAlpha()==.57,"turning HUD off restores only owned native visibility and latest native alpha")
AT.db.questHUDEnabled=true;inEdit=true;AT.RefreshQuestHUD()
assert(QuestObjectiveTracker.shown)
inEdit=false;AT.RefreshQuestHUD()
assert(not QuestObjectiveTracker.shown)
AT.db.questHUDEnabled=false;QuestObjectiveTracker.height=0;AT.RefreshQuestHUD()
assert(not QuestObjectiveTracker.shown,"do not force display of obsolete stock modules")
print("PASS native quest HUD hide/restore: quest-only plus other objectives, relayout, collapse/combat/edit mode, no foreign changes")

-- Repeated normal HUD Ctrl-clicks enqueue/dequeue three times while native
-- layout shows the stock frame immediately (and before timer callbacks).
AT.db.questHUDEnabled=true
AT.db.questHUDCollapsed=false
AT.db.hideCompleted=false
QuestObjectiveTracker.height=140
AT.RefreshQuestHUD()
local base=AT.ToggleQuestTrackingOrder
AT.ToggleQuestTrackingOrder=function(q)
    local ok,reason=base(q)
    ObjectiveTrackerFrame:Update()
    assert(QuestObjectiveTracker:GetAlpha()==0,"native update triggered by Ctrl-click must not flash")
    return ok,reason
end
for i=1,6 do
    inCombat=i==3 or i==4
    local click=find("No NPC metadata")
    assert(click and click.qid==15)
    click.titleHit.scripts.OnClick(click.titleHit,"LeftButton")
    assert(AT.GetQuestOrderPosition(15)==(i%2==1 and 1 or nil), "real tracking order should alternate correctly")
    assert(QuestObjectiveTracker:GetAlpha()==0 and ObjectiveTrackerFrame:GetAlpha()==.78)
    if inCombat then
        QuestObjectiveTracker:SetAlpha(1)
        assert(QuestObjectiveTracker:GetAlpha()==0,"native alpha update during combat must not flash")
    end
    drain()
end
print("PASS repeated Ctrl-click tracking order, same-frame suppression before timers, combat alpha and unrelated wrapper visibility")
AT.db.questHUDCollapsed=true;AT.RefreshQuestHUD()
assert(find("Rank Quest  +"),"the closed tab must say Rank Quest")
local src=assert(io.open("NQT/Options.lua")):read("*all")
assert(src:find("Enable Rank Quest",1,true) and not src:find("Enable Quest HUD",1,true))
assert(AT.db.questHUDEnabled,"do not rename or reset saved variables")
print("PASS Rank Quest labels in both layouts, collapsed tab and existing setting preservation")
-- Progress and area highlights use real state, safe evidence, and ticker movement.
AT.db.questHUDCollapsed=false
AT.db.hideCompleted=false
ready[15]=nil;gameComplete[11]=nil
local distances={[15]=100,[11]=10000}; local task={}
C_QuestLog.GetDistanceSqToQuest=function(q)
    local v=distances[q]; return v and v*v or nil,v and true or nil
end
GetTaskInfo=function(q) return task[q] end
local count=2
C_QuestLog.GetQuestObjectives=function(q)
    if q==15 then return {{text="Aged Troll Tooth: "..count.."/5",numFulfilled=count,numRequired=5,finished=false}} end
    if q==11 then return {{text="Defias slain: 1/5",numFulfilled=1,numRequired=5,finished=false}} end
end
local ordering=AT.GetQuestOrderPosition(15)
AT.db.questHUDEnabled=false;AT.RefreshQuestHUD()
AT.db.questHUDEnabled=true;AT.RefreshQuestHUD()
local area,progress=AT.GetRankQuestHighlight(15)
assert(area=="near" and not progress,"initial objective read is not a progress update")
assert(find("No NPC metadata").detail.text=="Near an objective")
assert(not AT.GetRankQuestHighlight(11))
-- Quest in another journal zone with a local objective, including under a roof.
local oldIndoors,oldInstance=IsIndoors,IsInInstance
IsIndoors=function() return true end
IsInInstance=function() return false,"none" end
distances[13]=100;areaTick()
assert(AT.GetRankQuestHighlight(13)=="near","movement samples objectives even if journal grouped them elsewhere")
distances[13]=240;areaTick()
assert(not AT.GetRankQuestHighlight(13),"movement clears newly distant objective")
IsInInstance=function() return true,"party" end
distances[13]=100;areaTick()
assert(not AT.GetRankQuestHighlight(13),"a dungeon must not reuse outdoor distances")
local oldSize,oldPos,oldWP=C_Map.GetMapWorldSize,C_Map.GetPlayerMapPosition,C_QuestLog.GetNextWaypoint
IsInInstance=function() return false,"none" end
C_Map.GetMapWorldSize=function(z) if z==1 then return 1000,1000 end end
C_Map.GetPlayerMapPosition=function(z) if z==1 then return { GetXY=function() return .5,.5 end } end end
C_QuestLog.GetNextWaypoint=function(q) if q==13 then return 1,.51,.5 elseif oldWP then return oldWP(q) end end
distances[13]=nil;map=88;areaTick()
assert(AT.GetRankQuestHighlight(13)=="near","micro map uses verified parent-zone waypoint geometry")
C_Map.GetMapWorldSize,C_Map.GetPlayerMapPosition,C_QuestLog.GetNextWaypoint=oldSize,oldPos,oldWP
map=1;AT.RefreshQuestHUD()
IsIndoors,IsInInstance=oldIndoors,oldInstance;distances[13]=nil
task[11]=true;areaTick()
assert(AT.GetRankQuestHighlight(11)=="inside" and find("A flight to Duskwood").detail.text~="In quest area")
count=3; AT.RefreshQuestHUD()
assert(select(2,AT.GetRankQuestHighlight(15)) and find("No NPC metadata").detail.text:match("Progress updated"))
distances[15]=115;areaTick()
assert(select(2,AT.GetRankQuestHighlight(15)),"nearby hysteresis preserves progress just beyond entry")
distances[15]=nil;areaTick()
assert(select(2,AT.GetRankQuestHighlight(15)),"brief unreadable location does not clear progress")
distances[15]=240;areaTick()
assert(not AT.GetRankQuestHighlight(15) and not select(2,AT.GetRankQuestHighlight(15)),"known departure clears highlight")
distances[15]=99;areaTick()
assert(AT.GetRankQuestHighlight(15)=="near" and not select(2,AT.GetRankQuestHighlight(15)),"re-entry restores area but not old progress")
ready[15]=true;AT.RefreshQuestHUD()
assert(AT.GetRankQuestHighlight(15)=="near" and not find("No NPC metadata"),"a ready quest leaves In Progress but keeps native proximity for Completed")
status.scripts.OnClick(status)
assert(find("No NPC metadata").detail.text:find("Ready to turn in",1,true),find("No NPC metadata").detail.text)
status.scripts.OnClick(status)
assert(AT.GetQuestOrderPosition(15)==ordering,"visual state never changes order")
distances[11]=nil;task[11]=false;areaTick()
assert(AT.GetRankQuestHighlight(11)=="inside","one lost native area flag is not confirmed departure")
areaTick();assert(not AT.GetRankQuestHighlight(11),"repeated negative after native positive clears area")
distances[11]=0;areaTick();assert(not AT.GetRankQuestHighlight(11),"unknown native zero is not area membership")
print("PASS quest log highlights: true progress, overlapping verified quests, movement/uncertainty, departure/re-entry and completion; leaves queue untouched")
-- The real same display controls in both themes must retain the browsed zone
-- and show untracked objective-complete quests, not turned-in history.
ready[15]=nil; gameComplete[11]=true; ready[12]=true; ready[16]=true
AT.db.hideCompleted=true
AT.ResetTrackingOrder()
AT.RefreshQuests()
AT.RefreshQuestHUD()
local function clickButton(label)
    local b=find(label);assert(b and b.kind=="Button",label);b.scripts.OnClick(b)
end
AT.db.questHUDTheme=1
AT.db.questHUDFontOffset=5
hud.w=358
AT.RefreshQuestHUD()
entries[3].suggestedGroup=3
Enum.QuestTag={Group=1}
C_QuestLog.GetQuestTagInfo=function(q) if q==11 then return {tagID=1} end end
AT.RefreshQuestHUD()
local selection=selected
local watch16=removeCount[16]
for _,theme in ipairs({"Map","Minimal"}) do
    assert(find(theme))
    local filter=find("In Progress")
    assert(filter.w>=filter.label:GetUnboundedStringWidth()+14 and filter.label.appliedFont[2]==15)
    assert(find("In Progress") and find("No NPC metadata") and not find("Only local POI"))
    local areaQuest=find("No NPC metadata")
    assert(areaQuest.groupIcon.shown and areaQuest.groupIcon.texture:match("_8$") and areaQuest.groupSize==3)
    AT.ToggleQuestTrackingOrder(15);AT.RefreshQuestHUD()
    areaQuest=find("No NPC metadata")
    assert(areaQuest.badge.shown and areaQuest.badge.anchor[2]<areaQuest.groupIcon.anchor[4]
        and areaQuest.groupIcon.anchor[4]<areaQuest.title.anchor[2],"group icon must not overwrite number")
    AT.ToggleQuestTrackingOrder(15);AT.RefreshQuestHUD()
    AT.BrowseQuestHUD(2)
    assert(find("Only in Duskwood") and not find("Only local POI"))
    clickButton("In Progress")
    assert(filter.w>=filter.label:GetUnboundedStringWidth()+14)
    assert(find("Completed") and find("A flight to Duskwood") and not find("Only local POI"))
    assert(find("A flight to Duskwood").groupIcon.shown,"explicit group tag survives transition to Completed")
    assert(not find("[26] Acquired in Stranglethorn").groupIcon.shown,"difficulty is not a group flag")
    assert(find("2/6 Quests"),"count is scoped to completed rows in the browsed zone")
    AT.BrowseQuestHUD(nil)
    assert(find("Only local POI") and find("3/6 Quests"),"native-untracked completed row appears by origin zone")
    clickButton("Completed")
    assert(find("No NPC metadata"))
    clickButton(theme)
end
assert(selected==selection and removeCount[16]==watch16)
-- A turned-in quest is absent from both views.
for i,entry in ipairs(entries) do if entry.questID==16 then table.remove(entries,i);break end end
AT.RefreshQuestHUD(); clickButton("In Progress")
assert(not find("Only local POI") and find("2/5 Quests"))
print("PASS actual status toggle in Map/Minimal, selected zones/count, preserves spacing/watch selection, completed untracked and turned-in excluded")
clickButton("Completed")
gameComplete[11]=nil
distances[15]=10000
AT.LevelGuideQuestGivers={[11]={{1,.50,.50,0,77,"Starter",0}},[15]={{1,.50,.50,0,77,"Starter",0}}}
AT.db.questHUDTheme=1;AT.db.questHUDFontOffset=0
AT.RefreshQuestHUD()
for _,theme in ipairs({"Map","Minimal"}) do
    assert(find(theme))
    local localQuest=find("No NPC metadata")
    assert(localQuest and not localQuest.detail.shown and localQuest.detail.text=="")
    assert(localQuest.objectives[1].anchor[3]==-24,"objectives move up without an empty subtitle")
    assert(find("A flight to Duskwood").detail.text=="Leads to Duskwood","cross-zone origin grouping and useful detail remain")
    local remote=AT.BuildQuestHUDModel(2,"Duskwood")
    assert(remote.zones[1].rows[15].kind=="origin","origin remains assigned to its zone")
    clickButton(theme)
end
print("PASS Starts here removed and row reflowed in Map/Minimal, with original grouping and outgoing labels retained")
distances[15]=100
count=count+1
AT.RefreshQuestHUD()
assert(find("No NPC metadata").detail.text=="Progress updated","no trailing separator when origin subtitle removed")

ready[12]=nil
local originalObjectives=C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives=function(q)
    if q==12 then return {{text="Test objective: 1/2",numFulfilled=1,numRequired=2,finished=false}} end
    return originalObjectives(q)
end
dest[12]=1
AT.RefreshQuestHUD()
for _,theme in ipairs({"Map","Minimal"}) do
    assert(find(theme))
    local localQuest=find("[26] Acquired in Stranglethorn")
    assert(localQuest and not localQuest.detail.shown and localQuest.detail.text=="")
    assert(localQuest.objectives[1].anchor[3]==-24,"recorded origin no longer adds an empty row")
    local record=AT.BuildQuestHUDModel(2,"Duskwood")
    assert(record.zones[1].rows[12].kind=="recorded","hide a label without losing recorded origin")
    clickButton(theme)
end
dest[12]=2;AT.RefreshQuestHUD()
assert(find("[26] Acquired in Stranglethorn").detail.text=="Leads to Duskwood","recorded origins still show relevant destination")
print("PASS Accepted here removed with no blank line in Map/Minimal; recorded origins and departure text retained")

-- Circle is a separate click target. Actual nav selection sticks over queue
-- head without mutating queue numbering; plain title opens the map only.
AT.ResetTrackingOrder()
AT.db.questHUDEnabled=true;AT.db.hideCompleted=true
gameComplete[11]=nil; ready[15]=nil;ready[12]=nil
AT.char.excludedQuests={}
local refreshedRoute
AT.RefreshQuestRoute=function() refreshedRoute=AT.GetQuestNavigationID() end
C_QuestLog.AddQuestWatch=function() return false end -- saturated native tracker
assert(AT.ToggleQuestTrackingOrder(11))
assert(AT.GetQuestNavigationID()==11 and AT.GetQuestOrderPosition(11)==1)
AT.db.questHUDTheme=1
for _,theme in ipairs({"Map","Minimal"}) do
    AT.RefreshQuestHUD()
    local qrow=find("No NPC metadata");assert(qrow and qrow.circle.available)
    local priorOpen=opened
    qrow.circle.scripts.OnClick(qrow.circle)
    drain()
    qrow=find("No NPC metadata")
    local active,source=AT.GetQuestNavigationID()
    assert(active==15 and source=="hud" and refreshedRoute==15 and qrow.circle.dot.shown)
    assert(opened==priorOpen and AT.GetQuestOrderPosition(11)==1 and not AT.GetQuestOrderPosition(15))
    AT.RefreshQuests();assert(AT.GetQuestNavigationID()==15)
    ctrl=false
    local queueRow=find("A flight to Duskwood")
    queueRow.titleHit.scripts.OnClick(queueRow.titleHit,"LeftButton")
    assert(opened==11 and AT.GetQuestNavigationID()==15 and not queueRow.circle.dot.shown)
    assert(queueRow.circle.anchor[4]<queueRow.badge.anchor[2] and queueRow.badge.anchor[2]<queueRow.title.anchor[2])
    ctrl=true;qrow.titleHit.scripts.OnClick(qrow.titleHit,"LeftButton");drain()
    assert(AT.GetQuestOrderPosition(15)==2 and AT.GetQuestNavigationID()==15)
    qrow=find("No NPC metadata");qrow.titleHit.scripts.OnClick(qrow.titleHit,"LeftButton");drain()
    assert(not AT.GetQuestOrderPosition(15))
    qrow=find("No NPC metadata");qrow.circle.scripts.OnClick(qrow.circle);drain()
    assert(AT.GetQuestNavigationID()==11)
    clickButton(theme)
end
local native=C_QuestLog.GetQuestsOnMap
local showFinisher=true
C_QuestLog.GetQuestsOnMap=function(m)
    local rows=native(m) or {}
    if m==1 then
        rows[#rows+1]={questID=15,x=.12,y=.2,isQuestStart=true,inProgress=false}
        rows[#rows+1]={questID=15,x=.32,y=.3,isQuestStart=false,inProgress=true}
        if showFinisher then rows[#rows+1]={questID=15,x=.8,y=.6,isQuestStart=false,inProgress=false} end
    end
    return rows
end
local prevDest=C_QuestLog.GetNextWaypoint
C_QuestLog.GetNextWaypoint=function(q) if q==15 then return 1,.32,.30 end return prevDest(q) end
local qrow=find("No NPC metadata");qrow.circle.scripts.OnClick(qrow.circle);drain()
ready[15]=true;AT.RefreshQuests();AT.RefreshQuestHUD()
assert(not AT.GetQuestHUDManualFocus() and AT.GetQuestNavigationID()==11,"manual in-progress focus ends when objectives complete")
clickButton("In Progress")
qrow=find("No NPC metadata");qrow.circle.scripts.OnClick(qrow.circle);drain()
assert(AT.GetQuestHUDManualFocus()==15 and AT.GetQuestNavigationID()==15,"explicit selection of a ready quest still navigates to turn-in")
clickButton("Completed")
local q,m,x,y=AT.GetFocusedQuestRoutePoint()
assert(q==15 and m==1 and x==.8 and y==.6,"finished native POI beats stale objective waypoint and starter")
local _,pins=AT.GetFocusedQuestRouteTargets(1);assert(#pins==1 and pins[1].x==.8)
-- The Completed view resolves destinations without selecting the quest.
do
    local savedObjectives=C_QuestLog.GetQuestObjectives
    C_QuestLog.GetQuestObjectives=function(q)
        if q==15 then return {{text="Old finished checklist",finished=true}} end
        return savedObjectives(q)
    end
    clickButton("In Progress")
    qrow=find("No NPC metadata");qrow.circle.scripts.OnClick(qrow.circle);drain()
    local previousNavigation=AT.GetQuestNavigationID()
    for _,theme in ipairs({"Map","Minimal"}) do
        local row=find("No NPC metadata")
        assert(row and row.detail.text=="Ready to turn in", "plain ready status")
        assert(row.objectives[1].shown and row.objectives[1].text:find("80.0, 60.0",1,true), "show native map coordinates even when not focused")
        for _,line in ipairs(row.objectives) do
            assert(not line.shown or not line.text:find("Old finished checklist",1,true))
        end
        assert(AT.GetQuestNavigationID()==previousNavigation and not AT.GetQuestHUDManualFocus())
        clickButton(theme)
    end
    showFinisher=false;AT.RefreshQuestHUD()
    local row=find("No NPC metadata")
    assert(row.detail.text=="Ready to turn in" and (not row.objectives[1] or not row.objectives[1].shown),"missing data must not retain old coordinates or reuse objective coordinates")
    showFinisher=true;AT.RefreshQuestHUD()
    qrow=find("No NPC metadata");qrow.circle.scripts.OnClick(qrow.circle);drain()
    clickButton("Completed")
    C_QuestLog.GetQuestObjectives=savedObjectives
    print("PASS completed view in both themes: no old checklist, uses exact native coordinates without altering tracking, and clears stale data")
end
showFinisher=false
local _,unknown=AT.GetFocusedQuestRoutePoint();assert(not unknown,"without a known finisher do not reuse objective")
local originalTurnIns,originalLocale=AT.ObservedQuestTurnIns,GetLocale
GetLocale=function() return "enUS" end
AT.ObservedQuestTurnIns={[15]={{1,.76,.58,1,12345,0,"Finishing NPC"}}}
local finisherMap,tx,ty=AT.GetQuestTurnInPoint(15)
assert(finisherMap==1 and tx==.76 and ty==.58,"confirmed bundled finisher fallback")
do
    clickButton("In Progress")
    local savedMacroBuilder=AT.GetRankQuestNPCMacro
    AT.GetRankQuestNPCMacro=function(n) return n=="Finishing NPC" and "native macro" end
    AT.RefreshQuestHUD()
    local named=find("No NPC metadata")
    assert(named.objectives[1].shown and named.objectives[1].text=="Stranglethorn Vale  |  76.0, 58.0"
        and named.objectives[2].shown and named.objectives[2].text=="Finishing NPC","area and coords above NPC name")
    local lastOpened=opened
    assert(named.turnInLabel==named.npcHit and named.turnInName=="Finishing NPC","secure binding uses a button, not a text region")
    assert(named.npcHit.shown and named.npcHit.parent==named and named.npcHit.anchor[2]==named)
    assert(named.titleHit.anchor[2]==named and named.npcHit.anchor[5]<named.titleHit.anchor[5])
    named.npcHit.scripts.OnClick(named.npcHit,"LeftButton")
    named.scripts.OnClick(named,"LeftButton")
    assert(opened==lastOpened,"neither NPC nor row background may open map")
    ctrl=false
    named.titleHit.scripts.OnClick(named.titleHit,"LeftButton")
    assert(opened==15,"title still opens quest")
    opened=lastOpened
    showFinisher=true;AT.RefreshQuestHUD()
    named=find("No NPC metadata")
    assert(not named.objectives[2].shown,"never attach a name to a different destination")
    showFinisher=false
    clickButton("Completed")
    AT.GetRankQuestNPCMacro=savedMacroBuilder
    print("PASS named finisher uses dedicated click hitbox and quest title still opens map")
end
AT.ObservedQuestTurnIns,GetLocale=originalTurnIns,originalLocale
do
    local function hasTurnInLine(row,value)
        for _,label in ipairs(row.objectives) do
            if label.shown and label.text==value then return true end
        end
        return false
    end
    local qid=15
    local prev=AT.GetReadyQuestTurnInArea
    local own=C_QuestLog.IsOnQuest
    local readyFor=C_QuestLog.ReadyForTurnIn
    local native=C_QuestLog.GetQuestsOnMap
    C_QuestLog.IsOnQuest=function(q) if q==qid then return true end return own(q) end
    C_QuestLog.ReadyForTurnIn=function(q) return q==qid or readyFor(q) end
    C_QuestLog.GetQuestsOnMap=function() return {} end
    local object=false
    AT.GetReadyQuestTurnInArea=function(q)
        if q==qid then return "An Instance Floor",object and "A Quest Chest" or "A Verified Finisher",not object end
    end
    clickButton("In Progress")
    local row=assert(find("No NPC metadata"),"completed entry visible")
    assert(hasTurnInLine(row,"An Instance Floor") and hasTurnInLine(row,"A Verified Finisher") and row.npcHit.shown)
    object=true;AT.RefreshQuestHUD()
    row=assert(find("No NPC metadata"))
    assert(hasTurnInLine(row,"A Quest Chest") and not row.npcHit.shown,"objects don't get NPC targeting")
    AT.GetReadyQuestTurnInArea=prev
    C_QuestLog.IsOnQuest,C_QuestLog.ReadyForTurnIn,C_QuestLog.GetQuestsOnMap=own,readyFor,native
    clickButton("Completed")
    print("PASS completed Rank Quest row shows instance area and named NPC/object without fake coordinates")
end
showFinisher=true
do
    local oldNav=AT.GetQuestNavigationID
    AT.GetQuestNavigationID=function()return 15,"nearby-turn-in" end
    AT.RefreshQuestHUD()
    assert(find("Completed") and find("No NPC metadata"),"automatic turn-in switches to and renders Completed")
    AT.GetQuestNavigationID=function()return 11,"nearby" end
    AT.RefreshQuestHUD()
    assert(find("In Progress") and not find("No NPC metadata"),"exiting automatic turn-in returns to In Progress")
    AT.GetQuestNavigationID=oldNav
end
clickButton("In Progress")
for _,theme in ipairs({"Map","Minimal"}) do
    qrow=find("No NPC metadata");assert(qrow.circle.available and qrow.circle.dot.shown)
    qrow.circle.scripts.OnClick(qrow.circle);drain()
    assert(AT.GetQuestNavigationID()==11)
    qrow=find("No NPC metadata");qrow.circle.scripts.OnClick(qrow.circle);drain()
    assert(AT.GetQuestNavigationID()==15 and AT.IsQuestTurnInNavigation(15))
    clickButton(theme)
end
local questEngineFrame
local originalQuestTicker=C_Timer.NewTicker
C_Timer.NewTicker=function() end
AT.InitQuests()
C_Timer.NewTicker=originalQuestTicker
for i=#objs,1,-1 do if objs[i].scripts.OnEvent then questEngineFrame=objs[i];break end end
questEngineFrame.scripts.OnEvent(questEngineFrame,"QUEST_TURNED_IN",15);drain()
assert(not AT.GetQuestHUDManualFocus() and AT.GetQuestNavigationID()==11,"turn-in event unpins, returns to existing queue")

-- A Blizzard-focused turn-in can forward to the already loaded Quest POI map.
local savedOrder,savedSelected=AT.char.trackingOrder,selected
local savedOnQuest=C_QuestLog.IsOnQuest
local savedPOIMap=C_QuestLog.GetMapForQuestPOIs
AT.char.trackingOrder={}
selected=13;ready[13]=true
C_QuestLog.IsOnQuest=function(q) if q==13 then return true end return savedOnQuest(q) end
C_QuestLog.GetMapForQuestPOIs=function() return 2 end
C_QuestLog.GetNextWaypoint=function(q) if q==13 then return 1,.3,.3 end return prevDest(q) end
C_QuestLog.GetQuestsOnMap=function(m)
    if m==2 then return {{questID=13,x=.45,y=.55,isQuestStart=false,inProgress=false}} end
    return native(m)
end
local nativeQ,source=AT.GetQuestNavigationID()
assert(nativeQ==13 and source=="turn-in" and AT.IsQuestTurnInNavigation(13))
local nativeID,turnMap,turnX,turnY=AT.GetFocusedQuestRoutePoint()
assert(nativeID==13 and turnMap==2 and turnX==.45 and turnY==.55,
    "stale objective hint must not block the turn-in on the POI map")
AT.char.trackingOrder,selected=savedOrder,savedSelected
ready[13]=nil
C_QuestLog.IsOnQuest=savedOnQuest
C_QuestLog.GetMapForQuestPOIs=savedPOIMap
print("PASS stock-focused ready quest resolves exact turn-in on the loaded POI map")
C_QuestLog.GetQuestsOnMap=native;C_QuestLog.GetNextWaypoint=prevDest
print("PASS sticky manual completed tracking both themes, finished native POI, bundled finisher, no guessed location, queue preserved, turn-in clears")
clickButton("Completed")
ready[15]=nil
local baseMap=C_Map.GetMapInfo
C_Map.GetMapInfo=function(i)
    if i==1 or i==2 then local z=baseMap(i);z.parentMapID=999;return z end
    if i==999 then return {mapID=999,mapType=1,name="World"} end
    if i==500 then return {mapID=500,mapType=4,name="Deadmines",parentMapID=1} end
    if i==501 then return {mapID=501,mapType=4,name="West Wing",parentMapID=500} end
    if i==510 then return {mapID=510,mapType=4,name="Stockade",parentMapID=1} end
    if i==520 then return {mapID=520,mapType=4,name="Raid Keep",parentMapID=2} end
    if i==530 then return {mapID=530,mapType=4,name="Empty Dungeon",parentMapID=1} end
    return baseMap(i)
end
C_Map.GetMapChildrenInfo=function(root,t,deep)
    assert(root==999 and t==4 and deep)
    local children={}
    for _,i in ipairs({500,501,510,520,530}) do children[#children+1]=C_Map.GetMapInfo(i) end
    return children
end
Enum.QuestTag.Raid=62;Enum.QuestTag.Dungeon=81
C_QuestLog.GetQuestTagInfo=function(q)
    if q==306 then return {tagID=62} end
    if q==301 or q==302 or q==307 then return {tagID=81} end
end
entries[#entries+1]={isHeader=true,title="Deadmines"}
entries[#entries+1]={questID=301,title="Quest categorized under dungeon"}
dest[301]=1 -- turn-in or destination out of the instance
entries[#entries+1]={isHeader=true,title="Travel"}
entries[#entries+1]={questID=302,title="Quest inside dungeon subfloor"}
dest[302]=501;ready[302]=true
entries[#entries+1]={questID=303,title="Quest in the Stockade"}
dest[303]=510
entries[#entries+1]={questID=305,title="Outdoor elite group",suggestedGroup=5}
dest[305]=1
entries[#entries+1]={questID=306,title="Raid quest"}
dest[306]=520
entries[#entries+1]={questID=307,title="Dungeon with no known name"}
dest[307]=1
AT.RefreshQuestHUD()
local model=AT.BuildQuestHUDModel(1,"Stranglethorn Vale")
assert(model.dungeons.Deadmines.rows[301] and model.dungeons.Deadmines.rows[302])
assert(model.dungeons.Stockade.rows[303] and not model.dungeons["Raid Keep"] and not model.dungeons["Empty Dungeon"])
assert(not model.dungeons.Deadmines.rows[305] and not model.dungeons.Deadmines.rows[307])
local prevNav=AT.GetQuestNavigationID();local priorOpening=opened
for _,style in ipairs({"Map","Minimal"}) do
    assert(find(style))
    local zoneButton=find("Zones")
    assert(not find("Dungeons"),"only one filter control")
    local oldWidth,oldFont=hud:GetWidth(),AT.db.questHUDFontOffset
    hud:SetWidth(358);AT.db.questHUDFontOffset=5;AT.RefreshQuestHUD()
    local shareButton=plus.anchor[2]; local guideButton=shareButton.anchor[2]
    assert(plus.anchor[1]=="RIGHT" and plus.anchor[3]=="LEFT" and plus.anchor[4]<0 and plus.anchor[5]==0)
    assert(guideButton.anchor[2]==zoneButton and guideButton.anchor[3]=="LEFT")
    local openedGuide=false;AT.ToggleLevelGuide=function() openedGuide=true end
    guideButton.scripts.OnClick(guideButton);assert(openedGuide);AT.ToggleLevelGuide=nil
    assert(minus.anchor[1]=="RIGHT" and minus.anchor[2]==plus and minus.anchor[3]=="LEFT" and minus.anchor[4]<0 and minus.anchor[5]==0)
    assert(zoneButton.anchor[5]==-35)
    for _,b in ipairs({minus,plus,zoneButton,guideButton,shareButton}) do
        assert(b:GetFrameLevel()>2 and b.label:GetUnboundedStringWidth()<b:GetWidth())
    end
    assert(358-13-zoneButton.w-5-guideButton.w-4-shareButton.w-4-plus.w-4-minus.w>90,"count area stays clear")
    minus.scripts.OnClick(minus);assert(AT.db.questHUDFontOffset==4)
    plus.scripts.OnClick(plus);assert(AT.db.questHUDFontOffset==5)
    hud:SetWidth(oldWidth);AT.db.questHUDFontOffset=oldFont;AT.RefreshQuestHUD()
    clickButton("Zones")
    local menu=find("Deadmines");assert(menu and menu.kind=="Button" and find("Stockade"))
    local first,second,third=find("Current Zone"),find("All Zones"),find("All Dungeons")
    assert(first.parent==second.parent and second.parent==third.parent)
    assert(third.questCount.text=="3" and menu.questCount.text=="2" and find("Stockade").questCount.text=="1")
    assert(second.questCount.text==tostring(model.total))
    local currentCount=0
    for _,entry in pairs(model.zones[1].rows) do if not entry.row.partyOnly then currentCount=currentCount+1 end end
    assert(first.questCount.text==tostring(currentCount))
    local dusk=find("Duskwood")
    if dusk then
        local count=0
        for _,entry in pairs(model.zones[2].rows) do if not entry.row.partyOnly then count=count+1 end end
        assert(dusk.questCount.text==tostring(count))
    end
    assert(menu.questCount.anchor[1]=="RIGHT" and menu.questCount.anchor[2]==menu
        and menu.label:GetWidth()+menu.questCount:GetWidth()<menu:GetWidth())
    assert(first.anchor[5]>second.anchor[5] and second.anchor[5]>third.anchor[5])
    assert(find("ZONES") and find("DUNGEONS") and menu.parent.parent.parent==first.parent)
    assert(not find("Empty Dungeon") and not find("Raid Keep") and not find("West Wing"))
    menu.scripts.OnClick(menu)
    assert(find("Quest categorized under dungeon") and not find("Quest inside dungeon subfloor") and not find("Outdoor elite group"))
    clickButton("In Progress")
    assert(find("Quest inside dungeon subfloor") and not find("Quest categorized under dungeon"))
    clickButton("Zones")
    assert(not find("All zones"))
    clickButton("All Dungeons")
    assert(find("All Dungeons") and not menu.parent.parent.parent.shown and find("Quest inside dungeon subfloor"))
    local branch=assert(find("-  Deadmines"));assert(branch.total.text=="1")
    branch.scripts.OnClick(branch)
    assert(find("+  Deadmines") and not find("Quest inside dungeon subfloor"))
    branch.scripts.OnClick(branch)
    assert(find("-  Deadmines") and find("Quest inside dungeon subfloor"))
    assert(not find("Quest categorized under dungeon") and not find("Outdoor elite group"))
    clickButton("Completed")
    assert(find("Quest categorized under dungeon") and find("Quest in the Stockade") and not find("Outdoor elite group"))
    local stockReady=ready[303]
    ready[303]=true;AT.RefreshQuestHUD()
    clickButton("Zones");clickButton("Stockade")
    assert(find("Completed") and find("Quest in the Stockade") and not find("Quest inside dungeon subfloor"))
    clickButton("Completed");AT.RefreshQuestHUD()
    assert(find("In Progress") and not find("Quest in the Stockade"),"manual status remains even on refresh")
    clickButton("Zones");clickButton("Deadmines")
    assert(find("In Progress") and find("Quest categorized under dungeon"),"mixed dungeon stays in progress")
    ready[303]=stockReady;AT.RefreshQuestHUD()
    AT.BrowseQuestHUD(nil)
    assert(find("Outdoor elite group"))
    clickButton(style)
end
assert(AT.GetQuestNavigationID()==prevNav and opened==priorOpening,"filter only changes displayed rows")
print("PASS both dungeon dropdowns: header and nested floor grouping, exact raid/group exclusions, held instances only, automatic status and All Dungeons")
local savedPOI=C_QuestLog.GetQuestsOnMap
entries[#entries+1]={questID=309,title="Dungeon POI without waypoint"}
C_QuestLog.GetQuestsOnMap=function(query)
    if query==500 then return {{questID=309,x=.4,y=.45}} end
    return savedPOI(query)
end
map=500; IsInInstance=function() return true,"party" end
assert(AT.BuildQuestHUDModel(1,"Stranglethorn Vale").dungeons.Deadmines.rows[309])
IsInInstance=function() return true,"raid" end
assert(not AT.BuildQuestHUDModel(1,"Stranglethorn Vale").dungeons.Deadmines.rows[309])
print("PASS current instance quest POI classification does not treat raid position as dungeon")

do
    local baselineMap,baselineInstance,baselineInfo=map,IsInInstance,GetInstanceInfo
    local function checkDungeon()
        assert(find("Deadmines") and find("Quest categorized under dungeon") and find("Dungeon POI without waypoint"))
        assert(not find("Quest in the Stockade") and not find("Outdoor elite group"))
    end
    for _,style in ipairs({"Map","Minimal"}) do
        IsInInstance=function() return true,"party" end
        map=500
        AT.BrowseQuestHUD(nil);AT.RefreshQuestHUD()
        checkDungeon()
        clickButton("In Progress")
        assert(find("Quest inside dungeon subfloor") and not find("Quest categorized under dungeon"))
        clickButton("Completed")
        map=501;AT.RefreshQuestHUD();checkDungeon()
        openZones()
        clickButton("All Zones")
        assert(find("All Zones") and find("Outdoor elite group") and find("Quest in the Stockade"))
        local zoneBranch=assert(find("-  Stranglethorn Vale"))
        zoneBranch.scripts.OnClick(zoneBranch)
        assert(find("+  Stranglethorn Vale") and not find("Outdoor elite group"))
        assert(find("Quest categorized under dungeon") and find("Quest in the Stockade"),
            "collapsing pickup zone must not hide dungeon rows")
        zoneBranch.scripts.OnClick(zoneBranch)
        assert(find("-  Stranglethorn Vale") and find("Outdoor elite group"))
        local savedNavigation=AT.GetQuestNavigationID
        AT.GetQuestNavigationID=function() return 301 end
        AT.RefreshQuestHUD()
        local deadmines=assert(find("-  Deadmines"))
        deadmines.scripts.OnClick(deadmines)
        assert(not find("Quest categorized under dungeon") and find("Quest in the Stockade"),
            "a dungeon row only belongs under its own branch")
        deadmines.scripts.OnClick(deadmines)
        assert(find("Quest categorized under dungeon"))
        AT.GetQuestNavigationID=savedNavigation
        clickButton("In Progress")
        assert(find("Quest inside dungeon subfloor") and find("-  Deadmines"),"completed dungeon quest keeps its branch")
        clickButton("Completed")
        IsInInstance=function() return false,"none" end
        map=1;AT.RefreshQuestHUD()
        assert(find("All Zones"))
        openZones()
        clickButton("Current Zone")
        assert(find("Stranglethorn Vale") and find("Outdoor elite group"))
        clickButton(style)
    end
    map=1
    IsInInstance=function() return true,"party" end
    GetInstanceInfo=function() return "Deadmines" end
    AT.RefreshQuestHUD()
    assert(find("Quest categorized under dungeon") and not find("Outdoor elite group"),"exact instance name works before floor API")
    GetInstanceInfo=function() return "No matching dungeon" end
    AT.RefreshQuestHUD()
    assert(find("No quests in progress for this dungeon.") and not find("Outdoor elite group"),"never fall through to outdoor quests")
    map,IsInInstance,GetInstanceInfo=baselineMap,baselineInstance,baselineInfo
    AT.RefreshQuestHUD()
    print("PASS Current Zone tracks exact instanced dungeon and nested floors in both themes, keeps status and All Zones independent, and never leaks outdoor quests")
end


-- Reproduce fresh account: no loaded Questie, current map/quest log arrives
-- after first render, native headers hide two held quests from visible rows.
Questie=nil;QuestieLoader=nil;AT.char.zoneQuestOrigins={}
IsInInstance=function() return false,"none" end
AT.db.questHUDTheme=1;AT.db.questHUDEnabled=false;AT.RefreshQuestHUD()
local sections={
    {name="Elwynn Forest",key=100,collapsed=true,quests={{questID=5010,title="Forest hidden quest"}}},
    {name="Hillsbrad Foothills",key=200,collapsed=true,quests={{questID=5030,title="Hillsbrad hidden quest"}}},
    {name="Trade Skills",key=300,collapsed=false,quests={{questID=5020,title="Unknown held quest"}}}
}
local nativeReady=false
local function getVisible()
    local rows={}
    if not nativeReady then return rows end
    for _,sect in ipairs(sections) do
        rows[#rows+1]={title=sect.name,isHeader=true,headerSortKey=sect.key,isCollapsed=sect.collapsed,questLogIndex=#rows+1,sect=sect}
        if not sect.collapsed then for _,q in ipairs(sect.quests) do rows[#rows+1]=q end end
    end
    return rows
end
C_QuestLog.GetNumQuestLogEntries=function() return #getVisible(),nativeReady and 3 or 0 end
C_QuestLog.GetInfo=function(n) return getVisible()[n] end
C_QuestLog.IsOnQuest=function(q) return nativeReady and (q==5010 or q==5020 or q==5030) end
C_QuestLog.GetNextWaypoint=function() end
C_QuestLog.GetQuestsOnMap=function()return {} end
ready[5030]=true
local mapInfo=C_Map.GetMapInfo
C_Map.GetMapInfo=function(i)
    if i==611 then return {mapID=i,mapType=3,name="Elwynn Forest",parentMapID=999} end
    if i==612 then return {mapID=i,mapType=3,name="Hillsbrad Foothills",parentMapID=999} end
    return mapInfo(i)
end
C_Map.GetMapChildrenInfo=function(root,kind)
    if kind==3 and root==999 then return {C_Map.GetMapInfo(611),C_Map.GetMapInfo(612)} end
    return {}
end
local expands,collapses=0,0
QuestMapFrame={ignoreQuestLogUpdate=false}
function ExpandQuestHeader(i)
    assert(not inCombat and QuestMapFrame.ignoreQuestLogUpdate)
    local sect=getVisible()[i].sect;assert(sect.collapsed)
    sect.collapsed=false;expands=expands+1
    watch.scripts.OnEvent(watch,"QUEST_LOG_UPDATE")
end
function CollapseQuestHeader(i)
    assert(not inCombat and QuestMapFrame.ignoreQuestLogUpdate)
    local sect=getVisible()[i].sect;assert(not sect.collapsed)
    sect.collapsed=true;collapses=collapses+1
    watch.scripts.OnEvent(watch,"QUEST_LOG_UPDATE")
end
map=nil
AT.db.questHUDEnabled=true;AT.RefreshQuestHUD()
clickButton("Zones")
assert(not find("Elwynn Forest") and not find("Forest hidden quest"))
nativeReady=true;map=1;inCombat=true
AT.RefreshQuestHUD()
assert(expands==0 and collapses==0,"defer protected native collapse changes in combat")
inCombat=false
watch.scripts.OnEvent(watch,"PLAYER_REGEN_ENABLED");drain()
assert(expands==2 and collapses==2 and not QuestMapFrame.ignoreQuestLogUpdate)
assert(sections[1].collapsed and sections[2].collapsed and not sections[3].collapsed)
local loaded=AT.BuildQuestHUDModel(1,"Stranglethorn Vale")
assert(loaded.zones[611].rows[5010] and loaded.zones[612].rows[5030] and loaded.zones["at-other"].rows[5020])
assert(expands==2,"opening/refreshing the Zones picker must reuse complete read and not create a refresh loop")
for _,theme in ipairs({"Map","Minimal"}) do
    assert(find(theme))
    clickButton("Zones")
    local other=find("Other quests");assert(other and other.kind=="Button");other.scripts.OnClick(other)
    assert(find("Unknown held quest"))
    clickButton("Zones")
    local h=find("Hillsbrad Foothills");assert(h and h.kind=="Button");h.scripts.OnClick(h)
    assert(find("Completed") and find("Hillsbrad hidden quest"),"completed-only named zone auto switches")
    clickButton("Completed");AT.RefreshQuestHUD()
    assert(find("In Progress") and not find("Hillsbrad hidden quest"),"manual status stays through refresh")
    clickButton(theme)
end
assert(expands==2 and collapses==2 and sections[1].collapsed and sections[2].collapsed)
print("PASS first-load held quests: no Questie or saved origin; collapsed native preserved, combat deferred, delayed map/fresh Zones, both themes and statuses, no mutation loop")

do
    local expected={
        [3065]={"Hall of Thanes",{96393,96394,96395,96403,98423}},
        [2999]={"Ruins of Lordaeron",{92401,92415,92421,92422,95189,95195,95204,95216,95250,97288}},
        [2998]={"Excavation Site: Wetlands",{95646,95647,95682,95697,95772,95795,95809,98815,98823,98824}},
        [2959]={"City of Dalaran",{92456,92457,92458,92489,96984,96986,96987,96988}},
        [2970]={"The Drowned City",{95775,95776,95787,95788,95789,95791,95798,95799,96078,96774,97130}},
        [3039]={"Krol'dok Stronghold",{94968,94972,94974,94975,94981,94982,94983,94984,94998,96771}},
        [2994]={"Alcaz Prison",{95262,95263,95309,95454,95483,96332,96334,96335,96337,96376,96377,96381,96772}},
        [2974]={"Blackmaw Hold",{92065,92066,92067,92069,92070,92343,92344,96246,97173,97198,97327,99187}},
        [3001]={"Shaper's Terrace",{95790,95924,95925,95926,95928,97049}},
    }
    local getInfo,getCount,getOnQuest=C_QuestLog.GetInfo,C_QuestLog.GetNumQuestLogEntries,C_QuestLog.IsOnQuest
    local getInstance,inInstance,savedMap=GetInstanceInfo,IsInInstance,map
    local rows={{isHeader=true,title="Stranglethorn Vale"}}
    local count=0
    for _,ex in pairs(expected) do
        for _,qid in ipairs(ex[2]) do
            count=count+1
            rows[#rows+1]={questID=qid,title="Audit quest "..qid}
        end
    end
    rows[#rows+1]={questID=95770,title="Locating the Lost City"}
    rows[#rows+1]={questID=95773,title="Enemies in the Water"}
    C_QuestLog.GetInfo=function(i) return rows[i] end
    C_QuestLog.GetNumQuestLogEntries=function() return #rows,#rows-1 end
    C_QuestLog.IsOnQuest=function() return true end
    map=1;IsInInstance=function() return false,"none" end
    for _,item in ipairs(rows) do
        if item.questID==95789 then item.title="Shady Saltseers" end
    end
    local outdoor=AT.BuildQuestHUDModel(1,"Stranglethorn Vale")
    assert(count==85 and not outdoor.currentDungeon)
    assert(outdoor.dungeons["The Drowned City"].rows[95789])
    assert(not (outdoor.zones["at-other"] and outdoor.zones["at-other"].rows[95789]))
    for instance,ex in pairs(expected) do
        local name,ids=ex[1],ex[2]
        local bucket=assert(outdoor.dungeons[name],name)
        for _,qid in ipairs(ids) do assert(bucket.rows[qid] and bucket.rows[qid].row.id==qid) end
        local members=0;for _ in pairs(bucket.rows) do members=members+1 end
        assert(members==#ids)
        IsInInstance=function() return true,"party" end
        GetInstanceInfo=function() return "Localized client label","party",1,nil,5,nil,false,instance end
        local inside=AT.BuildQuestHUDModel(1,"Stranglethorn Vale")
        local here=assert(inside.currentDungeon)
        assert(here.name==name and here.rows[ids[1]] and not here.rows[95770] and not here.rows[95773])
    end
    assert(AT.ForeverDungeonName(nil,"Drowned City")=="The Drowned City")
    assert(AT.ForeverDungeonName(nil,"The Shaper's Terrace")=="Shaper's Terrace")
    IsInInstance=function() return true,"raid" end
    assert(not AT.BuildQuestHUDModel(1,"Stranglethorn Vale").currentDungeon)
    IsInInstance=function() return false,"none" end
    ready[95775]=true
    AT.RefreshQuestHUD()
    local search
    for _,o in ipairs(objs) do if o.kind=="EditBox" then search=o;break end end
    search:SetText("DROWNED city")
    assert(find("Audit quest 95775") and find("Audit quest 95776") and not find("Audit quest 96393"))
    local branch=assert(find("-  The Drowned City"));assert(branch.total.text=="11")
    assert(find("Shady Saltseers") and not find("-  Other quests"))
    branch.scripts.OnClick(branch)
    assert(find("+  The Drowned City") and not find("Audit quest 95775"))
    branch.scripts.OnClick(branch)
    assert(find("Audit quest 95775"))
    assert(not find("Locating the Lost City"),"outdoor breadcrumb must not inherit the dungeon name")
    search:SetText("drowned 95775")
    assert(find("Audit quest 95775") and not find("Audit quest 95776"),"multi-keyword query and completed quest")
    search.scripts.OnEscapePressed(search)
    ready[95775]=nil
    C_QuestLog.GetInfo,C_QuestLog.GetNumQuestLogEntries,C_QuestLog.IsOnQuest=getInfo,getCount,getOnQuest
    GetInstanceInfo,IsInInstance,map=getInstance,inInstance,savedMap
    AT.RefreshQuestHUD()
    print("PASS 85 verified dungeon memberships across all nine Forever launch dungeons, exact instance ID scope, outdoor exclusion, log-wide active/completed search")
end

-- Forever native party tooltip data is grouped by public GUID, not names
-- or guessed localized strings; actual required/fulfilled numbers drive status.
local partyOn,memberCount=true,3
local namesByUnit={party1="Kara-A",party2="Mira-B",party3="Kara-C"}
local current={[1]=4,[3]=0}
local offline={}
local now=100
local liveReport=true
function IsInGroup() return partyOn end
function IsInRaid() return false end
function GetNumSubgroupMembers() return memberCount end
function UnitGUID(u) return (namesByUnit[u] or u=="player") and "unit:"..u end
function GetUnitName(u) return namesByUnit[u] end
function UnitIsConnected(u) return not offline[u] end
function UnitIsVisible(u) return u=="party2" end
function GetTime() return now end
C_QuestLog.IsUnitOnQuest=function(u,q) return q==5010 and u~="party2" end
Enum.TooltipDataLineType={QuestTitle=10,QuestPlayer=11,QuestObjective=12}
C_TooltipInfo={GetQuestPartyProgress=function(q,omit,ignore)
    assert(omit==false and ignore==false)
    if not liveReport or q~=5010 then return end
    local lines={{type=10,id=q},{type=11,guid="unit:player"},{type=12,leftText="My credit 3/999"},
        {type=11,guid="unit:party1"},{type=12,leftText="Wolves slain:",rightText="|cffaaaaaa"..current[1].."/7|r"},
        {type=11,leftText="|cffffffffKara-C|r"},{type=12,leftText="Pelts collected ("..current[3].."/7)"},
    }
    if current[3]<7 then lines[#lines+1]={type=12,leftText="Unrelated date 1/2/77"} end
    lines[#lines+1]={type=11,guid="outsider"}
    lines[#lines+1]={type=12,leftText="Other",numFulfilled=0,numRequired=99}
    return {lines=lines}
end}
assert(loadfile("NQT/PartyProgress.lua"))("NQT",AT)
local originalFrame=CreateFrame
local tooltip
CreateFrame=function(kind,name,parent,template)
    local f=originalFrame(kind,name,parent,template)
    if kind=="GameTooltip" then
        tooltip=f;f.lines={}
        function f:SetOwner(o) self.owner=o end
        function f:ClearLines() self.lines={} end
        function f:AddLine(t) self.lines[#self.lines+1]=t end
        function f:SetQuestPartyProgress(q,omit,ignore)
            assert(q==5010 and omit==false and ignore==false)
            if not liveReport then return false end
            self:AddLine("Kara-A stock " .. current[1] .. "/7")
            self:AddLine("Kara-C stock " .. current[3] .. "/7")
            return true
        end
    end
    return f
end
local tooltipTick
C_Timer.NewTicker=function(period,fn)
    assert(period==.55);tooltipTick=fn;return {Cancel=function() tooltipTick=nil end}
end
local stillHeld=true
local oldIsOn=C_QuestLog.IsOnQuest
C_QuestLog.IsOnQuest=function(q)
    if q==5010 then return stillHeld end
    return oldIsOn(q)
end
AT.db.questHUDTheme=1;AT.db.questPartyProgress=nil -- default-on semantics
ready[5010]=true
AT.BrowseQuestHUD(611)
AT.RefreshQuestHUD()
local function hasLine(part)
    for _,line in ipairs(tooltip.lines) do if line:find(part,1,true) then return true end end
    return false
end
do
    local objectiveAPI=C_QuestLog.GetQuestObjectives
    local tracker,loader,lib=Questie,QuestieLoader,LibQuestieDB
    Questie,QuestieLoader,LibQuestieDB=nil,nil,nil
    local dropPack=assert(AT.ObservedQuestDrops)
    local original=dropPack.items[990099]
    dropPack.items[990099]={{88,3,7,3,2,1}}
    C_QuestLog.GetQuestObjectives=function(q)
        if q==5010 then return {{type="item",itemID=990099,text="Cloud item: 0/3"}} end
        return objectiveAPI(q)
    end
    AT.RefreshQuestHUD()
    local row=assert(find("Forest hidden quest"))
    row.scripts.OnEnter(row)
    assert(not hasLine("Everloot") and not hasLine("CC BY") and not hasLine("opened loot windows"))
    row.scripts.OnLeave(row)
    local oldSetting=AT.db.rankQuestDropRates
    AT.db.rankQuestDropRates=false
    row.scripts.OnEnter(row)
    assert(not hasLine("opened loot windows"),"disabled option hides sample evidence")
    row.scripts.OnLeave(row)
    AT.db.rankQuestDropRates=oldSetting
    C_QuestLog.GetQuestObjectives=objectiveAPI
    Questie,QuestieLoader,LibQuestieDB=tracker,loader,lib
    dropPack.items[990099]=original
    AT.RefreshQuestHUD()
    print("PASS quest tooltip omits research credits and sample counts")
end
for _,theme in ipairs({"Map","Minimal"}) do
    local row=find("Forest hidden quest")
    assert(row and row.detail.text=="Ready to turn in")
    row.scripts.OnEnter(row)
    assert(tooltip.shown and hasLine("4/7") and hasLine("0/7") and hasLine("Mira-B: Not on this quest") and not hasLine("99"))
    current[1]=6;now=now+1;tooltipTick()
    assert(hasLine("6/7") and not hasLine("4/7"),"hover refresh while pointer remains")
    row.scripts.OnLeave(row)
    assert(not tooltip.shown and not tooltipTick)
    current[1]=4;now=now+1
    clickButton("In Progress")
    assert(find("Forest hidden quest"),"personally held objective-complete remains accessible from Completed")
    clickButton("Completed")
    clickButton(theme)
end
AT.db.questPartyProgress=false;AT.RefreshQuestHUD()
assert(not find("Forest hidden quest"),"disable clears party retention and normal solo completion wins")
AT.db.questPartyProgress=true;now=now+1;AT.RefreshQuestHUD()
assert(find("Forest hidden quest"))
sections[1].quests={}
stillHeld=false
watch.scripts.OnEvent(watch,"QUEST_TURNED_IN",5010);drain()
local remote=find("Forest hidden quest")
assert(remote and remote.partyOnly and not remote.circle.available and remote.detail.text:find("Turned in by you",1,true))
do
    local forest=sections[1]
    local oldQuests,oldCollapsed,oldCount=forest.quests,forest.collapsed,C_QuestLog.GetNumQuestLogEntries
    forest.quests={
        {questID=88001,title="Forest own quest 1"}, {questID=88002,title="Forest own quest 2"},
        {questID=88003,title="Forest own quest 3"}, {questID=88004,title="Forest own quest 4"},
    }
    forest.collapsed=false
    C_QuestLog.GetNumQuestLogEntries=function() return #getVisible(),20 end
    AT.RefreshQuestHUD()
    assert(find("Forest hidden quest").partyOnly,"the retained teammate quest stays visible")
    for n=1,4 do assert(find("Forest own quest "..n)) end
    assert(find("4/20 Quests") and not find("5/20 Quests"),"count only player quests even with a visible party-only row")
    forest.quests,forest.collapsed,C_QuestLog.GetNumQuestLogEntries=oldQuests,oldCollapsed,oldCount
    AT.RefreshQuestHUD()
    remote=assert(find("Forest hidden quest"))
    print("PASS Rank Quest 4/20 with four own quests and one extra retained teammate quest visible")
end
local unchangedNav,lastOpen=AT.GetQuestNavigationID(),opened
ctrl=false;remote.titleHit.scripts.OnClick(remote.titleHit,"LeftButton")
assert(AT.GetQuestNavigationID()==unchangedNav and opened==lastOpen)
remote.scripts.OnEnter(remote)
assert(hasLine("4/7") and hasLine("3 remaining") and hasLine("0/7"))
remote.scripts.OnLeave(remote)
liveReport=false;now=now+1;AT.RefreshQuestHUD()
remote=find("Forest hidden quest")
assert(remote); local foundLast;for _,label in ipairs(remote.objectives) do if label.shown and label.text and label.text:find("Kara-A  4/7 (last reported)",1,true) then foundLast=true end end;assert(foundLast)
remote.scripts.OnEnter(remote)
assert(hasLine("Current progress unavailable; last reported:") and hasLine("4/7"))
remote.scripts.OnLeave(remote)
now=now+46;AT.RefreshQuestHUD()
assert(not find("Forest hidden quest"),"expire data if native never returns after turn-in")
print("PASS default-on native party hover, zero vs unavailable/not on quest, exact GUID data/live refresh, local ready+after turn-in retention with limits and no GPS")

do
    local qid=5010
    local oldLocale=GetLocale
    GetLocale=function() return "enUS" end
    local old=AT.ObservedQuestTurnIns
    local oldOn=stillHeld
    stillHeld=true
    local m0,x0,y0=AT.GetReadyQuestTurnInPoint(qid)
    local targetMap=m0 or 611
    local x,y=x0 or .559,y0 or .637
    AT.ObservedQuestTurnIns={[qid]={{targetMap,x,y,1,737,0,"Kebok"}}}
    local m,px,py,npc,isNPC=AT.GetReadyQuestTurnInPoint(qid)
    assert(m==targetMap and px==x and py==y and npc=="Kebok" and isNPC)
    local actions={}
    assert(loadfile("NQT/QuestItems.lua"))("NQT",actions)
    local macro=assert(actions.GetRankQuestNPCMacro(npc))
    assert(macro:find("/targetexact Kebok",1,true) and macro:find("!3",1,true) and macro:find("/ping",1,true))
    GetLocale=function() return "koKR" end
    local localeMap,_,_,wrongName,shouldBind=AT.GetReadyQuestTurnInPoint(qid)
    assert(localeMap==targetMap and wrongName==nil and not shouldBind)
    local oldGUID,oldName=UnitGUID,UnitName
    UnitGUID=function(u) if u=="target" then return "Creature-0-0-1-5-737-ABC" end return oldGUID(u) end
    UnitName=function(u) if u=="target" then return "Localized finisher" end end
    local _,_,_,name,liveBinding=AT.GetReadyQuestTurnInPoint(qid)
    assert(name=="Localized finisher" and liveBinding)
    UnitGUID,UnitName=oldGUID,oldName
    GetLocale=function() return "enUS" end
    AT.ObservedQuestTurnIns[qid][2]={targetMap,x,y,1,738,0,"Another NPC"}
    local _,_,_,ambiguous=AT.GetReadyQuestTurnInPoint(qid)
    assert(not ambiguous,"never bind an ambiguous NPC")
    AT.ObservedQuestTurnIns[qid]={{targetMap,x,y,2,737,0,""}}
    local om,_,_,objectName,objectNPC=AT.GetReadyQuestTurnInPoint(qid)
    assert(om==targetMap and not objectName and not objectNPC)
    AT.ObservedQuestTurnIns,stillHeld,GetLocale=old,oldOn,oldLocale
    do
        local facts={}
        assert(loadfile("NQT/ForeverQuestFacts.lua"))("NQT",facts)
        local oldReferences=AT.ForeverQuestNPCReferences
        AT.ForeverQuestNPCReferences=facts.ForeverQuestNPCReferences
        local oldATTRefs=AT.ForeverATTQuestNPCReferences
        AT.ForeverATTQuestNPCReferences=facts.ForeverATTQuestNPCReferences
        local oldReady,oldOnQuest=C_QuestLog.ReadyForTurnIn,C_QuestLog.IsOnQuest
        local oldFaction,oldLocale=UnitFactionGroup,GetLocale
        local active,complete=true,true
        C_QuestLog.ReadyForTurnIn=function(q) if q==202 or q==140 or q==152 then return complete end return oldReady(q) end
        C_QuestLog.IsOnQuest=function(q) if q==202 or q==140 or q==152 then return active end return oldOnQuest(q) end
        UnitFactionGroup=function() return "Alliance" end
        GetLocale=function() return "enUS" end
        local m,x,y,name,clickable,reference=AT.GetReadyQuestTurnInPoint(202)
        assert(m==1434 and x==.3802 and y==.0308 and name=="Lieutenant Doren" and clickable and reference)
        local m2,_,_,chest,clickable2,reference2=AT.GetReadyQuestTurnInPoint(140)
        assert(m2==1436 and chest=="Locked Chest" and not clickable2 and reference2)
        local m3,_,_,grayson,npc3,reference3=AT.GetReadyQuestTurnInPoint(152)
        assert(m3==1436 and grayson=="Captain Grayson" and npc3 and reference3)
        local oldNav=AT.IsQuestTurnInNavigation
        AT.IsQuestTurnInNavigation=function(q) return q==202 end
        assert(not AT.GetQuestTurnInPoint(202),"no GPS to an approximate reference")
        AT.IsQuestTurnInNavigation=oldNav
        UnitFactionGroup=function() return "Horde" end
        assert(not AT.GetReadyQuestTurnInPoint(202),"never expose another faction's reference")
        UnitFactionGroup=function() return "Alliance" end
        active=false;assert(not AT.GetReadyQuestTurnInPoint(202))
        active=true;complete=false;assert(not AT.GetReadyQuestTurnInPoint(202))
        C_QuestLog.ReadyForTurnIn,C_QuestLog.IsOnQuest=oldReady,oldOnQuest
        UnitFactionGroup,GetLocale=oldFaction,oldLocale
        AT.ForeverQuestNPCReferences=oldReferences
        AT.ForeverATTQuestNPCReferences=oldATTRefs
    end
    print("PASS Questie-free observed turn-in coordinates and exact clickable NPC, rejects ambiguity and objects")
end

local function resetPartyQuest()
    current[1],current[3]=4,0;liveReport=true
    stillHeld=true;partyOn=true;memberCount=3;offline={}
    sections[1].quests={{questID=5010,title="Forest hidden quest"}}
    watch.scripts.OnEvent(watch,"QUEST_ACCEPTED",5010);drain()
    assert(find("Forest hidden quest"))
    stillHeld=false;sections[1].quests={}
    watch.scripts.OnEvent(watch,"QUEST_TURNED_IN",5010);drain()
    assert(find("Forest hidden quest").partyOnly)
    now=now+1
end
resetPartyQuest()
current[1]=7;AT.RefreshQuestHUD();assert(find("Forest hidden quest"),"other party member still needs credit")
current[3]=7;now=now+1;AT.RefreshQuestHUD();assert(not find("Forest hidden quest"),"all reported members finished")
resetPartyQuest()
offline.party1=true;memberCount=2;AT.RefreshQuestHUD()
assert(not find("Forest hidden quest"),"offline member and a departed member cannot retain a row")
resetPartyQuest()
partyOn=false;AT.RefreshQuestHUD()
assert(not find("Forest hidden quest"),"leaving party clears the transient row")
print("PASS retained party item clears after last member completes, roster leave/offline and entire party exit")
do
    resetPartyQuest()
    local origCreate,origChat=CreateFrame,C_ChatInfo
    local sync
    CreateFrame=function(...) sync=origCreate(...);return sync end
    C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,SendAddonMessage=function() return 0 end}
    AT.InitQuestPartySync()
    CreateFrame=origCreate
    local function remoteState(msg,sender)
        sync.scripts.OnEvent(sync,"CHAT_MSG_ADDON","NQTQuestState1",msg,"PARTY",sender)
        drain()
    end
    remoteState("P:5010:01:1/6/7,","Kara-A")
    local counted=assert(find("Forest hidden quest"))
    counted.scripts.OnEnter(counted)
    assert(hasLine("6/7") and hasLine("1 remaining") and not hasLine("4/7"))
    counted.scripts.OnLeave(counted)
    remoteState("D:5010","Kara-A")
    assert(find("Forest hidden quest").partyOnly,"one other member still needs the quest")
    local shown=assert(find("Forest hidden quest"))
    shown.scripts.OnEnter(shown)
    assert(hasLine("Kara-A: Objectives complete") and not hasLine("4/7"))
    shown.scripts.OnLeave(shown)
    remoteState("L:5010","Kara-C")
    assert(not find("Forest hidden quest"),"real HUD should remove retained row on sync despite stale native counts")
    -- Repro: an older shared count survives, then the client reports last teammate complete.
    AT.ClearRankQuestPartyProgress()
    resetPartyQuest()
    remoteState("P:5010:01:1/6/7,","Kara-A")
    remoteState("D:5010","Kara-C")
    assert(find("Forest hidden quest").partyOnly)
    local perfDraws=0
    AT.PerfBegin=function()return 1 end
    AT.PerfEnd=function(label)if label=="Rank Quest redraw" then perfDraws=perfDraws+1 end end
    now=now+1.4
    areaTick()
    assert(perfDraws==0,"unchanged party must not rebuild the full quest HUD")
    current[1]=7
    now=now+1.4
    areaTick()
    assert(perfDraws==1,"confirmed party progress change triggers one full redraw")
    AT.PerfBegin,AT.PerfEnd=nil,nil
    assert(not find("Forest hidden quest"),"native exact completion clears the stale shared row on the regular ticker, no hover")
    liveReport=false
    remoteState("P:5010:01:1/6/7,","Kara-A")
    assert(not find("Forest hidden quest"),"duplicate old progress must not invalidate confirmed completion")
    AT.ClearRankQuestPartyProgress()
    resetPartyQuest()
    remoteState("P:5010:01:1/6/7,","Kara-A")
    remoteState("D:5010","Kara-C")
    local hovering=assert(find("Forest hidden quest"))
    current[1]=7
    hovering.scripts.OnEnter(hovering)
    drain()
    assert(not find("Forest hidden quest"),"hover seeing new completion queues the row refresh, it does not just update its own text")
    C_ChatInfo=origChat
    AT.ClearRankQuestPartyProgress()
    print("PASS completion message clears the real Rank Quest row only after the last teammate finishes")
end
local originalInlineObjectives=C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives=function(q)
    if q==5010 then return {{text="My wolves: 7/7",finished=true}} end
    return originalInlineObjectives(q)
end
local function inlineText(row,part)
    for _,label in ipairs(row.objectives) do
        if label.shown and label.text and label.text:find(part,1,true) then return true end
    end
    return false
end
local person
for _,thing in ipairs(objs) do if thing.icon and thing.icon.texture and tostring(thing.icon.texture):find("PartyPerson.tga",1,true) then person=thing end end
assert(person:GetFrameLevel()>2,"icon must receive clicks above transparent title drag region")
assert(person and person.shown and person.anchor[1]=="RIGHT" and person.anchor[2].child[1].text=="In Progress" and person.anchor[3]=="LEFT")
partyOn=true;memberCount=3;offline={};liveReport=true
current[1],current[3]=4,0;now=now+1
sections[1].quests={{questID=5010,title="Forest hidden quest"}}
stillHeld=true
watch.scripts.OnEvent(watch,"QUEST_ACCEPTED",5010);drain()
hud:SetWidth(358);AT.db.questHUDFontOffset=5;AT.RefreshQuestHUD()
for _,name in ipairs({"Map","Minimal"}) do
    local quest=find("Forest hidden quest")
    assert(quest and quest.scripts.OnEnter)
    assert(not inlineText(quest,"My wolves") and not inlineText(quest,"3 remaining") and inlineText(quest,"Kara-A  4/7"),"finished quests show compact counts by default")
    local owner=person.parent
    local title
    for _,obj in ipairs(objs) do
        if obj.parent==owner then for _,label in ipairs(obj.child) do if label.text=="Rank Quest" then title=label end end end
    end
    assert(title and title.w>=title:GetUnboundedStringWidth() and title.w+13+6+23+4+person.anchor[2].w+person.anchor[2].anchor[2].w+24+8+10<=358)
    local scrollFrame
    for _,obj in ipairs(objs) do if obj.kind=="ScrollFrame" and obj.parent==owner and not scrollFrame then scrollFrame=obj end end
    scrollFrame:SetVerticalScroll(11)
    person.scripts.OnClick(person)
    local offScroll=scrollFrame:GetVerticalScroll()
    assert(offScroll>=0 and offScroll<=11,"hiding lines can clamp a now-overscrolled list")
    assert(not inlineText(quest,"Kara-A") and not inlineText(quest,"Kara-C"),"off means no inline party counts")
    quest.scripts.OnEnter(quest)
    assert(hasLine("4/7") and hasLine("0/7"),"off must not disable hover details")
    quest.scripts.OnLeave(quest)
    person.scripts.OnClick(person)
    assert(scrollFrame:GetVerticalScroll()==offScroll,"showing lines preserves the current scroll")
    assert(inlineText(quest,"Kara-A  4/7") and inlineText(quest,"Kara-C  0/7"))
    assert(not inlineText(quest,"remaining -") and not inlineText(quest,"Party objectives") and not inlineText(quest,"Your objectives"))
    assert(not inlineText(quest,"Mira-B") and not inlineText(quest,"99"))
    current[1]=6;current[3]=7;now=now+1;AT.RefreshQuestHUD()
    assert(inlineText(quest,"Kara-A  6/7") and not inlineText(quest,"Kara-C") and not inlineText(quest,"remaining -"))
    clickButton("In Progress")
    assert(inlineText(find("Forest hidden quest"),"Kara-A  6/7"),"active toggle follows status views")
    clickButton("Completed")
    liveReport=false;now=now+1;AT.RefreshQuestHUD()
    assert(inlineText(find("Forest hidden quest"),"Kara-A  6/7 (last reported)") and not inlineText(find("Forest hidden quest"),"remaining -"))
    AT.db.questPartyProgress=false;AT.RefreshQuestHUD()
    assert(not person.shown and not find("Forest hidden quest"))
    AT.db.questPartyProgress=true;liveReport=true;current[1],current[3]=4,0;now=now+1;AT.RefreshQuestHUD()
    quest=find("Forest hidden quest")
    assert(not inlineText(quest,"My wolves") and inlineText(quest,"Kara-A  4/7"))
    quest.scripts.OnEnter(quest)
    assert(hasLine("4/7") and hasLine("0/7"),"turning off inline must not disable hover")
    quest.scripts.OnLeave(quest)
    clickButton(name)
end
do
    local prior=AT.GetQuestPartySnapshot
    local function compactFixture(q,...)
        if q~=5010 then return prior(q,...) end
        return {pending=true,verifiedPending=true,members={{name="Mira",counts={
          {current=4,total=7,desc="Wolves"},{current=3,total=3,desc="Pelts"}
        }}}}
    end
    AT.GetQuestPartySnapshot=compactFixture
    ready[5010]=false
    AT.RefreshQuestHUD()
    local active=assert(find("Forest hidden quest"))
    assert(inlineText(active,"Mira  7/10") and not inlineText(active,"3 remaining"),"combine objectives before the player is done")
    ready[5010]=true;AT.RefreshQuestHUD()
    local finished=assert(find("Forest hidden quest"))
    assert(inlineText(finished,"Mira  7/10") and not inlineText(finished,"3 remaining - Wolves"))
    person.scripts.OnClick(person)
    assert(find("Forest hidden quest") and not inlineText(finished,"Mira"),"hiding counts does not hide the retained quest")
    ready[5010]=false;AT.RefreshQuestHUD()
    assert(not inlineText(find("Forest hidden quest"),"Mira"),"off also hides counts on active quests")
    person.scripts.OnClick(person)
    ready[5010]=true;AT.RefreshQuestHUD()
    AT.GetQuestPartySnapshot=prior
end
print("PASS person toggle is compact counts only, preserves hover details and retention, live/stale counts, master and scroll position")

-- An abandon removal must win over stale native/collapsed rows and party retention.
do
    current[1],current[3]=4,0;liveReport=true
    stillHeld=true;partyOn=true;memberCount=3;offline={}
    sections[1].quests={{questID=5010,title="Forest hidden quest"}}
    ready[5010]=false
    AT.db.questHUDTheme=2
    watch.scripts.OnEvent(watch,"QUEST_ACCEPTED",5010);drain()
    clickButton("Zones");clickButton("All Zones")
    assert(find("Forest hidden quest") and find("All Zones"))
    local beforeOnQuest=C_QuestLog.IsOnQuest
    C_QuestLog.IsOnQuest=function(id) if id==11 then return true end return beforeOnQuest(id) end
    AT.char.trackingOrder={5010,11}
    assert(AT.ToggleQuestHUDManualFocus(5010))
    questEngineFrame.scripts.OnEvent(questEngineFrame,"QUEST_REMOVED",5010)
    watch.scripts.OnEvent(watch,"QUEST_REMOVED",5010);drain()
    assert(not find("Forest hidden quest"),"ignore stale visible data after confirmed removal")
    assert(not AT.GetQuestOrderPosition(5010) and AT.GetQuestOrderPosition(11)==1 and not AT.GetQuestHUDManualFocus())
    stillHeld=false;sections[1].quests={};AT.RefreshQuestHUD()
    assert(not find("Forest hidden quest"),"party-only retention must not resurrect an abandoned quest")
    sections[1].quests={{questID=5010,title="Forest hidden quest"}}
    stillHeld=true
    watch.scripts.OnEvent(watch,"QUEST_ACCEPTED",5010);drain()
    assert(find("Forest hidden quest"),"accepting it again restores the row")
    -- Rank Quest's own confirmation can reconcile an authoritative absent
    -- response even if a separate quest-removed event has not arrived yet.
    stillHeld=false
    AT.RefreshRankQuestAfterAbandon(5010);drain()
    assert(not find("Forest hidden quest"))
    print("PASS confirmed abandon removes stale and party-retained rows, clears tracking, stays gone, then reaccept restores it")
end
do
    local ids={{isHeader=true,title="Stranglethorn Vale"},{questID=701,title="Zone share"},
        {questID=95789,title="Shady Saltseers"},{questID=95309,title="Alcaz quest"},
        {questID=702,title="Unshareable"},{questID=703,title="Hidden",isHidden=true},
        {isHeader=true,title="Duskwood"},{questID=704,title="Other zone"}}
    local picked,group,blocked,done=704,true,nil
    local queue,attempts,notices={},{},{}
    local now=100
    local held={party1={},party2={}}
    local visible={party1=true,party2=true}
    GetTime=function() return now end
    GetNumSubgroupMembers=function() return 2 end
    IsInRaid=function() return false end
    UnitGUID=function(unit) return "Player-"..unit end
    GetUnitName=function(unit) return unit=="party1" and "Kara-A" or "Mira-B" end
    UnitIsVisible=function(unit) return visible[unit]==true end
    UnitIsConnected=function() return true end
    C_QuestLog.IsUnitOnQuest=function(unit,q) return held[unit] and (held[unit][q]==true) end
    partyOn=false
    C_QuestLog.GetNumQuestLogEntries=function() return #ids end
    C_QuestLog.GetInfo=function(i) return ids[i] end
    C_QuestLog.IsOnQuest=function(q)
        for _,entry in ipairs(ids) do if entry.questID==q then return true end end
        return false
    end
    C_QuestLog.IsPushableQuest=function(q) return C_QuestLog.IsOnQuest(q) and q~=702 end
    C_QuestLog.GetSelectedQuest=function() return picked end
    C_QuestLog.SetSelectedQuest=function(q) picked=q end
    QuestLogPushQuest=function()
        if blocked then error("native block") end
        attempts[#attempts+1]=picked
    end
    C_Timer.After=function(seconds,f) if seconds==4 then queue[#queue+1]=f else f() end end
    DEFAULT_CHAT_FRAME={AddMessage=function(_,m) notices[#notices+1]=m end}
    IsInGroup=function() return group end
    IsInInstance=function() return false,"none" end
    AT.db.questHUDEnabled=true;AT.db.questHUDCollapsed=false
    map=1;AT.RefreshQuestHUD()
    local shareArrow
    for _,texture in ipairs(textures) do
        if texture.texture and tostring(texture.texture):find("ShareArrow.tga",1,true) and not (texture.parent.parent and texture.parent.parent.partyShareButtons) then shareArrow=texture.parent end
    end
    assert(shareArrow and shareArrow.anchor[1]=="RIGHT" and shareArrow.anchor[3]=="LEFT")
    if not shareArrow.shown then clickHeader() end
    local function runBatch(label,expected)
        now=now+30
        queue,attempts={},{}
        shareArrow.scripts.OnClick(shareArrow)
        local option=assert(find(label),label)
        assert(option:IsVisible())
        option.scripts.OnClick(option)
        while #queue>0 do local fn=table.remove(queue,1);now=now+4;fn() end
        assert(table.concat(attempts,",")==expected,table.concat(attempts,",").." != "..expected)
        assert(picked==704,"quest list selection must be restored")
    end
    runBatch("Share All Quests","701,95789,95309,704")
    AT.BrowseQuestHUD(2)
    runBatch("Share Zone Quests","701,95789,95309")
    runBatch("Share All Dungeon Quests","95789,95309")
    IsInInstance=function() return true,"party" end
    GetInstanceInfo=function() return "The Drowned City","party",1,nil,5,nil,false,2970 end
    AT.RefreshQuestHUD()
    runBatch("Share Zone Quests","95789")
    group=false
    runBatch("Share All Quests","")
    assert(notices[#notices]:find("Join a party",1,true))
    group,blocked=true,true
    runBatch("Share All Quests","")
    assert(notices[#notices]:find("WoW blocked",1,true))
    now=now+30;blocked=nil;queue,attempts={},{}
    shareArrow.scripts.OnClick(shareArrow)
    find("Share All Quests").scripts.OnClick()
    assert(#attempts==1 and #queue==1,"only one quest per native offer interval")
    shareArrow.scripts.OnClick(shareArrow)
    assert(find("Stop Sharing"):IsVisible())
    find("Stop Sharing").scripts.OnClick()
    table.remove(queue,1)()
    assert(#attempts==1,"cancelled batch must not share again")
    now=now+30;attempts={};queue={}
    visible.party2=false;held.party1[701]=true
    held.party1[95309]=true
    shareArrow.scripts.OnClick(shareArrow)
    ids[3].level=41
    AT.GetShareQuestStart=function(q)
        if q==95789 then return "Starts at: Dockmaster  |  Riverglades 35.2, 41.0" end
    end
    AT.char.zoneQuestOrigins[704]=nil
    local priorWP=C_QuestLog.GetNextWaypoint
    C_QuestLog.GetNextWaypoint=function(q) if q==704 then return 2,.5,.5 end if priorWP then return priorWP(q) end end
    find("Share Verify").scripts.OnClick()
    local startSeen,unknownSeen
    for _,obj in ipairs(objs) do
        if obj.qid==95789 and obj.source and obj:IsVisible() then
            startSeen=true
            assert(obj.title:GetText()=="[41] Shady Saltseers" and obj.source:GetText():find("Dockmaster",1,true))
            assert(obj.detail:GetText():find("Kara-A",1,true))
        elseif obj.qid==704 and obj.source and obj:IsVisible() then
            unknownSeen=true
            assert(obj.source:GetText()=="Start location unknown  |  Objective: Duskwood","an objective is not a pickup location")
        end
    end
    assert(startSeen and unknownSeen,"source and unknown rows were rendered")
    local function offer(q)
        for _,obj in ipairs(objs) do
            if obj.qid==q and obj.action and obj.action.label.text=="Share" and obj:IsVisible() then return obj.action end
        end
    end
    assert(not offer(701) and not offer(95309),"known held plus unavailable party member is not a confirmed candidate")
    assert(offer(95789) and offer(704),"verified missing quest gets its own Share button")
    local b=offer(95789);b.scripts.OnClick()
    assert(attempts[1]==95789 and not offer(95789),"pending offer is not offered twice")
    local function pendingRow(q)
        for _,obj in ipairs(objs) do
            if obj.qid==q and obj.offerPending and obj:IsVisible() then return obj end
        end
    end
    local waiting=assert(pendingRow(95789),"quest remains visible while the offer is pending")
    assert(waiting.detail:GetText():find("Offer pending: Kara-A",1,true) and waiting.action.label.text=="Pending")
    waiting.action.scripts.OnClick(waiting.action);assert(#attempts==1)
    held.party1[95789]=true;now=now+4;areaTick()
    assert(not offer(95789) and not pendingRow(95789),"accepted quest drops from the list on refresh")
    ERR_QUEST_PUSH_INVALID_S="%s is not eligible for that quest."
    ERR_QUEST_PUSH_ALREADY_DONE_S="%1$s has completed that quest."
    b=offer(704);b.scripts.OnClick()
    assert(attempts[2]==704)
    watch.scripts.OnEvent(watch,"UI_ERROR_MESSAGE",461,"Kara-A has completed that quest.")
    assert(notices[#notices]:find("Kara-A already completed",1,true))
    now=now+30;areaTick()
    assert(not offer(704),"reported completed quest stays off the list beyond pending expiry")
    assert(not offer(95789),"accepted quest stays off after pending expiry")
    held.party1[95309]=false
    areaTick();b=assert(offer(95309));b.scripts.OnClick()
    watch.scripts.OnEvent(watch,"CHAT_MSG_SYSTEM","Kara-A is not eligible for that quest.")
    assert(notices[#notices]:find("Kara-A is not eligible",1,true))
    now=now+30;areaTick();assert(not offer(95309))
    assert(picked==704)
    print("PASS Share Verify buttons: confirmed missing only, live accept, localized completion and ineligibility feedback, suppression, and selection restoration")

    now=now+30
    AT.BrowseQuestHUD(1)
    held.party1[701]=false;held.party2[701]=true
    AT.RefreshQuestHUD()
    local function inlineArrow()
        local row=find("Zone share")
        for _,arrow in ipairs(row and row.partyShareButtons or {}) do
            if arrow.memberGUID=="Player-party1" and arrow:IsVisible() then return arrow,row end
        end
    end
    local arrow,row=inlineArrow()
    assert(arrow and inlineText(row,"Kara-A  -  Not on quest"))
    local red
    for _,o in ipairs(row.objectives) do
        if o.text=="Kara-A  -  Not on quest" then red=o.textColor end
    end
    assert(red and red[1]>red[2] and red[1]>red[3])
    local toggle
    for _,texture in ipairs(textures) do
        if texture.texture and tostring(texture.texture):find("PartyPerson.tga",1,true) then toggle=texture.parent end
    end
    assert(toggle);toggle.scripts.OnClick(toggle)
    assert(not inlineArrow() and not inlineText(row,"Not on quest"),"toggle off hides row sharing")
    toggle.scripts.OnClick(toggle)
    arrow=assert(inlineArrow())
    arrow.scripts.OnClick(arrow)
    assert(attempts[#attempts]==701 and not inlineArrow(),"inline share is a real native offer, not a menu")
    row=find("Zone share");assert(inlineText(row,"Kara-A  -  Offer pending"))
    now=now+21;areaTick();AT.RefreshQuestHUD()
    arrow=assert(inlineArrow(),"an unanswered offer is shareable again after timeout")
    arrow.scripts.OnClick(arrow)
    held.party1[701]=true;now=now+30
    AT.GetQuestPartySnapshot=function(q)
        if q==701 then return {pending=true,members={{guid="Player-party1",name="Kara-A",counts={{current=1,total=3}}}}} end
    end
    partyOn=true;AT.RefreshQuestHUD()
    row=find("Zone share")
    assert(not inlineArrow() and inlineText(row,"Kara-A  1/3"),"accepted party member returns to progress display")
    print("PASS inline party share respects toggle, shows readable red missing status, sends through native share and restores accepted progress")
    print("PASS bulk quest sharing through the green toolbar menu: all scopes, no hidden quests, native eligibility, pacing, selection restore, blocked and cancelled")
end
