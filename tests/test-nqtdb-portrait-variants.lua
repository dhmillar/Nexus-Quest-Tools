local AT={}
function GetLocale()return "enUS" end
for _,f in ipairs({"LevelGuideData","QuestMobData","EverlootDrops","NQTDB","QuestMobs"}) do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
for _,x in ipairs({
    {5155,7113,"Jaedenar Guardian",6399},
    {8424,6006,"Shadowsworn Adept",6770},
    {95108,259876,"Deadwood Death Mystic",1010},
    {96897,275437,"Dark Enforcer",10391},
    {96261,264082,"Broodmother Valraxx",118566},
}) do
    local q,n,name,display=unpack(x)
    local resolved,npc=AT.GetQuestKillMobName(q,{type="monster",npcID=n},name.." slain: 0/1")
    assert(resolved==name and npc==n)
    assert(AT.GetQuestMobDisplayID(resolved,true,q,nil,npc)==display,name)
    assert(not AT.GetQuestMobDisplayID("Different Creature",true,q,nil,npc))
end
assert(not AT.NQTDB.CreaturePortraitVariants[263806],"never fill a hidden kill-credit unit")
local count=0
for id,r in pairs(AT.NQTDB.CreaturePortraitVariants) do
    local base=AT.QuestMobData.creatures[id]
    assert(base and base[1]==r[1] and (not base[5] or base[5]==0),"no existing model override")
    assert(r[2]>0 and r[2]~=11686 and r[2]~=1126 and r[2]~=52318)
    count=count+1
end
assert(count==759)
print("PASS native Forever portrait representatives and singleton zero-weight profiles use the exact creature; placeholders filtered")
