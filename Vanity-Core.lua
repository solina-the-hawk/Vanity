-- =========================================================================
-- VANITY: Modular Character Description Manager
-- A central script interface for Mudlet, allowing you to easily swap and
-- build character descriptions in Achaea without relying on XML packages.
-- Author: Solina (https://github.com/solina-the-hawk/vanity/)
-- Version: 1.1.0
-- =========================================================================
Vanity = Vanity or {}

-- =========================================================================
-- Configuration & State Variables
-- =========================================================================
Vanity.config = {
    colors = {
        border    = "<medium_orchid>",
        prefix    = "<orchid>",
        text      = "<white>",
        highlight = "<gold>",
        error     = "<red>",
        warning   = "<orange>"
    },
    limits = {
        main = 2034,
        element = 75,
        pose = 60
    },
    mode = Vanity.config and Vanity.config.mode or "standard",
    gagGameEcho = true,
    debug = false
}

Vanity.descriptions = Vanity.descriptions or {}
Vanity.elements = Vanity.elements or {}
Vanity.addon = Vanity.addon or { text = "", enabled = false }
Vanity.poses = Vanity.poses or {}
Vanity.currentPose = Vanity.currentPose or { type = "None", text = "Not set" }
Vanity.lastRoom = Vanity.lastRoom or 0

-- Complex Mode Variables
Vanity.phrases = Vanity.phrases or {}
Vanity.activeSlots = Vanity.activeSlots or {}
Vanity.slotBindings = Vanity.slotBindings or {}

-- =========================================================================
-- Standardized Output & Utilities
-- =========================================================================
function Vanity.echo(msg)
    local c = Vanity.config.colors
    cecho(string.format("\n%s[Vanity]:<reset> %s\n", c.prefix, msg))
end

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

function Vanity.gagEcho()
    if not Vanity.config.gagGameEcho then return end
    
    if Vanity.gagStartTrig then killTrigger(Vanity.gagStartTrig) end
    
    Vanity.gagStartTrig = tempRegexTrigger("^(Your previous description was:|This is now how you appear:)", function()
        deleteLine()
        
        if Vanity.config.debug then Vanity.echo("GAG START triggered by: " .. line) end
        if Vanity.gagEaterTrig then killTrigger(Vanity.gagEaterTrig) end
        
        Vanity.gagEaterTrig = tempRegexTrigger("^.*$", function()
            if Vanity.config.debug then
                cecho("<red>[EATING]:<reset> " .. line .. "\n")
            end
            
            deleteLine()
            
            if string.find(line, "try LOOK ME.", 1, true) then
                killTrigger(Vanity.gagEaterTrig)
                Vanity.gagEaterTrig = nil
                if Vanity.config.debug then Vanity.echo("GAG STOPPED safely at LOOK ME anchor.") end
            end
        end)
        
        tempTimer(1.5, function() 
            if Vanity.gagEaterTrig then 
                killTrigger(Vanity.gagEaterTrig) 
                Vanity.gagEaterTrig = nil
                if Vanity.config.debug then Vanity.echo("GAG FAILSAFE triggered (1.5s timeout expired).") end
            end 
        end)
    end)
    
    tempTimer(2, function() 
        if Vanity.gagStartTrig then 
            killTrigger(Vanity.gagStartTrig)
            Vanity.gagStartTrig = nil 
            if Vanity.config.debug then Vanity.echo("Gag Start Trigger expired waiting for Achaea.") end
        end 
    end)
end

function Vanity.onRoomMove()
    if not gmcp or not gmcp.Room or not gmcp.Room.Info then return end
    
    local currentRoom = gmcp.Room.Info.num
    
    if Vanity.lastRoom ~= 0 and Vanity.lastRoom ~= currentRoom then
        if Vanity.currentPose.type == "TPOSE" then
            Vanity.currentPose = { type = "None", text = "Not set" }
            Vanity.save()
            if Vanity.config.debug then Vanity.echo("TPOSE silently cleared due to room movement.") end
        end
    end
    
    Vanity.lastRoom = currentRoom
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
        config_mode = Vanity.config.mode,
        descriptions = Vanity.descriptions,
        elements = Vanity.elements,
        addon = Vanity.addon,
        poses = Vanity.poses,
        currentPose = Vanity.currentPose,
        phrases = Vanity.phrases,
        activeSlots = Vanity.activeSlots,
        slotBindings = Vanity.slotBindings
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
        
        Vanity.config.mode = data.config_mode or "standard"
        Vanity.phrases = data.phrases or {}
        Vanity.activeSlots = data.activeSlots or {}
        Vanity.slotBindings = data.slotBindings or {}
        Vanity.descriptions = data.descriptions or {}
        Vanity.elements = data.elements or data.components or {} 
        Vanity.addon = data.addon or { text = "", enabled = false }
        Vanity.poses = data.poses or {}
        Vanity.currentPose = data.currentPose or { type = "None", text = "Not set" }
        
        local phrasesMigrated = false
        for k, v in pairs(Vanity.phrases) do
            if type(v) == "string" then
                Vanity.phrases[k] = { category = "general", text = v }
                phrasesMigrated = true
            end
        end
        if phrasesMigrated then Vanity.save() end

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
-- Standard Mode: Main Descriptions
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
        local finalContent = Vanity.descriptions[keyword].content
        
        if Vanity.addon.enabled and Vanity.addon.text ~= "" then
            finalContent = finalContent .. " " .. Vanity.addon.text
        end
        
        local length = finalContent:len()
        local max = Vanity.config.limits.main
        
        if length > max then
            Vanity.echo(string.format("%sERROR: With your add-on, the description is %d characters. The Achaea limit is %d! Try disabling the add-on or shortening the description.<reset>", c.error, length, max))
            return
        elseif length > (max - 100) then
            Vanity.echo(string.format("%sWARNING: With your add-on, the description is %d characters. You are very close to the %d limit!<reset>", c.warning, length, max))
        end
        
        Vanity.gagEcho()
        send("DESCRIBE SELF " .. finalContent)
        
        local addonMsg = (Vanity.addon.enabled and Vanity.addon.text ~= "") and " (with add-on)" or ""
        Vanity.echo(string.format("%sApplied description '%s%s%s'%s.<reset>", c.text, c.highlight, Vanity.descriptions[keyword].name, c.text, addonMsg))
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
        
        if Vanity.addon.enabled and Vanity.addon.text ~= "" then
            cecho(string.format("\n%s(Add-on Active): %s%s<reset>\n", c.highlight, c.text, Vanity.addon.text))
        end
        
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
    
    Vanity.listPhrases()
end

-- =========================================================================
-- Complex Mode: Phrases & Slots
-- =========================================================================
function Vanity.setMode(mode)
    local c = Vanity.config.colors
    mode = mode:lower()
    if mode == "standard" or mode == "complex" then
        Vanity.config.mode = mode
        Vanity.save()
        Vanity.echo(string.format("%sVanity is now operating in %s%s%s mode.<reset>", c.text, c.highlight, mode:upper(), c.text))
    else
        Vanity.echo(string.format("%sInvalid mode. Please use 'standard' or 'complex'.<reset>", c.error))
    end
end

function Vanity.addPhrase(category, keyword, text)
    keyword = keyword:lower()
    category = category:lower()
    local c = Vanity.config.colors
    
    Vanity.phrases[keyword] = { category = category, text = text }
    Vanity.save()
    Vanity.echo(string.format("%sPhrase [%s%s%s] saved under category '%s%s%s'.<reset>", c.text, c.highlight, keyword, c.text, c.highlight, category, c.text))
end

function Vanity.setSlot(slotNum, keyword)
    slotNum = tonumber(slotNum)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    
    if not Vanity.phrases[keyword] then
        Vanity.echo(string.format("%sPhrase keyword '%s' not found! Use %svanity phrase list%s to see available phrases.<reset>", c.error, keyword, c.highlight, c.error))
        return
    end

    local requiredCategory = Vanity.slotBindings[slotNum]
    local phraseCategory = Vanity.phrases[keyword].category
    if requiredCategory and requiredCategory ~= phraseCategory then
        Vanity.echo(string.format("%sCannot assign! Slot %s%d%s is bound to category '%s%s%s', but '%s' is in category '%s'.<reset>", 
            c.error, c.highlight, slotNum, c.error, c.highlight, requiredCategory, c.error, keyword, phraseCategory))
        return
    end
    
    Vanity.activeSlots[slotNum] = keyword
    Vanity.save()
    Vanity.echo(string.format("%sSlot %s%d%s set to phrase [%s%s%s].<reset>", c.text, c.highlight, slotNum, c.text, c.highlight, keyword, c.text))
    
    if Vanity.config.mode == "complex" then
        Vanity.previewComplexDescription()
    end
end

function Vanity.bindSlot(slotNum, category)
    slotNum = tonumber(slotNum)
    category = category:lower()
    local c = Vanity.config.colors

    Vanity.slotBindings[slotNum] = category
    Vanity.save()
    Vanity.echo(string.format("%sSlot %s%d%s is now strictly bound to the '%s%s%s' category.<reset>", c.text, c.highlight, slotNum, c.text, c.highlight, category, c.text))
end

function Vanity.unbindSlot(slotNum)
    slotNum = tonumber(slotNum)
    local c = Vanity.config.colors

    if Vanity.slotBindings[slotNum] then
        Vanity.slotBindings[slotNum] = nil
        Vanity.save()
        Vanity.echo(string.format("%sSlot %s%d%s is no longer bound to a specific category.<reset>", c.text, c.highlight, slotNum, c.text))
    else
        Vanity.echo(string.format("%sSlot %d is not currently bound to any category.<reset>", c.error, slotNum))
    end
end

function Vanity.swapSlots(slotA, slotB)
    slotA = tonumber(slotA)
    slotB = tonumber(slotB)
    local c = Vanity.config.colors

    if slotA == slotB then
        Vanity.echo(string.format("%sYou cannot move a slot to itself.<reset>", c.error))
        return
    end

    local keyA = Vanity.activeSlots[slotA]
    local keyB = Vanity.activeSlots[slotB]

    if not keyA and not keyB then
        Vanity.echo(string.format("%sBoth Slot %d and Slot %d are empty.<reset>", c.warning, slotA, slotB))
        return
    end

    if keyA then
        local reqB = Vanity.slotBindings[slotB]
        local catA = Vanity.phrases[keyA].category
        if reqB and reqB ~= catA then
            Vanity.echo(string.format("%sCannot move! Moving [%s] to Slot %d violates its binding to category '%s'.<reset>", 
                c.error, keyA, slotB, reqB))
            return
        end
    end

    if keyB then
        local reqA = Vanity.slotBindings[slotA]
        local catB = Vanity.phrases[keyB].category
        if reqA and reqA ~= catB then
            Vanity.echo(string.format("%sCannot move! Moving [%s] to Slot %d violates its binding to category '%s'.<reset>", 
                c.error, keyB, slotA, reqA))
            return
        end
    end

    Vanity.activeSlots[slotA] = keyB
    Vanity.activeSlots[slotB] = keyA
    Vanity.save()

    Vanity.echo(string.format("%sMoved/Swapped the contents of Slot %s%d%s and Slot %s%d%s.<reset>", 
        c.text, c.highlight, slotA, c.text, c.highlight, slotB, c.text))

    if Vanity.config.mode == "complex" then
        Vanity.previewComplexDescription()
    end
end

function Vanity.buildComplexDescription()
    local parts = {}
    local maxSlot = 0
    for k, _ in pairs(Vanity.activeSlots) do
        if k > maxSlot then maxSlot = k end
    end
    
    for i = 1, maxSlot do
        local phraseKey = Vanity.activeSlots[i]
        if phraseKey and Vanity.phrases[phraseKey] then
            table.insert(parts, Vanity.phrases[phraseKey].text)
        end
    end
    
    return table.concat(parts, " ")
end

function Vanity.previewComplexDescription()
    local c = Vanity.config.colors
    local combined = Vanity.buildComplexDescription()
    
    if combined == "" then
        Vanity.echo(string.format("%sYour complex description is currently empty. Assign phrases to slots first!<reset>", c.error))
        return
    end
    
    Vanity.echo(string.format("%sCurrent Complex Description Preview:<reset>", c.highlight))
    cecho(string.format("%s%s<reset>\n", c.text, combined))
    Vanity.checkStyle(combined) 
end

function Vanity.useComplexDescription()
    local c = Vanity.config.colors
    if Vanity.config.mode ~= "complex" then
        Vanity.echo(string.format("%sYou are not in complex mode! Type %svanity mode complex%s to switch.<reset>", c.error, c.highlight, c.error))
        return
    end
    
    local finalContent = Vanity.buildComplexDescription()
    
    if finalContent == "" then
        Vanity.echo(string.format("%sCannot apply an empty description. Set some slots first!<reset>", c.error))
        return
    end
    
    if Vanity.addon.enabled and Vanity.addon.text ~= "" then
        finalContent = finalContent .. " " .. Vanity.addon.text
    end
    
    local length = finalContent:len()
    local max = Vanity.config.limits.main
    
    if length > max then
        Vanity.echo(string.format("%sERROR: Compiled description is %d chars. The Achaea limit is %d!<reset>", c.error, length, max))
        return
    elseif length > (max - 100) then
        Vanity.echo(string.format("%sWARNING: Compiled description is %d chars. You are very close to the %d limit!<reset>", c.warning, length, max))
    end
    
    Vanity.gagEcho()
    send("DESCRIBE SELF " .. finalContent)
    
    local addonMsg = (Vanity.addon.enabled and Vanity.addon.text ~= "") and " (with add-on)" or ""
    Vanity.echo(string.format("%sApplied compiled complex description%s.<reset>", c.text, addonMsg))
end

function Vanity.listPhrases()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        V A N I T Y   P H R A S E S                    <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))

    local categorized = {}
    local count = 0
    
    for keyword, data in pairs(Vanity.phrases) do
        local cat = data.category or "general"
        if not categorized[cat] then categorized[cat] = {} end
        categorized[cat][keyword] = data.text
        count = count + 1
    end

    if count == 0 then
        cecho(string.format("\n  %sNo phrases saved yet. Use %svanity phrase add <cat> <key> <text>%s to create one.<reset>\n", c.text, c.highlight, c.text))
    else
        for cat, phrases in pairs(categorized) do
            cecho(string.format("\n%s--[ %s%s%s ]---------------------------------------------------------------<reset>\n", c.border, c.highlight, cat:upper(), c.border))
            for keyword, text in pairs(phrases) do
                local preview = string.sub(text, 1, 55)
                if string.len(text) > 55 then preview = preview .. "..." end
                
                cecho("  ")
                cechoLink(string.format("%s[%s]<reset>", c.highlight, keyword), [[clearCmdLine() appendCmdLine("vanity slot 1 ]]..keyword..[[")]], "Click to prep assigning to a slot", true)
                cecho(string.format(" %s: %s%s<reset>\n", c.prefix, c.text, preview))
            end
        end
    end
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
end

