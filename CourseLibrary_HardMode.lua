--[[
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🏰 QUIZ CASTLE - COURSE: HARD MODE                          ║
║                                                                                ║
║  📁 ReplicatedStorage/CourseLibrary 폴더에 ModuleScript로 넣으세요!            ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
]]

return {
    metadata = {
        id = "hardmode",
        name = "Quiz Castle Hard Mode",
        author = "System",
        version = "1.0",
        length = 2000,
        difficulty = "hard",
        description = "고난이도 코스 - 빠른 장애물, 많은 퀴즈"
    },
    gimmicks = {
        -- 구간 1: 빠른 시작
        {type = "RotatingBar", z = 40, width = 32, height = 3, speed = 2.5},
        {type = "RotatingBar", z = 70, width = 30, height = 5, speed = -2.2},
        {type = "RotatingBar", z = 100, width = 34, height = 3, speed = 2.8},
        {type = "QuizGate", id = 1, triggerZ = 130, gateZ = 160, options = 3},
        {type = "ElectricFloor", z = 200, length = 40},
        {type = "QuizGate", id = 2, triggerZ = 280, gateZ = 310, options = 4},

        -- 구간 2: 위험 점프
        {type = "SlimeZone", z = 350, length = 60},
        {type = "JumpPad", x = -8, y = 0.5, z = 430},
        {type = "JumpPad", x = 8, y = 0.5, z = 470},
        {type = "JumpPad", x = 0, y = 0.5, z = 510},
        {type = "DisappearingBridge", z = 560, platformCount = 8},
        {type = "Elevator", id = 1, triggerZ = 650, elevZ = 700, options = 4},

        -- 구간 3: 콤보 장애물
        {type = "ConveyorBelt", z = 780, length = 80, direction = -1},
        {type = "RotatingBar", z = 820, width = 36, height = 4, speed = 3},
        {type = "PunchingCorridor", z = 880, length = 120},
        {type = "QuizGate", id = 3, triggerZ = 1020, gateZ = 1050, options = 4},
        {type = "RollingBoulder", zStart = 1100, zEnd = 1300},

        -- 구간 4: 지옥의 계단
        {type = "ElectricFloor", z = 1180, length = 50},
        {type = "SlimeZone", z = 1250, length = 100},
        {type = "RotatingBar", z = 1280, width = 38, height = 3, speed = 3.5},
        {type = "RotatingBar", z = 1320, width = 38, height = 6, speed = -3},
        {type = "QuizGate", id = 4, triggerZ = 1380, gateZ = 1410, options = 3},
        {type = "Elevator", id = 2, triggerZ = 1460, elevZ = 1510, options = 4},

        -- 구간 5: 최종 관문
        {type = "ConveyorBelt", z = 1580, length = 60, direction = -1},
        {type = "PunchingCorridor", z = 1660, length = 80},
        {type = "DisappearingBridge", z = 1760, platformCount = 10},
        {type = "QuizGate", id = 5, triggerZ = 1850, gateZ = 1880, options = 4},
        {type = "RotatingBar", z = 1920, width = 40, height = 3, speed = 4},
        {type = "RotatingBar", z = 1950, width = 40, height = 7, speed = -3.5},
        {type = "ElectricFloor", z = 1980, length = 20}
    }
}
