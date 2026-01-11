--[[
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🏰 QUIZ CASTLE - COURSE: CLASSIC                            ║
║                                                                                ║
║  📁 ReplicatedStorage/CourseLibrary 폴더에 ModuleScript로 넣으세요!            ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
]]

return {
    metadata = {
        id = "classic",
        name = "Quiz Castle Classic",
        author = "System",
        version = "3.2",
        length = 2000,
        difficulty = "medium",
        description = "기본 코스 - 균형 잡힌 난이도"
    },
    gimmicks = {
        -- 구간 1: 워밍업
        {type = "RotatingBar", z = 60, width = 28, height = 3, speed = 1.5},
        {type = "RotatingBar", z = 100, width = 30, height = 3, speed = 1.8},
        {type = "QuizGate", id = 1, triggerZ = 150, gateZ = 180, options = 2},
        {type = "RotatingBar", z = 250, width = 26, height = 3, speed = 2},
        {type = "QuizGate", id = 2, triggerZ = 320, gateZ = 350, options = 3},

        -- 구간 2: 점프 & 엘리베이터
        {type = "JumpPad", x = 0, y = 0.5, z = 430},
        {type = "JumpPad", x = 0, y = 0.5, z = 500},
        {type = "JumpPad", x = 0, y = 0.5, z = 570},
        {type = "Elevator", id = 1, triggerZ = 620, elevZ = 670, options = 3},
        {type = "DisappearingBridge", z = 750, platformCount = 6},

        -- 구간 3: 슬라임 & 퀴즈
        {type = "SlimeZone", z = 830, length = 80},
        {type = "QuizGate", id = 3, triggerZ = 960, gateZ = 990, options = 4},
        {type = "ConveyorBelt", z = 1040, length = 60, direction = -1},
        {type = "ElectricFloor", z = 1130, length = 60},

        -- 구간 4: 위험지대
        {type = "RollingBoulder", zStart = 1220, zEnd = 1380},
        {type = "PunchingCorridor", z = 1280, length = 100},
        {type = "QuizGate", id = 4, triggerZ = 1420, gateZ = 1450, options = 3},
        {type = "Elevator", id = 2, triggerZ = 1500, elevZ = 1550, options = 4},

        -- 구간 5: 파이널
        {type = "SlimeZone", z = 1620, length = 70},
        {type = "RotatingBar", z = 1730, width = 34, height = 3, speed = 2.5},
        {type = "RotatingBar", z = 1760, width = 34, height = 7, speed = -2},
        {type = "QuizGate", id = 5, triggerZ = 1800, gateZ = 1830, options = 2},
        {type = "ConveyorBelt", z = 1860, length = 40, direction = -1},
        {type = "ElectricFloor", z = 1920, length = 50},
        {type = "RotatingBar", z = 1970, width = 36, height = 3, speed = 3}
    }
}