-- =========================================================================
-- Pose Features
-- =========================================================================
function Vanity.validatePose(text)
    local c = Vanity.config.colors
    if not string.find(text, "%^") then
        Vanity.echo(string.format("%sERROR: A pose must include a '^' character to represent your name.<reset>", c.error))
        return false
    end
    if string.len(text) > Vanity.config.limits.pose then
        Vanity.echo(string.format("%sERROR: Pose is %d characters. The maximum length is %d.<reset>", c.error, string.len(text), Vanity.config.limits.pose))
        return false
    end
    return true
end

function Vanity.addPose(keyword, text)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    if Vanity.poses[keyword] then
        Vanity.echo(string.format("%sPose keyword '%s' already exists! Use %svanity pose update%s instead.<reset>", c.error, keyword, c.highlight, c.error))
        return
    end
    if Vanity.validatePose(text) then
        Vanity.poses[keyword] = text
        Vanity.save()
        Vanity.echo(string.format("%sPose [%s%s%s] saved successfully.<reset>", c.text, c.highlight, keyword, c.text))
    end
end

function Vanity.updatePose(keyword, text)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    if not Vanity.poses[keyword] then
        Vanity.echo(string.format("%sPose keyword '%s' not found! Use %svanity pose add%s instead.<reset>", c.error, keyword, c.highlight, c.error))
        return
    end
    if Vanity.validatePose(text) then
        Vanity.poses[keyword] = text
        Vanity.save()
        Vanity.echo(string.format("%sPose [%s%s%s] updated successfully.<reset>", c.text, c.highlight, keyword, c.text))
    end
