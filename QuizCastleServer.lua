--[[
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🏰 QUIZ CASTLE v3.2 - SERVER SCRIPT                         ║
║                                                                                ║
║  📁 ServerScriptService에 "Script"로 넣으세요!                                  ║
║                                                                                ║
║  🆕 v3.2 CHANGES:                                                              ║
║     - 엘리베이터: 5초 대기 (퀴즈 확인 시간)                                      ║
║     - 2층 바닥: 틈 없이 완전히 막음                                              ║
║     - 펀칭 글러브: 속도 감소 효과 (번개처럼)                                     ║
║     - 리스폰 시스템: 트랙 이탈 시 자동 복귀                                       ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
]]

-- 서비스 안전하게 로드
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

-- 서비스 로드 확인
if not ReplicatedStorage then
    warn("⚠️ ReplicatedStorage not found!")
    return
end

print("🏰 Quiz Castle v3.2 Loading...")

local BestTimeStore, LeaderboardStore, WinsStore, XPStore
pcall(function()
    BestTimeStore = DataStoreService:GetDataStore("QuizCastleV3_BestTimes")
    LeaderboardStore = DataStoreService:GetOrderedDataStore("QuizCastleV3_Leaderboard")
    WinsStore = DataStoreService:GetDataStore("QuizCastleV3_Wins")
    XPStore = DataStoreService:GetDataStore("QuizCastleV3_XP")
end)

-- ============================================
-- ⭐ LEVEL SYSTEM CONFIGURATION
-- ============================================
local LevelConfig = {
    [1]  = {xp = 0,    name = "Rookie",      icon = "⬜", trailType = "None"},
    [2]  = {xp = 100,  name = "Runner",      icon = "💨", trailType = "Dust"},
    [3]  = {xp = 300,  name = "Star Walker", icon = "⭐", trailType = "Stars"},
    [4]  = {xp = 600,  name = "Sparkle",     icon = "✨", trailType = "Sparkle"},
    [5]  = {xp = 1000, name = "Blazer",      icon = "🔥", trailType = "Fire"},
    [6]  = {xp = 1500, name = "Frost",       icon = "❄️", trailType = "Ice"},
    [7]  = {xp = 2200, name = "Thunder",     icon = "⚡", trailType = "Lightning"},
    [8]  = {xp = 3000, name = "Rainbow",     icon = "🌈", trailType = "Rainbow"},
    [9]  = {xp = 4000, name = "Royal",       icon = "👑", trailType = "Royal"},
    [10] = {xp = 5500, name = "Legend",      icon = "🐉", trailType = "Legend"},
}

local XPRewards = {
    RaceComplete = 30,
    FirstPlace = 100,
    SecondPlace = 50,
    ThirdPlace = 25,
    QuizCorrect = 5,
    DailyFirst = 50,
    StreakBonus = 30,
}

-- ============================================
-- 🎛️ GAME CONFIGURATION
-- ============================================
local Config = {
    TRACK_LENGTH = 2000,
    TRACK_WIDTH = 40,
    MIN_PLAYERS = 1,
    MAX_PLAYERS = 50,
    LOBBY_COUNTDOWN = 15,
    INTERMISSION = 20,
    
    EnableRotatingBars = true,
    EnableJumpPads = true,
    EnableSlime = true,
    EnablePunchingGloves = true,
    EnableQuizGates = true,
    EnableElevators = true,
    EnableDisappearingBridge = true,
    EnableConveyorBelt = true,
    EnableElectricFloor = true,
    EnableRollingBoulder = true,
    EnableSequencePuzzle = false,
    
    ObstacleSpeed = 1.0,
    SlimeSlowFactor = 0.4,
}

local Admins = {}

local GameState = {
    phase = "Waiting",
    roundNumber = 0,
    playersInRace = {},
    finishedPlayers = {},
    countdown = 0,
    raceStartTime = 0,
}

local PlayerData = {}
local PlayerGateAnswers = {}
local ActiveGimmicks = {}
local PlayerStreaks = {}

-- ============================================
-- 🔄 PERFORMANCE: 중앙 집중식 회전 오브젝트 관리
-- ============================================
local RotatingObjects = {}  -- {part, speed, rotation, rotationType}
local ItemBoxes = {}  -- {part, rotation}

-- ============================================
-- REMOTE EVENTS
-- ============================================
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if remoteFolder then remoteFolder:Destroy() end
remoteFolder = Instance.new("Folder")
remoteFolder.Name = "RemoteEvents"
remoteFolder.Parent = ReplicatedStorage

local eventNames = {
    "GameEvent", "TimeUpdate", "LeaderboardUpdate", "GateQuiz",
    "UseItem", "ItemEffect", "AdminCommand", "ConfigUpdate",
    "RoundUpdate", "LobbyUpdate", "XPUpdate", "LevelUp", "TrailUpdate"
}

for _, name in ipairs(eventNames) do
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = remoteFolder
end

local Events = remoteFolder
print("✅ RemoteEvents Created")

-- ============================================
-- ⭐ XP & LEVEL FUNCTIONS
-- ============================================
local function GetLevelFromXP(xp)
    local level = 1
    for lv = 10, 1, -1 do
        if xp >= LevelConfig[lv].xp then
            level = lv
            break
        end
    end
    return level
end

local function GetLevelProgress(xp, level)
    if level >= 10 then return 1, 0, 0 end
    local currentLevelXP = LevelConfig[level].xp
    local nextLevelXP = LevelConfig[level + 1].xp
    local xpInLevel = xp - currentLevelXP
    local xpNeeded = nextLevelXP - currentLevelXP
    local progress = xpInLevel / xpNeeded
    return progress, xpInLevel, xpNeeded
end

local function SavePlayerXP(player, xp)
    pcall(function()
        if XPStore then XPStore:SetAsync(tostring(player.UserId), xp) end
    end)
end

local function LoadPlayerXP(player)
    local xp = 0
    pcall(function()
        if XPStore then xp = XPStore:GetAsync(tostring(player.UserId)) or 0 end
    end)
    return xp
end

local function AwardXP(player, amount, reason)
    if not PlayerData[player] then return end
    
    local oldXP = PlayerData[player].xp or 0
    local oldLevel = GetLevelFromXP(oldXP)
    
    local newXP = oldXP + amount
    PlayerData[player].xp = newXP
    
    local newLevel = GetLevelFromXP(newXP)
    PlayerData[player].level = newLevel
    
    local progress, xpInLevel, xpNeeded = GetLevelProgress(newXP, newLevel)
    Events.XPUpdate:FireClient(player, {
        xp = newXP,
        level = newLevel,
        levelName = LevelConfig[newLevel].name,
        levelIcon = LevelConfig[newLevel].icon,
        trailType = LevelConfig[newLevel].trailType,
        progress = progress,
        xpInLevel = xpInLevel,
        xpNeeded = xpNeeded,
        xpGained = amount,
        reason = reason
    })
    
    if newLevel > oldLevel then
        local levelInfo = LevelConfig[newLevel]
        Events.LevelUp:FireClient(player, {
            newLevel = newLevel,
            levelName = levelInfo.name,
            levelIcon = levelInfo.icon,
            trailType = levelInfo.trailType
        })
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                Events.GameEvent:FireClient(otherPlayer, "PlayerLevelUp", {
                    playerName = player.Name,
                    newLevel = newLevel,
                    levelIcon = levelInfo.icon
                })
            end
        end
        
        Events.TrailUpdate:FireAllClients({
            playerName = player.Name,
            trailType = levelInfo.trailType,
            level = newLevel
        })
    end
    
    task.spawn(function()
        SavePlayerXP(player, newXP)
    end)
    
    return newXP, newLevel
end

-- ============================================
-- DATA FUNCTIONS
-- ============================================
local function SavePlayerStats(player, time, rank)
    pcall(function()
        if not BestTimeStore then return end
        local timeMs = math.floor(time * 1000)
        local currentBest = BestTimeStore:GetAsync(tostring(player.UserId))
        if not currentBest or timeMs < currentBest then
            BestTimeStore:SetAsync(tostring(player.UserId), timeMs)
        end
        if LeaderboardStore then
            LeaderboardStore:SetAsync(tostring(player.UserId) .. "_" .. player.Name, timeMs)
        end
        if rank == 1 and WinsStore then
            local wins = WinsStore:GetAsync(tostring(player.UserId)) or 0
            WinsStore:SetAsync(tostring(player.UserId), wins + 1)
        end
    end)
end

local function GetPlayerStats(player)
    local stats = {bestTime = nil, wins = 0, xp = 0}
    pcall(function()
        if BestTimeStore then
            local timeMs = BestTimeStore:GetAsync(tostring(player.UserId))
            stats.bestTime = timeMs and timeMs/1000 or nil
        end
        if WinsStore then
            stats.wins = WinsStore:GetAsync(tostring(player.UserId)) or 0
        end
        if XPStore then
            stats.xp = XPStore:GetAsync(tostring(player.UserId)) or 0
        end
    end)
    return stats
end

local function GetLeaderboard()
    local lb = {}
    pcall(function()
        if not LeaderboardStore then return end
        local pages = LeaderboardStore:GetSortedAsync(true, 10)
        for rank, entry in ipairs(pages:GetCurrentPage()) do
            table.insert(lb, {rank = rank, name = entry.key:match("_(.+)") or "?", time = entry.value/1000})
        end
    end)
    return lb
end

