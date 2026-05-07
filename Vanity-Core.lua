-- =========================================================================
-- VANITY: Modular Character Description Manager
-- A central script interface for Mudlet, allowing you to easily swap and
-- build character descriptions in Achaea without relying on XML packages.
-- =========================================================================
Vanity = Vanity or {}

-- =========================================================================
-- Configuration & Theme
-- =========================================================================
Vanity.config = {
    colors = {
        border    = "<medium_orchid>",
        prefix    = "<orchid>",
        text      = "<white>",
        highlight = "<gold>",
        error     = "<crimson>",
        warning   = "<orange>"
    },
    limits = {
        main = 2034,
        element = 75
    },
    gagGameEcho = true,
    debug = false -- Toggle via 'vanity debug' in-game
}

Vanity.descriptions = Vanity.descriptions or {}
Vanity.elements = Vanity.elements or {}

-- =========================================================================
-- Standardized Output Helper
-- =========================================================================
function Vanity.echo(msg)
    local c = Vanity.config.colors
    cecho(string.format("\n%s[Vanity]:<reset> %s\n", c.prefix, msg))
end

-- =========================================================================
-- Data Management & Migration
-- =========================================================================
function Vanity.save()
    local baseDir = getMudletHomeDir() .. "/Vanity"
    if not lfs.attributes(baseDir) then 
        lfs.mkdir(baseDir) 
    end
    
    local data = {
        descriptions = Vanity.descriptions,
        elements = Vanity.elements
    }
    
    local filepath = baseDir .. "/Vanity_Data.lua"
    table.save(filepath, data)
end

function Vanity.load()
    local baseDir = getMudletHomeDir() .. "/Vanity"
    local newFile = baseDir .. "/Vanity_Data.lua"
    
    if io.exists(newFile) then
        local data = {}
        table.load(newFile, data)
        Vanity.descriptions = data.descriptions or {}
        Vanity.elements = data.elements or data.components or {} 
        
        local migrated = false
        for k, v in pairs(Vanity.descriptions) do
            if type(v) == "string" then
                Vanity.descriptions[k] = {
                    name = k:gsub("^%l", string.upper), 
                    content = v
                }
                migrated = true
            end
        end
        if migrated then 
            Vanity.save() 
            Vanity.echo("Migrated older descriptions to the new Keyword/Name format.")
        end
    end
end

-- =========================================================================
-- Utility: Gag Game Echoes (Smart Line Eater)
-- =========================================================================
function Vanity.gagEcho()
    if not Vanity.config.gagGameEcho then return end
    
    if Vanity.gagStartTrig then killTrigger(Vanity.gagStartTrig) end
    
    -- We look for either anchor in case Achaea skips one for some reason
    Vanity.gagStartTrig = tempRegexTrigger("^(Your previous description was:|This is now how you appear:)", function()
        deleteLine()
        
        if Vanity.config.debug then Vanity.echo("GAG START triggered by: " .. line) end
        
        if Vanity.gagEaterTrig then killTrigger(Vanity.gagEaterTrig) end
        
        -- This trigger blindly eats every line that follows
        Vanity.gagEaterTrig = tempRegexTrigger("^.*$", function()
            if Vanity.config.debug then
                cecho("<red>[EATING]:<reset> " .. line .. "\n")
            end
            
            deleteLine()
            
            -- Stop eating the moment we see the final anchor text
            if string.find(line, "try LOOK ME.", 1, true) then
                killTrigger(Vanity.gagEaterTrig)
                Vanity.gagEaterTrig = nil
                if Vanity.config.debug then Vanity.echo("GAG STOPPED safely at LOOK ME anchor.") end
            end
        end)
        
        -- Failsafe: 1.5 seconds gives plenty of time for packet fragmentation to resolve
        tempTimer(1.5, function() 
            if Vanity.gagEaterTrig then 
                killTrigger(Vanity.gagEaterTrig) 
                Vanity.gagEaterTrig = nil
                if Vanity.config.debug then Vanity.echo("GAG FAILSAFE triggered (1.5s timeout expired).") end
            end 
        end)
    end)
    
    -- Cleanup the initial watcher if nothing happens
    tempTimer(2, function() 
        if Vanity.gagStartTrig then 
            killTrigger(Vanity.gagStartTrig)
            Vanity.gagStartTrig = nil 
            if Vanity.config.debug then Vanity.echo("Gag Start Trigger expired waiting for Achaea.") end
        end 
    end)
