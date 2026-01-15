--[[
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🏰 QUIZ CASTLE v3.2 - CLIENT SCRIPT                         ║
║                                                                                ║
║  📁 StarterPlayer → StarterPlayerScripts에 "LocalScript"로 넣으세요!            ║
║  ⚠️ Workspace나 다른 곳에 넣지 마세요!                                          ║
║                                                                                ║
║  🆕 v3.2 FEATURES:                                                             ║
║     - XP & 레벨 시스템 (10단계)                                                 ║
║     - 트레일 이펙트 시스템                                                       ║
║     - UI 투명화 (반투명 배경)                                                    ║
║     - 리스폰 시스템 UI                                                          ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- 서비스 확인
if not ReplicatedStorage then
    warn("⚠️ ReplicatedStorage not available!")
    return
end

local player = Players.LocalPlayer
if not player then
    warn("⚠️ LocalPlayer not found!")
    return
end

local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then
    warn("⚠️ PlayerGui not found!")
    return
end

-- Wait for RemoteEvents (서버가 먼저 생성해야 함)
print("🎮 Quiz Castle Client: Waiting for server...")
local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
if not remoteFolder then
    warn("⚠️ RemoteEvents not found! Make sure server script is running.")
    return
end

local Events = {
    GameEvent = remoteFolder:WaitForChild("GameEvent"),
    TimeUpdate = remoteFolder:WaitForChild("TimeUpdate"),
    LeaderboardUpdate = remoteFolder:WaitForChild("LeaderboardUpdate"),
    GateQuiz = remoteFolder:WaitForChild("GateQuiz"),
    UseItem = remoteFolder:WaitForChild("UseItem"),
    ItemEffect = remoteFolder:WaitForChild("ItemEffect"),
    RoundUpdate = remoteFolder:WaitForChild("RoundUpdate"),
    LobbyUpdate = remoteFolder:WaitForChild("LobbyUpdate"),
    XPUpdate = remoteFolder:WaitForChild("XPUpdate"),
    LevelUp = remoteFolder:WaitForChild("LevelUp"),
    TrailUpdate = remoteFolder:WaitForChild("TrailUpdate"),
    AdminCommand = remoteFolder:WaitForChild("AdminCommand"),
    ConfigUpdate = remoteFolder:WaitForChild("ConfigUpdate"),
}

print("🎮 Quiz Castle v3.2 Client Loading...")

-- ============================================
-- 🎨 CONFIGURATION
-- ============================================
local LevelConfig = {
    [1]  = {name = "Rookie",      icon = "⬜", trailType = "None",      color = Color3.fromRGB(200, 200, 200)},
    [2]  = {name = "Runner",      icon = "💨", trailType = "Dust",      color = Color3.fromRGB(139, 119, 101)},
    [3]  = {name = "Star Walker", icon = "⭐", trailType = "Stars",     color = Color3.fromRGB(255, 215, 0)},
    [4]  = {name = "Sparkle",     icon = "✨", trailType = "Sparkle",   color = Color3.fromRGB(255, 255, 150)},
    [5]  = {name = "Blazer",      icon = "🔥", trailType = "Fire",      color = Color3.fromRGB(255, 100, 0)},
    [6]  = {name = "Frost",       icon = "❄️", trailType = "Ice",       color = Color3.fromRGB(100, 200, 255)},
    [7]  = {name = "Thunder",     icon = "⚡", trailType = "Lightning", color = Color3.fromRGB(255, 255, 0)},
    [8]  = {name = "Rainbow",     icon = "🌈", trailType = "Rainbow",   color = Color3.fromRGB(255, 100, 200)},
    [9]  = {name = "Royal",       icon = "👑", trailType = "Royal",     color = Color3.fromRGB(180, 100, 255)},
    [10] = {name = "Legend",      icon = "🐉", trailType = "Legend",    color = Color3.fromRGB(255, 50, 50)},
}

local TrailColors = {
    None = {},
    Dust = {Color3.fromRGB(139, 119, 101), Color3.fromRGB(160, 140, 120)},
    Stars = {Color3.fromRGB(255, 215, 0), Color3.fromRGB(255, 255, 100)},
    Sparkle = {Color3.fromRGB(255, 255, 200), Color3.fromRGB(255, 255, 255)},
    Fire = {Color3.fromRGB(255, 100, 0), Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 50, 0)},
    Ice = {Color3.fromRGB(100, 200, 255), Color3.fromRGB(200, 230, 255), Color3.fromRGB(150, 220, 255)},
    Lightning = {Color3.fromRGB(255, 255, 0), Color3.fromRGB(200, 200, 255), Color3.fromRGB(255, 255, 150)},
    Rainbow = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,165,0), Color3.fromRGB(255,255,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,0,255), Color3.fromRGB(128,0,128)},
    Royal = {Color3.fromRGB(180, 100, 255), Color3.fromRGB(220, 180, 255), Color3.fromRGB(255, 215, 0)},
    Legend = {Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 215, 0), Color3.fromRGB(255, 100, 0), Color3.fromRGB(255, 255, 255)},
}

-- ============================================
-- 📊 PLAYER STATE
-- ============================================
local PlayerState = {
    level = 1,
    xp = 0,
    trailType = "None",
    currentItem = nil,
    isRacing = false,
    progress = 0,
}

-- ============================================
-- 🖼️ UI CREATION (모든 배경 투명)
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuizCastleUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Level Frame (Top Left) - 완전 투명
local levelFrame = Instance.new("Frame")
levelFrame.Name = "LevelFrame"
levelFrame.Size = UDim2.new(0, 220, 0, 70)
levelFrame.Position = UDim2.new(0, 15, 0, 15)
levelFrame.BackgroundTransparency = 1
levelFrame.BorderSizePixel = 0
levelFrame.Parent = screenGui

local levelIcon = Instance.new("TextLabel")
levelIcon.Name = "Icon"
levelIcon.Size = UDim2.new(0, 50, 0, 50)
levelIcon.Position = UDim2.new(0, 10, 0.5, -25)
levelIcon.BackgroundTransparency = 1
levelIcon.Text = "⬜"
levelIcon.TextSize = 40
levelIcon.Font = Enum.Font.GothamBold
levelIcon.TextColor3 = Color3.new(1, 1, 1)
levelIcon.TextStrokeTransparency = 0  -- 외곽선 강하게
levelIcon.TextStrokeColor3 = Color3.new(0, 0, 0)
levelIcon.Parent = levelFrame

local levelName = Instance.new("TextLabel")
levelName.Name = "LevelName"
levelName.Size = UDim2.new(0, 140, 0, 25)
levelName.Position = UDim2.new(0, 65, 0, 8)
levelName.BackgroundTransparency = 1
levelName.Text = "Lv.1 Rookie"
levelName.TextSize = 18
levelName.Font = Enum.Font.GothamBold
levelName.TextColor3 = Color3.new(1, 1, 1)
levelName.TextStrokeTransparency = 0  -- 외곽선 강하게
levelName.TextStrokeColor3 = Color3.new(0, 0, 0)
levelName.TextXAlignment = Enum.TextXAlignment.Left
levelName.Parent = levelFrame

local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "XPBarBg"
xpBarBg.Size = UDim2.new(0, 140, 0, 12)
xpBarBg.Position = UDim2.new(0, 65, 0, 38)
xpBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
xpBarBg.BackgroundTransparency = 0.5  -- 더 투명하게
xpBarBg.BorderSizePixel = 0
xpBarBg.Parent = levelFrame

local xpBarCorner = Instance.new("UICorner")
xpBarCorner.CornerRadius = UDim.new(0, 6)
xpBarCorner.Parent = xpBarBg

local xpBar = Instance.new("Frame")
xpBar.Name = "XPBar"
xpBar.Size = UDim2.new(0, 0, 1, 0)
xpBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
xpBar.BorderSizePixel = 0
xpBar.Parent = xpBarBg

local xpBarInnerCorner = Instance.new("UICorner")
xpBarInnerCorner.CornerRadius = UDim.new(0, 6)
xpBarInnerCorner.Parent = xpBar

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(0, 140, 0, 15)
xpText.Position = UDim2.new(0, 65, 0, 52)
xpText.BackgroundTransparency = 1
xpText.Text = "0 / 100 XP"
xpText.TextSize = 12
xpText.Font = Enum.Font.GothamBold
xpText.TextColor3 = Color3.fromRGB(200, 200, 200)
xpText.TextStrokeTransparency = 0  -- 외곽선 강하게
xpText.TextStrokeColor3 = Color3.new(0, 0, 0)
xpText.TextXAlignment = Enum.TextXAlignment.Left
xpText.Parent = levelFrame

-- ⏱️ 타임어택 카운트 (로비 타이틀과 같은 위치 - 화면 중앙)
local raceTimer = Instance.new("TextLabel")
raceTimer.Name = "RaceTimer"
raceTimer.Size = UDim2.new(0, 300, 0, 50)
raceTimer.Position = UDim2.new(0.5, -150, 0, 10)  -- 상단 중앙
raceTimer.BackgroundTransparency = 1
raceTimer.Text = "⏱️ 00:00.00"
raceTimer.TextSize = 36
raceTimer.Font = Enum.Font.GothamBlack
raceTimer.TextColor3 = Color3.fromRGB(255, 255, 100)
raceTimer.TextStrokeTransparency = 0
raceTimer.TextStrokeColor3 = Color3.new(0, 0, 0)
raceTimer.Visible = false
raceTimer.Parent = screenGui

-- 순위/진행도 표시 (타이머 아래)
local raceInfo = Instance.new("TextLabel")
raceInfo.Name = "RaceInfo"
raceInfo.Size = UDim2.new(0, 300, 0, 30)
raceInfo.Position = UDim2.new(0.5, -150, 0, 55)  -- 타이머 아래
raceInfo.BackgroundTransparency = 1
raceInfo.Text = "🏃 1st | 📍 0%"
raceInfo.TextSize = 22
raceInfo.Font = Enum.Font.GothamBold
raceInfo.TextColor3 = Color3.new(1, 1, 1)
raceInfo.TextStrokeTransparency = 0
raceInfo.TextStrokeColor3 = Color3.new(0, 0, 0)
raceInfo.Visible = false
raceInfo.Parent = screenGui

-- 🏆 TOP 10 (오른쪽) - 완전 투명, 텍스트만
local leaderboardFrame = Instance.new("Frame")
leaderboardFrame.Name = "LeaderboardFrame"
leaderboardFrame.Size = UDim2.new(0, 200, 0, 300)
leaderboardFrame.Position = UDim2.new(1, -215, 0, 15)  -- 오른쪽
leaderboardFrame.BackgroundTransparency = 1
leaderboardFrame.BorderSizePixel = 0
leaderboardFrame.Visible = false
leaderboardFrame.Parent = screenGui

local leaderboardTitle = Instance.new("TextLabel")
leaderboardTitle.Name = "Title"
leaderboardTitle.Size = UDim2.new(1, 0, 0, 30)
leaderboardTitle.Position = UDim2.new(0, 0, 0, 0)
leaderboardTitle.BackgroundTransparency = 1
leaderboardTitle.Text = "🏆 TOP 10"
leaderboardTitle.TextSize = 18
leaderboardTitle.Font = Enum.Font.GothamBlack
leaderboardTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
leaderboardTitle.TextStrokeTransparency = 0
leaderboardTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
leaderboardTitle.TextXAlignment = Enum.TextXAlignment.Right
leaderboardTitle.Parent = leaderboardFrame

