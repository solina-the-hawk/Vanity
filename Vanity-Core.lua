-- =========================================================================
-- VANITY: Modular Character Description Manager
-- A central script interface for Mudlet, allowing you to easily swap and
-- build character descriptions in Achaea without relying on XML packages.
-- =========================================================================
Vanity = Vanity or {}

-- =========================================================================
-- Configuration & Theme
-- Establish a unified color palette for all Vanity outputs and help menus.
-- =========================================================================
Vanity.config = {
    colors = {
        border    = "<medium_orchid>",
        prefix    = "<orchid>",
        text      = "<white>",
        highlight = "<gold>",
        error     = "<crimson>"
    }
}

Vanity.descriptions = Vanity.descriptions or {}

-- =========================================================================
-- Standardized Output Helper
-- =========================================================================
function Vanity.echo(msg)
    local c = Vanity.config.colors
    cecho(string.format("\n%s[Vanity]:<reset> %s\n", c.prefix, msg))
end

-- =========================================================================
-- Data Management (Save/Load)
-- =========================================================================
function Vanity.save()
    local baseDir = getMudletHomeDir() .. "/Vanity"
    if not lfs.attributes(baseDir) then 
        lfs.mkdir(baseDir) 
    end
    
    local filepath = baseDir .. "/Vanity_Descriptions.lua"
    table.save(filepath, Vanity.descriptions)
end

function Vanity.load()
    local filepath = getMudletHomeDir() .. "/Vanity/Vanity_Descriptions.lua"
    if io.exists(filepath) then
        table.load(filepath, Vanity.descriptions)
    end
end

-- =========================================================================
-- Core Features
-- =========================================================================
function Vanity.updateDescription(name, content)
    name = name:lower()
    local c = Vanity.config.colors
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

-- =========================================================================
-- In-Game Commands & Help Interface
-- =========================================================================
function Vanity.showHelp()
    local c = Vanity.config.colors
    cecho(string.format("\n%s=======================================================================<reset>", c.border))
    cecho(string.format("\n%s                        V A N I T Y   H E L P                          <reset>", c.border))
    cecho(string.format("\n%s=======================================================================<reset>\n", c.border))
    
    cecho(string.format("\n%sIn-Game Commands:<reset>", c.prefix))
    cecho(string.format("\n  %svanity update <name> <content><reset>  - Creates or overwrites a description.", c.highlight))
    cecho(string.format("\n  %svanity use <name><reset>               - Sends DESCRIBE SELF <content> to the MUD.", c.highlight))
    cecho(string.format("\n  %svanity list<reset>                     - Displays all saved descriptions.", c.highlight))
    cecho(string.format("\n  %svanity delete <name><reset>            - Removes a saved description.", c.highlight))
    cecho(string.format("\n  %svanity help<reset>                     - Shows this help menu.", c.highlight))
    
    cecho(string.format("\n\n%s=======================================================================<reset>\n", c.border))
end

function Vanity.handleCommand(args)
    local cmd = args:lower()
    
    if cmd == "help" or cmd == "" then
        Vanity.showHelp()
    elseif cmd == "list" then
        Vanity.listDescriptions()
    else
        -- Regex parsing for multi-word commands
        local updateName, updateContent = string.match(args, "^[Uu][Pp][Dd][Aa][Tt][Ee]%s+(%w+)%s+(.+)$")
        local useName = string.match(args, "^[Uu][Ss][Ee]%s+(%w+)$")
        local deleteName = string.match(args, "^[Dd][Ee][Ll][Ee][Tt][Ee]%s+(%w+)$")
        
        if updateName and updateContent then
            Vanity.updateDescription(updateName, updateContent)
        elseif useName then
            Vanity.useDescription(useName)
        elseif deleteName then
            Vanity.deleteDescription(deleteName)
        else
            Vanity.echo(string.format("%sUnknown command or invalid syntax. Type %svanity help%s for options.<reset>", Vanity.config.colors.error, Vanity.config.colors.highlight, Vanity.config.colors.error))
        end
    end
end

-- =========================================================================
-- Initialization
-- Loads the data and sets up the master alias programmatically.
-- =========================================================================
function Vanity.init()
    -- Ensure we don't duplicate the alias if the script is reloaded
    if Vanity.aliasHandler then killAlias(Vanity.aliasHandler) end
    
    -- Master Alias: Catches anything starting with "vanity "
    Vanity.aliasHandler = tempAlias("^vanity(?: (.*))?$", [[
        local args = matches[2] or "help"
        Vanity.handleCommand(args)
    ]])

    Vanity.load()
    Vanity.echo("Vanity Manager Initialized. Type " .. Vanity.config.colors.highlight .. "vanity help<reset> for commands.")
end

-- Boot the script
Vanity.init()
