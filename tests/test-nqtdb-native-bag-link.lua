local AT={db={enabled=true,questLeftoverMarks=true},char={}}
local on,live,found=false,nil,nil
local secret={}
function issecretvalue(v)return v==secret end
C_QuestLog={GetNumQuestLogEntries=function()return 0,1 end,
    IsOnQuest=function(q)return q==9205 and on end,
    GetQuestObjectives=function(q)if q==9205 then return live end end}
C_Container={GetContainerItemID=function()return 13890 end,
    GetContainerItemQuestInfo=function()return {isQuestItem=false,isActive=false}end}
C_Item={GetItemNameByID=function()return "Plated Armorfish" end}
IsControlKeyDown=function()return true end
AT.SearchRankQuestItem=function(q,item)found={q,item} end
CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end} end
local b={GetBagID=function()return 0 end,GetID=function()return 1 end,
    HookScript=function(self,_,cb)self.click=cb end}
ContainerFrameCombinedBags={EnumerateValidItems=function()return ipairs({b}) end}
for _,name in ipairs({"ForeverQuestFacts","NQTDB","QuestLeftovers"})do
    assert(loadfile("NQT/"..name..".lua"))("NQT",AT)
end
AT.InitBagQuestLink()
b.click(b,"LeftButton")
assert(not found and not AT.GetForeverObjectiveQuests(13890),"unheld native-only backlink never appears in the global discard index")
on=secret;b.click(b,"LeftButton");assert(not found)
on=true;b.click(b,"LeftButton");assert(found and found[1]==9205 and found[2]=="Plated Armorfish")
found=nil;live={{type="item",itemID=99999}}
b.click(b,"LeftButton");assert(not found,"complete native objective metadata rejects a stale fallback")
live={{type="item",text="Plated Armorfish: 2/30"}}
b.click(b,"LeftButton");assert(found and found[1]==9205,"missing live item ID does not block verified held backlink")
print("PASS native-only Plated Armorfish Ctrl-click across collapsed log; hold/secret/decoy/discard guards")