-- ============================================
-- QUIZ DATABASE
-- ============================================
local GateQuizzes = {
    {q = "Is Earth round?", o = {"Yes", "No"}, a = 1},
    {q = "Is fire cold?", o = {"Yes", "No"}, a = 2},
    {q = "Can birds fly?", o = {"Yes", "No"}, a = 1},
    {q = "Is ice hot?", o = {"Yes", "No"}, a = 2},
    {q = "Do fish swim?", o = {"Yes", "No"}, a = 1},
    {q = "Is moon a star?", o = {"Yes", "No"}, a = 2},
    {q = "Sky color?", o = {"Red", "Blue", "Green"}, a = 2},
    {q = "Cat legs?", o = {"2", "4", "6"}, a = 2},
    {q = "5 + 5?", o = {"8", "10", "12"}, a = 2},
    {q = "Water formula?", o = {"H2O", "CO2", "O2"}, a = 1},
    {q = "Sun is a?", o = {"Planet", "Star", "Moon"}, a = 2},
    {q = "2 + 3?", o = {"3", "4", "5", "6"}, a = 3},
    {q = "Grass color?", o = {"Red", "Blue", "Green", "Yellow"}, a = 3},
    {q = "Days in week?", o = {"5", "6", "7", "8"}, a = 3},
    {q = "3 x 3?", o = {"6", "7", "8", "9"}, a = 4},
    {q = "Spider legs?", o = {"4", "6", "8", "10"}, a = 3},
    {q = "Biggest planet?", o = {"Earth", "Mars", "Jupiter", "Venus"}, a = 3},
}

local function GetQuizByOptionCount(count)
    local f = {}
    for _, q in ipairs(GateQuizzes) do if #q.o == count then table.insert(f, q) end end
    return #f > 0 and f[math.random(#f)] or GateQuizzes[1]
end

local gateColors = {
    Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(80, 150, 255),
    Color3.fromRGB(255, 220, 80),
    Color3.fromRGB(80, 220, 80)
}

-- ============================================
-- 🏰 CREATE CASTLE EXTERIOR
-- ============================================
local function CreateCastleExterior(parent)
    print("  Building Castle Exterior...")
    
    local TL = Config.TRACK_LENGTH
    local TW = Config.TRACK_WIDTH
    
    local moat = Instance.new("Part")
    moat.Name = "Moat"
    moat.Size = Vector3.new(200, 8, 250)
    moat.Position = Vector3.new(0, -4, -50)
    moat.Anchored = true
    moat.CanCollide = false
    moat.BrickColor = BrickColor.new("Bright blue")
    moat.Material = Enum.Material.Glass
    moat.Transparency = 0.3
    moat.Parent = parent
    
    local bridge = Instance.new("Part")
    bridge.Name = "EntranceBridge"
    bridge.Size = Vector3.new(25, 2, 60)
    bridge.Position = Vector3.new(0, 0, -50)
    bridge.Anchored = true
    bridge.BrickColor = BrickColor.new("Reddish brown")
    bridge.Material = Enum.Material.Wood
    bridge.Parent = parent
    
    for _, xOffset in ipairs({-11, 11}) do
        local rail = Instance.new("Part")
        rail.Size = Vector3.new(2, 4, 60)
        rail.Position = Vector3.new(xOffset, 3, -50)
        rail.Anchored = true
        rail.BrickColor = BrickColor.new("Reddish brown")
        rail.Material = Enum.Material.Wood
        rail.Parent = parent
    end
    
    for _, xOffset in ipairs({-30, 30}) do
        local tower = Instance.new("Part")
        tower.Size = Vector3.new(20, 60, 20)
        tower.Position = Vector3.new(xOffset, 30, -15)
        tower.Anchored = true
        tower.BrickColor = BrickColor.new("Medium stone grey")
        tower.Material = Enum.Material.Brick
        tower.Parent = parent
        
        local roof = Instance.new("Part")
        roof.Size = Vector3.new(25, 20, 25)
        roof.Position = Vector3.new(xOffset, 70, -15)
        roof.Anchored = true
        roof.BrickColor = BrickColor.new("Bright red")
        roof.Material = Enum.Material.Slate
        roof.Shape = Enum.PartType.Ball
        roof.Parent = parent
        
        local flagPole = Instance.new("Part")
        flagPole.Size = Vector3.new(0.5, 25, 0.5)
        flagPole.Position = Vector3.new(xOffset, 92, -15)
        flagPole.Anchored = true
        flagPole.BrickColor = BrickColor.new("Dark stone grey")
        flagPole.Material = Enum.Material.Metal
        flagPole.Parent = parent
        
        local flag = Instance.new("Part")
        flag.Size = Vector3.new(0.2, 8, 12)
        flag.Position = Vector3.new(xOffset, 100, -9)
        flag.Anchored = true
        flag.BrickColor = BrickColor.new("Bright yellow")
        flag.Material = Enum.Material.Fabric
        flag.Parent = parent
    end
    
    local archTop = Instance.new("Part")
    archTop.Size = Vector3.new(40, 10, 8)
    archTop.Position = Vector3.new(0, 25, -15)
    archTop.Anchored = true
    archTop.BrickColor = BrickColor.new("Dark stone grey")
    archTop.Material = Enum.Material.Brick
    archTop.Parent = parent
    
    local signPart = Instance.new("Part")
    signPart.Size = Vector3.new(35, 8, 1)
    signPart.Position = Vector3.new(0, 33, -11)
    signPart.Anchored = true
    signPart.CanCollide = false
    signPart.Transparency = 1
    signPart.Parent = parent
    
    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.Parent = signPart
    local signLabel = Instance.new("TextLabel")
    signLabel.Size = UDim2.new(1,0,1,0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = "🏰 QUIZ CASTLE 🏰"
    signLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    signLabel.TextScaled = true
    signLabel.Font = Enum.Font.GothamBold
    signLabel.Parent = signGui
    
    for _, xPos in ipairs({-TW/2 - 5, TW/2 + 5}) do
        local sideWall = Instance.new("Part")
        sideWall.Size = Vector3.new(8, 25, TL + 100)
        sideWall.Position = Vector3.new(xPos, 12.5, TL/2)
        sideWall.Anchored = true
        sideWall.BrickColor = BrickColor.new("Medium stone grey")
        sideWall.Material = Enum.Material.Brick
        sideWall.Parent = parent
    end
    
    print("  ✅ Castle Exterior Complete!")
end

-- ============================================
-- 🎪 CREATE LOBBY
-- ============================================
local LobbySpawn = nil
local StartGate = nil

local function CreateLobby(parent)
    print("  Building Lobby...")
    
    local lobbyFolder = Instance.new("Folder")
    lobbyFolder.Name = "Lobby"
    lobbyFolder.Parent = parent
    
    local lobbyFloor = Instance.new("Part")
    lobbyFloor.Size = Vector3.new(80, 2, 80)
    lobbyFloor.Position = Vector3.new(0, -1, -80)
    lobbyFloor.Anchored = true
    lobbyFloor.BrickColor = BrickColor.new("Brick yellow")
    lobbyFloor.Material = Enum.Material.Cobblestone
    lobbyFloor.Parent = lobbyFolder
    
    LobbySpawn = Instance.new("SpawnLocation")
    LobbySpawn.Name = "LobbySpawn"
    LobbySpawn.Size = Vector3.new(30, 1, 30)
    LobbySpawn.Position = Vector3.new(0, 1, -100)
    LobbySpawn.Anchored = true
    LobbySpawn.BrickColor = BrickColor.new("Lime green")
    LobbySpawn.Material = Enum.Material.Neon
    LobbySpawn.Neutral = true  -- 모든 플레이어가 여기서 스폰
    LobbySpawn.Enabled = true
    LobbySpawn.Parent = lobbyFolder
    
    StartGate = Instance.new("Part")
    StartGate.Name = "StartGate"
    StartGate.Size = Vector3.new(40, 20, 3)
    StartGate.Position = Vector3.new(0, 10, -20)
    StartGate.Anchored = true
    StartGate.CanCollide = true
    StartGate.BrickColor = BrickColor.new("Bright red")
    StartGate.Material = Enum.Material.Metal
    StartGate.Transparency = 0.3
    StartGate.Parent = lobbyFolder
    
    local gateGui = Instance.new("SurfaceGui")
    gateGui.Face = Enum.NormalId.Back
    gateGui.Parent = StartGate
    local gateLabel = Instance.new("TextLabel")
    gateLabel.Name = "GateLabel"
    gateLabel.Size = UDim2.new(1, 0, 1, 0)
    gateLabel.BackgroundTransparency = 1
    gateLabel.Text = "⏳ WAITING..."
    gateLabel.TextColor3 = Color3.new(1, 1, 1)
    gateLabel.TextScaled = true
    gateLabel.Font = Enum.Font.GothamBold
    gateLabel.Parent = gateGui
    
    print("  ✅ Lobby Complete!")
    return lobbyFolder
end

-- ============================================
-- 🏃 CREATE RACE TRACK
-- ============================================
local RaceSpawn = nil

local function CreateRaceTrack(parent)
    print("  Building Race Track...")
    
    local trackFolder = Instance.new("Folder")
    trackFolder.Name = "RaceTrack"
    trackFolder.Parent = parent
    
    local TL = Config.TRACK_LENGTH
    local TW = Config.TRACK_WIDTH
    
    local floorSections = {
        {0, TL * 0.2, "Brick yellow", 0},
        {TL * 0.2, TL * 0.4, "Medium stone grey", 0},
        {TL * 0.4, TL * 0.6, "Sand blue", 0},
        {TL * 0.6, TL * 0.8, "Nougat", 0},
        {TL * 0.8, TL, "Bright yellow", 0},
    }
    
    for _, sec in ipairs(floorSections) do
        local startZ, endZ, color, height = sec[1], sec[2], sec[3], sec[4]
        local length = endZ - startZ
        
        local floor = Instance.new("Part")
        floor.Size = Vector3.new(TW, 2, length)
        floor.Position = Vector3.new(0, -1 + height, startZ + length/2)
        floor.Anchored = true
        floor.BrickColor = BrickColor.new(color)
        floor.Material = Enum.Material.Cobblestone
        floor.Parent = trackFolder
    end
    
    RaceSpawn = Instance.new("Part")
    RaceSpawn.Name = "RaceSpawn"
    RaceSpawn.Size = Vector3.new(TW, 1, 10)
    RaceSpawn.Position = Vector3.new(0, 0.5, 5)
    RaceSpawn.Anchored = true
    RaceSpawn.CanCollide = false
    RaceSpawn.BrickColor = BrickColor.new("Lime green")
    RaceSpawn.Material = Enum.Material.Neon
    RaceSpawn.Transparency = 0.5
    RaceSpawn.Parent = trackFolder
    
    local finishLine = Instance.new("Part")
    finishLine.Name = "FinishLine"
    finishLine.Size = Vector3.new(TW, 20, 5)
    finishLine.Position = Vector3.new(0, 10, TL - 2)
    finishLine.Anchored = true
    finishLine.CanCollide = false
    finishLine.BrickColor = BrickColor.new("Bright yellow")
    finishLine.Material = Enum.Material.Neon
    finishLine.Transparency = 0.5
    finishLine.Parent = trackFolder
    
    local finishGui = Instance.new("SurfaceGui")
    finishGui.Face = Enum.NormalId.Back
    finishGui.Parent = finishLine
    local finishLabel = Instance.new("TextLabel")
    finishLabel.Size = UDim2.new(1,0,1,0)
    finishLabel.BackgroundTransparency = 1
    finishLabel.Text = "🏆 FINISH 🏆"
    finishLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    finishLabel.TextScaled = true
    finishLabel.Font = Enum.Font.GothamBold
    finishLabel.Parent = finishGui
    
    finishLine.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and GameState.phase == "Racing" then
            if table.find(GameState.playersInRace, player) and not table.find(GameState.finishedPlayers, player) then
                table.insert(GameState.finishedPlayers, player)
                local rank = #GameState.finishedPlayers
                local raceTime = tick() - GameState.raceStartTime
                
                SavePlayerStats(player, raceTime, rank)
                
                if PlayerData[player] then
                    if not PlayerData[player].bestTime or raceTime < PlayerData[player].bestTime then
                        PlayerData[player].bestTime = raceTime
                    end
                    if rank == 1 then
                        PlayerData[player].wins = (PlayerData[player].wins or 0) + 1
                    end
                    PlayerData[player].lastRaceTime = raceTime
                end
                
                AwardXP(player, XPRewards.RaceComplete, "Race Complete")
                
                if rank == 1 then
                    AwardXP(player, XPRewards.FirstPlace, "1st Place!")
                elseif rank == 2 then
                    AwardXP(player, XPRewards.SecondPlace, "2nd Place!")
                elseif rank == 3 then
                    AwardXP(player, XPRewards.ThirdPlace, "3rd Place!")
                end
                
                PlayerStreaks[player] = (PlayerStreaks[player] or 0) + 1
                if PlayerStreaks[player] >= 3 then
                    AwardXP(player, XPRewards.StreakBonus, "3 Race Streak!")
                    PlayerStreaks[player] = 0
                end
                
                Events.GameEvent:FireClient(player, "Finished", {
                    rank = rank,
                    time = raceTime,
                    totalPlayers = #GameState.playersInRace,
                    bestTime = PlayerData[player] and PlayerData[player].bestTime
                })
                
                Events.RoundUpdate:FireAllClients("PlayerFinished", {
                    playerName = player.Name,
                    rank = rank,
                    time = raceTime
                })
                
                if #GameState.finishedPlayers >= #GameState.playersInRace then
                    EndRound()
                end
            end
        end
    end)
    
    print("  ✅ Race Track Complete!")
    return trackFolder