local leaderboardList = Instance.new("Frame")
leaderboardList.Name = "List"
leaderboardList.Size = UDim2.new(1, 0, 1, -35)
leaderboardList.Position = UDim2.new(0, 0, 0, 32)
leaderboardList.BackgroundTransparency = 1
leaderboardList.Parent = leaderboardFrame

local leaderboardLayout = Instance.new("UIListLayout")
leaderboardLayout.FillDirection = Enum.FillDirection.Vertical
leaderboardLayout.SortOrder = Enum.SortOrder.LayoutOrder
leaderboardLayout.Padding = UDim.new(0, 4)
leaderboardLayout.Parent = leaderboardList

-- Quiz Container - 더 투명하게 (배경이 보이도록)
local quizContainer = Instance.new("Frame")
quizContainer.Name = "QuizContainer"
quizContainer.Size = UDim2.new(0, 420, 0, 220)
quizContainer.Position = UDim2.new(0.5, -210, 0.5, -110)
quizContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
quizContainer.BackgroundTransparency = 0.6  -- 더 투명하게
quizContainer.BorderSizePixel = 0
quizContainer.Visible = false
quizContainer.Parent = screenGui

local quizCorner = Instance.new("UICorner")
quizCorner.CornerRadius = UDim.new(0, 16)
quizCorner.Parent = quizContainer

local quizQuestion = Instance.new("TextLabel")
quizQuestion.Name = "Question"
quizQuestion.Size = UDim2.new(1, -30, 0, 80)
quizQuestion.Position = UDim2.new(0, 15, 0, 15)
quizQuestion.BackgroundTransparency = 1
quizQuestion.Text = "Question?"
quizQuestion.TextSize = 22
quizQuestion.Font = Enum.Font.GothamBold
quizQuestion.TextColor3 = Color3.new(1, 1, 1)
quizQuestion.TextStrokeTransparency = 0  -- 외곽선 추가
quizQuestion.TextStrokeColor3 = Color3.new(0, 0, 0)
quizQuestion.TextWrapped = true
quizQuestion.Parent = quizContainer

local quizOptions = Instance.new("Frame")
quizOptions.Name = "Options"
quizOptions.Size = UDim2.new(1, -30, 0, 110)
quizOptions.Position = UDim2.new(0, 15, 0, 100)
quizOptions.BackgroundTransparency = 1
quizOptions.Parent = quizContainer

local optionsLayout = Instance.new("UIGridLayout")
optionsLayout.CellSize = UDim2.new(0.48, 0, 0, 48)
optionsLayout.CellPadding = UDim2.new(0.04, 0, 0, 10)
optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionsLayout.Parent = quizOptions

-- 🏰 로비 프레임 (화면 중앙) - 완전 투명
local lobbyFrame = Instance.new("Frame")
lobbyFrame.Name = "LobbyFrame"
lobbyFrame.Size = UDim2.new(0, 350, 0, 200)
lobbyFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
lobbyFrame.BackgroundTransparency = 1  -- 완전 투명
lobbyFrame.BorderSizePixel = 0
lobbyFrame.Visible = true
lobbyFrame.Parent = screenGui

local lobbyTitle = Instance.new("TextLabel")
lobbyTitle.Name = "Title"
lobbyTitle.Size = UDim2.new(1, 0, 0, 50)
lobbyTitle.Position = UDim2.new(0, 0, 0, 10)
lobbyTitle.BackgroundTransparency = 1
lobbyTitle.Text = "🏰 QUIZ CASTLE"
lobbyTitle.TextSize = 42
lobbyTitle.Font = Enum.Font.GothamBlack
lobbyTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
lobbyTitle.TextStrokeTransparency = 0
lobbyTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
lobbyTitle.Parent = lobbyFrame

local lobbyStatus = Instance.new("TextLabel")
lobbyStatus.Name = "Status"
lobbyStatus.Size = UDim2.new(1, 0, 0, 30)
lobbyStatus.Position = UDim2.new(0, 0, 0, 65)
lobbyStatus.BackgroundTransparency = 1
lobbyStatus.Text = "Waiting for players..."
lobbyStatus.TextSize = 20
lobbyStatus.Font = Enum.Font.GothamBold
lobbyStatus.TextColor3 = Color3.new(1, 1, 1)
lobbyStatus.TextStrokeTransparency = 0
lobbyStatus.TextStrokeColor3 = Color3.new(0, 0, 0)
lobbyStatus.Parent = lobbyFrame

local lobbyCountdown = Instance.new("TextLabel")
lobbyCountdown.Name = "Countdown"
lobbyCountdown.Size = UDim2.new(1, 0, 0, 60)
lobbyCountdown.Position = UDim2.new(0, 0, 0, 100)
lobbyCountdown.BackgroundTransparency = 1
lobbyCountdown.Text = ""
lobbyCountdown.TextSize = 56
lobbyCountdown.Font = Enum.Font.GothamBlack
lobbyCountdown.TextColor3 = Color3.fromRGB(100, 255, 100)
lobbyCountdown.TextStrokeTransparency = 0
lobbyCountdown.TextStrokeColor3 = Color3.new(0, 0, 0)
lobbyCountdown.Parent = lobbyFrame

local lobbyPlayers = Instance.new("TextLabel")
lobbyPlayers.Name = "Players"
lobbyPlayers.Size = UDim2.new(1, 0, 0, 25)
lobbyPlayers.Position = UDim2.new(0, 0, 0, 165)
lobbyPlayers.BackgroundTransparency = 1
lobbyPlayers.Text = "👥 Players: 0"
lobbyPlayers.TextSize = 16
lobbyPlayers.Font = Enum.Font.GothamBold
lobbyPlayers.TextColor3 = Color3.fromRGB(200, 200, 200)
lobbyPlayers.TextStrokeTransparency = 0
lobbyPlayers.TextStrokeColor3 = Color3.new(0, 0, 0)
lobbyPlayers.Parent = lobbyFrame

-- Progress Bar (Bottom Center) - 투명 배경
local progressContainer = Instance.new("Frame")
progressContainer.Name = "ProgressContainer"
progressContainer.Size = UDim2.new(0, 500, 0, 30)
progressContainer.Position = UDim2.new(0.5, -250, 1, -50)
progressContainer.BackgroundTransparency = 1
progressContainer.BorderSizePixel = 0
progressContainer.Visible = false
progressContainer.Parent = screenGui

local progressBarBg = Instance.new("Frame")
progressBarBg.Name = "Background"
progressBarBg.Size = UDim2.new(1, -20, 0, 14)
progressBarBg.Position = UDim2.new(0, 10, 0.5, -7)
progressBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
progressBarBg.BackgroundTransparency = 0.3
progressBarBg.BorderSizePixel = 0
progressBarBg.Parent = progressContainer

local progressBarCorner = Instance.new("UICorner")
progressBarCorner.CornerRadius = UDim.new(0, 7)
progressBarCorner.Parent = progressBarBg

local progressBarFill = Instance.new("Frame")
progressBarFill.Name = "Fill"
progressBarFill.Size = UDim2.new(0, 0, 1, 0)
progressBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
progressBarFill.BorderSizePixel = 0
progressBarFill.Parent = progressBarBg

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(0, 7)
progressFillCorner.Parent = progressBarFill

local progressIcon = Instance.new("TextLabel")
progressIcon.Name = "Icon"
progressIcon.Size = UDim2.new(0, 20, 0, 20)
progressIcon.BackgroundTransparency = 1
progressIcon.Text = "🏃"
progressIcon.TextSize = 16
progressIcon.Parent = progressContainer

-- Item Slot (왼쪽 하단) - 투명 배경
local itemSlot = Instance.new("Frame")
itemSlot.Name = "ItemSlot"
itemSlot.Size = UDim2.new(0, 70, 0, 70)
itemSlot.Position = UDim2.new(0, 15, 1, -90)  -- 왼쪽 하단
itemSlot.BackgroundTransparency = 1
itemSlot.BorderSizePixel = 0
itemSlot.Visible = false  -- 레이스 시작 전까지 숨김
itemSlot.Parent = screenGui

local itemIcon = Instance.new("TextLabel")
itemIcon.Name = "Icon"
itemIcon.Size = UDim2.new(1, 0, 1, -18)
itemIcon.Position = UDim2.new(0, 0, 0, 0)
itemIcon.BackgroundTransparency = 1
itemIcon.Text = ""
itemIcon.TextSize = 40
itemIcon.Font = Enum.Font.GothamBold
itemIcon.TextColor3 = Color3.new(1, 1, 1)
itemIcon.TextStrokeTransparency = 0.3
itemIcon.Parent = itemSlot

local itemKey = Instance.new("TextLabel")
itemKey.Name = "KeyHint"
itemKey.Size = UDim2.new(1, 0, 0, 18)
itemKey.Position = UDim2.new(0, 0, 1, -18)
itemKey.BackgroundTransparency = 1
itemKey.Text = "[Q]"
itemKey.TextSize = 12
itemKey.Font = Enum.Font.Gotham
itemKey.TextColor3 = Color3.fromRGB(200, 200, 200)
itemKey.TextStrokeTransparency = 0.5
itemKey.Parent = itemSlot

-- Title Banner (Top Center, for announcements) - 완전 투명
local titleBanner = Instance.new("Frame")
titleBanner.Name = "TitleBanner"
titleBanner.Size = UDim2.new(0, 500, 0, 80)
titleBanner.Position = UDim2.new(0.5, -250, 0, -100)
titleBanner.BackgroundTransparency = 1
titleBanner.BorderSizePixel = 0
titleBanner.Parent = screenGui

local bannerText = Instance.new("TextLabel")
bannerText.Name = "Text"
bannerText.Size = UDim2.new(1, 0, 1, 0)
bannerText.BackgroundTransparency = 1
bannerText.Text = ""
bannerText.TextSize = 42
bannerText.Font = Enum.Font.GothamBlack
bannerText.TextColor3 = Color3.new(1, 1, 1)
bannerText.TextStrokeTransparency = 0.3
bannerText.TextStrokeColor3 = Color3.new(0, 0, 0)
bannerText.Parent = titleBanner

-- Effect Message (Center)
local effectMessage = Instance.new("TextLabel")
effectMessage.Name = "EffectMessage"
effectMessage.Size = UDim2.new(0, 400, 0, 50)
effectMessage.Position = UDim2.new(0.5, -200, 0.3, 0)
effectMessage.BackgroundTransparency = 1
effectMessage.Text = ""
effectMessage.TextSize = 28
effectMessage.Font = Enum.Font.GothamBold
effectMessage.TextColor3 = Color3.fromRGB(255, 100, 100)
effectMessage.TextStrokeTransparency = 0.3
effectMessage.Visible = false
effectMessage.Parent = screenGui

-- XP Popup
local xpPopup = Instance.new("TextLabel")
xpPopup.Name = "XPPopup"
xpPopup.Size = UDim2.new(0, 200, 0, 40)
xpPopup.Position = UDim2.new(0.5, -100, 0.6, 0)
xpPopup.BackgroundTransparency = 1
xpPopup.Text = ""
xpPopup.TextSize = 24
xpPopup.Font = Enum.Font.GothamBold
xpPopup.TextColor3 = Color3.fromRGB(100, 255, 255)
xpPopup.TextStrokeTransparency = 0.5
xpPopup.Visible = false
xpPopup.Parent = screenGui

