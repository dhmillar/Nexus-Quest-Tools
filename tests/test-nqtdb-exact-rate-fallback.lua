local AT={db={}}
local grouped=false
function GetLocale()return "enUS" end
function IsInGroup()return grouped end
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","QuestMobData","EverlootDrops","ClassicQuestDropReferences","NQTDB","QuestMobs","QuestHUD"}) do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local suffix=AT.GetRankQuestDropRateSuffix
assert(suffix(92551,252760)==" (63%)")
assert(suffix(97009,276100)==" (57%)","known empty deaths change the rate per kill")
assert(suffix(95121,268345)==" (42%\226\128\14747%)","show distinct evaluated creature rates, not an arithmetic average")
assert(suffix(95122,268345)=="","never leak another quest's observed item rate")
assert(suffix(92551,252761)=="","never match by nearby item ID")
local classic=AT.ClassicQuestDropReferences[2870][9248]
assert(classic[1]==100 and suffix(2870,9248)==" (100%)")
AT.db.rankQuestLegacyDropRates=false
assert(suffix(2870,9248)=="" and suffix(92551,252760)==" (63%)")
grouped=true
assert(suffix(92551,252760)=="","new solo values never bleed into party")
grouped=false
AT.ForeverPublicDropWindows[92551]={[252760]={[0]={.19,.19}}}
assert(suffix(92551,252760)==" (19%)","do not override compatible existing evidence")
AT.ForeverPublicDropWindows[92551]=nil
local n=0
for q,items in pairs(AT.NQTDB.ExactQuestCorpseRates)do
    for i in pairs(items) do
        assert(suffix(q,i):match("^ %([0-9%%]+") and not suffix(q,i):find("reported"))
        n=n+1
    end
end
assert(n==10)
print("PASS 10 exact Forever solo estimates, rates-only display, normalized corpse counts, native priority, mode/quest identity and Classic toggle")