end

-- ============================================
-- 🎮 GIMMICK BUILDERS
-- ============================================

local function CreateRotatingBar(parent, zPos, width, height, speed)
    if not Config.EnableRotatingBars then return end

    local bar = Instance.new("Part")
    bar.Size = Vector3.new(width or 25, 2, 2)
    bar.Position = Vector3.new(0, height or 3, zPos)
    bar.Anchored = true
    bar.BrickColor = BrickColor.new("Bright red")
    bar.Material = Enum.Material.Metal
    bar.Parent = parent

    local actualSpeed = (speed or 2) * Config.ObstacleSpeed

    -- 🔄 PERFORMANCE: 개별 루프 대신 중앙 관리 테이블에 등록
    table.insert(RotatingObjects, {
        part = bar,
        speed = actualSpeed,
        rotation = math.random(0, 360),
        rotationType = "Y"  -- Y축 회전
    })

    local db = {}
    bar.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and not db[player] then
            db[player] = true
            local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
            if rp then
                Events.ItemEffect:FireClient(player, "Knockback", {direction = (rp.Position - bar.Position).Unit * 35 + Vector3.new(0, 18, 0)})
            end
            task.delay(0.5, function() db[player] = nil end)
        end
    end)

    table.insert(ActiveGimmicks, bar)
end

local function CreateJumpPad(parent, pos)
    if not Config.EnableJumpPads then return end
    
    local TW = Config.TRACK_WIDTH
    
    local pad = Instance.new("Part")
    pad.Name = "JumpPad"
    pad.Size = Vector3.new(8, 1, 8)
    pad.Position = pos
    pad.Anchored = true
    pad.BrickColor = BrickColor.new("Lime green")
    pad.Material = Enum.Material.Neon
    pad.Parent = parent
    
    local springGui = Instance.new("SurfaceGui")
    springGui.Face = Enum.NormalId.Top
    springGui.Parent = pad
    
    local springLabel = Instance.new("TextLabel")
    springLabel.Size = UDim2.new(1, 0, 1, 0)
    springLabel.BackgroundTransparency = 1
    springLabel.Text = "🔺\n⬆️"
    springLabel.TextColor3 = Color3.new(1, 1, 1)
    springLabel.TextScaled = true
    springLabel.Font = Enum.Font.GothamBold
    springLabel.Parent = springGui
    
    local wall = Instance.new("Part")
    wall.Name = "JumpWall"
    wall.Size = Vector3.new(TW, 12, 3)
    wall.Position = Vector3.new(0, 6, pos.Z + 6)
    wall.Anchored = true
    wall.BrickColor = BrickColor.new("Medium stone grey")
    wall.Material = Enum.Material.Brick
    wall.Parent = parent
    
    local wallGui = Instance.new("SurfaceGui")
    wallGui.Face = Enum.NormalId.Back
    wallGui.Parent = wall
    
    local wallLabel = Instance.new("TextLabel")
    wallLabel.Size = UDim2.new(1, 0, 1, 0)
    wallLabel.BackgroundTransparency = 1
    wallLabel.Text = "⬆️ JUMP! ⬆️"
    wallLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    wallLabel.TextScaled = true
    wallLabel.Font = Enum.Font.GothamBold
    wallLabel.Parent = wallGui
    
    local db = {}
    pad.Touched:Connect(function(hit)
        local hum = hit.Parent:FindFirstChild("Humanoid")
        local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
        if hum and rp and not db[hit.Parent] then
            db[hit.Parent] = true
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(0, 100000, 0)
            bv.Velocity = Vector3.new(0, 90, 0)
            bv.Parent = rp
            Debris:AddItem(bv, 0.2)
            task.delay(0.5, function() db[hit.Parent] = nil end)
        end
    end)
    
    table.insert(ActiveGimmicks, pad)
    table.insert(ActiveGimmicks, wall)
end

local function CreateSlimeZone(parent, zStart, length)
    if not Config.EnableSlime then return end
    
    local TW = Config.TRACK_WIDTH
    
    local slimeBase = Instance.new("Part")
    slimeBase.Size = Vector3.new(TW, 0.5, length)
    slimeBase.Position = Vector3.new(0, 0.25, zStart + length/2)
    slimeBase.Anchored = true
    slimeBase.BrickColor = BrickColor.new("Lime green")
    slimeBase.Material = Enum.Material.Marble
    slimeBase.Transparency = 0.3
    slimeBase.Parent = parent
    
    for i = 1, math.floor(length / 15) do
        local ghostPart = Instance.new("Part")
        ghostPart.Size = Vector3.new(6, 0.1, 6)
        ghostPart.Position = Vector3.new(math.random(-10, 10), 0.35, zStart + i * 15)
        ghostPart.Anchored = true
        ghostPart.CanCollide = false
        ghostPart.Transparency = 1
        ghostPart.Parent = parent
        
        local ghostGui = Instance.new("SurfaceGui")
        ghostGui.Face = Enum.NormalId.Top
        ghostGui.Parent = ghostPart
        
        local ghostLabel = Instance.new("TextLabel")
        ghostLabel.Size = UDim2.new(1, 0, 1, 0)
        ghostLabel.BackgroundTransparency = 1
        ghostLabel.Text = "👻"
        ghostLabel.TextScaled = true
        ghostLabel.Parent = ghostGui
        
        table.insert(ActiveGimmicks, ghostPart)
    end
    
    local pathWidth = 6
    local numPaths = math.floor(length / 20)
    
    for i = 1, numPaths do
        local xPos = (i % 2 == 0) and 10 or -10
        local safePath = Instance.new("Part")
        safePath.Name = "SafePath"
        safePath.Size = Vector3.new(pathWidth, 0.6, 12)
        safePath.Position = Vector3.new(xPos, 0.3, zStart + (i - 0.5) * (length / numPaths))
        safePath.Anchored = true
        safePath.BrickColor = BrickColor.new("Bright yellow")
        safePath.Material = Enum.Material.Cobblestone
        safePath.Parent = parent
        
        table.insert(ActiveGimmicks, safePath)
    end
    
    local inSlime = {}
    local safePaths = {}
    
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == "SafePath" then
            child.Touched:Connect(function(hit)
                local char = hit.Parent
                if char:FindFirstChild("Humanoid") then
                    safePaths[char] = true
                end
            end)
            child.TouchEnded:Connect(function(hit)
                local char = hit.Parent
                safePaths[char] = nil
            end)
        end
    end
    
    slimeBase.Touched:Connect(function(hit)
        if not hit or not hit.Parent then return end
        local hum = hit.Parent:FindFirstChild("Humanoid")
        if hum and not inSlime[hit.Parent] and not safePaths[hit.Parent] then
            inSlime[hit.Parent] = hum.WalkSpeed
            hum.WalkSpeed = hum.WalkSpeed * Config.SlimeSlowFactor
        end
    end)
    
    slimeBase.TouchEnded:Connect(function(hit)
        if not hit or not hit.Parent then return end
        local hum = hit.Parent:FindFirstChild("Humanoid")
        if hum and inSlime[hit.Parent] then
            hum.WalkSpeed = inSlime[hit.Parent]
            inSlime[hit.Parent] = nil
        end
    end)
    
    table.insert(ActiveGimmicks, slimeBase)