-- Level Up Celebration
local levelUpFrame = Instance.new("Frame")
levelUpFrame.Name = "LevelUpFrame"
levelUpFrame.Size = UDim2.new(0, 350, 0, 180)
levelUpFrame.Position = UDim2.new(0.5, -175, 0.5, -90)
levelUpFrame.BackgroundColor3 = Color3.fromRGB(50, 30, 80)
levelUpFrame.BackgroundTransparency = 0.3
levelUpFrame.BorderSizePixel = 0
levelUpFrame.Visible = false
levelUpFrame.Parent = screenGui

local levelUpCorner = Instance.new("UICorner")
levelUpCorner.CornerRadius = UDim.new(0, 20)
levelUpCorner.Parent = levelUpFrame

local levelUpTitle = Instance.new("TextLabel")
levelUpTitle.Name = "Title"
levelUpTitle.Size = UDim2.new(1, 0, 0, 50)
levelUpTitle.Position = UDim2.new(0, 0, 0, 15)
levelUpTitle.BackgroundTransparency = 1
levelUpTitle.Text = "🎉 LEVEL UP! 🎉"
levelUpTitle.TextSize = 32
levelUpTitle.Font = Enum.Font.GothamBlack
levelUpTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
levelUpTitle.Parent = levelUpFrame

local levelUpInfo = Instance.new("TextLabel")
levelUpInfo.Name = "Info"
levelUpInfo.Size = UDim2.new(1, 0, 0, 40)
levelUpInfo.Position = UDim2.new(0, 0, 0, 65)
levelUpInfo.BackgroundTransparency = 1
levelUpInfo.Text = "Level 2 - Runner"
levelUpInfo.TextSize = 24
levelUpInfo.Font = Enum.Font.GothamBold
levelUpInfo.TextColor3 = Color3.new(1, 1, 1)
levelUpInfo.Parent = levelUpFrame

local levelUpTrail = Instance.new("TextLabel")
levelUpTrail.Name = "Trail"
levelUpTrail.Size = UDim2.new(1, 0, 0, 30)
levelUpTrail.Position = UDim2.new(0, 0, 0, 110)
levelUpTrail.BackgroundTransparency = 1
levelUpTrail.Text = "New Trail Unlocked: Dust"
levelUpTrail.TextSize = 18
levelUpTrail.Font = Enum.Font.Gotham
levelUpTrail.TextColor3 = Color3.fromRGB(150, 255, 150)
levelUpTrail.Parent = levelUpFrame

-- ============================================
-- 🎨 TRAIL EFFECT SYSTEM (OPTIMIZED)
-- ============================================
local lastFootstepTime = 0
local MAX_TRAIL_PARTS = 20  -- 🔄 PERFORMANCE: 최대 파트 수 제한
local activeTrailParts = {}  -- 활성 트레일 파트 관리

local function CreateFootstepEffect(position, trailType, level)
    if trailType == "None" or not TrailColors[trailType] then return end

    local colors = TrailColors[trailType]
    if #colors == 0 then return end

    -- 🔄 PERFORMANCE: 최대 파트 수 초과 시 가장 오래된 파트 제거
    if #activeTrailParts >= MAX_TRAIL_PARTS then
        local oldPart = table.remove(activeTrailParts, 1)
        if oldPart and oldPart.Parent then
            oldPart:Destroy()
        end
    end

    local color = colors[math.random(1, #colors)]

    local part = Instance.new("Part")
    part.Name = "TrailEffect"
    part.Size = Vector3.new(0.3, 0.1, 0.3)
    part.Position = position + Vector3.new(math.random(-5, 5)/10, 0, math.random(-5, 5)/10)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.3
    part.Parent = workspace

    table.insert(activeTrailParts, part)

    -- Particle effect for higher levels (레벨 7 이상으로 조정하여 파티클 생성 줄임)
    if level >= 7 then
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(color)
        particles.Size = NumberSequence.new(0.3, 0)
        particles.Lifetime = NumberRange.new(0.3, 0.5)
        particles.Rate = 8  -- 🔄 PERFORMANCE: Rate 감소
        particles.Speed = NumberRange.new(1, 3)
        particles.SpreadAngle = Vector2.new(180, 180)
        particles.Parent = part

        task.delay(0.2, function()
            if particles then particles.Enabled = false end
        end)
    end

    -- Fade out
    local tween = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.5, 0.05, 0.5)
    })
    tween:Play()

    tween.Completed:Connect(function()
        -- activeTrailParts에서 제거
        local idx = table.find(activeTrailParts, part)
        if idx then table.remove(activeTrailParts, idx) end
        part:Destroy()
    end)
end

local function UpdateTrailEffects()
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not rootPart then return end
    if humanoid.MoveDirection.Magnitude < 0.1 then return end

    local now = tick()
    if now - lastFootstepTime < 0.18 then return end  -- 🔄 PERFORMANCE: 0.15 → 0.18
    lastFootstepTime = now

    local trailType = PlayerState.trailType
    local level = PlayerState.level

    if trailType ~= "None" then
        CreateFootstepEffect(rootPart.Position - Vector3.new(0, 3, 0), trailType, level)
    end
end

-- ============================================
-- 🔧 UI UPDATE FUNCTIONS
-- ============================================
local function UpdateLevelUI(data)
    if data.level and data.levelName and data.levelIcon then
        PlayerState.level = data.level
        PlayerState.xp = data.xp or 0
        PlayerState.trailType = data.trailType or "None"
        
        levelIcon.Text = data.levelIcon
        levelName.Text = string.format("Lv.%d %s", data.level, data.levelName)
        
        local levelColor = LevelConfig[data.level] and LevelConfig[data.level].color or Color3.new(1, 1, 1)
        levelName.TextColor3 = levelColor
        xpBar.BackgroundColor3 = levelColor
        
        if data.progress then
            local targetSize = UDim2.new(data.progress, 0, 1, 0)
            TweenService:Create(xpBar, TweenInfo.new(0.3), {Size = targetSize}):Play()
        end
        
        if data.xpInLevel and data.xpNeeded then
            xpText.Text = string.format("%d / %d XP", data.xpInLevel, data.xpNeeded)
        end
    end
end

local function ShowXPPopup(amount, reason)
    xpPopup.Text = string.format("+%d XP (%s)", amount, reason or "")
    xpPopup.Position = UDim2.new(0.5, -100, 0.6, 0)
    xpPopup.TextTransparency = 0
    xpPopup.Visible = true
    
    local tween = TweenService:Create(xpPopup, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -100, 0.5, 0),
        TextTransparency = 1
    })
    tween:Play()
    
    tween.Completed:Connect(function()
        xpPopup.Visible = false
    end)
end

local function ShowLevelUpCelebration(data)
    levelUpInfo.Text = string.format("%s Level %d - %s", data.levelIcon, data.newLevel, data.levelName)
    levelUpTrail.Text = string.format("🎨 New Trail: %s", data.trailType)
    levelUpFrame.Visible = true
    levelUpFrame.Position = UDim2.new(0.5, -175, 0.5, -90)
    levelUpFrame.BackgroundTransparency = 0.3
    
    -- Celebration animation
    local scaleUp = TweenService:Create(levelUpFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 380, 0, 200)
    })
    scaleUp:Play()
    
    task.delay(3, function()
        local fadeOut = TweenService:Create(levelUpFrame, TweenInfo.new(0.5), {
            BackgroundTransparency = 1
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            levelUpFrame.Visible = false
            levelUpFrame.Size = UDim2.new(0, 350, 0, 180)
            levelUpFrame.BackgroundTransparency = 0.3
        end)
    end)
end

local currentBannerTween = nil
local function ShowBanner(text, duration, color)
    -- 기존 트윈 취소
    if currentBannerTween then
        currentBannerTween:Cancel()
    end

    bannerText.Text = text
    bannerText.TextColor3 = color or Color3.new(1, 1, 1)
    titleBanner.Visible = true

    local showTween = TweenService:Create(titleBanner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -250, 0, 20)
    })
    showTween:Play()

    task.delay(duration or 3, function()
        local hideTween = TweenService:Create(titleBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -250, 0, -100)
        })
        currentBannerTween = hideTween
        hideTween:Play()
        hideTween.Completed:Connect(function()
            bannerText.Text = ""
            titleBanner.Visible = false  -- 완전히 숨기기
            titleBanner.Position = UDim2.new(0.5, -250, 0, -100)  -- 위치 초기화
        end)
    end)
end

local function ShowEffectMessage(text, duration, color)
    effectMessage.Text = text
    effectMessage.TextColor3 = color or Color3.fromRGB(255, 100, 100)
    effectMessage.TextTransparency = 0
    effectMessage.Visible = true
    
    task.delay(duration or 2, function()
        local fade = TweenService:Create(effectMessage, TweenInfo.new(0.5), {TextTransparency = 1})
        fade:Play()
        fade.Completed:Connect(function()
            effectMessage.Visible = false
        end)
    end)
end

local function UpdateLeaderboard(data)
    -- Clear existing entries
    for _, child in ipairs(leaderboardList:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Add entries (최대 10명)
    for i, entry in ipairs(data) do
        if i > 10 then break end
        
        local label = Instance.new("TextLabel")
        label.Name = "Entry" .. i
        label.Size = UDim2.new(1, 0, 0, 22)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Right  -- 오른쪽 정렬
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.LayoutOrder = i
        
        local medal = i == 1 and "🥇" or (i == 2 and "🥈" or (i == 3 and "🥉" or string.format("%d.", i)))
        local progressText = entry.finished and string.format("%.1fs", entry.time or 0) or string.format("%d%%", entry.progress or 0)
        
        label.Text = string.format("%s %s %s", medal, entry.name or "???", progressText)
        label.TextColor3 = entry.name == player.Name and Color3.fromRGB(100, 255, 100) or Color3.new(1, 1, 1)
        label.Parent = leaderboardList
    end
end

local function UpdateItem(itemName)
    PlayerState.currentItem = itemName
    
    local itemIcons = {
        SpeedBoost = "🚀",
        Shield = "🛡️",
        Banana = "🍌",
        Lightning = "⚡",
        Teleport = "🌀",
        PunchingGlove = "🥊",
    }
    
    itemIcon.Text = itemIcons[itemName] or ""
end

local function UpdateProgress(progress)
    PlayerState.progress = progress
    
    local fillSize = UDim2.new(progress / 100, 0, 1, 0)
    TweenService:Create(progressBarFill, TweenInfo.new(0.2), {Size = fillSize}):Play()
    
    -- Move icon
    progressIcon.Position = UDim2.new(progress / 100, -10, 0.5, -10)
end

-- ============================================
-- 🎮 QUIZ UI
-- ============================================
local currentQuizData = nil

local function ShowQuiz(data)
    currentQuizData = data
    quizQuestion.Text = data.question or "Question?"
    
    -- Clear old options
    for _, child in ipairs(quizOptions:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- 색상 배열 (서버에서 받거나 기본값)
    local colors = data.colors or {
        Color3.fromRGB(255, 80, 80),   -- 빨강
        Color3.fromRGB(80, 150, 255),  -- 파랑
        Color3.fromRGB(80, 255, 80),   -- 초록
        Color3.fromRGB(255, 255, 80),  -- 노랑
    }
    
    -- Create option buttons with colors
    for i, option in ipairs(data.options or {}) do
        local btnColor = colors[i] or Color3.fromRGB(100, 100, 100)
        -- 좀 더 어두운 버전 (배경용)
        local darkColor = Color3.fromRGB(
            math.floor(btnColor.R * 255 * 0.4),
            math.floor(btnColor.G * 255 * 0.4),
            math.floor(btnColor.B * 255 * 0.4)
        )
        -- 밝은 버전 (호버용)
        local brightColor = Color3.fromRGB(
            math.min(255, math.floor(btnColor.R * 255 * 1.2)),
            math.min(255, math.floor(btnColor.G * 255 * 1.2)),
            math.min(255, math.floor(btnColor.B * 255 * 1.2))
        )
        
        local btn = Instance.new("TextButton")
        btn.Name = "Option" .. i
        btn.Size = UDim2.new(0.48, 0, 0, 48)
        btn.BackgroundColor3 = btnColor  -- 게이트와 같은 색상!
        btn.BackgroundTransparency = 0.3
        btn.Text = option
        btn.TextSize = 18
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextStrokeTransparency = 0
        btn.TextStrokeColor3 = Color3.new(0, 0, 0)
        btn.LayoutOrder = i
        btn.Parent = quizOptions
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 10)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            if data.gateId then
                Events.GateQuiz:FireServer(data.gateId, i)
            end
            quizContainer.Visible = false
        end)
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = brightColor, BackgroundTransparency = 0.1}):Play()
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = btnColor, BackgroundTransparency = 0.3}):Play()
        end)
    end
    
    quizContainer.Visible = true