end

-- =========================================================================
-- Style Checker
-- =========================================================================
function Vanity.checkStyle(text)
    local t = text:lower()
    local warnings = {}
    
    if t:match("wearing") or t:match("dressed in") or t:match("clothes") or t:match("cloak") or t:match("wielding") or t:match("holding") then
        table.insert(warnings, "Clothing/Items: The game automatically shows your inventory and worn items. Adding clothes here may contradict your actual gear.")
    end
    
    if t:match(" is a human") or t:match(" is a dwarf") or t:match(" male ") or t:match(" female ") then
        table.insert(warnings, "Race/Gender: Achaea automatically prepends your race and gender. You don't need to repeat it.")
    end
    
    if t:match("makes you feel") or t:match("you can't help but") or t:match("intimidating you") then
        table.insert(warnings, "Godmoding: Remember to describe only what people *see*, rather than telling them how to feel or react.")
    end
    
    if #warnings > 0 then
        local c = Vanity.config.colors
        Vanity.echo(string.format("%sStyle Guidance Hints:<reset>", c.warning))
        for _, w in ipairs(warnings) do
            cecho(string.format("  %s*%s %s%s<reset>\n", c.highlight, c.text, c.text, w))
        end
    end
end

-- =========================================================================
-- Element Features
-- =========================================================================
function Vanity.updateElement(elemType, text)
    elemType = elemType:upper()
    local c = Vanity.config.colors
    local validTypes = {HAIR=true, BALD=true, EYES=true, COMPLEXION=true, HEIGHT=true, BUILD=true}
    
    if not validTypes[elemType] then
        Vanity.echo(string.format("%sInvalid element. Use HAIR, BALD, EYES, COMPLEXION, HEIGHT, or BUILD.<reset>", c.error))
        return
    end
    
    if elemType == "BALD" then
        Vanity.elements["HAIR"] = "bald"
        Vanity.save()
        Vanity.gagEcho()
        send("DESCRIBE SELF BALD")
        Vanity.echo(string.format("%sElement %sHair%s set to %sBald%s and sent to Achaea.<reset>", c.text, c.highlight, c.text, c.highlight, c.text))
        return
    end
    
    if text:len() > Vanity.config.limits.element then
        Vanity.echo(string.format("%sElement text is too long! Max %d characters. You entered %d.<reset>", c.error, Vanity.config.limits.element, text:len()))
        return
    end
    
    Vanity.elements[elemType] = text
    Vanity.save()
    Vanity.gagEcho()
    send("DESCRIBE SELF " .. elemType .. " " .. text)
    
    local niceName = elemType:lower():gsub("^%l", string.upper)
    Vanity.echo(string.format("%sElement %s%s%s updated and sent to Achaea.<reset>", c.text, c.highlight, niceName, c.text))
end

function Vanity.listElements()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                          E L E M E N T S                              <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    local elems = {"HEIGHT", "BUILD", "COMPLEXION", "EYES", "HAIR"}
    for _, k in ipairs(elems) do
        local val = Vanity.elements[k] or "Not set"
        local niceName = k:lower():gsub("^%l", string.upper)
        cecho(string.format("%s%-15s<reset> : %s%s<reset>\n", c.highlight, niceName, c.text, val))
    end
    cecho(string.format("%s=======================================================================<reset>\n", c.border))
end

