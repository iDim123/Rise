local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local JC = require(script.Parent:WaitForChild("JournalConstants"))

local JournalWindow = {}

local isOpen = false
local activePage = nil -- "Bosses" | "Spellbook" | "Map"
local pages = {} -- [pageName] = { frame, module }
local screenGui, mainFrame, navBar, contentFrame
local bgImage

local WindowManager
-- ═══ Navbar pages config ═══
local PAGE_ORDER = {"Map", "Bosses", "Spellbook"}

local navButtons = {}

-- ═══ Build ═══
function JournalWindow.build()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "JournalGui"
    screenGui.DisplayOrder = 850
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "JournalWindow"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = JC.BG_COLOR
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Active = true
    mainFrame.Parent = screenGui

    -- Background image (same as BossJournal)
    bgImage = Instance.new("ImageLabel")
    bgImage.Name = "BackgroundImage"
    bgImage.Size = UDim2.new(1, 0, 1, 0)
    bgImage.BackgroundTransparency = 1
    bgImage.Image = "rbxassetid://130567382079214"
    bgImage.ImageTransparency = 0.4
    bgImage.ScaleType = Enum.ScaleType.Crop
    bgImage.Parent = mainFrame

    local overlay = Instance.new("Frame")
    overlay.Name = "DarkOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.Parent = mainFrame

    -- ═══ Navbar ═══
    navBar = Instance.new("Frame")
    navBar.Name = "Navbar"
    navBar.Size = UDim2.new(1, 0, 0, JC.NAVBAR_H)
    navBar.BackgroundColor3 = JC.NAVBAR_BG
    navBar.BackgroundTransparency = 0.3
    navBar.BorderSizePixel = 0
    navBar.ZIndex = 5
    navBar.Parent = mainFrame

    -- Navbar bottom separator
    local navSep = Instance.new("Frame")
    navSep.Size = UDim2.new(1, 0, 0, 1)
    navSep.Position = UDim2.new(0, 0, 1, 0)
    navSep.AnchorPoint = Vector2.new(0, 1)
    navSep.BackgroundColor3 = JC.STROKE_COLOR
    navSep.BackgroundTransparency = 0.5
    navSep.BorderSizePixel = 0
    navSep.ZIndex = 5
    navSep.Parent = navBar

    -- Nav tabs centered
    local navTabContainer = Instance.new("Frame")
    navTabContainer.Name = "NavTabs"
    navTabContainer.Size = UDim2.new(0, #PAGE_ORDER * (JC.TAB_WIDTH + JC.TAB_GAP) - JC.TAB_GAP, 1, 0)
    navTabContainer.AnchorPoint = Vector2.new(0.5, 0)
    navTabContainer.Position = UDim2.new(0.5, 0, 0, 0)
    navTabContainer.BackgroundTransparency = 1
    navTabContainer.ZIndex = 5
    navTabContainer.Parent = navBar

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Horizontal
    navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, JC.TAB_GAP)
    navLayout.Parent = navTabContainer

    for i, pageName in PAGE_ORDER do
        local btn = Instance.new("TextButton")
        btn.Name = "NavBtn_" .. pageName
        btn.Size = UDim2.new(0, JC.TAB_WIDTH, 0, JC.NAVBAR_H - 8)
        btn.BackgroundTransparency = 1
        btn.AutoButtonColor = false
        btn.Text = pageName
        btn.TextColor3 = JC.TEXT_DIM
        btn.TextSize = 16
        btn.Font = Enum.Font.GothamBold
        btn.LayoutOrder = i
        btn.ZIndex = 6
        btn.Parent = navTabContainer

        -- Underline indicator
        local underline = Instance.new("Frame")
        underline.Name = "Underline"
        underline.Size = UDim2.new(1, 0, 0, 2)
        underline.AnchorPoint = Vector2.new(0, 1)
        underline.Position = UDim2.new(0, 0, 1, 0)
        underline.BackgroundColor3 = JC.TEXT_COLOR
        underline.BorderSizePixel = 0
        underline.Visible = false
        underline.ZIndex = 6
        underline.Parent = btn

        navButtons[pageName] = {
            button = btn,
            underline = underline
        }

        btn.Activated:Connect(function()
            JournalWindow.switchPage(pageName)
        end)

        btn.MouseEnter:Connect(function()
            if activePage ~= pageName then
                btn.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end)

        btn.MouseLeave:Connect(function()
            if activePage ~= pageName then
                btn.TextColor3 = JC.TEXT_DIM
            end
        end)
    end

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.BackgroundColor3 = JC.CLOSE_BG
    closeBtn.TextColor3 = JC.CLOSE_TEXT
    closeBtn.Text = "x"
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 6
    closeBtn.Parent = navBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    closeBtn.Activated:Connect(function()
        JournalWindow.close()
    end)

    -- ═══ Content area (below navbar) ═══
    contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, 0, 1, -JC.NAVBAR_H)
    contentFrame.Position = UDim2.new(0, 0, 0, JC.NAVBAR_H)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ZIndex = 2
    contentFrame.Parent = mainFrame

    return screenGui, contentFrame
end

function JournalWindow.setWindowManager(wm)
    WindowManager = wm
end

-- ═══ Register a page ═══
function JournalWindow.registerPage(pageName, pageModule)
    pages[pageName] = {
        module = pageModule,
        built = false
    }
end

-- ═══ Switch page ═══
function JournalWindow.switchPage(pageName)
    if not pages[pageName] then
        warn("[JournalWindow] Unknown page:", pageName)
        return
    end

    -- Hide all pages
    for name, pageData in pages do
        if pageData.module.setVisible then
            pageData.module.setVisible(false)
        end
    end

    -- Update nav buttons
    for name, data in navButtons do
        if name == pageName then
            data.button.TextColor3 = JC.TEXT_COLOR
            data.underline.Visible = true
        else
            data.button.TextColor3 = JC.TEXT_DIM
            data.underline.Visible = false
        end
    end

    -- Build if first time
    local pageData = pages[pageName]
    if not pageData.built then
        if pageData.module.build then
            pageData.module.build(contentFrame, screenGui)
        end
        pageData.built = true
    end

    -- Show and activate
    if pageData.module.setVisible then
        pageData.module.setVisible(true)
    end
    if pageData.module.onActivate then
        pageData.module.onActivate()
    end

    activePage = pageName
end

-- ═══ Open / Close / Toggle ═══
function JournalWindow.open(pageName)
    if isOpen and activePage == pageName then
        return
    end
    mainFrame.Visible = true
    isOpen = true
    JournalWindow.switchPage(pageName or activePage or "Bosses")

    if WindowManager then
        WindowManager.push("JournalWindow", function()
            JournalWindow.close()
        end)
    end
end

function JournalWindow.close()
    if not isOpen then
        return
    end
    mainFrame.Visible = false
    isOpen = false

    -- Notify active page
    if activePage and pages[activePage] and pages[activePage].module.onDeactivate then
        pages[activePage].module.onDeactivate()
    end

    if WindowManager then
        WindowManager.remove("JournalWindow")
    end
end

function JournalWindow.toggle(pageName)
    if isOpen then
        if pageName and activePage ~= pageName then
            JournalWindow.switchPage(pageName)
        else
            JournalWindow.close()
        end
    else
        JournalWindow.open(pageName)
    end
end

function JournalWindow.isOpen()
    return isOpen
end

function JournalWindow.getScreenGui()
    return screenGui
end

function JournalWindow.setBackground(imageId)
    if bgImage then
        bgImage.Image = imageId or JC.DEFAULT_BG
    end
end

return JournalWindow