end

-- 🥊 펀칭 글러브 (속도 감소 효과로 변경!)
local function CreatePunchingCorridor(parent, zStart, length)
    if not Config.EnablePunchingGloves then return end
    
    local corridorWidth = 12
    local TW = Config.TRACK_WIDTH
    
    for _, xOffset in ipairs({-corridorWidth/2 - 5, corridorWidth/2 + 5}) do
        local wall = Instance.new("Part")
        wall.Size = Vector3.new((TW - corridorWidth) / 2, 10, length)
        wall.Position = Vector3.new((xOffset > 0) and (TW/4 + corridorWidth/4) or (-TW/4 - corridorWidth/4), 5, zStart + length/2)
        wall.Anchored = true
        wall.BrickColor = BrickColor.new("Dark stone grey")
        wall.Material = Enum.Material.Brick
        wall.Parent = parent
        
        table.insert(ActiveGimmicks, wall)
    end
    
    local numGloves = math.floor(length / 25)
    
    for i = 1, numGloves do
        local zPos = zStart + i * (length / (numGloves + 1))
        local side = (i % 2 == 0) and 1 or -1
        local xPos = side * (corridorWidth/2 + 3)
        
        local glove = Instance.new("Part")
        glove.Name = "PunchingGlove"
        glove.Size = Vector3.new(5, 5, 5)
        glove.Position = Vector3.new(xPos, 4, zPos)
        glove.Anchored = true
        glove.BrickColor = BrickColor.new("Bright red")
        glove.Material = Enum.Material.SmoothPlastic
        glove.Parent = parent
        
        local gloveGui = Instance.new("SurfaceGui")
        gloveGui.Face = (side == 1) and Enum.NormalId.Left or Enum.NormalId.Right
        gloveGui.Parent = glove
        
        local gloveLabel = Instance.new("TextLabel")
        gloveLabel.Size = UDim2.new(1, 0, 1, 0)
        gloveLabel.BackgroundTransparency = 1
        gloveLabel.Text = "🥊"
        gloveLabel.TextScaled = true
        gloveLabel.Parent = gloveGui
        
        local gloveFrontGui = Instance.new("SurfaceGui")
        gloveFrontGui.Face = Enum.NormalId.Front
        gloveFrontGui.Parent = glove
        
        local gloveFrontLabel = Instance.new("TextLabel")
        gloveFrontLabel.Size = UDim2.new(1, 0, 1, 0)
        gloveFrontLabel.BackgroundTransparency = 1
        gloveFrontLabel.Text = "🥊"
        gloveFrontLabel.TextScaled = true
        gloveFrontLabel.Parent = gloveFrontGui
        
        local retracted = Vector3.new(xPos, 4, zPos)
        local extended = Vector3.new(-side * (corridorWidth/2 - 2), 4, zPos)
        
        task.spawn(function()
            task.wait(i * 0.3)
            while glove and glove.Parent do
                task.wait(2 / Config.ObstacleSpeed)
                glove.BrickColor = BrickColor.new("Really red")
                task.wait(0.3)
                TweenService:Create(glove, TweenInfo.new(0.1, Enum.EasingStyle.Back), {Position = extended}):Play()
                task.wait(0.2)
                TweenService:Create(glove, TweenInfo.new(0.4), {Position = retracted}):Play()
                glove.BrickColor = BrickColor.new("Bright red")
                task.wait(0.4)
            end
        end)
        
        -- 🔧 수정: 튕기기 대신 속도 감소!
        local db = {}
        glove.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            local hum = hit.Parent:FindFirstChild("Humanoid")
            if player and hum and not db[player] then
                db[player] = true
                local origSpeed = hum.WalkSpeed
                local origJump = hum.JumpPower
                hum.WalkSpeed = origSpeed * 0.3
                hum.JumpPower = 0
                Events.ItemEffect:FireClient(player, "PunchStun", {duration = 1.5})
                task.delay(1.5, function()
                    if hum then
                        hum.WalkSpeed = origSpeed
                        hum.JumpPower = origJump
                    end
                    db[player] = nil
                end)
            end
        end)
        
        table.insert(ActiveGimmicks, glove)
    end
end

local function CreateQuizGate(parent, gateId, triggerZ, gateZ, optionCount)
    if not Config.EnableQuizGates then return end
    
    local quiz = GetQuizByOptionCount(optionCount)
    local TW = Config.TRACK_WIDTH
    
    local trigger = Instance.new("Part")
    trigger.Size = Vector3.new(TW, 10, 5)
    trigger.Position = Vector3.new(0, 5, triggerZ)
    trigger.Anchored = true
    trigger.CanCollide = false
    trigger.Transparency = 1
    trigger.Parent = parent
    
    local triggerFloor = Instance.new("Part")
    triggerFloor.Size = Vector3.new(TW, 0.5, 5)
    triggerFloor.Position = Vector3.new(0, 0.25, triggerZ)
    triggerFloor.Anchored = true
    triggerFloor.CanCollide = false
    triggerFloor.BrickColor = BrickColor.new("Bright violet")
    triggerFloor.Material = Enum.Material.Neon
    triggerFloor.Transparency = 0.5
    triggerFloor.Parent = parent
    
    local gateWidth = TW / optionCount
    for i = 1, optionCount do
        local xPos = -TW/2 + gateWidth/2 + (i-1) * gateWidth
        local gate = Instance.new("Part")
        gate.Name = "Gate" .. gateId .. "_" .. i
        gate.Size = Vector3.new(gateWidth - 1, 14, 3)
        gate.Position = Vector3.new(xPos, 7, gateZ)
        gate.Anchored = true
        gate.CanCollide = false
        gate.Color = gateColors[i]
        gate.Material = Enum.Material.Neon
        gate.Transparency = 0.2
        gate.Parent = parent
        
        local outline = Instance.new("SelectionBox")
        outline.Adornee = gate
        outline.Color3 = gateColors[i]
        outline.LineThickness = 0.05
        outline.Parent = gate
        
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Back
        gui.Parent = gate
        
        local num = Instance.new("TextLabel")
        num.Size = UDim2.new(1,0,0.35,0)
        num.BackgroundTransparency = 1
        num.Text = "[" .. i .. "]"
        num.TextColor3 = Color3.new(1,1,1)
        num.TextScaled = true
        num.Font = Enum.Font.GothamBold
        num.Parent = gui
        
        local opt = Instance.new("TextLabel")
        opt.Size = UDim2.new(0.9,0,0.55,0)
        opt.Position = UDim2.new(0.05,0,0.4,0)
        opt.BackgroundTransparency = 1
        opt.Text = quiz.o[i]
        opt.TextColor3 = Color3.new(1,1,1)
        opt.TextScaled = true
        opt.Font = Enum.Font.GothamBold
        opt.Parent = gui
        
        local db = {}
        gate.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if not player or db[player] then return end
            local answer = PlayerGateAnswers[player] and PlayerGateAnswers[player][gateId]
            if answer == i then
                Events.ItemEffect:FireClient(player, "GateCorrect", {})
                AwardXP(player, XPRewards.QuizCorrect, "Quiz Correct!")
            else
                db[player] = true
                local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
                local hum = hit.Parent:FindFirstChild("Humanoid")
                if hum and rp then
                    local origSpeed = hum.WalkSpeed
                    local origJump = hum.JumpPower
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    local bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(50000,50000,50000)
                    bv.Velocity = Vector3.new(0, 22, -50)
                    bv.Parent = rp
                    Debris:AddItem(bv, 0.3)
                    Events.ItemEffect:FireClient(player, "GateWrong", {duration = 1.2})
                    task.delay(1.2, function()
                        if hum then hum.WalkSpeed = origSpeed; hum.JumpPower = origJump end
                        db[player] = nil
                    end)
                end
            end
        end)
        
        table.insert(ActiveGimmicks, gate)
    end
    
    local triggered = {}
    trigger.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if not player or triggered[player] then return end
        triggered[player] = true
        if not PlayerGateAnswers[player] then PlayerGateAnswers[player] = {} end
        PlayerGateAnswers[player][gateId] = quiz.a
        Events.GateQuiz:FireClient(player, {
            gateId = gateId, 
            question = quiz.q, 
            options = quiz.o, 
            optionCount = optionCount,
            colors = gateColors
        })
        task.delay(20, function() triggered[player] = nil end)
    end)
    
    table.insert(ActiveGimmicks, trigger)
end

