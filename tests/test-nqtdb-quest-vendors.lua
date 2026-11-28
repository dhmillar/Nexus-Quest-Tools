local AT={}
local root="NQT/"
local load=function(f) assert(loadfile(root..f..".lua"))("NQT",AT) end
load("ForeverQuestFacts")
load("QuestMobData")
load("NQTDB")
load("QuestMobs")
load("QuestHUD")
local side,zone,x,y="Alliance",1432,.35,.49
local locale="enUS"
local secret={}
function GetLocale() return locale end
function UnitFactionGroup() return side end
function issecretvalue(v) return v==secret end
C_Map={
    GetBestMapForUnit=function(unit) assert(unit=="player");return zone end,
    GetPlayerMapPosition=function(m) return {GetXY=function()return x,y end} end,
    GetMapInfo=function(m) if m==1666 then return {parentMapID=1432} end end,
}
local name,npc=AT.GetQuestObjectiveVendor(308,2686)
assert(name=="Yanni Stoutheart" and npc==1682,"verified Forever local seller for exact quest objective")
-- Exercise the exact item-resolution path the Rank Quest row uses.
local resolve=AT.ResolveRankQuestObjectiveItem
assert(AT.GetQuestObjectiveVendor(308,resolve(308,{type="item",itemID=2686},"Dynamic item"))==name)
assert(AT.GetQuestObjectiveVendor(308,resolve(308,{type="item"},"|Hitem:2686:0|h[link]|h"))==name)
assert(not resolve(308,{type="item"},"|Hitem:2686:0|h[a]|h |Hitem:2894:0|h[b]|h"))
C_Item={GetItemNameByID=function(i) if i==2686 then return "Thunder Ale" end end}
assert(AT.GetQuestObjectiveVendor(308,resolve(308,{type="item"},"Thunder Ale: 0/1"))==name)
assert(not resolve(308,{type="monster",itemID=2686},"Thunder Ale: 0/1"))
assert(AT.GetQuestObjectiveVendor(384,2894)=="Yanni Stoutheart")
assert(not AT.GetQuestObjectiveVendor(384,2686),"stock alone is not an objective join")
assert(not AT.GetQuestObjectiveVendor(384,2886),"do not replace known loot with a merchant")
zone=1666
assert(AT.GetQuestObjectiveVendor(308,2686)=="Yanni Stoutheart","lookup through subzone")
side="Horde"
assert(not AT.GetQuestObjectiveVendor(308,2686),"do not show other-faction merchant")
zone=1458;x,y=.58,.55
assert(AT.GetQuestObjectiveVendor(238,8523)=="Alessandro Luca","Undercity exact Horde objective")
zone=1432
assert(not AT.GetQuestObjectiveVendor(238,8523),"do not send player to remote merchant")
zone=secret
assert(not AT.GetQuestObjectiveVendor(238,8523),"restricted map is not inspected")
locale="deDE";zone=1458
assert(not AT.GetQuestObjectiveVendor(238,8523),"no English targeting text in other locales")
locale="enUS";side="Alliance";zone=1453;x,y=.6479,.715
assert(AT.GetQuestObjectiveVendor(2609,3372)=="Edna Mullby","choose nearer eligible source")
x,y=.63,.7493
assert(AT.GetQuestObjectiveVendor(2609,3372)=="Keldric Boucher","selection follows position")
x=secret
assert(not AT.GetQuestObjectiveVendor(2609,3372),"don't guess among multiple candidates without position")
assert(AT.GetQuestObjectiveVendor(116,1941)=="Roberto Pupellyverbos","preserve stronger curated reference")
for _,rows in pairs(AT.NQTDB.ObjectiveVendors) do
    for _,r in ipairs(rows) do assert(r[1]~=256575,"world-prop merchant never gets an NPC target button") end
end
local qn,pn=0,0
for q,rows in pairs(AT.NQTDB.VendorObjectives) do
    qn=qn+1
    for item in pairs(rows) do
        local found
        for i=3,#AT.ForeverQuestFacts[q] do if AT.ForeverQuestFacts[q][i][1]==item then found=true end end
        assert(found and #AT.NQTDB.ObjectiveVendors[item]>0)
        pn=pn+1
    end
end
assert(qn>=20 and pn>=20)
print("PASS NQTDB exact vendor objectives:",qn,"quests,",pn,"quest/item pairs; nearest, faction, locale, and native priority")
