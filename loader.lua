-- loader.lua — то, что вставляют в экзекьютор.
-- Замени USER и REPO на свои (2 ссылки ниже).

local URLS = {
    "https://raw.githubusercontent.com/USER/REPO/main/blockpvp_ka.obf.luau",
    "https://cdn.jsdelivr.net/gh/USER/REPO@main/blockpvp_ka.obf.luau",
}

local src
for i = 1, #URLS do
    local ok, res = pcall(function()
        return game:HttpGet(URLS[i], true)
    end)
    if ok and type(res) == "string" and #res > 1000 then
        src = res
        break
    end
end

if not src then
    error("[loader] не смог скачать скрипт")
end

local fn = loadstring(src)
if not fn then
    error("[loader] скрипт не компилируется")
end

return fn()