-- 🛗 엘리베이터 (5초 대기 + 2층 바닥 틈 없음!)
local function CreateElevator(parent, elevId, triggerZ, elevZ, optionCount)
    if not Config.EnableElevators then return end
    
    local quiz = GetQuizByOptionCount(optionCount)
    local TW = Config.TRACK_WIDTH
    local platformLength = 22
    local elevationHeight = 15
    local startY = 1  -- 🔧 판넬 시작 높이 (바닥 위)
    
    -- 검은 구멍 (시각 효과) - 판넬 아래
    local hole = Instance.new("Part")
    hole.Size = Vector3.new(TW, 1, platformLength + 4)
    hole.Position = Vector3.new(0, -0.5, elevZ)
    hole.Anchored = true
    hole.CanCollide = false
    hole.BrickColor = BrickColor.new("Really black")
    hole.Parent = parent
    
    -- 트리거 존
    local trigger = Instance.new("Part")
    trigger.Size = Vector3.new(TW, 10, 5)
    trigger.Position = Vector3.new(0, 5, triggerZ)
    trigger.Anchored = true
    trigger.CanCollide = false
    trigger.Transparency = 1
    trigger.Parent = parent
    
    -- 트리거 바닥 표시 (파란색 선)
    local triggerFloor = Instance.new("Part")
    triggerFloor.Size = Vector3.new(TW, 0.5, 5)
    triggerFloor.Position = Vector3.new(0, 0.25, triggerZ)
    triggerFloor.Anchored = true
    triggerFloor.CanCollide = false
    triggerFloor.BrickColor = BrickColor.new("Cyan")
    triggerFloor.Material = Enum.Material.Neon
    triggerFloor.Transparency = 0.5
    triggerFloor.Parent = parent
    
    local platWidth = TW / optionCount
    local platforms = {}
    
    for i = 1, optionCount do
        local xPos = -TW/2 + platWidth/2 + (i-1) * platWidth
        
        -- 메인 판넬 (두껍게)
        local plat = Instance.new("Part")
        plat.Size = Vector3.new(platWidth - 1, 4, platformLength)
        plat.Position = Vector3.new(xPos, startY, elevZ)
        plat.Anchored = true
        plat.BrickColor = BrickColor.new("Medium stone grey")
        plat.Material = Enum.Material.Concrete
        plat.Parent = parent
        
        -- 색상 표시 상단
        local colorTop = Instance.new("Part")
        colorTop.Size = Vector3.new(platWidth - 1, 0.5, platformLength)
        colorTop.Position = Vector3.new(xPos, startY + 2.25, elevZ)
        colorTop.Anchored = true
        colorTop.Color = gateColors[i]
        colorTop.Material = Enum.Material.Neon
        colorTop.Parent = parent
        
        -- 번호/옵션 표시
        local numPart = Instance.new("Part")
        numPart.Size = Vector3.new(platWidth - 2, 5, 1)
        numPart.Position = Vector3.new(xPos, startY + 5, elevZ - platformLength/2 + 1)
        numPart.Anchored = true
        numPart.CanCollide = false
        numPart.Transparency = 1
        numPart.Parent = parent
        
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        gui.Parent = numPart
        local num = Instance.new("TextLabel")
        num.Size = UDim2.new(1,0,0.5,0)
        num.BackgroundTransparency = 1
        num.Text = "[" .. i .. "]"
        num.TextColor3 = Color3.new(1,1,1)
        num.TextScaled = true
        num.Font = Enum.Font.GothamBold
        num.Parent = gui
        local opt = Instance.new("TextLabel")
        opt.Size = UDim2.new(1,0,0.5,0)
        opt.Position = UDim2.new(0,0,0.5,0)
        opt.BackgroundTransparency = 1
        opt.Text = quiz.o[i]
        opt.TextColor3 = Color3.new(1,1,1)
        opt.TextScaled = true
        opt.Font = Enum.Font.GothamBold
        opt.Parent = gui
        
        platforms[i] = {
            plat = plat, 
            colorTop = colorTop, 
            numPart = numPart, 
            correct = (i == quiz.a), 
            startY = startY,
            targetY = elevationHeight + startY  -- 판넬이 올라갈 높이
        }
        
        -- 플랫폼 터치 시 퀴즈 숨김 + 정답/오답 처리
        local platDb = {}
        plat.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if not player or platDb[player] then return end
            platDb[player] = true
            
            -- 퀴즈 UI 숨기기
            if i == quiz.a then
                Events.ItemEffect:FireClient(player, "GateCorrect", {})
                AwardXP(player, XPRewards.QuizCorrect, "Elevator Correct!")
            else
                Events.ItemEffect:FireClient(player, "GateWrong", {})
            end
            
            task.delay(3, function() platDb[player] = nil end)
        end)
        
        table.insert(ActiveGimmicks, plat)
    end
    
    -- 🔧 2층 바닥 - 판넬 바로 뒤에 연결!
    local upperFloorY = elevationHeight + startY + 1  -- 판넬 도착 높이와 맞춤
    local upperFloor = Instance.new("Part")
    upperFloor.Size = Vector3.new(TW, 3, platformLength + 10)
    upperFloor.Position = Vector3.new(0, upperFloorY, elevZ + platformLength)  -- 판넬 바로 뒤
    upperFloor.Anchored = true
    upperFloor.BrickColor = BrickColor.new("Brick yellow")
    upperFloor.Material = Enum.Material.Cobblestone
    upperFloor.Parent = parent
    
    -- 연결 바닥 (판넬과 2층 사이 틈 방지)
    local bridge = Instance.new("Part")
    bridge.Size = Vector3.new(TW, 1, 5)
    bridge.Position = Vector3.new(0, upperFloorY - 1, elevZ + platformLength/2 + 2)
    bridge.Anchored = true
    bridge.BrickColor = BrickColor.new("Brick yellow")
    bridge.Material = Enum.Material.Cobblestone
    bridge.Parent = parent
    
    -- 아래 지지대 (시각용)
    local underFloor = Instance.new("Part")
    underFloor.Size = Vector3.new(TW + 10, 10, 100)
    underFloor.Position = Vector3.new(0, -10, elevZ + platformLength + 30)
    underFloor.Anchored = true
    underFloor.BrickColor = BrickColor.new("Dark stone grey")
    underFloor.Material = Enum.Material.Brick
    underFloor.Parent = parent
    
    -- 내리막 램프 (2층에서 1층으로)
    local ramp = Instance.new("Part")
    ramp.Size = Vector3.new(TW, 3, 50)
    local rampZ = elevZ + platformLength + platformLength/2 + 30
    ramp.Position = Vector3.new(0, upperFloorY/2, rampZ)
    ramp.Anchored = true
    ramp.BrickColor = BrickColor.new("Brick yellow")
    ramp.Material = Enum.Material.Cobblestone
    ramp.CFrame = CFrame.new(ramp.Position) * CFrame.Angles(math.rad(18), 0, 0)
    ramp.Parent = parent
    
    -- 램프 지지대
    local rampSupport = Instance.new("Part")
    rampSupport.Size = Vector3.new(TW, upperFloorY, 50)
    rampSupport.Position = Vector3.new(0, -3, rampZ)
    rampSupport.Anchored = true
    rampSupport.BrickColor = BrickColor.new("Dark stone grey")
    rampSupport.Material = Enum.Material.Brick
    rampSupport.Parent = parent
    
    local triggered = {}
    trigger.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if not player or triggered[player] then return end
        triggered[player] = true
        
        Events.GateQuiz:FireClient(player, {
            gateId = "elev" .. elevId,
            question = quiz.q,
            options = quiz.o,
            optionCount = optionCount,
            isElevator = true,
            colors = gateColors
        })
        
        -- 🔧 5초 대기 (퀴즈 확인 후 도달할 시간)
        task.delay(5, function()
            for i, p in ipairs(platforms) do
                local riseTime = p.correct and 1.5 or 4
                local targetY = p.targetY
                
                TweenService:Create(p.plat, TweenInfo.new(riseTime, Enum.EasingStyle.Quad), {
                    Position = Vector3.new(p.plat.Position.X, targetY, p.plat.Position.Z)
                }):Play()
                TweenService:Create(p.colorTop, TweenInfo.new(riseTime, Enum.EasingStyle.Quad), {
                    Position = Vector3.new(p.colorTop.Position.X, targetY + 2.25, p.colorTop.Position.Z)
                }):Play()
                TweenService:Create(p.numPart, TweenInfo.new(riseTime, Enum.EasingStyle.Quad), {
                    Position = Vector3.new(p.numPart.Position.X, targetY + 5, p.numPart.Position.Z)
                }):Play()
            end
        end)
        
        task.delay(25, function()
            for _, p in ipairs(platforms) do
                TweenService:Create(p.plat, TweenInfo.new(2), {Position = Vector3.new(p.plat.Position.X, p.startY, p.plat.Position.Z)}):Play()
                TweenService:Create(p.colorTop, TweenInfo.new(2), {Position = Vector3.new(p.colorTop.Position.X, p.startY + 2.25, p.colorTop.Position.Z)}):Play()
                TweenService:Create(p.numPart, TweenInfo.new(2), {Position = Vector3.new(p.numPart.Position.X, p.startY + 5, p.numPart.Position.Z)}):Play()
            end
            triggered[player] = nil
        end)
    end)
    
    table.insert(ActiveGimmicks, trigger)
    table.insert(ActiveGimmicks, upperFloor)
    table.insert(ActiveGimmicks, underFloor)
    table.insert(ActiveGimmicks, ramp)
    table.insert(ActiveGimmicks, rampSupport)
end

local function CreateConveyorBelt(parent, zStart, length, direction)
    if not Config.EnableConveyorBelt then return end
    
    local TW = Config.TRACK_WIDTH
    
    local belt = Instance.new("Part")
    belt.Size = Vector3.new(TW - 4, 1, length)
    belt.Position = Vector3.new(0, 0.5, zStart + length/2)
    belt.Anchored = true
    belt.BrickColor = BrickColor.new("Dark stone grey")
    belt.Material = Enum.Material.DiamondPlate
    belt.Parent = parent
    
    local signPart = Instance.new("Part")
    signPart.Size = Vector3.new(10, 5, 1)
    signPart.Position = Vector3.new(0, 5, zStart - 3)
    signPart.Anchored = true
    signPart.CanCollide = false
    signPart.Transparency = 0.5
    signPart.BrickColor = BrickColor.new("Bright yellow")
    signPart.Parent = parent
    
    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.Parent = signPart
    local signLabel = Instance.new("TextLabel")
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = "⬅️ CONVEYOR"
    signLabel.TextColor3 = Color3.new(0, 0, 0)
    signLabel.TextScaled = true
    signLabel.Font = Enum.Font.GothamBold
    signLabel.Parent = signGui
    
    local playersOnBelt = {}
    belt.Touched:Connect(function(hit)
        local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
        if rp then playersOnBelt[hit.Parent] = true end
    end)
    belt.TouchEnded:Connect(function(hit) playersOnBelt[hit.Parent] = nil end)
    
    task.spawn(function()
        while belt and belt.Parent do
            for char, _ in pairs(playersOnBelt) do
                local rp = char:FindFirstChild("HumanoidRootPart")
                -- 속도 대폭 줄임: 0.05 → 0.02 (점프+달리기로 통과 가능)
                if rp then rp.CFrame = rp.CFrame + Vector3.new(0, 0, direction * 0.02) end
            end
            task.wait()
        end
    end)
    
    table.insert(ActiveGimmicks, belt)
    table.insert(ActiveGimmicks, signPart)
