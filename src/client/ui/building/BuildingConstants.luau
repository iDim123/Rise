--[[
    BuildingConstants.luau
    Константы для строительной системы (клиент).
    
    Формат: как AbilitiesConstants.luau
    Цвета: из UIConstants.luau (character)
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local C = {}

-- ═══ Grid ═══
C.GRID_SIZE = Config.Building.GridSize -- 4

-- ═══ Layout ═══
C.SLOT_SIZE = 54
C.PADDING = 5
C.CORNER_RADIUS = 6
C.SMALL_RADIUS = 4
C.HEADER_H = 36
C.TAB_H = 28
C.BUTTON_H = 32
C.WINDOW_PAD = 10
C.COLS = 4 -- блоков в ряду в меню

-- ═══ Позиционирование окна ═══
C.WINDOW_WIDTH = C.WINDOW_PAD * 2 + C.PADDING + C.COLS * (C.SLOT_SIZE + C.PADDING)
C.TOP_OFFSET = 40

-- ═══ Ghost preview ═══
C.GHOST_TRANSPARENCY = 0.5
C.GHOST_VALID_COLOR = Color3.fromRGB(50, 200, 50)
C.GHOST_INVALID_COLOR = Color3.fromRGB(200, 50, 50)
C.GHOST_VALID_BORDER = Color3.fromRGB(80, 255, 80)
C.GHOST_INVALID_BORDER = Color3.fromRGB(255, 80, 80)
C.GHOST_BORDER_THICKNESS = 2

-- ═══ Режим удаления ═══
C.DELETE_HIGHLIGHT_COLOR = Color3.fromRGB(255, 60, 60)
C.DELETE_HIGHLIGHT_TRANSPARENCY = 0.4

-- ═══ Цвета — из UIConstants.luau ═══
C.windowBg = Color3.fromRGB(25, 25, 35)
C.panelBg = Color3.fromRGB(35, 35, 50)
C.slotBg = Color3.fromRGB(50, 50, 65)
C.slotBgHover = Color3.fromRGB(65, 65, 85)
C.slotBorder = Color3.fromRGB(80, 80, 100)
C.textColor = Color3.fromRGB(220, 220, 220)
C.textDim = Color3.fromRGB(180, 180, 200)
C.bindColor = Color3.fromRGB(180, 180, 100)
C.tabActive = Color3.fromRGB(60, 100, 60)
C.tabInactive = Color3.fromRGB(50, 50, 70)
C.activeStrokeColor = Color3.fromRGB(50, 130, 255)

-- Кнопки
C.btnGreen = Color3.fromRGB(50, 130, 50)
C.btnGreenHover = Color3.fromRGB(65, 155, 65)
C.btnRed = Color3.fromRGB(150, 40, 40)
C.btnRedHover = Color3.fromRGB(180, 55, 55)
C.btnBlue = Color3.fromRGB(50, 50, 70)
C.btnBlueHover = Color3.fromRGB(65, 65, 90)
C.btnGold = Color3.fromRGB(180, 150, 50)
C.btnGoldHover = Color3.fromRGB(210, 180, 70)

-- Castle Heart
C.heartColor = Color3.fromRGB(120, 30, 30)
C.heartBorder = Color3.fromRGB(180, 50, 50)
C.hpBarGreen = Color3.fromRGB(50, 200, 50)
C.hpBarYellow = Color3.fromRGB(220, 180, 30)
C.hpBarRed = Color3.fromRGB(200, 30, 30)

-- Стоимость
C.costAfford = Color3.fromRGB(180, 220, 180)
C.costCantAfford = Color3.fromRGB(220, 100, 100)

-- ═══ Floating damage ═══
C.DAMAGE_FLOAT_HEIGHT = 3
C.DAMAGE_LIFETIME = 1.2
C.DAMAGE_TEXT_SIZE = 18
C.DAMAGE_COLOR = Color3.fromRGB(255, 180, 50)

-- ═══ Горячие клавиши ═══
C.KEY_TOGGLE_MENU = Enum.KeyCode.B
C.KEY_ROTATE = Enum.KeyCode.R
C.KEY_DELETE_MODE = Enum.KeyCode.X
C.KEY_CANCEL = Enum.KeyCode.Escape
C.KEY_INTERACT = Enum.KeyCode.F

-- ═══ Категории (из конфига, для удобства) ═══
C.CATEGORIES = Config.Building.BlockCategories

return C
