local CoreGui = game.CoreGui
local ContentProvider = game.ContentProvider
local RobloxGuis = {"RobloxGui", "TeleportGui", "RobloxPromptGui", "RobloxLoadingGui", "PlayerList", "RobloxNetworkPauseNotification", "PurchasePrompt", "HeadsetDisconnectedDialog", "ThemeProvider", "DevConsoleMaster"}

local function FilterTable(tbl)
    local context = syn_context_get()
    syn_context_set(7)
    local new = {}
    for i,v in ipairs(tbl) do --roblox iterates the array part
        if typeof(v) ~= "Instance" then
            table.insert(new, v)
        else
            if v == CoreGui or v == game then
                --insert only the default roblox guis
                for i,v in pairs(RobloxGuis) do
                    local gui = CoreGui:FindFirstChild(v)
                    if gui then
                        table.insert(new, gui)
                    end
                end

                if v == game then
                    for i,v in pairs(game:GetChildren()) do
                        if v ~= CoreGui then
                            table.insert(new, v)
                        end
                    end
                end
            else
                if not CoreGui:IsAncestorOf(v) then
                    table.insert(new, v)
                else
                    --don't insert it if it's a descendant of a different gui than default roblox guis
                    for j,k in pairs(RobloxGuis) do
                        local gui = CoreGui:FindFirstChild(k)
                        if gui then
                            if v == gui or gui:IsAncestorOf(v) then
                                table.insert(new, v)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    syn_context_set(context)
    return new
end

local old
old = hookfunc(ContentProvider.PreloadAsync, function(self, tbl, cb)
    if self ~= ContentProvider or type(tbl) ~= "table" or type(cb) ~= "function" then --note: callback can be nil but in that case it's useless anyways
        return old(self, tbl, cb)
    end

    --check for any errors that I might've missed (such as table being {[2] = "something"} which causes "Unable to cast to Array")
    local err
    task.spawn(function() --TIL pcalling a C yield function inside a C yield function is a bad idea ("cannot resume non-suspended coroutine")
        local s,e = pcall(old, self, tbl)
        if not s and e then
            err = e
        end
    end)
   
    if err then
        return old(self, tbl) --don't pass the callback, just in case
    end

    tbl = FilterTable(tbl)
    return old(self, tbl, cb)
end)

local old
old = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if self == ContentProvider and (method == "PreloadAsync" or method == "preloadAsync") then
        local args = {...}
        if type(args[1]) ~= "table" or type(args[2]) ~= "function" then
            return old(self, ...)
        end

        local err
        task.spawn(function()
            setnamecallmethod(method) --different thread, different namecall method
            local s,e = pcall(old, self, args[1])
            if not s and e then
                err = e
            end
        end)

        if err then
            return old(self, args[1])
        end

        args[1] = FilterTable(args[1])
        setnamecallmethod(method)
        return old(self, args[1], args[2])
    end
    return old(self, ...)
end)