function Vanity.combineElements(saveKey, saveName)
    local c = Vanity.config.colors
    local order = {"HEIGHT", "BUILD", "COMPLEXION", "EYES", "HAIR"}
    local parts = {}
    
    for _, elem in ipairs(order) do
        if Vanity.elements[elem] and Vanity.elements[elem] ~= "" then
            table.insert(parts, Vanity.elements[elem])
        end
    end
    
    local combined = table.concat(parts, " ")
    
    if combined == "" then
        Vanity.echo(string.format("%sYou have not set any elements to combine yet!<reset>", c.error))
        return
    end
    
    Vanity.echo(string.format("%sExperimental Combined Description:<reset>", c.highlight))
    cecho(string.format("%s%s<reset>\n", c.text, combined))
    
    Vanity.checkStyle(combined)
    
    if saveKey and saveName then
        Vanity.addDescription(saveKey, saveName, combined)
    else
        cecho(string.format("\n%s(Tip: Use '%svanity elem combine <keyword> \"<Name>\"%s' to automatically save this.)<reset>\n", c.warning, c.highlight, c.warning))
    end
end

-- =========================================================================
-- Main Description Features
-- =========================================================================
function Vanity.addDescription(keyword, name, content)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[keyword] then
        Vanity.echo(string.format("%sKeyword '%s' already exists! Use %svanity update%s instead.<reset>", c.error, keyword, c.highlight, c.error))
        return
    end
    
    Vanity.performSaveLogic(keyword, name, content, "added")
end

function Vanity.updateDescription(keyword, name, content)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if not Vanity.descriptions[keyword] then
        Vanity.echo(string.format("%sKeyword '%s' not found! Use %svanity add%s to create a new one.<reset>", c.error, keyword, c.highlight, c.error))
        return
    end
    
    name = name or Vanity.descriptions[keyword].name
    Vanity.performSaveLogic(keyword, name, content, "updated")
end

function Vanity.performSaveLogic(keyword, name, content, actionWord)
    local c = Vanity.config.colors
    local length = content:len()
    local max = Vanity.config.limits.main
    
    if length > max then
        Vanity.echo(string.format("%sERROR: Description is %d characters. The Achaea limit is %d!<reset>", c.error, length, max))
        return
    elseif length > (max - 100) then
        Vanity.echo(string.format("%sWARNING: Description is %d characters. You are very close to the %d limit!<reset>", c.warning, length, max))
    end
    
    Vanity.checkStyle(content)
    
    Vanity.descriptions[keyword] = { name = name, content = content }
    Vanity.save()
    Vanity.echo(string.format("%sDescription [%s%s%s] '%s%s%s' has been %s.<reset>", c.text, c.highlight, keyword, c.text, c.highlight, name, c.text, actionWord))
end

function Vanity.copyDescription(oldKey, newKey, newName)
    oldKey = oldKey:lower()
    newKey = newKey:lower()
    local c = Vanity.config.colors
    
    if not Vanity.descriptions[oldKey] then
        Vanity.echo(string.format("%sSource keyword '%s' not found.<reset>", c.error, oldKey))
        return
    end
    if Vanity.descriptions[newKey] then
        Vanity.echo(string.format("%sDestination keyword '%s' already exists! Pick a new keyword.<reset>", c.error, newKey))
        return
    end
    
    local content = Vanity.descriptions[oldKey].content
    Vanity.descriptions[newKey] = { name = newName, content = content }
    Vanity.save()
    Vanity.echo(string.format("%sCopied [%s] to new description [%s%s%s] '%s%s%s'.<reset>", c.text, oldKey, c.highlight, newKey, c.text, c.highlight, newName, c.text))
end

