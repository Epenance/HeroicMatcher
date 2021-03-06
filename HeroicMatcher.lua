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

HeroicMatcher = LibStub("AceAddon-3.0"):NewAddon("HeroicMatcher", "AceTimer-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local AceGUI = LibStub("AceGUI-3.0")

local EventPrefix = "HCM"

local playerDungeonStatus = {}
local partyDungeonStatus = {}

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

local function isInArray (tab, val)
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
    self:RegisterComm(EventPrefix)

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

    local serializedDungeonStatus = HeroicMatcher:Serialize(playerDungeonStatus)
    print("Sending sync event")
    HeroicMatcher:SendCommMessage(EventPrefix, "PlayerSync|"..serializedDungeonStatus, "PARTY")
end

function HeroicMatcher:GetReveredFactions()
    factionsThatMatter = {"Cenarion Expedition", "Thrallmar", "Lower City", "The Sha'tar", "Keepers of Time", "Honor Hold"}
    reveredFactions = {}
    for factionIndex = 1, GetNumFactions() do
        name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

        if isInArray(factionsThatMatter, name) and earnedValue >= 21000 then
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
    heroicDungeons["Hellfire Citadel: Ramparts"] = {"Honor Hold", "Thrallmar"}
    heroicDungeons["Hellfire Citadel: The Blood Furnace"] = {"Honor Hold", "Thrallmar"}
    heroicDungeons["Hellfire Citadel: The Shattered Halls"] = {"Honor Hold", "Thrallmar"}
    heroicDungeons["Auchindoun: Mana-Tombs"] = {"Lower City"}
    heroicDungeons["Auchindoun: Auchenai Crypts"] = {"Lower City"}
    heroicDungeons["Auchindoun: Sethekk Halls"] = {"Lower City"}
    heroicDungeons["Auchindoun: Shadow Labyrinth"] = {"Lower City"}
    heroicDungeons["Coilfang: The Slave Pens"] = {"Cenarion Expedition"}
    heroicDungeons["Coilfang: The Underbog"] = {"Cenarion Expedition"}
    heroicDungeons["Coilfang: The Steamvault"] = {"Cenarion Expedition"}
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
            if isInArray(reveredFactions, faction) then
                availableDungeons[key] = "Available"
            end
        end
    end

    for dungeon, isAvailable in pairs(availableDungeons) do
        if isAvailable == "Available" then
            if isInArray(savedHeroics, dungeon) then
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
    hmlocal_frame:SetStatusText("Made by Epenance")

    hmlocal_frame:SetHeight(400)
    hmlocal_frame:SetWidth(400)

    HeroicMatcher:AddDungeonInfoToFrame(hmlocal_frame)

    local syncDataBtn = AceGUI:Create("Button")
    syncDataBtn:SetText("Sync data")
    syncDataBtn:SetCallback("OnClick", function()
        HeroicMatcher:SyncStatus()

    end)
    hmlocal_frame:AddChild(syncDataBtn)
end

function HeroicMatcher:wat()
    return 1, 2
end

function HeroicMatcher:AddDungeonInfoToFrame(frame)
    print("Add to frame")
    local availableDungeons, unavailableDungeons = HeroicMatcher:MapPartyDungeons()

    for _, dungeonName in ipairs(availableDungeons) do
        print(dungeonName)
        local testText = AceGUI:Create("Label")
        -- testText:SetImage("Interface\\Icons\\inv_bannerpvp_01")
        -- testText:SetImageSize(32, 32)
        testText:SetText(dungeonName)
        testText:SetColor(0, 255, 0)
        testText:SetFullWidth(true)

        frame:AddChild(testText)
    end

    for dungeonName, playerList in pairs(unavailableDungeons) do
        local testText = AceGUI:Create("Label")
        testText:SetText(dungeonName.." "..playerList)
        testText:SetColor(255, 0, 0)
        testText:SetFullWidth(true)

        frame:AddChild(testText)
    end
end

function HeroicMatcher:MapPartyDungeons()
    tempDungeons = {}
    availableDungeons = {}
    unavailableDungeons = {}

    playerName, _ = UnitName("player")

    partyDungeonStatus[playerName] = playerDungeonStatus

    for playerName, dungeons in pairs(partyDungeonStatus) do
        for dungeonName, status in pairs(dungeons) do
            if (tempDungeons[dungeonName] == nil) then
                tempDungeons[dungeonName] = {
                    available = {},
                    missingReputation = {},
                    saved = {}
                }
            end

            if status == "Available" then
                table.insert(tempDungeons[dungeonName].available, playerName)
            elseif status == "Saved" then
                table.insert(tempDungeons[dungeonName].saved, playerName)
            else
                table.insert(tempDungeons[dungeonName].missingReputation, playerName)
            end
        end
    end

    for dungeonName, data in pairs(tempDungeons) do
        if (table.getn(data.saved) == 0 and table.getn(data.missingReputation) == 0) then
            table.insert(availableDungeons, dungeonName)
        else
            local stringsToConcat = {}

            if table.getn(data.available) > 0 then
                local stringStart = "|cff00FF00"
                local stringEnd = "|r"

                local namesString = table.concat(data.available, ", ")

                table.insert(stringsToConcat, stringStart..namesString..stringEnd)
            end

            if table.getn(data.saved) > 0 then
                local stringStart = "|cffFF0000"
                local stringEnd = "|r"

                local namesString = table.concat(data.saved, ", ")

                table.insert(stringsToConcat, stringStart..namesString..stringEnd)
            end

            if table.getn(data.missingReputation) > 0 then
                local stringStart = "|cffFF0000"
                local stringEnd = "|r"

                local namesString = table.concat(data.missingReputation, ", ")

                table.insert(stringsToConcat, stringStart..namesString..stringEnd)
            end

            unavailableDungeons[dungeonName] = "("..table.concat(stringsToConcat, ", ")..")"
        end
    end

    return availableDungeons, unavailableDungeons
end

function HeroicMatcher:OnCommReceived(prefix, message, distribution, sender)
    print("Received event")
    local serializedData = ""

    if (prefix==EventPrefix) then
        if string.find(message, "|") then
            local amess = SplitAtSep(message, "|")
            message = amess[1]
            serializedData = amess[2]
        end

        if(message == "PlayerSync") then
            status, data = HeroicMatcher:Deserialize(serializedData)

            if status then
                partyDungeonStatus[sender] = data
            end
        end


    end
end

function SplitAtSep(str, sep)
    local t = {}
    local ind = string.find(str, sep)
    while (ind ~= nil) do
        table.insert(t, string.sub(str, 1, ind-1))
        str = string.sub(str, ind+1)
        ind = string.find(str, sep, 1, true)
    end
    if (str ~="") then table.insert(t, str) end
    return t
end