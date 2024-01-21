local function fetchBuilds(path)
    local co = coroutine.create(function(path)
        if os.getenv("BUILDLINKS") then
            local fileHnd, errMsg = io.open(os.getenv("BUILDLINKS"), "r")
            if not fileHnd then
                error(errMsg)
            end
            local fileText = fileHnd:read("*a")
            fileHnd:close()
            for line in splitLines( fileText ) do
                if line ~= "" then
                    for j=1,#buildSites.websiteList do
                        if line:match(buildSites.websiteList[j].matchURL) then
                            local filename = line:gsub('%W','')

                            -- Load from cache if downloaded already
                            local fileHnd = io.open((os.getenv("CACHEDIR")  or "/tmp") .. "/" .. filename .. ".xml", "r") 
                            if fileHnd then
                                coroutine.yield({xml = fileHnd:read("*a"), filename = filename, link = line})
                                fileHnd:close()
                            else
                                buildSites.DownloadBuild(line, buildSites.websiteList[j], function(isSuccess, data) 
                                    if isSuccess then
                                        local xml = Inflate(common.base64.decode(data:gsub("-","+"):gsub("_","/")))
                                        coroutine.yield({xml = xml, filename = filename, link = line})
                                        local xmlHnd = io.open((os.getenv("CACHEDIR")  or "/tmp") .. "/" .. filename .. ".xml", "w+")
                                        xmlHnd:write(xml)
                                        xmlHnd:close()
                                    else
                                       print("Failed to download build: " .. line)
                                    end
                                end)     
                            end
                            break
                        elseif j == #buildSites.websiteList then
                            print("Failed to match provider for: " .. line)
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
	local filepath = (os.getenv("BUILDCACHEPREFIX") or "/tmp") .. "/" .. testBuild.filename
    print("[+] Computing ".. filepath)
    loadBuildFromXML(testBuild.xml)
    local buildHnd = io.open(filepath .. ".build", "w+")
    buildHnd:write(build:SaveDB("Cache"))
    buildHnd:close()

    local outputHnd = io.open(filepath .. ".lua", "w+")
    outputHnd:write("return {\n " .. buildTable("output", build.calcsTab.mainOutput) .. "\n}")
    outputHnd:close()
end