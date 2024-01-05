local l = loadfile(arg[1])().output
local r = loadfile(arg[2])().output
local mismatch = {}

for key, val in pairs(l) do
    if r[key] ~= val then
        table.insert(mismatch, key)
    end
end

for key, val in pairs(r) do
    if l[key] ~= val then
        table.insert(mismatch, key)
    end
end

print("[?] Mismatch count: " .. #mismatch .. " for " .. arg[1] .. " and " .. arg[2])
for _, key in ipairs(mismatch) do
    print(string.format("[%s] mismatch:", key))
    print("\t".. arg[1] .. ": " .. tostring(l[key]))
    print("\t".. arg[2] .. ": " .. tostring(r[key]))
end