function Vanity.deleteDescription(keyword, confirmText)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if not Vanity.descriptions[keyword] then
        Vanity.echo(string.format("%sKeyword '%s' not found.<reset>", c.error, keyword))
        return
    end
    
    if confirmText ~= "CONFIRM" then
        Vanity.echo(string.format("%sTo delete this description, you must type: %svanity delete %s CONFIRM<reset>", c.warning, c.highlight, keyword))
        return
    end
    
    local name = Vanity.descriptions[keyword].name
    Vanity.descriptions[keyword] = nil
    Vanity.save()
    Vanity.echo(string.format("%sDescription [%s%s%s] '%s%s%s' deleted.<reset>", c.text, c.highlight, keyword, c.text, c.highlight, name, c.text))
end

function Vanity.useDescription(keyword)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[keyword] then
        Vanity.gagEcho()
        send("DESCRIBE SELF " .. Vanity.descriptions[keyword].content)
        Vanity.echo(string.format("%sApplied description '%s%s%s'.<reset>", c.text, c.highlight, Vanity.descriptions[keyword].name, c.text))
    else
        Vanity.echo(string.format("%sKeyword '%s' not found.<reset>", c.error, keyword))
    end
end

function Vanity.showDescription(keyword)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[keyword] then
        local data = Vanity.descriptions[keyword]
        cecho(string.format("\n%s=======================================================================<reset>", c.border))
        cecho(string.format("\n%s                 V A N I T Y : %s%s %s(%s)<reset>", c.border, c.highlight, data.name:upper(), c.prefix, keyword))
        cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
        cecho(string.format("%s%s<reset>\n", c.text, data.content))
        cecho(string.format("%s=======================================================================<reset>\n", c.border))
    else
        Vanity.echo(string.format("%sKeyword '%s' not found.<reset>", c.error, keyword))
    end
end

function Vanity.editDescription(keyword)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[keyword] then
        local data = Vanity.descriptions[keyword]
        clearCmdLine()
        appendCmdLine(string.format("vanity update %s \"%s\" %s", keyword, data.name, data.content))
        Vanity.echo(string.format("%sDescription [%s%s%s] loaded into your command line. Edit it and press Enter to save!<reset>", c.text, c.highlight, keyword, c.text))
    else
        Vanity.echo(string.format("%sKeyword '%s' not found.<reset>", c.error, keyword))
    end
end

