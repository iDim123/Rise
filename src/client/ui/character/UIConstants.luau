local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local C = {}

-- Из конфига
C.cols = Config.Inventory.Columns
C.totalRows = Config.Inventory.Rows
C.displayRows = C.totalRows - 1
C.slotSize = Config.Inventory.SlotSize
C.padding = Config.Inventory.Padding

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
C.equipPanelInner = C.padding + C.slotSize + 6 + 40 + C.padding
C.equipPanelHeight = C.padding + math.max(leftCount, rightCount) * (C.slotSize + C.padding)

-- Ширина: левая панель + инвентарь + правая панель
C.invGridWidth = C.padding + C.cols * (C.slotSize + C.padding)
C.windowPadX = 10
C.contentWidth = C.equipPanelInner + 8 + C.invGridWidth + 8 + C.equipPanelInner
C.windowWidth = C.windowPadX * 2 + C.contentWidth

-- Позиции панелей внутри окна
C.leftPanelX = C.windowPadX
C.invGridX = C.windowPadX + C.equipPanelInner + 8
C.rightPanelX = C.windowPadX + C.equipPanelInner + 8 + C.invGridWidth + 8

-- Вертикаль
C.headerH = 36
C.tabsY = C.headerH
C.tabsH = 28
C.contentY = C.tabsY + C.tabsH + 8

C.actionRowY = C.contentY
C.actionRowLabelH = 14
C.actionRowTotalH = C.slotSize + C.actionRowLabelH + 2

C.separatorY = C.actionRowY + C.actionRowTotalH + 4
C.separatorH = 2
C.actualInvY = C.separatorY + C.separatorH + 4

C.sortH = 25
C.actualSortY = C.actualInvY + C.displayRows * (C.slotSize + C.padding) + 4

-- Высота окна: больше из (equip панель) и (инвентарь с ActionBar)
local invBottomY = C.actualSortY + C.sortH + 10
local equipBottomY = C.contentY + C.equipPanelHeight + 10
C.windowHeight = math.max(invBottomY, equipBottomY)

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