end

local function CreateElectricFloor(parent, zStart, length)
    if not Config.EnableElectricFloor then return end
    
    local TW = Config.TRACK_WIDTH
    
    local floor = Instance.new("Part")
    floor.Name = "ElectricFloor"
    floor.Size = Vector3.new(TW - 4, 0.5, length + 20)
    floor.Position = Vector3.new(0, 0.25, zStart + length/2)
    floor.Anchored = true
    floor.BrickColor = BrickColor.new("Medium stone grey")
    floor.Material = Enum.Material.Metal
    floor.Parent = parent
    
    for i = 1, math.floor(length / 12) do
        local boltPart = Instance.new("Part")
        boltPart.Size = Vector3.new(5, 0.1, 5)
        boltPart.Position = Vector3.new(math.random(-12, 12), 0.35, zStart + i * 12)
        boltPart.Anchored = true
        boltPart.CanCollide = false
        boltPart.Transparency = 1
        boltPart.Parent = parent
        
        local boltGui = Instance.new("SurfaceGui")
        boltGui.Face = Enum.NormalId.Top
        boltGui.Parent = boltPart
        
        local boltLabel = Instance.new("TextLabel")
        boltLabel.Size = UDim2.new(1, 0, 1, 0)
        boltLabel.BackgroundTransparency = 1
        boltLabel.Text = "⚡"
        boltLabel.TextScaled = true
        boltLabel.Parent = boltGui
        
        table.insert(ActiveGimmicks, boltPart)
    end
    
    local warnSign = Instance.new("Part")
    warnSign.Size = Vector3.new(12, 6, 1)
    warnSign.Position = Vector3.new(0, 5, zStart - 5)
    warnSign.Anchored = true
    warnSign.CanCollide = false
    warnSign.BrickColor = BrickColor.new("Bright yellow")
    warnSign.Parent = parent
    
    local warnGui = Instance.new("SurfaceGui")
    warnGui.Face = Enum.NormalId.Front
    warnGui.Parent = warnSign
    local warnLabel = Instance.new("TextLabel")
    warnLabel.Size = UDim2.new(1, 0, 1, 0)
    warnLabel.BackgroundTransparency = 1
    warnLabel.Text = "⚡ DANGER ⚡"
    warnLabel.TextColor3 = Color3.new(0, 0, 0)
    warnLabel.TextScaled = true
    warnLabel.Font = Enum.Font.GothamBold
    warnLabel.Parent = warnGui
    
    local playersOnFloor = {}
    
    floor.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then playersOnFloor[player] = true end
    end)
    floor.TouchEnded:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then playersOnFloor[player] = nil end
    end)
    
    task.spawn(function()
        while floor and floor.Parent do
            floor.BrickColor = BrickColor.new("Bright yellow")
            floor.Material = Enum.Material.Metal
            task.wait(1.5)
            floor.BrickColor = BrickColor.new("Cyan")
            floor.Material = Enum.Material.Neon
            for player, _ in pairs(playersOnFloor) do
                Events.ItemEffect:FireClient(player, "Electrocuted", {duration = 0.8})
            end
            task.wait(0.6)
            floor.BrickColor = BrickColor.new("Medium stone grey")
            floor.Material = Enum.Material.Metal
            task.wait(2)
        end
    end)
    
    table.insert(ActiveGimmicks, floor)
    table.insert(ActiveGimmicks, warnSign)
end

local function CreateRollingBoulder(parent, zStart, zEnd)
    if not Config.EnableRollingBoulder then return end
    
    local warnSign = Instance.new("Part")
    warnSign.Size = Vector3.new(12, 8, 1)
    warnSign.Position = Vector3.new(0, 6, zStart - 15)
    warnSign.Anchored = true
    warnSign.CanCollide = false
    warnSign.BrickColor = BrickColor.new("Bright red")
    warnSign.Parent = parent
    
    local warnGui = Instance.new("SurfaceGui")
    warnGui.Face = Enum.NormalId.Front
    warnGui.Parent = warnSign
    local warnLabel = Instance.new("TextLabel")
    warnLabel.Size = UDim2.new(1,0,1,0)
    warnLabel.BackgroundTransparency = 1
    warnLabel.Text = "⚠️ BOULDER! ⚠️\n🪨 DODGE! 🪨"
    warnLabel.TextColor3 = Color3.new(1,1,1)
    warnLabel.TextScaled = true
    warnLabel.Font = Enum.Font.GothamBold
    warnLabel.Parent = warnGui
    
    task.spawn(function()
        while parent and parent.Parent do
            task.wait(7 / Config.ObstacleSpeed)
            
            local boulder = Instance.new("Part")
            boulder.Size = Vector3.new(10, 10, 10)
            boulder.Position = Vector3.new(0, 6, zEnd + 5)
            boulder.Anchored = false
            boulder.Shape = Enum.PartType.Ball
            boulder.BrickColor = BrickColor.new("Dark stone grey")
            boulder.Material = Enum.Material.Slate
            boulder.Parent = parent
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
            bv.Velocity = Vector3.new(0, 0, -45 * Config.ObstacleSpeed)
            bv.Parent = boulder
            
            local db = {}
            boulder.Touched:Connect(function(hit)
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if player and not db[player] then
                    db[player] = true
                    Events.ItemEffect:FireClient(player, "BoulderHit", {direction = Vector3.new(0, 35, -55)})
                    task.delay(1, function() db[player] = nil end)
                end
            end)
            
            task.delay(12, function() if boulder and boulder.Parent then boulder:Destroy() end end)
        end
    end)
    
    table.insert(ActiveGimmicks, warnSign)
end

local function CreateDisappearingBridge(parent, zStart, platformCount)
    if not Config.EnableDisappearingBridge then return end
    
    local platformWidth = 10
    local gap = 6
    local TW = Config.TRACK_WIDTH
    
    local lava = Instance.new("Part")
    lava.Size = Vector3.new(TW, 1, platformCount * (platformWidth + gap) + 20)
    lava.Position = Vector3.new(0, -15, zStart + platformCount * (platformWidth + gap) / 2)
    lava.Anchored = true
    lava.CanCollide = false
    lava.BrickColor = BrickColor.new("Bright orange")
    lava.Material = Enum.Material.Neon
    lava.Parent = parent
    
    local lavaTop = Instance.new("Part")
    lavaTop.Size = Vector3.new(TW - 2, 0.5, platformCount * (platformWidth + gap) + 18)
    lavaTop.Position = Vector3.new(0, -14.5, zStart + platformCount * (platformWidth + gap) / 2)
    lavaTop.Anchored = true
    lavaTop.CanCollide = false
    lavaTop.BrickColor = BrickColor.new("Bright red")
    lavaTop.Material = Enum.Material.Neon
    lavaTop.Transparency = 0.3
    lavaTop.Parent = parent
    
    lava.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then Events.ItemEffect:FireClient(player, "LavaFall", {}) end
    end)
    
    local warnSign = Instance.new("Part")
    warnSign.Size = Vector3.new(14, 7, 1)
    warnSign.Position = Vector3.new(0, 6, zStart - 8)
    warnSign.Anchored = true
    warnSign.CanCollide = false
    warnSign.BrickColor = BrickColor.new("Bright orange")
    warnSign.Parent = parent
    
    local warnGui = Instance.new("SurfaceGui")
    warnGui.Face = Enum.NormalId.Front
    warnGui.Parent = warnSign
    local warnLabel = Instance.new("TextLabel")
    warnLabel.Size = UDim2.new(1, 0, 1, 0)
    warnLabel.BackgroundTransparency = 1
    warnLabel.Text = "⏰ DISAPPEARING!\n🔥 DON'T STOP! 🔥"
    warnLabel.TextColor3 = Color3.new(1, 1, 1)
    warnLabel.TextScaled = true
    warnLabel.Font = Enum.Font.GothamBold
    warnLabel.Parent = warnGui
    
    for i = 1, platformCount do
        local z = zStart + (i - 1) * (platformWidth + gap)
        local xOffset = (i % 2 == 0) and -8 or 8
        
        local platform = Instance.new("Part")
        platform.Name = "DisappearingPlatform"
        platform.Size = Vector3.new(14, 2, platformWidth)
        platform.Position = Vector3.new(xOffset, 1, z)
        platform.Anchored = true
        platform.BrickColor = BrickColor.new("Bright orange")
        platform.Material = Enum.Material.Wood
        platform.Parent = parent
        
        local clockGui = Instance.new("SurfaceGui")
        clockGui.Face = Enum.NormalId.Top
        clockGui.Parent = platform
        
        local clockLabel = Instance.new("TextLabel")
        clockLabel.Size = UDim2.new(1, 0, 1, 0)
        clockLabel.BackgroundTransparency = 1
        clockLabel.Text = "⏰"
        clockLabel.TextScaled = true
        clockLabel.Parent = clockGui
        
        local db = {}
        platform.Touched:Connect(function(hit)
            local hum = hit.Parent:FindFirstChild("Humanoid")
            if hum and not db[platform] then
                db[platform] = true
                TweenService:Create(platform, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 0, 0)}):Play()
                clockLabel.Text = "⏰❗"
                
                task.delay(1.2, function()
                    platform.CanCollide = false
                    TweenService:Create(platform, TweenInfo.new(0.3), {
                        Transparency = 1,
                        Position = platform.Position + Vector3.new(0, -2, 0)
                    }):Play()
                    
                    task.delay(3, function()
                        platform.Position = Vector3.new(xOffset, 1, z)
                        platform.CanCollide = true
                        platform.BrickColor = BrickColor.new("Bright orange")
                        clockLabel.Text = "⏰"
                        TweenService:Create(platform, TweenInfo.new(0.3), {Transparency = 0}):Play()
                        db[platform] = nil
                    end)
                end)
            end
        end)
        
        table.insert(ActiveGimmicks, platform)
    end
    
    table.insert(ActiveGimmicks, lava)
    table.insert(ActiveGimmicks, lavaTop)
    table.insert(ActiveGimmicks, warnSign)
