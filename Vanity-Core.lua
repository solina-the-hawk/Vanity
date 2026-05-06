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
        component = 75
    }
}

Vanity.descriptions = Vanity.descriptions or {}
Vanity.components = Vanity.components or {}

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
        components = Vanity.components
    }
    
    local filepath = baseDir .. "/Vanity_Data.lua"
    table.save(filepath, data)
end

function Vanity.load()
    local baseDir = getMudletHomeDir() .. "/Vanity"
    local newFile = baseDir .. "/Vanity_Data.lua"
    local oldFile = baseDir .. "/Vanity_Descriptions.lua"
    
    if io.exists(newFile) then
        local data = {}
        table.load(newFile, data)
        Vanity.descriptions = data.descriptions or {}
        Vanity.components = data.components or {}
    elseif io.exists(oldFile) then
        table.load(oldFile, Vanity.descriptions)
        Vanity.components = {}
        Vanity.save() 
        os.remove(oldFile)
        Vanity.echo("Migrated your old descriptions to the new data format.")
    end
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
-- Component Features
-- =========================================================================
function Vanity.updateComponent(compType, text)
    compType = compType:upper()
    local c = Vanity.config.colors
    local validTypes = {HAIR=true, BALD=true, EYES=true, COMPLEXION=true, HEIGHT=true, BUILD=true}
    
    if not validTypes[compType] then
        Vanity.echo(string.format("%sInvalid component. Use HAIR, BALD, EYES, COMPLEXION, HEIGHT, or BUILD.<reset>", c.error))
        return
    end
    
    if compType == "BALD" then
        Vanity.components["HAIR"] = "bald"
        Vanity.save()
        send("DESCRIBE SELF BALD")
        Vanity.echo(string.format("%sComponent %sHAIR%s set to %sBALD%s and sent to Achaea.<reset>", c.text, c.highlight, c.text, c.highlight, c.text))
        return
    end
    
    if text:len() > Vanity.config.limits.component then
        Vanity.echo(string.format("%sComponent text is too long! Max %d characters. You entered %d.<reset>", c.error, Vanity.config.limits.component, text:len()))
        return
    end
    
    Vanity.components[compType] = text
    Vanity.save()
    send("DESCRIBE SELF " .. compType .. " " .. text)
    Vanity.echo(string.format("%sComponent %s%s%s updated and sent to Achaea.<reset>", c.text, c.highlight, compType, c.text))
end

function Vanity.listComponents()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        C O M P O N E N T S                            <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    local comps = {"HEIGHT", "BUILD", "COMPLEXION", "EYES", "HAIR"}
    for _, k in ipairs(comps) do
        local val = Vanity.components[k] or "Not set"
        cecho(string.format("%s%-15s<reset> : %s%s<reset>\n", c.highlight, k, c.text, val))
    end
    cecho(string.format("%s=======================================================================<reset>\n", c.border))
end

function Vanity.combineComponents(saveName)
    local c = Vanity.config.colors
    local order = {"HEIGHT", "BUILD", "COMPLEXION", "EYES", "HAIR"}
    local parts = {}
    
    -- Gather all saved components sequentially
    for _, comp in ipairs(order) do
        if Vanity.components[comp] and Vanity.components[comp] ~= "" then
            table.insert(parts, Vanity.components[comp])
        end
    end
    
    -- Combine them with a single space
    local combined = table.concat(parts, " ")
    
    if combined == "" then
        Vanity.echo(string.format("%sYou have not set any components to combine yet!<reset>", c.error))
        return
    end
    
    Vanity.echo(string.format("%sExperimental Combined Description:<reset>", c.highlight))
    cecho(string.format("%s%s<reset>\n", c.text, combined))
    
    Vanity.checkStyle(combined)
    
    if saveName and saveName ~= "" then
        Vanity.updateDescription(saveName, combined)
    else
        cecho(string.format("\n%s(Tip: Use '%svanity comp combine <name>%s' to automatically save this to your list.)<reset>\n", c.warning, c.highlight, c.warning))
    end
end

-- =========================================================================
-- Main Description Features
-- =========================================================================
function Vanity.updateDescription(name, content)
    name = name:lower()
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
    
    Vanity.descriptions[name] = content
    Vanity.save()
    Vanity.echo(string.format("%sDescription '%s%s%s' has been saved.<reset>", c.text, c.highlight, name, c.text))
end

function Vanity.useDescription(name)
    name = name:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[name] then
        send("DESCRIBE SELF " .. Vanity.descriptions[name])
        Vanity.echo(string.format("%sApplied description '%s%s%s'.<reset>", c.text, c.highlight, name, c.text))
    else
        Vanity.echo(string.format("%sDescription '%s' not found.<reset>", c.error, name))
    end
end

function Vanity.showDescription(name)
    name = name:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[name] then
        cecho(string.format("\n%s=======================================================================<reset>", c.border))
        cecho(string.format("\n%s                   V A N I T Y : %s%s<reset>", c.border, c.highlight, name:upper()))
        cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
        cecho(string.format("%s%s<reset>\n", c.text, Vanity.descriptions[name]))
        cecho(string.format("%s=======================================================================<reset>\n", c.border))
    else
        Vanity.echo(string.format("%sDescription '%s' not found.<reset>", c.error, name))
    end
end