end

local function HideQuiz()
    quizContainer.Visible = false
    currentQuizData = nil
end

-- ============================================
-- 📡 EVENT HANDLERS
-- ============================================
Events.GameEvent.OnClientEvent:Connect(function(eventType, data)
    if eventType == "RaceStart" then
        PlayerState.isRacing = true
        lobbyFrame.Visible = false
        raceTimer.Visible = true
        raceInfo.Visible = true
        leaderboardFrame.Visible = true
        progressContainer.Visible = true
        ShowBanner("🏁 GO!", 2, Color3.fromRGB(100, 255, 100))
        
    elseif eventType == "RaceEnd" then
        PlayerState.isRacing = false
        raceTimer.Visible = false
        raceInfo.Visible = false
        leaderboardFrame.Visible = false
        progressContainer.Visible = false
        
    elseif eventType == "Countdown" then
        if data.count then
            lobbyCountdown.Text = tostring(data.count)
            local color = data.count <= 3 and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
            lobbyCountdown.TextColor3 = color
        end
        
    elseif eventType == "PhaseChange" then
        if data.phase == "Waiting" then
            lobbyFrame.Visible = true
            raceTimer.Visible = false
            raceInfo.Visible = false
            lobbyStatus.Text = "Waiting for players..."
            lobbyCountdown.Text = ""
        elseif data.phase == "Countdown" then
            lobbyStatus.Text = "Race starting soon!"
        elseif data.phase == "Racing" then
            lobbyFrame.Visible = false
            raceTimer.Visible = true
            raceInfo.Visible = true
        elseif data.phase == "Intermission" then
            lobbyFrame.Visible = true
            raceTimer.Visible = false
            raceInfo.Visible = false
            lobbyStatus.Text = "Intermission"
        end
        
    elseif eventType == "Finish" then
        local place = data.place or 1
        local timeStr = data.time or "0.00"
        local medals = {"🥇", "🥈", "🥉"}
        local medal = medals[place] or "🏅"
        ShowBanner(string.format("%s %s Place! Time: %s", medal, 
            place == 1 and "1st" or (place == 2 and "2nd" or (place == 3 and "3rd" or place .. "th")), 
            timeStr), 5, Color3.fromRGB(255, 215, 0))
        
    elseif eventType == "GateCorrect" then
        quizContainer.Visible = false  -- 정답 시 퀴즈 창 즉시 숨김
        ShowEffectMessage("✅ CORRECT!", 1.5, Color3.fromRGB(100, 255, 100))
        
    elseif eventType == "GateWrong" then
        quizContainer.Visible = false  -- 오답 시에도 퀴즈 창 숨김
        ShowEffectMessage("❌ WRONG!", 1.5, Color3.fromRGB(255, 100, 100))
        
    elseif eventType == "Stunned" then
        ShowEffectMessage("⚡ STUNNED!", 2, Color3.fromRGB(255, 255, 0))
        
    elseif eventType == "Slowed" then
        ShowEffectMessage("🐌 SLOWED!", 2, Color3.fromRGB(150, 100, 255))
        
    elseif eventType == "SpeedBoost" then
        ShowEffectMessage("🚀 SPEED BOOST!", 2, Color3.fromRGB(0, 200, 255))
        
    elseif eventType == "Shielded" then
        ShowEffectMessage("🛡️ SHIELD ACTIVE!", 2, Color3.fromRGB(100, 200, 255))
        
    elseif eventType == "Knockback" then
        ShowEffectMessage("🥊 KNOCKED BACK!", 1.5, Color3.fromRGB(255, 150, 0))
        
    elseif eventType == "PlayerLevelUp" then
        if data.playerName then
            ShowBanner(string.format("🎉 %s reached Level %d!", data.playerName, data.newLevel or 0), 3, Color3.fromRGB(255, 215, 0))
        end
    end
end)

Events.TimeUpdate.OnClientEvent:Connect(function(timeOrData, position, progress)
    -- 서버에서 숫자 또는 테이블로 보낼 수 있음
    local elapsed = type(timeOrData) == "number" and timeOrData or (timeOrData and timeOrData.time)
    local pos = position or (type(timeOrData) == "table" and timeOrData.position)
    local prog = progress or (type(timeOrData) == "table" and timeOrData.progress)
    
    if elapsed then
        local minutes = math.floor(elapsed / 60)
        local seconds = elapsed % 60
        raceTimer.Text = string.format("⏱️ %02d:%05.2f", minutes, seconds)
    end
    
    -- 순위와 진행도를 한 줄에 표시
    local posText = ""
    local progText = ""
    
    if pos then
        local suffix = pos == 1 and "st" or (pos == 2 and "nd" or (pos == 3 and "rd" or "th"))
        posText = string.format("🏃 %d%s", pos, suffix)
    end
    
    if prog then
        progText = string.format("📍 %d%%", math.floor(prog))
        UpdateProgress(prog)
    end
    
    if posText ~= "" and progText ~= "" then
        raceInfo.Text = posText .. " | " .. progText
    elseif posText ~= "" then
        raceInfo.Text = posText
    elseif progText ~= "" then
        raceInfo.Text = progText
    end
end)

Events.LeaderboardUpdate.OnClientEvent:Connect(function(data)
    UpdateLeaderboard(data)
end)

Events.GateQuiz.OnClientEvent:Connect(function(data)
    -- question이 있으면 퀴즈 표시, 없으면 숨김
    if data.question then
        ShowQuiz(data)
    else
        HideQuiz()
    end
end)

Events.ItemEffect.OnClientEvent:Connect(function(action, data)
    data = data or {}
    
    -- 서버에서 action, data 두 개로 보냄
    if action == "GotItem" then
        -- 아이템 획득
        UpdateItem(data.itemType)
        ShowEffectMessage("📦 " .. (data.itemType or "Item") .. " 획득! [Q]로 사용", 2, Color3.fromRGB(100, 200, 255))
    elseif action == "ItemUsed" then
        -- 아이템 사용됨 - UI에서 제거
        UpdateItem(nil)
    elseif action == "SpeedBoost" then
        ShowEffectMessage("🚀 SPEED BOOST!", 2, Color3.fromRGB(0, 200, 255))
    elseif action == "Shielded" then
        ShowEffectMessage("🛡️ SHIELD ACTIVE!", 2, Color3.fromRGB(100, 200, 255))
    elseif action == "Stun" or action == "PunchStun" then
        ShowEffectMessage("⚡ STUNNED!", 1.5, Color3.fromRGB(255, 255, 0))
    elseif action == "LightningHit" then
        ShowEffectMessage("⚡ LIGHTNING!", 1.5, Color3.fromRGB(255, 255, 0))
    elseif action == "Knockback" or action == "BoulderHit" then
        ShowEffectMessage("💥 HIT!", 1, Color3.fromRGB(255, 100, 100))
    elseif action == "Electrocuted" then
        ShowEffectMessage("⚡ SHOCKED!", 1, Color3.fromRGB(255, 255, 0))
    elseif action == "Respawning" then
        ShowEffectMessage("⚠️ OUT OF BOUNDS!", 3, Color3.fromRGB(255, 100, 100))
    elseif action == "Invincible" then
        ShowEffectMessage("🛡️ INVINCIBLE (2s)", 2, Color3.fromRGB(100, 200, 255))
    elseif action == "GateCorrect" then
        quizContainer.Visible = false
        ShowEffectMessage("✅ CORRECT!", 1.5, Color3.fromRGB(100, 255, 100))
    elseif action == "GateWrong" then
        quizContainer.Visible = false
        ShowEffectMessage("❌ WRONG!", 1.5, Color3.fromRGB(255, 100, 100))
    elseif action == "LavaFall" then
        ShowEffectMessage("🔥 LAVA!", 1, Color3.fromRGB(255, 100, 0))
    end
end)

Events.XPUpdate.OnClientEvent:Connect(function(data)
    UpdateLevelUI(data)
    if data.xpGained and data.xpGained > 0 then
        ShowXPPopup(data.xpGained, data.reason)
    end
end)

Events.LevelUp.OnClientEvent:Connect(function(data)
    ShowLevelUpCelebration(data)
end)

Events.LobbyUpdate.OnClientEvent:Connect(function(data)
    -- 서버는 playersInLobby를 보냄
    if data.playersInLobby then
        lobbyPlayers.Text = string.format("👥 Players: %d", data.playersInLobby)
    end
    
    -- 페이즈 업데이트
    if data.phase then
        if data.phase == "Waiting" then
            lobbyStatus.Text = "Waiting for players..."
        elseif data.phase == "Countdown" then
            lobbyStatus.Text = "Starting soon!"
        end
    end
    
    -- 카운트다운
    if data.countdown and data.countdown > 0 then
        lobbyCountdown.Text = string.format("⏱️ %d", data.countdown)
        lobbyCountdown.Visible = true
    else
        lobbyCountdown.Visible = false
    end
end)