end

-- ============================================
-- 🏗️ BUILD FULL COURSE
-- ============================================
local function BuildCourse(parent)
    print("  Building Course Obstacles...")
    
    local TL = Config.TRACK_LENGTH
    
    CreateRotatingBar(parent, 60, 28, 3, 1.5)
    CreateRotatingBar(parent, 100, 30, 3, 1.8)
    CreateQuizGate(parent, 1, 150, 180, 2)
    CreateRotatingBar(parent, 250, 26, 3, 2)
    CreateQuizGate(parent, 2, 320, 350, 3)
    
    CreateJumpPad(parent, Vector3.new(0, 0.5, 430))
    CreateJumpPad(parent, Vector3.new(0, 0.5, 500))
    CreateJumpPad(parent, Vector3.new(0, 0.5, 570))
    
    CreateElevator(parent, 1, 620, 670, 3)
    CreateDisappearingBridge(parent, 750, 6)
    
    CreateSlimeZone(parent, 830, 80)
    CreateQuizGate(parent, 3, 960, 990, 4)
    CreateConveyorBelt(parent, 1040, 60, -1)
    CreateElectricFloor(parent, 1130, 60)
    
    CreateRollingBoulder(parent, 1220, 1380)
    CreatePunchingCorridor(parent, 1280, 100)
    CreateQuizGate(parent, 4, 1420, 1450, 3)
    CreateElevator(parent, 2, 1500, 1550, 4)
    
    CreateSlimeZone(parent, 1620, 70)
    CreateRotatingBar(parent, 1730, 34, 3, 2.5)
    CreateRotatingBar(parent, 1760, 34, 7, -2)
    CreateQuizGate(parent, 5, 1800, 1830, 2)
    
    CreateConveyorBelt(parent, 1860, 40, -1)
    CreateElectricFloor(parent, 1920, 50)
    CreateRotatingBar(parent, 1970, 36, 3, 3)
    
    print("  ✅ Course Obstacles Complete!")
end

-- ============================================
-- 📦 ITEM SYSTEM
-- ============================================
local itemList = {"Banana", "Booster", "Shield", "Lightning"}