end

function Vanity.usePose(keyword, isTemp)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    if not Vanity.poses[keyword] then
        Vanity.echo(string.format("%sPose keyword '%s' not found.<reset>", c.error, keyword))
        return
    end
    
    local text = Vanity.poses[keyword]
    local command = isTemp and "TPOSE " or "POSE "
    local pType = isTemp and "TPOSE" or "POSE"
    
    send(command .. text)
    Vanity.currentPose = { type = pType, text = text }
    Vanity.save()
    Vanity.echo(string.format("%sApplied %s [%s%s%s]: %s<reset>", c.text, pType, c.highlight, keyword, c.text, text))
end

function Vanity.clearPose()
    local c = Vanity.config.colors
    send("UNPOSE")
    Vanity.currentPose = { type = "None", text = "Not set" }
    Vanity.save()
    Vanity.echo(string.format("%sPose cleared.<reset>", c.text))
end

function Vanity.deletePose(keyword)
    keyword = keyword:lower()
    local c = Vanity.config.colors
    if Vanity.poses[keyword] then
        Vanity.poses[keyword] = nil
        Vanity.save()
        Vanity.echo(string.format("%sPose [%s%s%s] deleted.<reset>", c.text, c.highlight, keyword, c.text))
    else
        Vanity.echo(string.format("%sPose keyword '%s' not found.<reset>", c.error, keyword))
    end