function Vanity.listDescriptions()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        V A N I T Y   L I S T                          <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    -- Dynamic Padding Calculator
    local maxKeyLen = 10
    local maxNameLen = 20
    for k, d in pairs(Vanity.descriptions) do
        if #k > maxKeyLen then maxKeyLen = #k end
        if #d.name > maxNameLen then maxNameLen = #d.name end
    end
    
    local count = 0
    for keyword, data in pairs(Vanity.descriptions) do
        local preview = string.sub(data.content, 1, 35)
        if string.len(data.content) > 35 then preview = preview .. "..." end
        
        local keyPad = keyword .. string.rep(" ", maxKeyLen - #keyword)
        local namePad = data.name .. string.rep(" ", maxNameLen - #data.name)
        
        cecho("  ")
        cechoLink(string.format("%s[%s]<reset>", c.highlight, keyPad), [[Vanity.useDescription("]]..keyword..[[")]], "Click to activate " .. data.name, true)
        cecho(string.format(" %s%s<reset> : %s%s<reset>\n", c.prefix, namePad, c.text, preview))
        count = count + 1
    end
    
    if count == 0 then
        cecho(string.format("\n%sNo descriptions saved yet. Use %svanity add <keyword> \"<Name>\" <desc>%s to create one.<reset>\n", c.text, c.highlight, c.text))
    end
    cecho(string.format("%s=======================================================================<reset>\n", c.border))
end

-- =========================================================================
-- In-Game Commands, Dashboard & Help Interface
-- =========================================================================
function Vanity.showDashboard()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                     V A N I T Y   D A S H B O A R D                   <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    cecho(string.format("\n%sCurrent Elements:<reset>\n", c.prefix))
    local elems = {"HEIGHT", "BUILD", "COMPLEXION", "EYES", "HAIR"}
    for _, k in ipairs(elems) do
        local val = Vanity.elements[k] or "Not set"
        local niceName = k:lower():gsub("^%l", string.upper)
        cecho(string.format("  %s%-15s<reset> : %s%s<reset>\n", c.highlight, niceName, c.text, val))
    end

    cecho(string.format("\n%sSaved Descriptions (Click Keyword to Activate):<reset>\n", c.prefix))
    
    -- Dynamic Padding Calculator
    local maxKeyLen = 10
    for k, d in pairs(Vanity.descriptions) do
        if #k > maxKeyLen then maxKeyLen = #k end
    end
    
    local count = 0
    for keyword, data in pairs(Vanity.descriptions) do
        local keyPad = keyword .. string.rep(" ", maxKeyLen - #keyword)
        
        cecho("  ")
        cechoLink(string.format("%s[%s]<reset>", c.highlight, keyPad), [[Vanity.useDescription("]]..keyword..[[")]], "Activate " .. data.name, true)
        cecho(string.format(" %s%s<reset>\n", c.text, data.name))
        count = count + 1
    end
    if count == 0 then
        cecho(string.format("  %sNo descriptions saved yet.<reset>\n", c.text))
    end
    
    cecho(string.format("\n%sQuick Syntax Guide:<reset>\n", c.prefix))
    cecho(string.format("  %svanity use <keyword><reset>                  - Activate a saved description.\n", c.highlight))
    cecho(string.format("  %svanity add <keyword> \"<Name>\" <text><reset>  - Save a new description.\n", c.highlight))
    cecho(string.format("  %svanity elem update <type> <text><reset>      - Save an element.\n", c.highlight))
    cecho(string.format("  %svanity help<reset>                           - View the full list of commands.\n", c.warning))

    cecho(string.format("%s=======================================================================<reset>\n", c.border))
end

function Vanity.showHelp()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        V A N I T Y   H E L P                          <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    cecho(string.format("\n%sMain Descriptions:<reset>", c.prefix))
    cecho(string.format("\n  %svanity add <keyword> \"<Name>\" <text><reset>     - Creates a new description.", c.highlight))
    cecho(string.format("\n  %svanity update <keyword> \"<Name>\" <text><reset>  - Updates an existing description.", c.highlight))
    cecho(string.format("\n  %svanity update <keyword> <text><reset>           - Updates text only (keeps Name).", c.highlight))
    cecho(string.format("\n  %svanity copy <old_key> <new_key> \"<Name>\"<reset> - Copies an existing description.", c.highlight))
    cecho(string.format("\n  %svanity use <keyword><reset>                     - Sends description to Achaea.", c.highlight))
    cecho(string.format("\n  %svanity show <keyword><reset>                    - Displays the full text.", c.highlight))
    cecho(string.format("\n  %svanity list<reset>                              - Displays a table of all descriptions.", c.highlight))
    cecho(string.format("\n  %svanity edit <keyword><reset>                    - Loads description into input to edit.", c.highlight))
    cecho(string.format("\n  %svanity delete <keyword> CONFIRM<reset>          - Safely removes a description.", c.highlight))
    
    cecho(string.format("\n\n%sElement Descriptions:<reset>", c.prefix))
    cecho(string.format("\n  %svanity elem update <type> <text><reset>         - Sets an element (e.g. HAIR blonde).", c.highlight))
    cecho(string.format("\n  %svanity elem update BALD<reset>                  - Sets your character to bald.", c.highlight))
    cecho(string.format("\n  %svanity elem list<reset>                         - Shows your local saved elements.", c.highlight))
    cecho(string.format("\n  %svanity elem combine <keyword> \"<Name>\"<reset>   - Generates & saves a full desc.", c.highlight))
    
    cecho(string.format("\n\n%sUtility:<reset>", c.prefix))
    cecho(string.format("\n  %svanity debug<reset>                             - Toggles gag visualizer.", c.highlight))

    cecho(string.format("\n\n%s=======================================================================<reset>\n", c.border))
end

function Vanity.handleCommand(args)
    local cmd = args:lower()
    
    if cmd == "" then
        Vanity.showDashboard()
    elseif cmd == "help" then
        Vanity.showHelp()
    elseif cmd == "list" then
        Vanity.listDescriptions()
    elseif cmd == "debug" then
        Vanity.config.debug = not Vanity.config.debug
        local state = Vanity.config.debug and "<green>ON<reset>" or "<red>OFF<reset>"
        Vanity.echo("Debug mode is now " .. state)
    else
        -- Main Description Parsers
        local addKey, addName, addContent = string.match(args, "^[Aa][Dd][Dd]%s+(%w+)%s+\"([^\"]+)\"%s+(.+)$")
        local updKeyName, updName, updContentName = string.match(args, "^[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+\"([^\"]+)\"%s+(.+)$")
        local updKey, updContent = string.match(args, "^[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+(.+)$")
        local copyOld, copyNew, copyName = string.match(args, "^[Cc][Oo][Pp][Yy]%s+(%w+)%s+(%w+)%s+\"([^\"]+)\"$")
        local useKey = string.match(args, "^[Uu][Ss][Ee]%s+(%w+)$")
        local showKey = string.match(args, "^[Ss][Hh][Oo][Ww]%s+(%w+)$")
        local delKey, delConfirm = string.match(args, "^[Dd][Ee][Ll][Ee][Tt][Ee]%s+(%w+)%s*(.*)$")
        local editKey = string.match(args, "^[Ee][Dd][Ii][Tt]%s+(%w+)$")
        
        -- Element Parsers
        local elemUpdateType, elemUpdateText = string.match(args, "^[Ee][Ll][Ee][Mm]%s+[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%a+)%s*(.*)$")
        local elemList = string.match(args, "^[Ee][Ll][Ee][Mm]%s+[Ll][Ii][Ss][Tt]$")
        local elemCombineAll = string.match(args, "^[Ee][Ll][Ee][Mm]%s+[Cc][Oo][Mm][Bb][Ii][Nn][Ee]%s*(.*)$")
        
        -- Routing Logic
        if elemUpdateType then
            Vanity.updateElement(elemUpdateType, elemUpdateText)
        elseif elemList then
            Vanity.listElements()
        elseif elemCombineAll then
            local combKey, combName = string.match(elemCombineAll, "^(%w+)%s+\"([^\"]+)\"$")
            Vanity.combineElements(combKey, combName)
        elseif addKey then
            Vanity.addDescription(addKey, addName, addContent)
        elseif updKeyName then
            Vanity.updateDescription(updKeyName, updName, updContentName)
        elseif updKey then
            Vanity.updateDescription(updKey, nil, updContent)
        elseif copyOld then
            Vanity.copyDescription(copyOld, copyNew, copyName)
        elseif useKey then
            Vanity.useDescription(useKey)
        elseif showKey then
            Vanity.showDescription(showKey)
        elseif editKey then
            Vanity.editDescription(editKey)
        elseif delKey then
            Vanity.deleteDescription(delKey, delConfirm)
        else
            Vanity.echo(string.format("%sUnknown command or invalid syntax. Type %svanity help%s for options.<reset>", Vanity.config.colors.error, Vanity.config.colors.highlight, Vanity.config.colors.error))
        end
    end
end

-- =========================================================================
-- Initialization
-- =========================================================================
function Vanity.init()
    if Vanity.aliasHandler then killAlias(Vanity.aliasHandler) end
    
    Vanity.aliasHandler = tempAlias("^vanity(?: (.*))?$", [[
        local args = matches[2] or ""
        Vanity.handleCommand(args)
    ]])

    Vanity.load()
    Vanity.echo("Manager Initialized. Type " .. Vanity.config.colors.highlight .. "vanity<reset> to view your dashboard.")
end

Vanity.init()