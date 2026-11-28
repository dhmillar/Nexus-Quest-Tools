local AT={}
local function load(f) assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
load("LevelGuideData")
load("NQTDB")
load("LevelGuide")
function GetLocale() return "enUS" end
C_Item={
    GetItemNameByID=function(id) if id==3578 then return "Harvesting Through the Fields" end end,
    GetItemIconByID=function(id) return 1000000+id end,
}
local rows=AT.GetLevelGuideRewardRows(9)
assert(#rows==4 and rows[1].text=="Choose one" and rows[2].item==3578)
assert(rows[2].text:find("Harvesting Through the Fields",1,true) and rows[2].icon==1003578)
assert(rows[3].item==1561 and rows[4].item==276695)
assert(#AT.GetLevelGuideRewardRows(2)==0,"do not show unknown reputation or guess an XP amount")
assert(#AT.GetLevelGuideRewardRows(9999999)==0,"no rewards for an unknown quest")
assert(AT.GetLevelGuideRewardRows(97291)[1].text=="13s")
GetCoinTextureString=function(n) assert(n==1300);return "Native coins" end
assert(AT.GetLevelGuideRewardRows(97291)[1].text=="Native coins")
local n=0
for id,r in pairs(AT.NQTDB.Rewards) do
 assert(AT.ForeverLevelGuideQuests[id],"each reward joins the standalone quest catalog")
 assert(type(r[8])=="number" and r[8]>=0 and type(r[9])=="number" and r[9]>=0)
 n=n+1
end
assert(n==3380)
print("PASS 3380 qualified NQTDB reward rows, localized items, choice distinction, copper, no invented XP")