end

function Vanity.syncPose()
    local c = Vanity.config.colors
    
    if Vanity.syncPosePosTrig then killTrigger(Vanity.syncPosePosTrig) end
    if Vanity.syncPoseNegTrig then killTrigger(Vanity.syncPoseNegTrig) end
    
    Vanity.syncPosePosTrig = tempRegexTrigger("^You are (?:currently )?posing as: (.*)$", function()
        deleteLine()
        local text = matches[2]
        
        if Vanity.currentPose.type == "TPOSE" and Vanity.currentPose.text == text then
        else
            Vanity.currentPose = { type = "POSE", text = text }
        end
        Vanity.save()
        Vanity.echo(string.format("%sPose synced with server: %s%s<reset>", c.text, c.highlight, text))
    end, 1)
    
    Vanity.syncPoseNegTrig = tempRegexTrigger("^You are not (?:currently )?posing.*$", function()
        deleteLine()
        Vanity.currentPose = { type = "None", text = "Not set" }
        Vanity.save()
        Vanity.echo(string.format("%sPose synced with server: None active.<reset>", c.text))
    end, 1)
    
    tempTimer(1, function()
        if Vanity.syncPosePosTrig then killTrigger(Vanity.syncPosePosTrig) end
        if Vanity.syncPoseNegTrig then killTrigger(Vanity.syncPoseNegTrig) end
    end)
    
    send("SHOW POSE", false)
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
-- Add-on Features
-- =========================================================================
function Vanity.setAddon(text)
    local c = Vanity.config.colors
    Vanity.addon.text = text
    Vanity.addon.enabled = true
    Vanity.save()
    Vanity.echo(string.format("%sAdd-on string set and <green>ENABLED%s: %s%s<reset>", c.text, c.text, c.highlight, text))