-- RoundUpdate 핸들러 추가
Events.RoundUpdate.OnClientEvent:Connect(function(eventType, data)
    data = data or {}
    
    if eventType == "Countdown" then
        -- 카운트다운 표시 (lobbyCountdown만 사용, ShowBanner 제거로 중복 방지)
        if data.count then
            lobbyCountdown.Text = tostring(data.count)
            local color = data.count <= 3 and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
            lobbyCountdown.TextColor3 = color
        end
        
    elseif eventType == "CountdownCancelled" then
        lobbyStatus.Text = "Waiting for players..."
        lobbyCountdown.Text = ""
        
    elseif eventType == "RaceStart" then
        PlayerState.isRacing = true
        lobbyFrame.Visible = false
        raceTimer.Visible = true
        raceInfo.Visible = true
        leaderboardFrame.Visible = true
        progressContainer.Visible = true
        itemSlot.Visible = true  -- 아이템 슬롯 표시
        ShowBanner("🏁 GO!", 2, Color3.fromRGB(100, 255, 100))
        -- 컨트롤 안내 표시
        task.delay(2.5, function()
            ShowEffectMessage("💡 Q: 아이템 사용", 4, Color3.fromRGB(200, 200, 255))
        end)
        
    elseif eventType == "PlayerFinished" then
        if data.playerName and data.rank then
            local msg = string.format("🏆 #%d %s", data.rank, data.playerName)
            if data.time then
                msg = msg .. string.format(" - %.1fs", data.time)
            end
            ShowEffectMessage(msg, 3, Color3.fromRGB(255, 215, 0))
        end
        
    elseif eventType == "RoundEnd" then
        PlayerState.isRacing = false
        raceTimer.Visible = false
        raceInfo.Visible = false
        progressContainer.Visible = false
        quizContainer.Visible = false
        itemSlot.Visible = false  -- 아이템 슬롯 숨김
        ShowBanner("🏁 RACE COMPLETE!", 3, Color3.fromRGB(255, 215, 0))
        
        -- 결과 리더보드 업데이트
        if data.leaderboard then
            UpdateLeaderboard(data.leaderboard)
        end
        
    elseif eventType == "Intermission" then
        lobbyFrame.Visible = true
        lobbyStatus.Text = "Next round starting soon..."
        leaderboardFrame.Visible = true
    end
end)

-- ============================================
-- 🔧 ADMIN PANEL UI
-- ============================================
local AdminPanel = {
    visible = false,
    courses = {},
    currentCourse = nil
}

-- Forward declaration for auto-sync status label
local autoSyncStatusLabel = nil

-- Admin Panel GUI
local adminScreenGui = Instance.new("ScreenGui")
adminScreenGui.Name = "AdminPanel"
adminScreenGui.ResetOnSpawn = false
adminScreenGui.DisplayOrder = 100
adminScreenGui.Parent = playerGui

-- Main Panel Frame
local adminFrame = Instance.new("Frame")
adminFrame.Name = "AdminFrame"
adminFrame.Size = UDim2.new(0, 400, 0, 500)
adminFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
adminFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
adminFrame.BackgroundTransparency = 0.1
adminFrame.BorderSizePixel = 0
adminFrame.Visible = false
adminFrame.Parent = adminScreenGui

local adminCorner = Instance.new("UICorner")
adminCorner.CornerRadius = UDim.new(0, 12)
adminCorner.Parent = adminFrame

local adminStroke = Instance.new("UIStroke")
adminStroke.Color = Color3.fromRGB(100, 100, 180)
adminStroke.Thickness = 2
adminStroke.Parent = adminFrame

-- Header
local adminHeader = Instance.new("Frame")
adminHeader.Name = "Header"
adminHeader.Size = UDim2.new(1, 0, 0, 50)
adminHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
adminHeader.BorderSizePixel = 0
adminHeader.Parent = adminFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = adminHeader

-- Fix bottom corners of header
local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
headerFix.BorderSizePixel = 0
headerFix.Parent = adminHeader

local adminTitle = Instance.new("TextLabel")
adminTitle.Size = UDim2.new(1, -50, 1, 0)
adminTitle.Position = UDim2.new(0, 15, 0, 0)
adminTitle.BackgroundTransparency = 1
adminTitle.Text = "🔧 Admin Panel"
adminTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
adminTitle.TextSize = 20
adminTitle.Font = Enum.Font.GothamBold
adminTitle.TextXAlignment = Enum.TextXAlignment.Left
adminTitle.Parent = adminHeader

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 24
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = adminHeader

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Content Area
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -20, 1, -60)
contentFrame.Position = UDim2.new(0, 10, 0, 55)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 6
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 180)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
contentFrame.Parent = adminFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.Parent = contentFrame

-- Helper function to create section
local function CreateSection(title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 40)
    section.BackgroundColor3 = Color3.fromRGB(50, 50, 90)
    section.BorderSizePixel = 0
    section.Parent = contentFrame

    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 8)
    sectionCorner.Parent = section

    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Size = UDim2.new(1, -20, 1, 0)
    sectionTitle.Position = UDim2.new(0, 10, 0, 0)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Text = title
    sectionTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
    sectionTitle.TextSize = 14
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.Parent = section

    return section
end

-- Helper function to create button
local function CreateButton(text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = color or Color3.fromRGB(60, 60, 120)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = contentFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(callback)

    return btn
end

-- Helper function to create info label
local function CreateInfoLabel(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(180, 180, 180)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = contentFrame
    return label
end

-- Current Course Info Label
local courseInfoLabel = CreateInfoLabel("📋 현재 코스: 로딩 중...")

-- Section: Course Preview
CreateSection("👁️ 코스 미리보기")

-- Preview Frame
local previewFrame = Instance.new("Frame")
previewFrame.Name = "PreviewFrame"
previewFrame.Size = UDim2.new(1, 0, 0, 120)
previewFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
previewFrame.BorderSizePixel = 0
previewFrame.Parent = contentFrame

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 8)
previewCorner.Parent = previewFrame

-- Track background
local trackBg = Instance.new("Frame")
trackBg.Name = "TrackBg"
trackBg.Size = UDim2.new(1, -20, 0, 40)
trackBg.Position = UDim2.new(0, 10, 0.5, -20)
trackBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
trackBg.BorderSizePixel = 0
trackBg.Parent = previewFrame

local trackBgCorner = Instance.new("UICorner")
trackBgCorner.CornerRadius = UDim.new(0, 4)
trackBgCorner.Parent = trackBg

-- Start marker
local startMarker = Instance.new("Frame")
startMarker.Size = UDim2.new(0, 4, 1, 0)
startMarker.Position = UDim2.new(0, 0, 0, 0)
startMarker.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
startMarker.BorderSizePixel = 0
startMarker.Parent = trackBg

-- Finish marker
local finishMarker = Instance.new("Frame")
finishMarker.Size = UDim2.new(0, 4, 1, 0)
finishMarker.Position = UDim2.new(1, -4, 0, 0)
finishMarker.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
finishMarker.BorderSizePixel = 0
finishMarker.Parent = trackBg

-- Gimmick container
local gimmickContainer = Instance.new("Frame")
gimmickContainer.Name = "GimmickContainer"
gimmickContainer.Size = UDim2.new(1, 0, 1, 0)
gimmickContainer.BackgroundTransparency = 1
gimmickContainer.Parent = trackBg

-- Preview labels
local previewStartLabel = Instance.new("TextLabel")
previewStartLabel.Size = UDim2.new(0, 40, 0, 15)
previewStartLabel.Position = UDim2.new(0, 10, 0, 5)
previewStartLabel.BackgroundTransparency = 1
previewStartLabel.Text = "START"
previewStartLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
previewStartLabel.TextSize = 10
previewStartLabel.Font = Enum.Font.GothamBold
previewStartLabel.Parent = previewFrame

local previewEndLabel = Instance.new("TextLabel")
previewEndLabel.Size = UDim2.new(0, 40, 0, 15)
previewEndLabel.Position = UDim2.new(1, -50, 0, 5)
previewEndLabel.BackgroundTransparency = 1
previewEndLabel.Text = "FINISH"
previewEndLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
previewEndLabel.TextSize = 10
previewEndLabel.Font = Enum.Font.GothamBold
previewEndLabel.Parent = previewFrame

-- Legend
local legendFrame = Instance.new("Frame")
legendFrame.Size = UDim2.new(1, -20, 0, 20)
legendFrame.Position = UDim2.new(0, 10, 1, -25)
legendFrame.BackgroundTransparency = 1
legendFrame.Parent = previewFrame

local legendLayout = Instance.new("UIListLayout")
legendLayout.FillDirection = Enum.FillDirection.Horizontal
legendLayout.Padding = UDim.new(0, 10)
legendLayout.Parent = legendFrame

-- Gimmick colors and icons for preview
local GimmickPreviewConfig = {
    RotatingBar = {color = Color3.fromRGB(255, 100, 100), icon = "🔄"},
    QuizGate = {color = Color3.fromRGB(100, 200, 255), icon = "❓"},
    Elevator = {color = Color3.fromRGB(255, 200, 100), icon = "🛗"},
    JumpPad = {color = Color3.fromRGB(100, 255, 150), icon = "⬆️"},
    SlimeZone = {color = Color3.fromRGB(150, 255, 100), icon = "💚"},
    DisappearingBridge = {color = Color3.fromRGB(200, 150, 255), icon = "🌉"},
    ConveyorBelt = {color = Color3.fromRGB(150, 150, 150), icon = "➡️"},
    ElectricFloor = {color = Color3.fromRGB(255, 255, 100), icon = "⚡"},
    PunchingCorridor = {color = Color3.fromRGB(255, 150, 100), icon = "👊"},
    RollingBoulder = {color = Color3.fromRGB(139, 90, 43), icon = "🪨"}
}

-- Create legend items
local function CreateLegendItem(gimmickType, config)
    local item = Instance.new("Frame")
    item.Size = UDim2.new(0, 50, 1, 0)
    item.BackgroundTransparency = 1
    item.Parent = legendFrame

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 0, 0.5, -4)
    dot.BackgroundColor3 = config.color
    dot.BorderSizePixel = 0
    dot.Parent = item

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = config.icon
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = item
end

-- Add some legend items
CreateLegendItem("QuizGate", GimmickPreviewConfig.QuizGate)
CreateLegendItem("RotatingBar", GimmickPreviewConfig.RotatingBar)
CreateLegendItem("Elevator", GimmickPreviewConfig.Elevator)
CreateLegendItem("JumpPad", GimmickPreviewConfig.JumpPad)

-- Function to render preview
local function RenderCoursePreview(courseData)
    -- Clear existing gimmicks
    for _, child in ipairs(gimmickContainer:GetChildren()) do
        child:Destroy()
    end

    if not courseData or not courseData.gimmicks then
        return
    end

    local trackLength = courseData.length or 2000
    local trackWidth = trackBg.AbsoluteSize.X - 10

    for _, gimmick in ipairs(courseData.gimmicks) do
        local config = GimmickPreviewConfig[gimmick.type]
        if config then
            -- Get Z position
            local z = gimmick.z or gimmick.triggerZ or gimmick.zStart or 0
            local zEnd = gimmick.gateZ or gimmick.elevZ or gimmick.zEnd or z
            local zLength = gimmick.length or 0

            -- Calculate position on track
            local xPos = (z / trackLength)
            local width = math.max(4, ((zEnd - z + zLength) / trackLength) * trackWidth)

            -- Create gimmick marker
            local marker = Instance.new("Frame")
            marker.Size = UDim2.new(0, math.max(4, width), 0.6, 0)
            marker.Position = UDim2.new(xPos, 0, 0.2, 0)
            marker.BackgroundColor3 = config.color
            marker.BorderSizePixel = 0
            marker.Parent = gimmickContainer

            local markerCorner = Instance.new("UICorner")
            markerCorner.CornerRadius = UDim.new(0, 2)
            markerCorner.Parent = marker

            -- Tooltip on hover (using TextLabel as tooltip container)
            local tooltip = Instance.new("TextLabel")
            tooltip.Size = UDim2.new(0, 80, 0, 20)
            tooltip.Position = UDim2.new(0.5, -40, -1.5, 0)
            tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            tooltip.Text = string.format("%s Z:%d", config.icon, z)
            tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
            tooltip.TextSize = 9
            tooltip.Font = Enum.Font.Gotham
            tooltip.Visible = false
            tooltip.ZIndex = 10
            tooltip.Parent = marker

            local tooltipCorner = Instance.new("UICorner")
            tooltipCorner.CornerRadius = UDim.new(0, 4)
            tooltipCorner.Parent = tooltip

            -- Create invisible button for hover detection
            local hoverBtn = Instance.new("TextButton")
            hoverBtn.Size = UDim2.new(1, 0, 1, 0)
            hoverBtn.BackgroundTransparency = 1
            hoverBtn.Text = ""
            hoverBtn.Parent = marker

            hoverBtn.MouseEnter:Connect(function()
                tooltip.Visible = true
            end)
            hoverBtn.MouseLeave:Connect(function()
                tooltip.Visible = false
            end)
        end
    end