function Vanity.listDescriptions()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        V A N I T Y   L I S T                          <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    local count = 0
    for name, content in pairs(Vanity.descriptions) do
        local preview = string.sub(content, 1, 60)
        if string.len(content) > 60 then preview = preview .. "..." end
        cecho(string.format("%s%-15s<reset> : %s%s<reset>\n", c.highlight, name, c.text, preview))
        count = count + 1
    end
    
    if count == 0 then
        cecho(string.format("\n%sNo descriptions saved yet. Use %svanity update <name> <desc>%s to create one.<reset>\n", c.text, c.highlight, c.text))
    end
    cecho(string.format("%s=======================================================================<reset>\n", c.border))
end

function Vanity.deleteDescription(name)
    name = name:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[name] then
        Vanity.descriptions[name] = nil
        Vanity.save()
        Vanity.echo(string.format("%sDescription '%s%s%s' deleted.<reset>", c.text, c.highlight, name, c.text))
    else
        Vanity.echo(string.format("%sDescription '%s' not found.<reset>", c.error, name))
    end
end

function Vanity.editDescription(name)
    name = name:lower()
    local c = Vanity.config.colors
    
    if Vanity.descriptions[name] then
        clearCmdLine()
        appendCmdLine("vanity update " .. name .. " " .. Vanity.descriptions[name])
        Vanity.echo(string.format("%sDescription '%s%s%s' loaded into your command line. Edit it and press Enter to save!<reset>", c.text, c.highlight, name, c.text))
    else
        Vanity.echo(string.format("%sDescription '%s' not found.<reset>", c.error, name))
    end
end

-- =========================================================================
-- In-Game Commands & Help Interface
-- =========================================================================
function Vanity.showHelp()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        V A N I T Y   H E L P                          <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    cecho(string.format("\n%sMain Descriptions:<reset>", c.prefix))
    cecho(string.format("\n  %svanity update <name> <text><reset> - Creates or overwrites a full description.", c.highlight))
    cecho(string.format("\n  %svanity use <name><reset>           - Sends DESCRIBE SELF <text> to Achaea.", c.highlight))
    cecho(string.format("\n  %svanity show <name><reset>          - Displays the full text of a description.", c.highlight))
    cecho(string.format("\n  %svanity list<reset>                 - Displays a preview of all descriptions.", c.highlight))
    cecho(string.format("\n  %svanity edit <name><reset>          - Loads a description into input to edit.", c.highlight))
    cecho(string.format("\n  %svanity delete <name><reset>        - Removes a saved description.", c.highlight))
    
    cecho(string.format("\n\n%sComponent Descriptions:<reset>", c.prefix))
    cecho(string.format("\n  %svanity comp update <type> <text><reset> - Sets a component (e.g. HAIR blonde).", c.highlight))
    cecho(string.format("\n  %svanity comp update BALD<reset>          - Sets your character to bald.", c.highlight))
    cecho(string.format("\n  %svanity comp list<reset>                 - Shows your local saved components.", c.highlight))
    cecho(string.format("\n  %svanity comp combine [name]<reset>       - Generates a full desc from components.", c.highlight))
    
    cecho(string.format("\n\n%s=======================================================================<reset>\n", c.border))
end

function Vanity.handleCommand(args)
    local cmd = args:lower()
    
    if cmd == "help" or cmd == "" then
        Vanity.showHelp()
    elseif cmd == "list" then
        Vanity.listDescriptions()
    else
        -- Main Description Parsers
        local updateName, updateContent = string.match(args, "^[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+(.+)$")
        local useName = string.match(args, "^[Uu][Ss][Ee]%s+(%w+)$")
        local showName = string.match(args, "^[Ss][Hh][Oo][Ww]%s+(%w+)$")
        local deleteName = string.match(args, "^[Dd][Ee][Ll][Ee][Tt][Ee]%s+(%w+)$")
        local editName = string.match(args, "^[Ee][Dd][Ii][Tt]%s+(%w+)$")
        
        -- Component Parsers
        local compUpdateType, compUpdateText = string.match(args, "^[Cc][Oo][Mm][Pp]%s+[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%a+)%s*(.*)$")
        local compList = string.match(args, "^[Cc][Oo][Mm][Pp]%s+[Ll][Ii][Ss][Tt]$")
        local compCombine = string.match(args, "^[Cc][Oo][Mm][Pp]%s+[Cc][Oo][Mm][Bb][Ii][Nn][Ee]%s*(%w*)$")
        
        -- Routing Logic
        if compUpdateType then
            Vanity.updateComponent(compUpdateType, compUpdateText)
        elseif compList then
            Vanity.listComponents()
        elseif compCombine then
            Vanity.combineComponents(compCombine ~= "" and compCombine or nil)
        elseif updateName and updateContent then
            Vanity.updateDescription(updateName, updateContent)
        elseif useName then
            Vanity.useDescription(useName)
        elseif showName then
            Vanity.showDescription(showName)
        elseif editName then
            Vanity.editDescription(editName)
        elseif deleteName then
            Vanity.deleteDescription(deleteName)
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
        local args = matches[2] or "help"
        Vanity.handleCommand(args)
    ]])

    Vanity.load()
    Vanity.echo("Manager Initialized. Type " .. Vanity.config.colors.highlight .. "vanity help<reset> for commands.")
end

Vanity.init()
