-- loader.lua — то, что вставляют в экзекьютор.
-- Into The Hive: no recoil / no spread / magazine.

local URLS = {
    "https://raw.githubusercontent.com/fieyhqwis/test/main/hive/gun_cheat.luau",
    "https://cdn.jsdelivr.net/gh/fieyhqwis/test@main/hive/gun_cheat.luau",
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
