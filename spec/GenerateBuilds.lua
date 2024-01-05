local function fetchBuilds(path)
    local co = coroutine.create(function(path)
        if os.getenv("BUILDLINKS") then
            local fileHnd, errMsg = io.open(os.getenv("BUILDLINKS"), "r")
            if not fileHnd then
                error(errMsg)
            end
            local fileText = fileHnd:read("*a")
            for line in magiclines( fileText ) do
                if line ~= "" then
                   for j=1,#buildSites.websiteList do
                       if line:match(buildSites.websiteList[j].matchURL) then
                            -- TODO: cache the downloaded xmls
                            buildSites.DownloadBuild(line, buildSites.websiteList[j], function(isSuccess, data) 
                               if isSuccess then
                                  coroutine.yield({xml = Inflate(common.base64.decode(data:gsub("-","+"):gsub("_","/"))), filename = line})
                               else
                                  print("Failed to download build: " .. line)
                               end
                           end)
                           break
                       end
                   end
                end
            end
        else
            for file in lfs.dir(path) do
                if file ~= "." and file ~= ".." then
                   local f = path..'/'..file
                   local attr = lfs.attributes (f)
                   assert(type(attr) == "table")
                   if attr.mode ~= "directory" and file:match("^.+(%..+)$") == ".xml" then
                       local fileHnd, errMsg = io.open(f, "r")
                       if not fileHnd then
                           error(errMsg)
                       end
                       local fileText = fileHnd:read("*a")
                       fileHnd:close()
                       coroutine.yield({xml = fileText, filename = file})
                   end
                end
            end
        end
    end)
 
    return function()
        local ok, result = coroutine.resume(co, path)
        if not ok then
            error(result)
        end
        return result
    end
 end
 

function buildTable(tableName, values, string)
    string = string or ""
    string = string .. tableName .. " = {"
    for key, value in pairs(values) do
        if type(value) == "table" then
            buildTable(key, value, string)
        elseif type(value) == "boolean" then
            string = string .. "[\"" .. key .. "\"] = " .. (value and "true" or "false") .. ",\n"
        elseif type(value) == "string" then
            string = string .. "[\"" .. key .. "\"] = \"" .. value .. "\",\n"
        else
            string = string .. "[\"" .. key .. "\"] = " .. round(value, 4) .. ",\n"
        end
    end
    string = string .. "}\n"
    return string
end

for testBuild in fetchBuilds("../spec/TestBuilds") do
    local filename = testBuild.filename:gsub('%W','')
	local filepath = (os.getenv("BUILDCACHEPREFIX") or "/tmp") .. "/" .. filename
    print("[+] Computing ".. filepath)
    loadBuildFromXML(testBuild.xml)
    local buildHnd = io.open(filepath .. ".build", "w+")
    buildHnd:write(build:SaveDB("Cache"))
    buildHnd:close()

    local outputHnd = io.open(filepath .. ".lua", "w+")
    outputHnd:write("return {\n " .. buildTable("output", build.calcsTab.mainOutput) .. "\n}")
    outputHnd:close()
end