end

function Vanity.toggleAddon()
    local c = Vanity.config.colors
    if Vanity.addon.text == "" then
        Vanity.echo(string.format("%sYou do not have an add-on string set. Use %svanity addon set <text>%s first.<reset>", c.error, c.highlight, c.error))
        return
    end
    
    Vanity.addon.enabled = not Vanity.addon.enabled
    Vanity.save()
    local state = Vanity.addon.enabled and "<green>ENABLED<reset>" or "<red>DISABLED<reset>"
    Vanity.echo(string.format("%sAdd-on string is now %s.", c.text, state))
end

function Vanity.clearAddon()
    local c = Vanity.config.colors
    Vanity.addon.text = ""
    Vanity.addon.enabled = false
    Vanity.save()
    Vanity.echo(string.format("%sAdd-on string cleared.<reset>", c.text))
end

-- =========================================================================
-- UI: Dashboard & Help Interface
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

    cecho(string.format("\n%sCurrent Add-on:<reset>\n", c.prefix))
    if Vanity.addon.text == "" then
        cecho(string.format("  %sNone set.<reset>\n", c.text))
    else
        local status = Vanity.addon.enabled and "<green>[ON]<reset>" or "<red>[OFF]<reset>"
        cecho(string.format("  %s %s%s<reset>\n", status, c.text, Vanity.addon.text))
    end
    
    cecho(string.format("\n%sCurrent Pose:<reset>\n", c.prefix))
    if Vanity.currentPose.type == "None" then
        cecho(string.format("  %sNone set via Vanity.<reset>\n", c.text))
    else
        cecho(string.format("  %s[%-5s]%s %s<reset>\n", c.highlight, Vanity.currentPose.type, c.text, Vanity.currentPose.text))
    end

    cecho(string.format("\n%sCurrent Mode:<reset> %s%s<reset>\n", c.prefix, c.highlight, Vanity.config.mode:upper()))

    if Vanity.config.mode == "complex" then
        cecho(string.format("\n%sActive Phrase Slots (Complex Mode):<reset>\n", c.prefix))
        local maxSlot = 0
        for k, _ in pairs(Vanity.activeSlots) do
            if k > maxSlot then maxSlot = k end
        end

        if maxSlot == 0 then
            cecho(string.format("  %sNo phrases assigned to slots yet.<reset>\n", c.text))
        else
            for i = 1, maxSlot do
                local phraseKey = Vanity.activeSlots[i]
                local bindTag = Vanity.slotBindings[i] and string.format(" %s(%s)%s", c.warning, Vanity.slotBindings[i]:upper(), c.text) or ""
                
                if phraseKey and Vanity.phrases[phraseKey] then
                    local phraseData = Vanity.phrases[phraseKey]
                    local preview = string.sub(phraseData.text, 1, 40)
                    if string.len(phraseData.text) > 40 then preview = preview .. "..." end
                    cecho(string.format("  %s[Slot %d]%s%s %-10s : %s%s<reset>\n", c.highlight, i, c.text, bindTag, phraseKey, c.text, preview))
                else
                    cecho(string.format("  %s[Slot %d]%s%s <Empty><reset>\n", c.highlight, i, c.text, bindTag))
                end
            end
        end
    end

    cecho(string.format("\n%sSaved Descriptions (Click Keyword to Activate):<reset>\n", c.prefix))
    
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
    
    cecho(string.format("\n%sSaved Poses (Click Keyword to Set as POSE):<reset>\n", c.prefix))
    local pCount = 0
    for pKey, pText in pairs(Vanity.poses) do
        cecho("  ")
        cechoLink(string.format("%s[%s]<reset>", c.highlight, pKey), [[Vanity.usePose("]]..pKey..[[", false)]], "Set as POSE", true)
        cecho(string.format(" %s%s<reset>\n", c.text, pText))
        pCount = pCount + 1
    end
    if pCount == 0 then
        cecho(string.format("  %sNo poses saved yet.<reset>\n", c.text))
    end
    
    cecho(string.format("\n%sQuick Syntax Guide:<reset>\n", c.prefix))
    cecho(string.format("  %svanity use <keyword><reset>                  - Activate a saved description.\n", c.highlight))
    cecho(string.format("  %svanity update <keyword> <text><reset>        - Updates text (keeps name).\n", c.highlight))
    cecho(string.format("  %svanity addon toggle<reset>                   - Toggle your add-on text.\n", c.highlight))
    cecho(string.format("  %svanity tpose/pose use <keyword><reset>       - Sets a saved pose permanently or temporarily.\n", c.highlight))
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
    
    cecho(string.format("\n\n%sPoses:<reset>", c.prefix))
    cecho(string.format("\n  %svanity pose add <keyword> <text><reset>         - Saves a new pose.", c.highlight))
    cecho(string.format("\n  %svanity pose update <keyword> <text><reset>      - Updates an existing pose.", c.highlight))
    cecho(string.format("\n  %svanity pose use <keyword><reset>                - Sets a saved pose permanently.", c.highlight))
    cecho(string.format("\n  %svanity tpose use <keyword><reset>               - Sets a saved pose temporarily.", c.highlight))
    cecho(string.format("\n  %svanity pose clear<reset>                        - Removes your active pose.", c.highlight))
    cecho(string.format("\n  %svanity pose delete <keyword><reset>             - Deletes a saved pose.", c.highlight))
    cecho(string.format("\n  %svanity pose sync<reset>                         - Syncs dashboard pose with server.", c.highlight))

    cecho(string.format("\n\n%sAdd-on Strings:<reset>", c.prefix))
    cecho(string.format("\n  %svanity addon set <text><reset>                  - Sets and enables your add-on string.", c.highlight))
    cecho(string.format("\n  %svanity addon toggle<reset>                      - Toggles your add-on on or off.", c.highlight))
    cecho(string.format("\n  %svanity addon clear<reset>                       - Removes your add-on string.", c.highlight))

    cecho(string.format("\n\n%sElement Descriptions:<reset>", c.prefix))
    cecho(string.format("\n  %svanity elem update <type> <text><reset>         - Sets an element (e.g. HAIR blonde).", c.highlight))
    cecho(string.format("\n  %svanity elem update BALD<reset>                  - Sets your character to bald.", c.highlight))
    cecho(string.format("\n  %svanity elem list<reset>                         - Shows your local saved elements.", c.highlight))
    cecho(string.format("\n  %svanity elem combine <keyword> \"<Name>\"<reset>   - Generates & saves a full desc.", c.highlight))
    
    cecho(string.format("\n\n%sComplex Mode (Phrases):<reset>", c.prefix))
    cecho(string.format("\n  %svanity mode <standard|complex><reset>           - Switches description mode.", c.highlight))
    cecho(string.format("\n  %svanity phrase add <cat> <key> <text><reset>     - Saves a modular phrase.", c.highlight))
    cecho(string.format("\n  %svanity phrase list<reset>                       - Lists all saved phrases.", c.highlight))
    cecho(string.format("\n  %svanity slot <num> <key><reset>                  - Assigns a phrase to a slot.", c.highlight))
    cecho(string.format("\n  %svanity slot bind <num> <cat><reset>             - Binds a category to a slot.", c.highlight))
    cecho(string.format("\n  %svanity slot unbind <num><reset>                 - Unbinds a slot.", c.highlight))
    cecho(string.format("\n  %svanity slot move <num1> <num2><reset>           - Moves/swaps phrases between slots.", c.highlight))
    cecho(string.format("\n  %svanity apply<reset>                             - Applies your complex description.", c.highlight))

    cecho(string.format("\n\n%sUtility:<reset>", c.prefix))
    cecho(string.format("\n  %svanity debug<reset>                             - Toggles hiding of desc. update spam.", c.highlight))

    cecho(string.format("\n\n%s=======================================================================<reset>\n", c.border))
