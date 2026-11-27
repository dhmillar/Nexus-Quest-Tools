
-- Inspect every Lua/XML module in the packaged manifest, including modules
-- not reached by a particular client fixture. Comments may cite provenance.
local toc=assert(io.open("NQT/NQT.toc","r"))
local count=0
for line in toc:lines() do
    assert(not line:lower():find("questie",1,true),"TOC must not request Questie")
    local name=line:match("^%s*([%w_.-]+)%s*$")
    if name and name:match("%.lua$") then
        local file=assert(io.open("NQT/"..name,"r"))
        for source in file:lines() do
            source=source:gsub("%-%-.*$","")
            assert(not source:lower():find("questie",1,true),"Questie runtime reference in "..name)
        end
        file:close()
        assert(loadfile("NQT/"..name))
        count=count+1
    elseif name and name:match("%.xml$") then
        local file=assert(io.open("NQT/"..name,"r"))
        assert(not file:read("*a"):lower():find("questie",1,true))
        file:close()
    end
end
toc:close()
assert(count>=30)
print("PASS no Questie runtime references or load dependencies in the packaged addon; all TOC Lua files compile")
