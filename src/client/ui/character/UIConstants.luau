local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local C = {}

-- Из конфига
C.cols = Config.Inventory.Columns       -- 8
C.totalRows = Config.Inventory.Rows     -- 5
C.displayRows = C.totalRows - 1         -- 4
C.slotSize = Config.Inventory.SlotSize  -- 50
C.padding = 5

-- Подсчёт слотов по сторонам
local leftCount = 0
local rightCount = 0
for _, sc in Config.Equipment.Slots do
    if sc.Side == "Right" then
        rightCount += 1
    else
        leftCount += 1
    end
end

C.leftEquipCount = leftCount
C.rightEquipCount = rightCount

-- Панель экипировки
C.equipPanelInner = C.padding + C.slotSize + 6 + 40 + C.padding
C.equipPanelHeight = C.padding + math.max(leftCount, rightCount) * (C.slotSize + C.padding)

-- Ширина инвентаря
C.invGridWidth = C.padding + C.cols * (C.slotSize + C.padding)

-- Ширина окна = инвентарь (ActionBar и панели вписываются в эту же ширину)
C.windowPadX = 10
C.windowWidth = C.windowPadX * 2 + C.invGridWidth

-- Горизонтальные позиции панелей экипировки (внутри окна)
C.leftPanelX = C.windowPadX
C.rightPanelX = C.windowWidth - C.windowPadX - C.equipPanelInner

-- Вертикаль
C.headerH = 36
C.tabsY = C.headerH
C.tabsH = 28
C.contentY = C.tabsY + C.tabsH + 8

-- Панели экипировки занимают зону от contentY
C.equipZoneY = C.contentY

-- ActionBar начинается ПОД панелями экипировки
C.actionRowY = C.equipZoneY + C.equipPanelHeight + 8
C.actionRowLabelH = 14
C.actionRowTotalH = C.slotSize + C.actionRowLabelH + 2

C.contentH = C.actionRowY - C.contentY - 4
C.contentWidth = C.invGridWidth

C.separatorY = C.actionRowY + C.actionRowTotalH + 4
C.separatorH = 2
C.actualInvY = C.separatorY + C.separatorH + 4

C.sortH = 25
C.actualSortY = C.actualInvY + C.displayRows * (C.slotSize + C.padding) + 4
C.windowHeight = C.actualSortY + C.sortH + 10

-- Цвета
C.slotBg = Color3.fromRGB(50, 50, 65)
C.slotBgFilled = Color3.fromRGB(60, 60, 80)
C.slotBgDrag = Color3.fromRGB(80, 80, 110)
C.slotBgTarget = Color3.fromRGB(80, 120, 80)
C.slotBorder = Color3.fromRGB(80, 80, 100)
C.windowBg = Color3.fromRGB(25, 25, 35)
C.panelBg = Color3.fromRGB(35, 35, 50)
C.tabActive = Color3.fromRGB(60, 100, 60)
C.tabInactive = Color3.fromRGB(50, 50, 70)
C.textColor = Color3.fromRGB(220, 220, 220)
C.bindColor = Color3.fromRGB(180, 180, 100)
C.activeStrokeColor = Color3.fromRGB(50, 130, 255)

-- ═══ HUD Bar Constants ═══
C.FLASK_WIDTH = 50
C.GAP = 8
C.MARGIN = 10
C.AB_HEIGHT = C.slotSize + 20  -- 70

C.HP_HEIGHT = 22
C.XP_HEIGHT = 6
C.LEVEL_SIZE = 34
C.LEVEL_GAP = 6

C.AB_WIDTH = C.padding + C.cols * (C.slotSize + C.padding)
C.HP_BAR_WIDTH = C.AB_WIDTH - C.LEVEL_GAP - C.LEVEL_SIZE
C.HP_BLOCK_H = C.HP_HEIGHT + 2 + C.XP_HEIGHT

-- Colors (HUD)
C.BG_COLOR = Color3.fromRGB(25, 25, 35)
C.HP_GREEN = Color3.fromRGB(50, 200, 50)
C.HP_YELLOW = Color3.fromRGB(220, 180, 30)
C.HP_RED = Color3.fromRGB(200, 30, 30)
C.XP_COLOR = Color3.fromRGB(100, 80, 220)
C.XP_BG = Color3.fromRGB(18, 18, 26)
C.LEVEL_BG = Color3.fromRGB(35, 30, 55)
C.LEVEL_BORDER = Color3.fromRGB(60, 15, 15)
C.TEXT_COLOR = Color3.fromRGB(255, 255, 255)
C.TEXT_DIM = Color3.fromRGB(180, 180, 200)

return C