local function CreateItemBoxes(parent)
    local TL = Config.TRACK_LENGTH

    for z = 100, TL - 150, 200 do
        local x = math.random(-12, 12)
        local box = Instance.new("Part")
        box.Name = "ItemBox"
        box.Size = Vector3.new(5, 5, 5)
        box.Position = Vector3.new(x, 4, z)
        box.Anchored = true
        box.CanCollide = false
        box.BrickColor = BrickColor.new("Bright yellow")
        box.Material = Enum.Material.Neon
        box.Transparency = 0.2
        box.Parent = parent

        -- 🔄 PERFORMANCE: 개별 루프 대신 중앙 관리 테이블에 등록
        table.insert(ItemBoxes, {
            part = box,
            rotation = math.random(0, 360)
        })

        local db, active = {}, true
        box.Touched:Connect(function(hit)
            if not active then return end
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if not player or not PlayerData[player] or db[player] or PlayerData[player].currentItem then return end
            db[player] = true
            active = false
            box.Transparency = 0.85
            local itemType = itemList[math.random(#itemList)]
            PlayerData[player].currentItem = itemType
            Events.ItemEffect:FireClient(player, "GotItem", {itemType = itemType})
            task.delay(10, function() active = true; box.Transparency = 0.2; db[player] = nil end)
        end)
    end
end

Events.UseItem.OnServerEvent:Connect(function(player, itemType)
    local data = PlayerData[player]
    if not data or not data.currentItem then return end
    local char = player.Character
    local rp = char and char:FindFirstChild("HumanoidRootPart")
    if not rp then return end
    
    local usedItem = data.currentItem
    data.currentItem = nil  -- 아이템 먼저 소모
    
    -- 클라이언트에 아이템 사용됨 알림
    Events.ItemEffect:FireClient(player, "ItemUsed", {itemType = usedItem})
    
    if usedItem == "Banana" then
        local banana = Instance.new("Part")
        banana.Size = Vector3.new(2.5, 1.2, 2.5)
        banana.Position = rp.Position - rp.CFrame.LookVector * 6
        banana.Position = Vector3.new(banana.Position.X, 0.6, banana.Position.Z)
        banana.Anchored = true
        banana.BrickColor = BrickColor.new("Bright yellow")
        banana.Parent = workspace
        Debris:AddItem(banana, 35)
        local bd = {}
        banana.Touched:Connect(function(hit)
            local hp = Players:GetPlayerFromCharacter(hit.Parent)
            if hp and hp ~= player and not bd[hp] then
                bd[hp] = true
                Events.ItemEffect:FireClient(hp, "Stun", {duration = 1.5})
                banana:Destroy()
            end
        end)
    elseif usedItem == "Booster" then
        Events.ItemEffect:FireClient(player, "SpeedBoost", {duration = 4.5})
    elseif usedItem == "Shield" then
        local shield = Instance.new("Part")
        shield.Size = Vector3.new(6,6,6)
        shield.CFrame = rp.CFrame
        shield.Anchored = false
        shield.CanCollide = false
        shield.Shape = Enum.PartType.Ball
        shield.Material = Enum.Material.ForceField
        shield.Transparency = 0.7
        shield.Parent = char
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1 = rp, shield
        weld.Parent = shield
        Debris:AddItem(shield, 14)
        Events.ItemEffect:FireClient(player, "Shielded", {duration = 14})
    elseif usedItem == "Lightning" then
        for _, op in ipairs(Players:GetPlayers()) do
            if op ~= player and table.find(GameState.playersInRace, op) then
                Events.ItemEffect:FireClient(op, "LightningHit", {duration = 1.8})
            end
        end
    end
end)

-- ============================================
-- 🎮 GAME FLOW
-- ============================================
local CastleFolder = nil
local LobbyFolder = nil
local TrackFolder = nil

local function ClearActiveGimmicks()
    for _, gimmick in ipairs(ActiveGimmicks) do
        if gimmick and gimmick.Parent then
            gimmick:Destroy()
        end
    end
    ActiveGimmicks = {}
    RotatingObjects = {}
    ItemBoxes = {}
end

local function InitializeMap()
    print("🏰 Building Quiz Castle v3.2...")

    -- 기존 기믹들 정리
    ClearActiveGimmicks()

    local existing = workspace:FindFirstChild("QuizCastle")
    if existing then existing:Destroy() end
    
    CastleFolder = Instance.new("Folder")
    CastleFolder.Name = "QuizCastle"
    CastleFolder.Parent = workspace
    
    CreateCastleExterior(CastleFolder)
    LobbyFolder = CreateLobby(CastleFolder)
    TrackFolder = CreateRaceTrack(CastleFolder)
    BuildCourse(TrackFolder)
    CreateItemBoxes(TrackFolder)
    
    print("🏰 Quiz Castle v3.2 Ready!")
end

local function TeleportToLobby(player)
    local char = player.Character
    if char and LobbySpawn then
        local rp = char:FindFirstChild("HumanoidRootPart")
        if rp then
            rp.CFrame = LobbySpawn.CFrame + Vector3.new(math.random(-8, 8), 3, math.random(-8, 8))
        end
    end
end

local function TeleportToRace(player)
    local char = player.Character
    if char and RaceSpawn then
        local rp = char:FindFirstChild("HumanoidRootPart")
        if rp then
            rp.CFrame = RaceSpawn.CFrame + Vector3.new(math.random(-15, 15), 3, 0)
        end
    end
end

local function UpdateLobbyUI()
    local lobbyPlayers = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if PlayerData[player] and not table.find(GameState.playersInRace, player) then
            lobbyPlayers = lobbyPlayers + 1
        end
    end
    
    Events.LobbyUpdate:FireAllClients({
        playersInLobby = lobbyPlayers,
        minPlayers = Config.MIN_PLAYERS,
        phase = GameState.phase,
        countdown = GameState.countdown
    })
end

local function OpenStartGate()
    if StartGate then
        StartGate.CanCollide = false
        StartGate.Transparency = 0.9
        local gui = StartGate:FindFirstChildOfClass("SurfaceGui")
        if gui then
            local label = gui:FindFirstChild("GateLabel")
            if label then label.Text = "🏃 GO!" end
        end
    end
end

local function CloseStartGate()
    if StartGate then
        StartGate.CanCollide = true
        StartGate.Transparency = 0.3
        local gui = StartGate:FindFirstChildOfClass("SurfaceGui")
        if gui then
            local label = gui:FindFirstChild("GateLabel")
            if label then label.Text = "⏳ WAITING..." end
        end
    end
end

function StartCountdown()
    GameState.phase = "Countdown"
    GameState.countdown = Config.LOBBY_COUNTDOWN
    
    CloseStartGate()
    
    GameState.playersInRace = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if PlayerData[player] then
            table.insert(GameState.playersInRace, player)
            TeleportToRace(player)
        end
    end
    
    for i = Config.LOBBY_COUNTDOWN, 1, -1 do
        GameState.countdown = i
        
        if StartGate then
            local gui = StartGate:FindFirstChildOfClass("SurfaceGui")
            if gui then
                local label = gui:FindFirstChild("GateLabel")
                if label then label.Text = "⏰ " .. i end
            end
        end
        
        Events.RoundUpdate:FireAllClients("Countdown", {count = i})
        task.wait(1)
        
        local stillReady = 0
        for _, p in ipairs(GameState.playersInRace) do
            if p and p.Parent then stillReady = stillReady + 1 end
        end
        
        if stillReady < Config.MIN_PLAYERS then
            GameState.phase = "Waiting"
            CloseStartGate()
            Events.RoundUpdate:FireAllClients("CountdownCancelled", {})
            return
        end
    end
    
    StartRace()
end

function StartRace()
    GameState.phase = "Racing"
    GameState.roundNumber = GameState.roundNumber + 1
    GameState.finishedPlayers = {}
    GameState.raceStartTime = tick()
    
    OpenStartGate()
    
    Events.RoundUpdate:FireAllClients("RaceStart", {
        roundNumber = GameState.roundNumber,
        totalPlayers = #GameState.playersInRace
    })
    
    task.spawn(function()
        while GameState.phase == "Racing" do
            local elapsed = tick() - GameState.raceStartTime
            for _, player in ipairs(GameState.playersInRace) do
                if player and player.Parent and not table.find(GameState.finishedPlayers, player) then
                    Events.TimeUpdate:FireClient(player, elapsed)
                end
            end
            task.wait(0.1)
        end
    end)
    
    task.delay(300, function()
        if GameState.phase == "Racing" then
            EndRound()
        end
    end)
end

function EndRound()
    GameState.phase = "Ended"
    
    CloseStartGate()
    
    local results = {}
    for rank, player in ipairs(GameState.finishedPlayers) do
        table.insert(results, {
            rank = rank,
            name = player.Name,
            time = PlayerData[player] and PlayerData[player].lastRaceTime or 0
        })
    end
    
    Events.RoundUpdate:FireAllClients("RoundEnd", {
        results = results,
        totalPlayers = #GameState.playersInRace
    })
    
    local lb = GetLeaderboard()
    for _, player in ipairs(Players:GetPlayers()) do
        Events.LeaderboardUpdate:FireClient(player, lb)
    end
    
    task.delay(Config.INTERMISSION, function()
        for _, player in ipairs(Players:GetPlayers()) do
            TeleportToLobby(player)
            PlayerGateAnswers[player] = {}
        end
        
        GameState.phase = "Waiting"
        GameState.playersInRace = {}
        GameState.finishedPlayers = {}
        
        Events.RoundUpdate:FireAllClients("Intermission", {duration = 0})
    end)
end

-- ============================================
-- 🎮 PLAYER MANAGEMENT
-- ============================================
local function IsAdmin(player)
    return Admins[player.UserId] or player.UserId == game.CreatorId
end

local function InitPlayer(player)
    local stats = GetPlayerStats(player)
    local xp = stats.xp
    local level = GetLevelFromXP(xp)
    local progress, xpInLevel, xpNeeded = GetLevelProgress(xp, level)
    
    PlayerData[player] = {
        bestTime = stats.bestTime,
        wins = stats.wins,
        xp = xp,
        level = level,
        currentItem = nil,
        lastRaceTime = nil
    }
    PlayerGateAnswers[player] = {}
    PlayerStreaks[player] = 0
    
    Events.GameEvent:FireClient(player, "InitPlayer", {
        bestTime = stats.bestTime,
        wins = stats.wins,
        xp = xp,
        level = level,
        levelName = LevelConfig[level].name,
        levelIcon = LevelConfig[level].icon,
        trailType = LevelConfig[level].trailType,
        progress = progress,
        xpInLevel = xpInLevel,
        xpNeeded = xpNeeded,
        isAdmin = IsAdmin(player),
        config = Config,
        levelConfig = LevelConfig
    })
    
    Events.TrailUpdate:FireAllClients({
        playerName = player.Name,
        trailType = LevelConfig[level].trailType,
        level = level
    })
    
    task.delay(1, function()
        Events.LeaderboardUpdate:FireClient(player, GetLeaderboard())
        UpdateLobbyUI()
    end)
end

Players.PlayerAdded:Connect(function(player)
    InitPlayer(player)
    
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        
        if GameState.phase == "Waiting" or GameState.phase == "Ended" then
            TeleportToLobby(player)
        end
        
        PlayerGateAnswers[player] = {}
        if PlayerData[player] then
            PlayerData[player].currentItem = nil
            PlayerData[player].lastSafePosition = nil
            PlayerData[player].isInvincible = false
            
            local level = PlayerData[player].level or 1
            Events.TrailUpdate:FireAllClients({
                playerName = player.Name,
                trailType = LevelConfig[level].trailType,
                level = level
            })
        end
        
        UpdateLobbyUI()
        
        -- ============================================
        -- 🔄 RESPAWN SYSTEM - Out of Bounds Detection
        -- ============================================
        local humanoidRootPart = char:WaitForChild("HumanoidRootPart", 5)
        local humanoid = char:WaitForChild("Humanoid", 5)
        if not humanoidRootPart or not humanoid then return end
        
        -- Safe position tracking loop (every 0.5 seconds)
        task.spawn(function()
            while char and char.Parent and humanoid and humanoid.Health > 0 do
                task.wait(0.5)
                
                if GameState.phase == "Racing" and PlayerData[player] then
                    local pos = humanoidRootPart.Position
                    -- Check if within track bounds (X: -50 to TRACK_WIDTH+50, Z: -100 to TRACK_LENGTH+100, Y > -20)
                    if pos.X >= -50 and pos.X <= Config.TRACK_WIDTH + 50 and
                       pos.Z >= -100 and pos.Z <= Config.TRACK_LENGTH + 100 and
                       pos.Y > -20 then
                        PlayerData[player].lastSafePosition = pos
                    end
                end
            end
        end)
        
        -- Out of bounds detection loop (every 0.2 seconds)
        task.spawn(function()
            while char and char.Parent and humanoid and humanoid.Health > 0 do
                task.wait(0.2)
                
                if GameState.phase == "Racing" and PlayerData[player] and not PlayerData[player].isInvincible then
                    local pos = humanoidRootPart.Position
                    local isOutOfBounds = false
                    
                    -- Check if out of bounds
                    if pos.Y < -30 then -- Fell too far
                        isOutOfBounds = true
                    elseif pos.X < -80 or pos.X > Config.TRACK_WIDTH + 80 then -- Too far left/right
                        isOutOfBounds = true
                    elseif pos.Z < -150 or pos.Z > Config.TRACK_LENGTH + 150 then -- Too far back/forward
                        isOutOfBounds = true
                    end
                    
                    if isOutOfBounds then
                        PlayerData[player].isInvincible = true
                        
                        -- Send respawning notification
                        Events.ItemEffect:FireClient(player, "Respawning", {})
                        
                        -- Wait 3 seconds then teleport
                        task.wait(3)
                        
                        if char and char.Parent and humanoidRootPart then
                            local safePos = PlayerData[player].lastSafePosition
                            if not safePos then
                                -- Default to start line
                                safePos = Vector3.new(Config.TRACK_WIDTH / 2, 10, 10)
                            end
                            
                            humanoidRootPart.CFrame = CFrame.new(safePos + Vector3.new(0, 5, 0))
                            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                            
                            -- Send invincible notification
                            Events.ItemEffect:FireClient(player, "Invincible", {})
                            
                            -- Add visual invincibility (ForceField + transparency)
                            local forceField = Instance.new("ForceField")
                            forceField.Name = "RespawnShield"
                            forceField.Visible = true
                            forceField.Parent = char
                            
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Transparency = math.min(part.Transparency + 0.5, 0.8)
                                end
                            end
                            
                            -- Remove invincibility after 2 seconds
                            task.delay(2, function()
                                if char and char.Parent then
                                    local shield = char:FindFirstChild("RespawnShield")
                                    if shield then shield:Destroy() end
                                    
                                    for _, part in ipairs(char:GetDescendants()) do
                                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                            part.Transparency = math.max(part.Transparency - 0.5, 0)
                                        end
                                    end
                                end
                                
                                if PlayerData[player] then
                                    PlayerData[player].isInvincible = false
                                end
                            end)
                        else
                            if PlayerData[player] then
                                PlayerData[player].isInvincible = false
                            end
                        end
                    end
                end
            end
        end)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if PlayerData[player] then
        SavePlayerXP(player, PlayerData[player].xp or 0)
    end
    
    PlayerData[player] = nil
    PlayerGateAnswers[player] = nil
    PlayerStreaks[player] = nil
    
    local idx = table.find(GameState.playersInRace, player)
    if idx then table.remove(GameState.playersInRace, idx) end
    
    UpdateLobbyUI()
end)

for _, player in ipairs(Players:GetPlayers()) do
    InitPlayer(player)
end

-- ============================================
-- 🔄 GAME LOOP
-- ============================================
task.spawn(function()
    while true do
        task.wait(1)
        
        if GameState.phase == "Waiting" then
            local readyPlayers = 0
            for _, player in ipairs(Players:GetPlayers()) do
                if PlayerData[player] then
                    readyPlayers = readyPlayers + 1
                end
            end
            
            UpdateLobbyUI()
            
            if readyPlayers >= Config.MIN_PLAYERS then
                StartCountdown()
            end
        end
    end
end)

-- ============================================
-- 🔄 PERFORMANCE: 중앙 집중식 회전 업데이트 루프
-- ============================================
RunService.Heartbeat:Connect(function(dt)
    -- 회전 오브젝트 업데이트 (회전바 등)
    for i = #RotatingObjects, 1, -1 do
        local obj = RotatingObjects[i]
        if obj.part and obj.part.Parent then
            obj.rotation = obj.rotation + obj.speed
            if obj.rotationType == "Y" then
                obj.part.CFrame = CFrame.new(obj.part.Position) * CFrame.Angles(0, math.rad(obj.rotation), 0)
            end
        else
            -- 파트가 삭제되면 테이블에서 제거
            table.remove(RotatingObjects, i)
        end
    end

    -- 아이템 박스 업데이트
    for i = #ItemBoxes, 1, -1 do
        local obj = ItemBoxes[i]
        if obj.part and obj.part.Parent then
            obj.rotation = obj.rotation + 2
            obj.part.CFrame = CFrame.new(obj.part.Position) * CFrame.Angles(0, math.rad(obj.rotation), math.rad(obj.rotation * 0.5))
        else
            -- 파트가 삭제되면 테이블에서 제거
            table.remove(ItemBoxes, i)
        end
    end
end)

-- ============================================
-- 🚀 INITIALIZE
-- ============================================
InitializeMap()

print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🏰 QUIZ CASTLE v3.2 Server Ready!")
print("⭐ XP & Level System Active!")
print("🎮 Min Players: " .. Config.MIN_PLAYERS)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
