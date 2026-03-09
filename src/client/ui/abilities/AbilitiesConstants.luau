local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local C = {}

-- Layout
C.SLOT_SIZE = Config.Inventory.SlotSize
C.PADDING = 5
C.CORNER_RADIUS = 6
C.FLASK_WIDTH = 50
C.GAP = 8

-- Colors — General
C.WINDOW_BG = Color3.fromRGB(25, 25, 35)
C.SLOT_BG = Color3.fromRGB(50, 50, 65)
C.SLOT_BORDER = Color3.fromRGB(80, 80, 100)
C.SLOT_BORDER_INACTIVE = Color3.fromRGB(50, 50, 50)
C.BIND_COLOR = Color3.fromRGB(180, 180, 100)
C.COOLDOWN_COLOR = Color3.fromRGB(0, 0, 0)
C.COOLDOWN_TRANSPARENCY = 0.45

-- Colors — Spell slots (R, G)
C.SPELL_SLOT_BG = Color3.fromRGB(40, 35, 55)
C.SPELL_SLOT_BORDER = Color3.fromRGB(100, 70, 130)
C.SPELL_SLOT_BORDER_EMPTY = Color3.fromRGB(60, 50, 75)

-- Colors — Ultimate slot (Z)
C.ULT_SLOT_BG = Color3.fromRGB(50, 30, 50)
C.ULT_SLOT_BORDER = Color3.fromRGB(150, 50, 150)
C.ULT_SLOT_BORDER_EMPTY = Color3.fromRGB(70, 40, 70)

-- Colors — Class slot (X)
C.CLASS_SLOT_BG = Color3.fromRGB(35, 45, 55)
C.CLASS_SLOT_BORDER = Color3.fromRGB(70, 120, 160)
C.CLASS_SLOT_BORDER_EMPTY = Color3.fromRGB(45, 55, 65)

-- Colors — Charges
C.CHARGE_COLOR_ACTIVE = Color3.fromRGB(255, 220, 100)
C.CHARGE_COLOR_EMPTY = Color3.fromRGB(150, 80, 80)

-- Colors — Separator
C.SEPARATOR_COLOR = Color3.fromRGB(80, 80, 100)
C.SEPARATOR_TRANSPARENCY = 0.5

-- Slot definitions per section
C.WEAPON_KEYS = {"LMB", "Q", "E", "Space"}
C.SPELL_KEYS = {"R", "G"}
C.ULT_KEYS = {"Z"}
C.CLASS_KEYS = {"X"}
C.ALL_KEYS = {"LMB", "Q", "E", "Space", "R", "G", "Z", "X"}

-- KeyCode mapping
C.KEYCODES = {
    Q = Enum.KeyCode.Q,
    E = Enum.KeyCode.E,
    Space = Enum.KeyCode.Space,
    R = Enum.KeyCode.R,
    G = Enum.KeyCode.G,
    T = Enum.KeyCode.T,
    Z = Enum.KeyCode.Z,
    X = Enum.KeyCode.X
}

return C
