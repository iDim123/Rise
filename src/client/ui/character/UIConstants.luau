local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local C = {}

-- Из конфига
C.cols = Config.Inventory.Columns
C.totalRows = Config.Inventory.Rows
C.displayRows = C.totalRows - 1
C.slotSize = Config.Inventory.SlotSize
C.padding = Config.Inventory.Padding

-- Панели
C.equipSlotCount = #Config.Equipment.Slots
C.equipPanelInner = C.padding + C.slotSize + 6 + 40 + C.padding
C.equipPanelHeight = C.padding + C.equipSlotCount * (C.slotSize + C.padding)
C.invGridWidth = C.padding + C.cols * (C.slotSize + C.padding)
C.contentWidth = C.invGridWidth
C.windowPadX = 10
C.windowWidth = C.windowPadX * 2 + C.contentWidth

-- Вертикаль
C.headerH = 36
C.tabsY = C.headerH
C.tabsH = 28
C.contentY = C.tabsY + C.tabsH + 8
C.contentH = math.max(C.equipPanelHeight, 180) + 30
C.charNameY = C.contentY + C.equipPanelHeight + 4

C.actionRowY = C.charNameY + 30 + 8
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