end

-- Preview placeholder text
local previewPlaceholder = Instance.new("TextLabel")
previewPlaceholder.Name = "PreviewPlaceholder"
previewPlaceholder.Size = UDim2.new(1, 0, 0, 20)
previewPlaceholder.Position = UDim2.new(0, 0, 0.5, -10)
previewPlaceholder.BackgroundTransparency = 1
previewPlaceholder.Text = "코스 정보를 로드하면 미리보기가 표시됩니다"
previewPlaceholder.TextColor3 = Color3.fromRGB(100, 100, 120)
previewPlaceholder.TextSize = 11
previewPlaceholder.Font = Enum.Font.Gotham
previewPlaceholder.Parent = gimmickContainer

-- Section: Course Management
CreateSection("📚 코스 관리")

CreateButton("📋 코스 목록 보기", Color3.fromRGB(60, 120, 180), function()
    Events.AdminCommand:FireServer("courses")
end)

CreateButton("🔄 코스 재빌드", Color3.fromRGB(180, 120, 60), function()
    Events.AdminCommand:FireServer("rebuild")
end)

CreateButton("ℹ️ 현재 코스 정보", Color3.fromRGB(60, 150, 120), function()
    Events.AdminCommand:FireServer("courseinfo")
end)

-- Section: Course List
CreateSection("🎮 코스 선택")

local courseListFrame = Instance.new("Frame")
courseListFrame.Name = "CourseList"
courseListFrame.Size = UDim2.new(1, 0, 0, 150)
courseListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
courseListFrame.BorderSizePixel = 0
courseListFrame.Parent = contentFrame

local courseListCorner = Instance.new("UICorner")
courseListCorner.CornerRadius = UDim.new(0, 8)
courseListCorner.Parent = courseListFrame

local courseListScroll = Instance.new("ScrollingFrame")
courseListScroll.Size = UDim2.new(1, -10, 1, -10)
courseListScroll.Position = UDim2.new(0, 5, 0, 5)
courseListScroll.BackgroundTransparency = 1
courseListScroll.ScrollBarThickness = 4
courseListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
courseListScroll.Parent = courseListFrame

local courseListLayout = Instance.new("UIListLayout")
courseListLayout.Padding = UDim.new(0, 5)
courseListLayout.Parent = courseListScroll

local courseListPlaceholder = Instance.new("TextLabel")
courseListPlaceholder.Name = "Placeholder"
courseListPlaceholder.Size = UDim2.new(1, 0, 0, 30)
courseListPlaceholder.BackgroundTransparency = 1
courseListPlaceholder.Text = "📋 '코스 목록 보기' 클릭하세요"
courseListPlaceholder.TextColor3 = Color3.fromRGB(120, 120, 120)
courseListPlaceholder.TextSize = 12
courseListPlaceholder.Font = Enum.Font.Gotham
courseListPlaceholder.Parent = courseListScroll

-- Section: GitHub Load
CreateSection("🌐 GitHub 코스 로드")

local githubInput = Instance.new("TextBox")
githubInput.Size = UDim2.new(1, 0, 0, 35)
githubInput.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
githubInput.Text = ""
githubInput.PlaceholderText = "코스 ID 입력 (예: sample-easy)"
githubInput.TextColor3 = Color3.fromRGB(255, 255, 255)
githubInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
githubInput.TextSize = 14
githubInput.Font = Enum.Font.Gotham
githubInput.ClearTextOnFocus = false
githubInput.Parent = contentFrame

local githubInputCorner = Instance.new("UICorner")
githubInputCorner.CornerRadius = UDim.new(0, 8)
githubInputCorner.Parent = githubInput

CreateButton("🌐 GitHub에서 로드", Color3.fromRGB(100, 60, 180), function()
    local courseId = githubInput.Text
    if courseId and courseId ~= "" then
        Events.AdminCommand:FireServer("loadgithub", courseId)
        githubInput.Text = ""
    end
end)

-- Section: Course Selection
CreateSection("🎮 코스 선택")

CreateButton("🏠 Classic (기본)", Color3.fromRGB(60, 120, 60), function()
    Events.AdminCommand:FireServer("setcourse", "classic", "library")
end)

CreateButton("🔥 Hard Mode (고난이도)", Color3.fromRGB(180, 60, 60), function()
    Events.AdminCommand:FireServer("setcourse", "hardmode", "library")
end)

CreateButton("📗 Easy Tutorial (입문)", Color3.fromRGB(60, 160, 100), function()
    Events.AdminCommand:FireServer("setcourse", "sample-easy", "github")
end)

CreateButton("⚡ Skill Test (기믹 테스트)", Color3.fromRGB(100, 100, 200), function()
    Events.AdminCommand:FireServer("setcourse", "skill-test", "github")
end)

-- Section: Auto-Sync
CreateSection("🔄 GitHub 자동 동기화")

-- Auto-sync status frame
local autoSyncFrame = Instance.new("Frame")
autoSyncFrame.Name = "AutoSyncFrame"
autoSyncFrame.Size = UDim2.new(1, 0, 0, 80)
autoSyncFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
autoSyncFrame.BorderSizePixel = 0
autoSyncFrame.Parent = contentFrame

local autoSyncCorner = Instance.new("UICorner")
autoSyncCorner.CornerRadius = UDim.new(0, 8)
autoSyncCorner.Parent = autoSyncFrame

-- Status label
autoSyncStatusLabel = Instance.new("TextLabel")
autoSyncStatusLabel.Name = "StatusLabel"
autoSyncStatusLabel.Size = UDim2.new(1, -20, 0, 30)
autoSyncStatusLabel.Position = UDim2.new(0, 10, 0, 5)
autoSyncStatusLabel.BackgroundTransparency = 1
autoSyncStatusLabel.Font = Enum.Font.GothamMedium
autoSyncStatusLabel.TextSize = 14
autoSyncStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
autoSyncStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
autoSyncStatusLabel.Text = "🔄 Auto-Sync: ON (30s 간격)"
autoSyncStatusLabel.Parent = autoSyncFrame

-- Buttons row
local syncButtonsRow = Instance.new("Frame")
syncButtonsRow.Size = UDim2.new(1, -20, 0, 35)
syncButtonsRow.Position = UDim2.new(0, 10, 0, 38)
syncButtonsRow.BackgroundTransparency = 1
syncButtonsRow.Parent = autoSyncFrame

local syncButtonsLayout = Instance.new("UIListLayout")
syncButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
syncButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
syncButtonsLayout.Padding = UDim.new(0, 8)
syncButtonsLayout.Parent = syncButtonsRow

-- Toggle button
local toggleSyncBtn = Instance.new("TextButton")
toggleSyncBtn.Size = UDim2.new(0, 100, 1, 0)
toggleSyncBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
toggleSyncBtn.Font = Enum.Font.GothamBold
toggleSyncBtn.TextSize = 12
toggleSyncBtn.TextColor3 = Color3.new(1, 1, 1)
toggleSyncBtn.Text = "⏸️ 일시정지"
toggleSyncBtn.Parent = syncButtonsRow

local toggleSyncCorner = Instance.new("UICorner")
toggleSyncCorner.CornerRadius = UDim.new(0, 6)
toggleSyncCorner.Parent = toggleSyncBtn

local autoSyncEnabled = true
toggleSyncBtn.MouseButton1Click:Connect(function()
    Events.AdminCommand:FireServer("autosync")
    autoSyncEnabled = not autoSyncEnabled
    if autoSyncEnabled then
        toggleSyncBtn.Text = "⏸️ 일시정지"
        toggleSyncBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
        autoSyncStatusLabel.Text = "🔄 Auto-Sync: ON"
        autoSyncStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        toggleSyncBtn.Text = "▶️ 재개"
        toggleSyncBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 60)
        autoSyncStatusLabel.Text = "🔄 Auto-Sync: OFF"
        autoSyncStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    end
end)

-- Sync now button
local syncNowBtn = Instance.new("TextButton")
syncNowBtn.Size = UDim2.new(0, 100, 1, 0)
syncNowBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
syncNowBtn.Font = Enum.Font.GothamBold
syncNowBtn.TextSize = 12
syncNowBtn.TextColor3 = Color3.new(1, 1, 1)
syncNowBtn.Text = "🔄 지금 동기화"
syncNowBtn.Parent = syncButtonsRow

local syncNowCorner = Instance.new("UICorner")
syncNowCorner.CornerRadius = UDim.new(0, 6)
syncNowCorner.Parent = syncNowBtn

syncNowBtn.MouseButton1Click:Connect(function()
    Events.AdminCommand:FireServer("syncnow")
    syncNowBtn.Text = "⏳ 확인 중..."
    task.delay(2, function()
        syncNowBtn.Text = "🔄 지금 동기화"
    end)
end)

-- Status check button
local checkStatusBtn = Instance.new("TextButton")
checkStatusBtn.Size = UDim2.new(0, 80, 1, 0)
checkStatusBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
checkStatusBtn.Font = Enum.Font.GothamBold
checkStatusBtn.TextSize = 12
checkStatusBtn.TextColor3 = Color3.new(1, 1, 1)
checkStatusBtn.Text = "ℹ️ 상태"
checkStatusBtn.Parent = syncButtonsRow

local checkStatusCorner = Instance.new("UICorner")
checkStatusCorner.CornerRadius = UDim.new(0, 6)
checkStatusCorner.Parent = checkStatusBtn

checkStatusBtn.MouseButton1Click:Connect(function()
    Events.AdminCommand:FireServer("autosyncstatus")
end)

-- Section: Game Settings
CreateSection("⚙️ 게임 설정")

-- Settings container
local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(1, 0, 0, 300)
settingsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
settingsFrame.BorderSizePixel = 0
settingsFrame.Parent = contentFrame

local settingsCorner = Instance.new("UICorner")
settingsCorner.CornerRadius = UDim.new(0, 8)
settingsCorner.Parent = settingsFrame

local settingsScroll = Instance.new("ScrollingFrame")
settingsScroll.Size = UDim2.new(1, -10, 1, -10)
settingsScroll.Position = UDim2.new(0, 5, 0, 5)
settingsScroll.BackgroundTransparency = 1
settingsScroll.ScrollBarThickness = 4
settingsScroll.CanvasSize = UDim2.new(0, 0, 0, 500)
settingsScroll.Parent = settingsFrame

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0, 5)
settingsLayout.Parent = settingsScroll