end

-- =========================================================================
-- Command Parser
-- =========================================================================
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
        -- Poses
        local poseAddKey, poseAddText = string.match(args, "^[Pp][Oo][Ss][Ee]%s+[Aa][Dd][Dd]%s+(%w+)%s+(.+)$")
        local poseUpdKey, poseUpdText = string.match(args, "^[Pp][Oo][Ss][Ee]%s+[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+(.+)$")
        local poseUseKey = string.match(args, "^[Pp][Oo][Ss][Ee]%s+[Uu][Ss][Ee]%s+(%w+)$")
        local tposeUseKey = string.match(args, "^[Tt][Pp][Oo][Ss][Ee]%s+[Uu][Ss][Ee]%s+(%w+)$")
        local poseClear = string.match(args, "^[Pp][Oo][Ss][Ee]%s+[Cc][Ll][Ee][Aa][Rr]$")
        local poseDelKey = string.match(args, "^[Pp][Oo][Ss][Ee]%s+[Dd][Ee][Ll][Ee][Tt][Ee]%s+(%w+)$")
        local poseSync = string.match(args, "^[Pp][Oo][Ss][Ee]%s+[Ss][Yy][Nn][Cc]$")
        
        -- Add-ons
        local addonSet = string.match(args, "^[Aa][Dd][Dd][Oo][Nn]%s+[Ss][Ee][Tt]%s+(.+)$")
        local addonToggle = string.match(args, "^[Aa][Dd][Dd][Oo][Nn]%s+[Tt][Oo][Gg][Gg][Ll][Ee]%s*$")
        local addonClear = string.match(args, "^[Aa][Dd][Dd][Oo][Nn]%s+[Cc][Ll][Ee][Aa][Rr]%s*$")

        -- Elements
        local elemUpdateType, elemUpdateText = string.match(args, "^[Ee][Ll][Ee][Mm]%s+[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%a+)%s*(.*)$")
        local elemCombineAll = string.match(args, "^[Ee][Ll][Ee][Mm]%s+[Cc][Oo][Mm][Bb][Ii][Nn][Ee]%s*(.*)$")

        -- Standard Descriptions
        local addKey, addName, addContent = string.match(args, "^[Aa][Dd][Dd]%s+(%w+)%s+\"([^\"]+)\"%s+(.+)$")
        local updKeyName, updName, updContentName = string.match(args, "^[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+\"([^\"]+)\"%s+(.+)$")
        local updKey, updContent = string.match(args, "^[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+(.+)$")
        local copyOld, copyNew, copyName = string.match(args, "^[Cc][Oo][Pp][Yy]%s+(%w+)%s+(%w+)%s+\"([^\"]+)\"$")
        local useKey = string.match(args, "^[Uu][Ss][Ee]%s+(%w+)$")
        local showKey = string.match(args, "^[Ss][Hh][Oo][Ww]%s+(%w+)$")
        local delKey, delConfirm = string.match(args, "^[Dd][Ee][Ll][Ee][Tt][Ee]%s+(%w+)%s*(.*)$")
        local editKey = string.match(args, "^[Ee][Dd][Ii][Tt]%s+(%w+)$")
        
        -- Complex Mode
        local modeSet = string.match(args, "^[Mm][Oo][Dd][Ee]%s+(%w+)$")
        local phraseAddCat, phraseAddKey, phraseAddText = string.match(args, "^[Pp][Hh][Rr][Aa][Ss][Ee]%s+[Aa][Dd][Dd]%s+(%w+)%s+(%w+)%s+(.+)$")
        local phraseList = string.match(args, "^[Pp][Hh][Rr][Aa][Ss][Ee]%s+[Ll][Ii][Ss][Tt]$")
        local slotBindNum, slotBindCat = string.match(args, "^[Ss][Ll][Oo][Tt]%s+[Bb][Ii][Nn][Dd]%s+(%d+)%s+(%w+)$")
        local slotUnbindNum = string.match(args, "^[Ss][Ll][Oo][Tt]%s+[Uu][Nn][Bb][Ii][Nn][Dd]%s+(%d+)$")
        local slotNum, slotKey = string.match(args, "^[Ss][Ll][Oo][Tt]%s+(%d+)%s+(%w+)$")
        local applyComplex = string.match(args, "^[Aa][Pp][Pp][Ll][Yy]$")
        local slotSwapA, slotSwapB = string.match(args, "^[Ss][Ll][Oo][Tt]%s+[Mm][Oo][Vv][Ee]%s+(%d+)%s+(%d+)$")
        if not slotSwapA then 
            slotSwapA, slotSwapB = string.match(args, "^[Ss][Ll][Oo][Tt]%s+[Ss][Ww][Aa][Pp]%s+(%d+)%s+(%d+)$")
        end

        -- Route execution
        if poseAddKey then Vanity.addPose(poseAddKey, poseAddText)
        elseif poseUpdKey then Vanity.updatePose(poseUpdKey, poseUpdText)
        elseif poseUseKey then Vanity.usePose(poseUseKey, false)
        elseif tposeUseKey then Vanity.usePose(tposeUseKey, true)
        elseif poseClear then Vanity.clearPose()
        elseif poseDelKey then Vanity.deletePose(poseDelKey)
        elseif poseSync then Vanity.syncPose()
        
        elseif addonSet then Vanity.setAddon(addonSet)
        elseif addonToggle then Vanity.toggleAddon()
        elseif addonClear then Vanity.clearAddon()
        
        elseif elemUpdateType then Vanity.updateElement(elemUpdateType, elemUpdateText)
        elseif elemCombineAll then
            local combKey, combName = string.match(elemCombineAll, "^(%w+)%s+\"([^\"]+)\"$")
            Vanity.combineElements(combKey, combName)
            
        elseif addKey then Vanity.addDescription(addKey, addName, addContent)
        elseif updKeyName then Vanity.updateDescription(updKeyName, updName, updContentName)
        elseif updKey then Vanity.updateDescription(updKey, nil, updContent)
        elseif copyOld then Vanity.copyDescription(copyOld, copyNew, copyName)
        elseif useKey then Vanity.useDescription(useKey)
        elseif showKey then Vanity.showDescription(showKey)
        elseif editKey then Vanity.editDescription(editKey)
        elseif delKey then Vanity.deleteDescription(delKey, delConfirm)
            
        elseif modeSet then Vanity.setMode(modeSet)
        elseif phraseAddCat then Vanity.addPhrase(phraseAddCat, phraseAddKey, phraseAddText)
        elseif phraseList then Vanity.listPhrases()
        elseif slotBindNum then Vanity.bindSlot(slotBindNum, slotBindCat)
        elseif slotUnbindNum then Vanity.unbindSlot(slotUnbindNum)
        elseif slotSwapA then Vanity.swapSlots(slotSwapA, slotSwapB)
        elseif slotNum then Vanity.setSlot(slotNum, slotKey)
        elseif applyComplex then Vanity.useComplexDescription()
        
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
    if Vanity.roomHandler then killAnonymousEventHandler(Vanity.roomHandler) end
    
    Vanity.aliasHandler = tempAlias("^vanity(?: (.*))?$", [[
        local args = matches[2] or ""
        Vanity.handleCommand(args)
    ]])
    
    Vanity.roomHandler = registerAnonymousEventHandler("gmcp.Room.Info", "Vanity.onRoomMove")

    Vanity.load()
    Vanity.echo("Manager Initialized. Type " .. Vanity.config.colors.highlight .. "vanity<reset> to view your dashboard.")
end

Vanity.init()