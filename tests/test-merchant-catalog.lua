local AT={db={enabled=true}}
function GetLocale() return "enUS" end
function UnitFactionGroup() return "Alliance" end
local restricted={}
function issecretvalue(v) return v==restricted end
local root="NQT/"
assert(loadfile(root.."QuestMobs.lua"))("NQT",AT)
assert(loadfile(root.."QuestItems.lua"))("NQT",AT)
assert(select(2,AT.GetQuestObjectiveVendor(79236,4600))==2832)
assert(select(2,AT.GetQuestObjectiveVendor(116,1941))==277)
assert(not AT.GetQuestObjectiveVendor(97583,278265))
local done,ready=false,false
local quest=722222
local stock={999900,4600,999901}
local objs={{type="item",text="0/2 Exact item",finished=false},{type="monster",itemID=999901,finished=false}}
AT.ResolveRankQuestObjectiveItem=function(q,o,text)
    assert(q==quest and text=="0/2 Exact item")
    return 999900
end
C_QuestLog={GetNumQuestLogEntries=function()return 2,1 end,
    GetInfo=function(i)return i==1 and {isHeader=true,questID=111} or {isHeader=false,questID=quest} end,
    GetQuestObjectives=function(q)assert(q==quest);objs[1].finished=done;return objs end,
    ReadyForTurnIn=function(q)assert(q==quest);return ready end}
local shown=true
local hooks,pending={},{ }
local recalc=0
AT.RefreshQuestHUD=function() recalc=recalc+1 end
C_Timer={After=function(_,fn) pending[#pending+1]=fn end}
local function flush()
    while #pending>0 do table.remove(pending,1)() end
end
function CreateFrame()
    return {RegisterEvent=function()end,SetScript=function(_,k,f)hooks[k]=f end}
end
function hooksecurefunc(k,f)hooks[k]=f end
function MerchantFrame_UpdateMerchantInfo() end
function MerchantFrame_UpdateBuybackInfo() end
MerchantFrame={IsShown=function()return shown end,selectedTab=1,HookScript=function(_,k,f)hooks[k]=f end}
MERCHANT_ITEMS_PER_PAGE=2
local guid=restricted
function UnitGUID(u)assert(u=="npc");return guid end
function UnitName(u)assert(u=="npc");return "Exact Goods Merchant" end
function GetMerchantNumItems()return #stock end
function GetMerchantItemID(i)return i==1 and 0 or stock[i] end
function GetMerchantItemLink(i)return stock[i] and "|Hitem:"..stock[i]..":0|h[item]|h" end
local function button(index)
 local b={index=index,art={}}
 function b:GetID()return self.index end
 function b:IsShown()return true end
 function b:CreateTexture()
    local r={Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
    for _,k in ipairs({"SetColorTexture","SetPoint","SetHeight","SetWidth","SetSize","SetDrawLayer","SetTextColor"}) do r[k]=function()end end
    r.SetText=function(self,x)self.text=x end
    self.art[#self.art+1]=r;return r
 end
 b.CreateFontString=b.CreateTexture
 return b
end
local a,b=button(1),button(2)
MerchantItem1ItemButton,MerchantItem2ItemButton=a,b
AT.InitRankQuestMerchantHighlights()
hooks.OnEvent(nil,"MERCHANT_SHOW")
hooks.OnEvent(nil,"MERCHANT_UPDATE")
assert(#pending==1,"events coalesce")
flush()
assert(#a.art==6 and a.art[1].shown and a.art[6].text=="!" and #b.art==0,"exact stock and quest ID; no GUID required")
assert(not AT.GetQuestObjectiveVendor(quest,999900),"cannot learn restricted identity")
guid="Creature-0-1-2-3-54444-001"
hooks.MerchantFrame_UpdateMerchantInfo();flush()
assert(select(2,AT.GetQuestObjectiveVendor(quest,999900))==54444 and recalc==1)
hooks.MerchantFrame_UpdateMerchantInfo();flush();assert(recalc==1,"no repeated HUD refresh")
a.index=3;hooks.MerchantFrame_UpdateMerchantInfo();assert(not a.art[1].shown,"different page and monster item")
b.index=1;hooks.MerchantFrame_UpdateMerchantInfo();assert(b.art[1].shown,"page button index reused")
done=true;hooks.OnEvent(nil,"QUEST_LOG_UPDATE");flush();assert(not b.art[1].shown)
done=false;ready=true;hooks.OnEvent(nil,"QUEST_LOG_UPDATE");flush();assert(not b.art[1].shown)
ready=false;hooks.OnEvent(nil,"MERCHANT_UPDATE");flush();assert(b.art[1].shown)
MerchantFrame.selectedTab=2;hooks.MerchantFrame_UpdateBuybackInfo();assert(not b.art[1].shown)
MerchantFrame.selectedTab=1;hooks.MerchantFrame_UpdateMerchantInfo();assert(b.art[1].shown)
shown=false;hooks.OnHide();hooks.OnEvent(nil,"MERCHANT_CLOSED");assert(not b.art[1].shown)
print("PASS verified known/unknown merchant, exact item link lookup, row refresh, single redraw, pagination, ready/done, buyback, close")