-- Current config cache
local currentConfig = {}

-- Helper to create a toggle setting
local function CreateToggleSetting(key, label)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 75)
    row.BorderSizePixel = 0
    row.Parent = settingsScroll

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(0.7, 0, 1, 0)
    labelText.Position = UDim2.new(0, 10, 0, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
    labelText.TextSize = 11
    labelText.Font = Enum.Font.Gotham
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Parent = row

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = key
    toggleBtn.Size = UDim2.new(0, 50, 0, 22)
    toggleBtn.Position = UDim2.new(1, -60, 0.5, -11)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    toggleBtn.Text = "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    toggleBtn.TextSize = 10
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = row

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        local newValue = not currentConfig[key]
        Events.AdminCommand:FireServer("setconfig", key, tostring(newValue))
    end)

    return toggleBtn
end

-- Helper to create a number setting
local function CreateNumberSetting(key, label, min, max, step)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 75)
    row.BorderSizePixel = 0
    row.Parent = settingsScroll

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(0.5, 0, 1, 0)
    labelText.Position = UDim2.new(0, 10, 0, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
    labelText.TextSize = 11
    labelText.Font = Enum.Font.Gotham
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Parent = row

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 24, 0, 22)
    minusBtn.Position = UDim2.new(1, -100, 0.5, -11)
    minusBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
    minusBtn.Text = "-"
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.TextSize = 14
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.Parent = row

    local minusBtnCorner = Instance.new("UICorner")
    minusBtnCorner.CornerRadius = UDim.new(0, 4)
    minusBtnCorner.Parent = minusBtn

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = key
    valueLabel.Size = UDim2.new(0, 40, 0, 22)
    valueLabel.Position = UDim2.new(1, -74, 0.5, -11)
    valueLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    valueLabel.Text = "0"
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextSize = 11
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Parent = row

    local valueLabelCorner = Instance.new("UICorner")
    valueLabelCorner.CornerRadius = UDim.new(0, 4)
    valueLabelCorner.Parent = valueLabel

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 24, 0, 22)
    plusBtn.Position = UDim2.new(1, -32, 0.5, -11)
    plusBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.TextSize = 14
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.Parent = row

    local plusBtnCorner = Instance.new("UICorner")
    plusBtnCorner.CornerRadius = UDim.new(0, 4)
    plusBtnCorner.Parent = plusBtn

    minusBtn.MouseButton1Click:Connect(function()
        local current = currentConfig[key] or 0
        local newValue = math.max(min, current - step)
        Events.AdminCommand:FireServer("setconfig", key, tostring(newValue))
    end)

    plusBtn.MouseButton1Click:Connect(function()
        local current = currentConfig[key] or 0
        local newValue = math.min(max, current + step)
        Events.AdminCommand:FireServer("setconfig", key, tostring(newValue))
    end)

    return valueLabel
end

-- Create subsection label
local function CreateSubsection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(150, 180, 255)
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = settingsScroll
end

-- Load settings button
local loadSettingsBtn = Instance.new("TextButton")
loadSettingsBtn.Size = UDim2.new(1, -10, 0, 30)
loadSettingsBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
loadSettingsBtn.Text = "🔄 설정 불러오기"
loadSettingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
loadSettingsBtn.TextSize = 12
loadSettingsBtn.Font = Enum.Font.GothamMedium
loadSettingsBtn.Parent = settingsScroll

local loadSettingsBtnCorner = Instance.new("UICorner")
loadSettingsBtnCorner.CornerRadius = UDim.new(0, 6)
loadSettingsBtnCorner.Parent = loadSettingsBtn

loadSettingsBtn.MouseButton1Click:Connect(function()
    Events.AdminCommand:FireServer("getconfig")
end)

-- Subsection: Game
CreateSubsection("🎮 게임")
local minPlayersCtrl = CreateNumberSetting("MIN_PLAYERS", "최소 플레이어", 1, 10, 1)
local lobbyCountdownCtrl = CreateNumberSetting("LOBBY_COUNTDOWN", "로비 카운트다운", 5, 60, 5)
local intermissionCtrl = CreateNumberSetting("INTERMISSION", "인터미션", 5, 60, 5)

-- Subsection: Obstacles
CreateSubsection("🚧 장애물 활성화")
local toggleRotatingBars = CreateToggleSetting("EnableRotatingBars", "🔄 회전 막대")
local toggleJumpPads = CreateToggleSetting("EnableJumpPads", "⬆️ 점프 패드")
local toggleSlime = CreateToggleSetting("EnableSlime", "💚 슬라임")
local togglePunching = CreateToggleSetting("EnablePunchingGloves", "👊 펀칭 글러브")
local toggleQuizGates = CreateToggleSetting("EnableQuizGates", "❓ 퀴즈 게이트")
local toggleElevators = CreateToggleSetting("EnableElevators", "🛗 엘리베이터")
local toggleBridge = CreateToggleSetting("EnableDisappearingBridge", "🌉 사라지는 다리")
local toggleConveyor = CreateToggleSetting("EnableConveyorBelt", "➡️ 컨베이어")
local toggleElectric = CreateToggleSetting("EnableElectricFloor", "⚡ 전기 바닥")
local toggleBoulder = CreateToggleSetting("EnableRollingBoulder", "🪨 굴러오는 바위")

-- Subsection: Balance
CreateSubsection("⚖️ 밸런스")
local obstacleSpeedCtrl = CreateNumberSetting("ObstacleSpeed", "장애물 속도", 0.5, 3.0, 0.1)
local slimeSlowCtrl = CreateNumberSetting("SlimeSlowFactor", "슬라임 감속", 0.1, 0.9, 0.1)

-- Update UI when config is received
local function UpdateSettingsUI(config)
    currentConfig = config

    -- Update number controls
    if minPlayersCtrl then minPlayersCtrl.Text = tostring(config.MIN_PLAYERS or 1) end
    if lobbyCountdownCtrl then lobbyCountdownCtrl.Text = tostring(config.LOBBY_COUNTDOWN or 15) end
    if intermissionCtrl then intermissionCtrl.Text = tostring(config.INTERMISSION or 20) end
    if obstacleSpeedCtrl then obstacleSpeedCtrl.Text = string.format("%.1f", config.ObstacleSpeed or 1.0) end
    if slimeSlowCtrl then slimeSlowCtrl.Text = string.format("%.1f", config.SlimeSlowFactor or 0.4) end

    -- Update toggle controls
    local toggles = {
        {ctrl = toggleRotatingBars, key = "EnableRotatingBars"},
        {ctrl = toggleJumpPads, key = "EnableJumpPads"},
        {ctrl = toggleSlime, key = "EnableSlime"},
        {ctrl = togglePunching, key = "EnablePunchingGloves"},
        {ctrl = toggleQuizGates, key = "EnableQuizGates"},
        {ctrl = toggleElevators, key = "EnableElevators"},
        {ctrl = toggleBridge, key = "EnableDisappearingBridge"},
        {ctrl = toggleConveyor, key = "EnableConveyorBelt"},
        {ctrl = toggleElectric, key = "EnableElectricFloor"},
        {ctrl = toggleBoulder, key = "EnableRollingBoulder"},
    }

    for _, toggle in ipairs(toggles) do
        local enabled = config[toggle.key]
        if enabled then
            toggle.ctrl.Text = "ON"
            toggle.ctrl.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
        else
            toggle.ctrl.Text = "OFF"
            toggle.ctrl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end
end

-- Update settings layout canvas size
settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    settingsScroll.CanvasSize = UDim2.new(0, 0, 0, settingsLayout.AbsoluteContentSize.Y + 10)
end)

-- Section: Player Management
CreateSection("👥 플레이어 관리")

-- Player list container
local playerFrame = Instance.new("Frame")
playerFrame.Name = "PlayerFrame"
playerFrame.Size = UDim2.new(1, 0, 0, 200)
playerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
playerFrame.BorderSizePixel = 0
playerFrame.Parent = contentFrame

local playerFrameCorner = Instance.new("UICorner")
playerFrameCorner.CornerRadius = UDim.new(0, 8)
playerFrameCorner.Parent = playerFrame

-- Refresh button
local refreshPlayersBtn = Instance.new("TextButton")
refreshPlayersBtn.Size = UDim2.new(1, -10, 0, 25)
refreshPlayersBtn.Position = UDim2.new(0, 5, 0, 5)
refreshPlayersBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
refreshPlayersBtn.Text = "🔄 플레이어 목록 새로고침"
refreshPlayersBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshPlayersBtn.TextSize = 11
refreshPlayersBtn.Font = Enum.Font.GothamMedium
refreshPlayersBtn.Parent = playerFrame

local refreshPlayersBtnCorner = Instance.new("UICorner")
refreshPlayersBtnCorner.CornerRadius = UDim.new(0, 6)
refreshPlayersBtnCorner.Parent = refreshPlayersBtn

refreshPlayersBtn.MouseButton1Click:Connect(function()
    Events.AdminCommand:FireServer("getplayers")
end)

-- Player list scroll
local playerListScroll = Instance.new("ScrollingFrame")
playerListScroll.Size = UDim2.new(1, -10, 1, -35)
playerListScroll.Position = UDim2.new(0, 5, 0, 32)
playerListScroll.BackgroundTransparency = 1
playerListScroll.ScrollBarThickness = 4
playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListScroll.Parent = playerFrame

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0, 3)
playerListLayout.Parent = playerListScroll

-- Selected player
local selectedPlayer = nil

-- Player list cache
local playerListCache = {}

-- Create player row
local function CreatePlayerRow(playerData)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 35)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 75)
    row.BorderSizePixel = 0
    row.Parent = playerListScroll

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    -- Status indicator
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(0, 8, 0.5, -4)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = row

    local statusDotCorner = Instance.new("UICorner")
    statusDotCorner.CornerRadius = UDim.new(1, 0)
    statusDotCorner.Parent = statusDot

    if playerData.isRacing then
        if playerData.hasFinished then
            statusDot.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold - finished
        else
            statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green - racing
        end
    else
        statusDot.BackgroundColor3 = Color3.fromRGB(150, 150, 150) -- Gray - lobby
    end

    -- Admin badge
    local adminBadge = ""
    if playerData.isAdmin then
        adminBadge = "👑 "
    end

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.5, -20, 1, 0)
    nameLabel.Position = UDim2.new(0, 20, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = adminBadge .. playerData.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = row

    -- Level
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Size = UDim2.new(0, 50, 1, 0)
    levelLabel.Position = UDim2.new(0.5, -25, 0, 0)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "Lv." .. playerData.level
    levelLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    levelLabel.TextSize = 10
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.Parent = row

    -- Select button
    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 50, 0, 22)
    selectBtn.Position = UDim2.new(1, -55, 0.5, -11)
    selectBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
    selectBtn.Text = "선택"
    selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.TextSize = 10
    selectBtn.Font = Enum.Font.GothamMedium
    selectBtn.Parent = row

    local selectBtnCorner = Instance.new("UICorner")
    selectBtnCorner.CornerRadius = UDim.new(0, 4)
    selectBtnCorner.Parent = selectBtn

    selectBtn.MouseButton1Click:Connect(function()
        selectedPlayer = playerData.name
        UpdateSelectedPlayerUI()
        ShowStatus("👤 선택됨: " .. playerData.name)
    end)

    -- Hover effect
    local hoverBtn = Instance.new("TextButton")
    hoverBtn.Size = UDim2.new(0.7, 0, 1, 0)
    hoverBtn.BackgroundTransparency = 1
    hoverBtn.Text = ""
    hoverBtn.Parent = row

    hoverBtn.MouseEnter:Connect(function()
        row.BackgroundColor3 = Color3.fromRGB(55, 55, 95)
    end)
    hoverBtn.MouseLeave:Connect(function()
        row.BackgroundColor3 = Color3.fromRGB(45, 45, 75)
    end)

    return row
