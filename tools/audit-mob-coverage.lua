local AT={}
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","QuestMobData","EverlootDrops","ClassicQuestDropReferences","NQTDB","QuestMobs"}) do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
local fallback=io.open("NQT/ClassicQuestMobReferences.lua","r")
if fallback then fallback:close(); assert(loadfile("NQT/ClassicQuestMobReferences.lua"))("NQT",AT) end
function GetLocale() return "enUS" end
local rows=assert(io.open(arg and arg[1] or "mob-coverage.tsv","w"))
local qc,kill,collect,kn,kp,cn,cp=0,0,0,0,0,0,0
local mobData=AT.QuestMobData
local visited={}
local function item(q,i)
    local key=q..":"..i
    if visited[key] then return end
    visited[key]=true
    collect=collect+1
    local names=AT.GetQuestDropMobNames(i,q)
    local hasPortrait=false
    for _,name in ipairs(names or {}) do
        local model=AT.GetQuestMobDisplayID(name,true,q,i)
        if model then hasPortrait=true;break end
    end
    local named=names and #names>0
    if named then cn=cn+1 end
    if hasPortrait then cp=cp+1 end
    rows:write(string.format("item\t%d\t%d\t%d\t%d\n",q,i,named and 1 or 0,hasPortrait and 1 or 0))
end
for q,quest in pairs(AT.ForeverLevelGuideQuests) do
    qc=qc+1
    local killed={}
    for _,ob in ipairs(quest[10] or {}) do
        local kind,id=unpack(ob)
        if kind==1 and type(id)=="number" and id>0 and not killed[id] then
            killed[id]=true
            kill=kill+1
            local mob=mobData.creatures[id] or (AT.ClassicQuestCreatureProfiles and AT.ClassicQuestCreatureProfiles[id])
            local name,resolved
            if mob and mob[1] then name,resolved=AT.GetQuestKillMobName(q,{type="monster",npcID=id},mob[1].." slain: 0/1")
            else name,resolved=AT.GetQuestKillMobName(q,{type="monster",npcID=id},"Kill target: 0/1") end
            local model=name and AT.GetQuestMobDisplayID(name,true,q,nil,resolved)
            if name then kn=kn+1 end
            if model then kp=kp+1 end
            rows:write(string.format("kill\t%d\t%d\t%d\t%d\n",q,id,name and 1 or 0,model and 1 or 0))
        elseif kind==2 and type(id)=="number" and id>0 then item(q,id) end
    end
end
for q,r in pairs(AT.ForeverQuestFacts) do for n=3,#r do item(q,r[n][1]) end end
rows:close()
print(string.format("quests=%d kill_pairs=%d with_name=%d with_portrait=%d collect_pairs=%d with_name=%d with_portrait=%d",qc,kill,kn,kp,collect,cn,cp))
