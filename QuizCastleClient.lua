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

-- Item Slot (Bottom Left) - 투명 배경
local itemSlot = Instance.new("Frame")
itemSlot.Name = "ItemSlot"
itemSlot.Size = UDim2.new(0, 70, 0, 70)
itemSlot.Position = UDim2.new(0, 15, 1, -90)
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

local function ShowBanner(text, duration, color)
    bannerText.Text = text
    bannerText.TextColor3 = color or Color3.new(1, 1, 1)
    
    local showTween = TweenService:Create(titleBanner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -250, 0, 20)
    })
    showTween:Play()
    
    task.delay(duration or 3, function()
        local hideTween = TweenService:Create(titleBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -250, 0, -100)
        })
        hideTween:Play()
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
