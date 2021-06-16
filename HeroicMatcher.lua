-- Maintain list of guildies for guild tab
-- Maintain list of party members for party tab

-- SendStatus() -> Sends the status of all instances that the character is eligible to and not saved for
-- Send to both guild and party, should be called when rep changes (Party, Guild) and when party changes (Party)
-- https://wowwiki-archive.fandom.com/wiki/API_SendAddonMessage
-- https://wowwiki-archive.fandom.com/wiki/API_GetSavedInstanceInfo
-- https://wowwiki-archive.fandom.com/wiki/API_GetNumSavedInstances

-- Create interface that shows cross referenced list of all party members,
-- and shows which ones are not available and why (Take inspiration from Attune)


-- GROUP_ROSTER_CHANGED / PARTY_MEMBERS_CHANGED

HeroicMatcher = LibStub("AceAddon-3.0"):NewAddon("HeroicMatcher", "AceTimer-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

local AceGUI = LibStub("AceGUI-3.0")

local playerDungeonStatus = {}

local options = {
    name = 'HeroicMatcher',
    handler = HeroicMatcher,
    type = 'group',
    args = {
        type1 = {
            name = "First Type",
            desc = "First type to swap between",
            type = "select",
            values = classTrackingValues,
            get = 'GetType1',
            set = 'SetType1',
        },
        type2 = {
            name = "Second Type",
            desc = "Second type to swap between",
            type = "select",
            values = classTrackingValues,
            get = 'GetType2',
            set = 'SetType2',
        },
        castInterval = {
            name = "Toggle Interval",
            desc = "Time in seconds between toggle casts",
            type = "range",
            min = 2,
            max = 45,
            step = 1,
            get = 'GetCastInterval',
            set = 'SetCastInterval',
            width = "full"
        }
    }
}

local function hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function HeroicMatcher:OnInitialize()
    print('Thank you for using HeroicMatcher, write /hm to enable. To change tracking types use /hm opt')

    self.db = LibStub("AceDB-3.0"):New("HeroicMatcherCharDB", defaults, true)

    LibStub('AceConfig-3.0'):RegisterOptionsTable('HeroicMatcher', options)
    self.optionsFrame = LibStub('AceConfigDialog-3.0'):AddToBlizOptions('HeroicMatcher', 'HeroicMatcher')
    self:RegisterChatCommand('hm', 'ChatCommand')
    self:RegisterChatCommand('HeroicMatcher', 'ChatCommand')

    -- Set default values
    HeroicMatcher.IS_RUNNING = false;
end

function HeroicMatcher:ChatCommand(input)
    if not input or input:trim() == "" then
        HeroicMatcher:SyncStatus();
    else
        if(input:trim() == 'opt') then
            InterfaceOptionsFrame_OpenToCategory(self.optionsFrame);
        elseif (input:trim() == 'open')  then
            HeroicMatcher:OpenFrame()
        else
            print('Did you mean "/hm opt"? To start simply type "/hm"');
        end
    end
end

function HeroicMatcher:SyncStatus()
    savedHeroics = HeroicMatcher:GetSavedHeroics()
    reveredFactions = HeroicMatcher:GetReveredFactions()
    heroicDungeons = HeroicMatcher:GetAvailableDungeons(reveredFactions, savedHeroics)

    playerDungeonStatus = heroicDungeons
end

function HeroicMatcher:GetReveredFactions()
    factionsThatMatter = {"Cenarion Expedition", "Thrallmar", "Lower City", "The Sha'tar", "Keepers of Time", "Honor Hold"}
    reveredFactions = {}
    for factionIndex = 1, GetNumFactions() do
        name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

        if hasValue(factionsThatMatter, name) and earnedValue >= 21000 then
            table.insert(reveredFactions, name)
            -- print("Faction: " .. name .. " - " .. earnedValue)
        end
    end

    return reveredFactions
end

function HeroicMatcher:GetSavedHeroics()
    savedHeroics = {}
    numInstances = GetNumSavedInstances()

    for i=1,numInstances do
        name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress
        = GetSavedInstanceInfo(i)

        if difficultyName == "Heroic" then
            table.insert(savedHeroics, name)
        end
    end

    return savedHeroics
end

function HeroicMatcher:GetAvailableDungeons(reveredFactions, savedHeroics)
    -- "Cenarion Expedition"
    -- "Thrallmar"
    -- "Lower City"
    -- "The Sha'tar"
    -- "Keepers of Time"
    -- "Honor Hold"
    heroicDungeons = {}
    heroicDungeons["Hellfire Ramparts"] = {"Honor Hold", "Thrallmar"}
    heroicDungeons["The Blood Furnace"] = {"Honor Hold", "Thrallmar"}
    heroicDungeons["The Shattered Halls"] = {"Honor Hold", "Thrallmar"}
    heroicDungeons["Mana-Tombs"] = {"Lower City"}
    heroicDungeons["Auchenai Crypts"] = {"Lower City"}
    heroicDungeons["Sethekk Halls"] = {"Lower City"}
    heroicDungeons["Shadow Labyrinth"] = {"Lower City"}
    heroicDungeons["The Slave Pens"] = {"Cenarion Expedition"}
    heroicDungeons["The Underbog"] = {"Cenarion Expedition"}
    heroicDungeons["The Steamvault"] = {"Cenarion Expedition"}
    heroicDungeons["Old Hillsbrad Foothills"] = {"Keepers of Time"}
    heroicDungeons["The Black Morass"] = {"Keepers of Time"}
    heroicDungeons["Tempest Keep: The Arcatraz"] = {"The Sha'tar"}
    heroicDungeons["Tempest Keep: The Botanica"] = {"The Sha'tar"}
    heroicDungeons["Tempest Keep: The Mechanar"] = {"The Sha'tar"}

    availableDungeons = {}

    -- print("Heroic Dungeons")

    for key, dungeon in pairs(heroicDungeons) do
        availableDungeons[key] = "Missing reputation"
        for _, faction in ipairs(dungeon) do
            -- If we are revered set true
            if hasValue(reveredFactions, faction) then
                availableDungeons[key] = "Available"
            end
        end
    end

    for dungeon, isAvailable in pairs(availableDungeons) do
        if isAvailable == "Available" then
            if hasValue(savedHeroics, dungeon) then
                availableDungeons[dungeon] = "Saved"
                -- print("Saved for "..dungeon)
            end
        end

    end

    return availableDungeons
end

function HeroicMatcher:OpenFrame()
    HeroicMatcher:SyncStatus()

    hmlocal_frame = AceGUI:Create("Frame")
    hmlocal_frame:SetTitle("  HeroicMatcher")
    hmlocal_frame:SetStatusText("Wuhuuu")

    hmlocal_frame:SetHeight(950)
    hmlocal_frame:SetWidth(950)

    local testText = AceGUI:Create("Label")
    testText:SetText("Hellfire Ramparts")
    testText:SetColor(0, 255, 0)

    hmlocal_frame:AddChild(testText)

    local syncDataBtn = AceGUI:Create("Button")
    syncDataBtn:SetText("Sync data")
    syncDataBtn:SetCallback("OnClick", function()

    end)
    hmlocal_frame:AddChild(syncDataBtn)


    for dungeonName, status in pairs(playerDungeonStatus) do
        if status == "Available" then
            print(dungeonName.." is available")
        else
            print(dungeonName.." not available: "..status)
        end
    end
end

function HeroicMatcher:AddDungeonInfoToFrame(frame)

end