end

-- Update player list UI
local function UpdatePlayerListUI(players)
    playerListCache = players

    -- Clear existing
    for _, child in ipairs(playerListScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for _, playerData in ipairs(players) do
        CreatePlayerRow(playerData)
    end

    -- Update canvas size
    playerListScroll.CanvasSize = UDim2.new(0, 0, 0, #players * 38)
end

-- Selected player actions frame
local actionsFrame = Instance.new("Frame")
actionsFrame.Name = "ActionsFrame"
actionsFrame.Size = UDim2.new(1, 0, 0, 180)
actionsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
actionsFrame.BorderSizePixel = 0
actionsFrame.Parent = contentFrame

local actionsFrameCorner = Instance.new("UICorner")
actionsFrameCorner.CornerRadius = UDim.new(0, 8)
actionsFrameCorner.Parent = actionsFrame

-- Selected player label
local selectedPlayerLabel = Instance.new("TextLabel")
selectedPlayerLabel.Size = UDim2.new(1, -10, 0, 25)
selectedPlayerLabel.Position = UDim2.new(0, 5, 0, 5)
selectedPlayerLabel.BackgroundTransparency = 1
selectedPlayerLabel.Text = "👤 플레이어를 선택하세요"
selectedPlayerLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
selectedPlayerLabel.TextSize = 12
selectedPlayerLabel.Font = Enum.Font.GothamBold
selectedPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedPlayerLabel.Parent = actionsFrame

-- Action buttons container
local actionButtonsFrame = Instance.new("Frame")
actionButtonsFrame.Size = UDim2.new(1, -10, 1, -35)
actionButtonsFrame.Position = UDim2.new(0, 5, 0, 30)
actionButtonsFrame.BackgroundTransparency = 1
actionButtonsFrame.Parent = actionsFrame

local actionButtonsLayout = Instance.new("UIGridLayout")
actionButtonsLayout.CellSize = UDim2.new(0.5, -3, 0, 28)
actionButtonsLayout.CellPadding = UDim2.new(0, 6, 0, 4)
actionButtonsLayout.Parent = actionButtonsFrame

-- Helper to create action button
local function CreateActionButton(text, color, callback)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = actionButtonsFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        if selectedPlayer then
            callback(selectedPlayer)
        else
            ShowStatus("❌ 플레이어를 먼저 선택하세요", true)
        end
    end)

    return btn
end

-- Teleport buttons
CreateActionButton("🏠 로비로", Color3.fromRGB(60, 120, 60), function(name)
    Events.AdminCommand:FireServer("teleportplayer", name, "lobby")
end)

CreateActionButton("🏁 레이스로", Color3.fromRGB(60, 100, 160), function(name)
    Events.AdminCommand:FireServer("teleportplayer", name, "race")
end)

CreateActionButton("📍 내게로", Color3.fromRGB(100, 80, 160), function(name)
    Events.AdminCommand:FireServer("teleportplayer", name, "tome")
end)

CreateActionButton("💚 힐", Color3.fromRGB(80, 160, 80), function(name)
    Events.AdminCommand:FireServer("heal", name)
end)

-- Item buttons
CreateActionButton("🚀 부스터", Color3.fromRGB(255, 150, 50), function(name)
    Events.AdminCommand:FireServer("giveitem", name, "Booster")
end)

CreateActionButton("🛡️ 실드", Color3.fromRGB(100, 150, 255), function(name)
    Events.AdminCommand:FireServer("giveitem", name, "Shield")
end)

CreateActionButton("🍌 바나나", Color3.fromRGB(255, 220, 100), function(name)
    Events.AdminCommand:FireServer("giveitem", name, "Banana")
end)

CreateActionButton("⚡ 번개", Color3.fromRGB(255, 255, 100), function(name)
    Events.AdminCommand:FireServer("giveitem", name, "Lightning")
end)

-- XP/Level buttons
CreateActionButton("⭐ +100 XP", Color3.fromRGB(180, 150, 50), function(name)
    Events.AdminCommand:FireServer("givexp", name, 100)
end)

CreateActionButton("🚫 추방", Color3.fromRGB(200, 60, 60), function(name)
    Events.AdminCommand:FireServer("kickplayer", name)
end)

-- Update selected player UI
function UpdateSelectedPlayerUI()
    if selectedPlayer then
        selectedPlayerLabel.Text = "👤 선택됨: " .. selectedPlayer
    else
        selectedPlayerLabel.Text = "👤 플레이어를 선택하세요"
    end
end

-- Heal All button
CreateButton("💚 전체 힐", Color3.fromRGB(80, 160, 80), function()
    Events.AdminCommand:FireServer("heal", "all")
end)

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 50)
statusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.Visible = false
statusLabel.Parent = contentFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusLabel

-- Update canvas size
contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 20)
end)

-- Toggle admin panel
local function ToggleAdminPanel()
    AdminPanel.visible = not AdminPanel.visible
    adminFrame.Visible = AdminPanel.visible

    if AdminPanel.visible then
        -- Request course info when opening
        Events.AdminCommand:FireServer("courseinfo")
    end
end

-- Close button
closeBtn.MouseButton1Click:Connect(function()
    AdminPanel.visible = false
    adminFrame.Visible = false
end)

-- Show status message
local function ShowStatus(message, isError)
    statusLabel.Text = message
    statusLabel.TextColor3 = isError and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
    statusLabel.Visible = true

    task.delay(5, function()
        statusLabel.Visible = false
    end)
end

-- Update course list UI
local function UpdateCourseListUI(courses)
    -- Clear existing items
    for _, child in ipairs(courseListScroll:GetChildren()) do
        if child:IsA("TextButton") or (child:IsA("TextLabel") and child.Name == "Placeholder") then
            child:Destroy()
        end
    end

    if #courses == 0 then
        local placeholder = Instance.new("TextLabel")
        placeholder.Name = "Placeholder"
        placeholder.Size = UDim2.new(1, 0, 0, 30)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "코스가 없습니다"
        placeholder.TextColor3 = Color3.fromRGB(120, 120, 120)
        placeholder.TextSize = 12
        placeholder.Font = Enum.Font.Gotham
        placeholder.Parent = courseListScroll
        return
    end

    for _, course in ipairs(courses) do
        local courseBtn = Instance.new("TextButton")
        courseBtn.Size = UDim2.new(1, -10, 0, 35)
        courseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 90)
        courseBtn.Text = string.format("  %s (%s)", course.name, course.difficulty)
        courseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        courseBtn.TextSize = 12
        courseBtn.Font = Enum.Font.Gotham
        courseBtn.TextXAlignment = Enum.TextXAlignment.Left
        courseBtn.Parent = courseListScroll

        local courseBtnCorner = Instance.new("UICorner")
        courseBtnCorner.CornerRadius = UDim.new(0, 6)
        courseBtnCorner.Parent = courseBtn

        courseBtn.MouseButton1Click:Connect(function()
            Events.AdminCommand:FireServer("setcourse", course.id, "library")
        end)

        -- Hover effect
        courseBtn.MouseEnter:Connect(function()
            courseBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 120)
        end)
        courseBtn.MouseLeave:Connect(function()
            courseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 90)
        end)
    end

    -- Update canvas size
    courseListScroll.CanvasSize = UDim2.new(0, 0, 0, #courses * 40)
end

-- Handle admin command responses
Events.AdminCommand.OnClientEvent:Connect(function(action, data)
    if action == "CourseList" then
        AdminPanel.courses = data
        UpdateCourseListUI(data)
        ShowStatus(string.format("📚 %d개의 코스를 찾았습니다", #data))

    elseif action == "CourseInfo" then
        AdminPanel.currentCourse = data
        courseInfoLabel.Text = string.format("📋 현재 코스: %s (by %s) - %d 기믹",
            data.name, data.author, data.gimmickCount)

        -- Render course preview
        if data.gimmicks and #data.gimmicks > 0 then
            previewPlaceholder.Visible = false
            RenderCoursePreview(data)
        else
            previewPlaceholder.Visible = true
            previewPlaceholder.Text = "미리보기 데이터 없음"
        end

    elseif action == "Success" then
        ShowStatus("✅ " .. data)
        Events.AdminCommand:FireServer("courseinfo")  -- Refresh course info

    elseif action == "ConfigData" then
        -- Received config data
        UpdateSettingsUI(data)
        ShowStatus("⚙️ 설정을 불러왔습니다")

    elseif action == "PlayerList" then
        -- Received player list
        UpdatePlayerListUI(data)
        ShowStatus(string.format("👥 %d명의 플레이어", #data))

    elseif action == "AutoSyncNotify" then
        -- GitHub 자동 동기화 알림
        ShowStatus(data.message)
        -- 토스트 알림도 표시
        if autoSyncStatusLabel then
            autoSyncStatusLabel.Text = "🔄 " .. (data.message or "업데이트됨")
            task.delay(5, function()
                if autoSyncStatusLabel then
                    autoSyncStatusLabel.Text = "🔄 Auto-Sync: ON"
                end
            end)
        end

    elseif action == "AutoSyncStatus" then
        -- 자동 동기화 상태 정보
        if data then
            local statusText = data.enabled and "ON" or "OFF"
            if autoSyncStatusLabel then
                autoSyncStatusLabel.Text = string.format("🔄 Auto-Sync: %s (v%s)",
                    statusText, data.lastVersion or "?")
            end
            ShowStatus(string.format("🔄 Auto-Sync: %s | Interval: %ds | Last: %s",
                statusText, data.interval or 30, data.lastVersion or "unknown"))
        end

    elseif action == "Error" then
        ShowStatus("❌ " .. data, true)
    end
end)

-- Handle config updates from server
Events.ConfigUpdate.OnClientEvent:Connect(function(key, value)
    -- Update local config cache
    currentConfig[key] = value

    -- Refresh the settings UI
    UpdateSettingsUI(currentConfig)
end)

-- ============================================
-- ⌨️ INPUT HANDLING
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Q: Use Item
    if input.KeyCode == Enum.KeyCode.Q then
        if PlayerState.currentItem then
            Events.UseItem:FireServer(PlayerState.currentItem)
        end
    end

    -- F7: Toggle Admin Panel
    if input.KeyCode == Enum.KeyCode.F7 then
        ToggleAdminPanel()
    end
end)

-- ============================================
-- 🔄 MAIN LOOP
-- ============================================
RunService.Heartbeat:Connect(function(dt)
    -- Trail effects
    if PlayerState.isRacing then
        UpdateTrailEffects()
    end
end)

-- ============================================
-- 🚀 INITIALIZATION
-- ============================================
-- Request initial data
task.delay(1, function()
    -- Initial UI state
    UpdateProgress(0)

    print("✅ Quiz Castle v3.2 Client Ready!")
end)
