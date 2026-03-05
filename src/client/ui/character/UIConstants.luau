local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local C = {}

-- Из конфига
C.cols = Config.Inventory.Columns       -- 8
C.totalRows = Config.Inventory.Rows     -- 5
C.displayRows = C.totalRows - 1         -- 4
C.slotSize = Config.Inventory.SlotSize  -- 50
C.padding = Config.Inventory.Padding    -- 4

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

return C