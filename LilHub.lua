--[[
    LilLib — Lightweight, dependency-free GUI library for Lil Script.
    No external loadstring, no third-party lib. Optimized for PC and mobile.

    Public API (kept identical to what LilHub.lua expects):
        Lib = Library.new()
        KS  = Lib:CreateKeySystem({ Title, Theme, Size })
            KS:CreateButton({ Description, Callback })
            KS:GetText()
            KS:Notify({ Title, Description, Duration })
            KS:Destroy()
        Window = Lib:CreateWindow({ Title, Subtitle, Icon, Theme, Size, MinSize, MaxSize,
                                     AutoSave, AutoLoad, TitleConfig, FloatButton, Acrylic, ConfigPanel, ... })
            Window:CreateTab({ Title, Icon }) -> Tab
            Window:Notify({ Title, Description, Duration })
        Tab:CreateSection({ Text })
        Tab:CreateButton({ Title, Description, Confirmation, Callback })
        Tab:CreateToggle({ Title, Default, Callback })
        Tab:CreateSlider({ Title, Min, Max, Default, Callback })
        Tab:CreateDropdown({ Title, Multiple, Options, Callback })
        Tab:CreateTextBox({ Title, Placeholder, Default, MaxLength, Callback })
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled

local Theme = {
    BG        = Color3.fromRGB(12, 9, 18),
    BG_2      = Color3.fromRGB(18, 13, 26),
    SURFACE   = Color3.fromRGB(24, 17, 34),
    SURFACE_2 = Color3.fromRGB(30, 22, 42),
    ACCENT    = Color3.fromRGB(220, 38, 38),
    ACCENT_2  = Color3.fromRGB(153, 27, 27),
    TEXT      = Color3.fromRGB(245, 243, 251),
    SUBTEXT   = Color3.fromRGB(171, 164, 196),
    MUTED     = Color3.fromRGB(114, 108, 136),
    STROKE    = Color3.fromRGB(48, 34, 58),
    SUCCESS   = Color3.fromRGB(74, 222, 128),
    WARN      = Color3.fromRGB(250, 204, 21),
}

--// Helpers ----------------------------------------------------------------

local function New(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            obj[k] = v
        end
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

local function Round(obj, radius)
    New("UICorner", { CornerRadius = UDim.new(0, radius), Parent = obj })
end

local function Stroke(obj, color, thickness)
    New("UIStroke", {
        Parent = obj,
        Color = color or Theme.STROKE,
        Thickness = thickness or 1,
        Transparency = 0.35,
    })
end

local function Pad(obj, all)
    New("UIPadding", {
        Parent = obj,
        PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
        PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
    })
end

local function Tween(obj, time, props, style, dir)
    return TweenService:Create(
        obj,
        TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

-- Works with both mouse (PC) and touch (mobile).
local function MakeDraggable(frame, handle)
    local dragging = false
    local dragInput, startPos, startFramePos

    local function update(input)
        local delta = input.Position - startPos
        frame.Position = UDim2.new(
            startFramePos.X.Scale, startFramePos.X.Offset + delta.X,
            startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = input.Position
            startFramePos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            update(input)
        end
    end)
end

local function ClickFeedback(button, base, hover)
    button.MouseEnter:Connect(function()
        Tween(button, 0.12, { BackgroundColor3 = hover })
    end)
    button.MouseLeave:Connect(function()
        Tween(button, 0.12, { BackgroundColor3 = base })
    end)
end

--// Library ------------------------------------------------------------------

local Library = {}
Library.__index = Library

function Library.new()
    return setmetatable({}, Library)
end

-- Root ScreenGui shared by everything this library creates.
local function GetGui(name)
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild(name)
    if existing then existing:Destroy() end
    return New("ScreenGui", {
        Name = name,
        Parent = pg,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
end

--// Notifications -------------------------------------------------------------

local function AttachNotify(gui)
    local holder = New("Frame", {
        Name = "Notifications",
        Parent = gui,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = IsMobile and UDim2.new(1, -12, 0, 12) or UDim2.new(1, -20, 0, 20),
        Size = UDim2.new(0, IsMobile and 260 or 300, 1, -20),
    })
    local layout = New("UIListLayout", {
        Parent = holder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 8),
    })

    return function(opts)
        opts = opts or {}
        local card = New("Frame", {
            Parent = holder,
            BackgroundColor3 = Theme.SURFACE,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        Round(card, 10)
        Stroke(card, Theme.ACCENT, 1)
        Pad(card, 12)

        local list = New("UIListLayout", { Parent = card, Padding = UDim.new(0, 4) })

        New("TextLabel", {
            Parent = card,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Theme.TEXT,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = opts.Title or "Notice",
        })

        New("TextLabel", {
            Parent = card,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.SUBTEXT,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = opts.Description or "",
        })

        card.BackgroundTransparency = 1
        for _, d in ipairs({ card:GetDescendants() }) do end
        Tween(card, 0.2, { BackgroundTransparency = 0 })

        task.delay(opts.Duration or 3, function()
            if card and card.Parent then
                Tween(card, 0.25, { BackgroundTransparency = 1 })
                for _, d in ipairs(card:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        Tween(d, 0.25, { TextTransparency = 1 })
                    end
                end
                task.wait(0.25)
                card:Destroy()
            end
        end)
    end
end

--// Key System ----------------------------------------------------------------

function Library:CreateKeySystem(cfg)
    cfg = cfg or {}
    local gui = GetGui("LilKeySystem")

    local sizeVec = cfg.Size or Vector2.new(380, 220)
    local main = New("Frame", {
        Parent = gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = IsMobile and UDim2.fromScale(0.86, 0.32) or UDim2.fromOffset(sizeVec.X, sizeVec.Y),
        BackgroundColor3 = Theme.BG,
    })
    Round(main, 16)
    Stroke(main, Theme.ACCENT, 1)

    New("UIGradient", {
        Parent = main,
        Color = ColorSequence.new(Theme.BG, Theme.BG_2),
        Rotation = 90,
    })

    local header = New("Frame", { Parent = main, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60) })
    Pad(header, 18)

    New("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = Theme.TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = cfg.Title or "Key Required",
    })

    local body = New("Frame", {
        Parent = main,
        Position = UDim2.new(0, 0, 0, 60),
        Size = UDim2.new(1, 0, 1, -60),
        BackgroundTransparency = 1,
    })
    Pad(body, 18)
    local bodyLayout = New("UIListLayout", { Parent = body, Padding = UDim.new(0, 12) })

    local input = New("TextBox", {
        Parent = body,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.SURFACE,
        TextColor3 = Theme.TEXT,
        PlaceholderText = "Enter key...",
        PlaceholderColor3 = Theme.MUTED,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        ClearTextOnFocus = false,
    })
    Round(input, 10)
    Stroke(input, Theme.STROKE, 1)
    Pad(input, 10)

    local notify = AttachNotify(gui)

    local KS = {}

    function KS:GetText()
        return input.Text
    end

    function KS:Notify(opts)
        notify(opts)
    end

    function KS:Destroy()
        gui:Destroy()
    end

    function KS:CreateButton(opts)
        opts = opts or {}
        local btn = New("TextButton", {
            Parent = body,
            Size = UDim2.new(1, 0, 0, 46),
            BackgroundColor3 = Theme.ACCENT,
            Text = opts.Description or "Submit",
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextColor3 = Theme.TEXT,
            AutoButtonColor = false,
        })
        Round(btn, 10)
        ClickFeedback(btn, Theme.ACCENT, Theme.ACCENT_2)

        btn.MouseButton1Click:Connect(function()
            if opts.Callback then opts.Callback() end
        end)

        return btn
    end

    return KS
end

--// Main Window ----------------------------------------------------------------

function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local gui = GetGui("LilHub")

    local sizeVec = cfg.Size or Vector2.new(520, 380)
    local minVec = cfg.MinSize or Vector2.new(340, 260)

    local main = New("Frame", {
        Parent = gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = IsMobile and UDim2.fromScale(0.94, 0.78) or UDim2.fromOffset(sizeVec.X, sizeVec.Y),
        BackgroundColor3 = Theme.BG,
        ClipsDescendants = true,
    })
    Round(main, 14)
    Stroke(main, Theme.ACCENT, 1)
    New("UISizeConstraint", { Parent = main, MinSize = minVec })

    New("UIGradient", {
        Parent = main,
        Color = ColorSequence.new(Theme.BG, Theme.BG_2),
        Rotation = 90,
    })

    --// Header
    local headerHeight = IsMobile and 64 or 56
    local header = New("Frame", {
        Parent = main,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, headerHeight),
    })
    Pad(header, 16)

    local titleWords = (cfg.TitleConfig and cfg.TitleConfig.Words and table.concat(cfg.TitleConfig.Words, " ")) or cfg.Title or "Hub"

    local title = New("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -100, 0, 22),
        Font = Enum.Font.GothamBold,
        TextSize = IsMobile and 18 or 20,
        TextColor3 = Theme.TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = titleWords,
    })

    if cfg.TitleConfig and cfg.TitleConfig.Gradient then
        local colors = cfg.TitleConfig.Colors or { Theme.TEXT, Theme.ACCENT }
        New("UIGradient", { Parent = title, Color = ColorSequence.new(colors[1], colors[2] or colors[1]) })
    end

    New("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 24),
        Size = UDim2.new(1, -100, 0, 16),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.SUBTEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = cfg.Subtitle or "",
    })

    local closeBtn = New("TextButton", {
        Parent = header,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.SURFACE,
        Text = "✕",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.TEXT,
        AutoButtonColor = false,
    })
    Round(closeBtn, 8)
    ClickFeedback(closeBtn, Theme.SURFACE, Theme.SURFACE_2)

    local minimizeBtn = closeBtn:Clone()
    minimizeBtn.Text = "—"
    minimizeBtn.Position = UDim2.new(1, -40, 0.5, 0)
    minimizeBtn.Parent = header
    ClickFeedback(minimizeBtn, Theme.SURFACE, Theme.SURFACE_2)

    MakeDraggable(main, header)

    --// Layout: sidebar (tabs) + content
    local sidebarWidth = IsMobile and 96 or 140
    local sidebar = New("Frame", {
        Parent = main,
        Position = UDim2.new(0, 0, 0, headerHeight),
        Size = UDim2.new(0, sidebarWidth, 1, -headerHeight),
        BackgroundColor3 = Theme.BG_2,
    })

    local sidebarScroll = New("ScrollingFrame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    Pad(sidebarScroll, 8)
    local sidebarLayout = New("UIListLayout", { Parent = sidebarScroll, Padding = UDim.new(0, 6) })

    local content = New("Frame", {
        Parent = main,
        Position = UDim2.new(0, sidebarWidth, 0, headerHeight),
        Size = UDim2.new(1, -sidebarWidth, 1, -headerHeight),
        BackgroundTransparency = 1,
    })
    Pad(content, 12)

    local notify = AttachNotify(gui)

    local Window = { Tabs = {} }

    function Window:Notify(opts)
        notify(opts)
    end

    local hasFloatButton = cfg.FloatButton ~= nil
    local showFloatButton -- assigned below when FloatButton is configured

    local function handleClose()
        if hasFloatButton then
            main.Visible = false
            if showFloatButton then showFloatButton() end
        else
            gui:Destroy()
        end
    end
    closeBtn.MouseButton1Click:Connect(handleClose)

    local minimized = false
    local expandedSize = main.Size
    local function toggleMinimize()
        minimized = not minimized
        if minimized then
            expandedSize = main.Size
            Tween(main, 0.22, { Size = UDim2.new(expandedSize.X.Scale, expandedSize.X.Offset, 0, headerHeight) })
        else
            Tween(main, 0.22, { Size = expandedSize })
        end
    end
    minimizeBtn.MouseButton1Click:Connect(toggleMinimize)

    --// Floating toggle button (essential on mobile where there's no hotkey)
    if cfg.FloatButton then
        local fb = cfg.FloatButton
        local floatBtn = New("TextButton", {
            Parent = gui,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(fb.Size or 50, (fb.Size or 50) + 40),
            Size = UDim2.fromOffset(fb.Size or 50, fb.Size or 50),
            BackgroundColor3 = Theme.SURFACE,
            Text = "L",
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextColor3 = Theme.TEXT,
            Visible = false,
            AutoButtonColor = false,
            ZIndex = 10,
        })
        Round(floatBtn, fb.Shape == "Square" and 12 or 999)
        Stroke(floatBtn, Theme.ACCENT, 1)
        MakeDraggable(floatBtn, floatBtn)

        showFloatButton = function() floatBtn.Visible = true end

        floatBtn.MouseButton1Click:Connect(function()
            main.Visible = true
            floatBtn.Visible = false
        end)
    end

    --// Bind key toggle on PC (RightControl), matches common hub UX
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            main.Visible = not main.Visible
        end
    end)

    local firstTab = true

    function Window:CreateTab(tcfg)
        tcfg = tcfg or {}

        local tabBtn = New("TextButton", {
            Parent = sidebarScroll,
            Size = UDim2.new(1, 0, 0, IsMobile and 46 or 40),
            BackgroundColor3 = Theme.SURFACE,
            Text = tcfg.Title or "Tab",
            Font = Enum.Font.Gotham,
            TextSize = IsMobile and 13 or 14,
            TextColor3 = Theme.SUBTEXT,
            AutoButtonColor = false,
            TextWrapped = true,
        })
        Round(tabBtn, 8)

        local page = New("ScrollingFrame", {
            Parent = content,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.ACCENT,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        })
        local pageLayout = New("UIListLayout", { Parent = page, Padding = UDim.new(0, 10) })

        local function selectTab()
            for _, t in ipairs(Window.Tabs) do
                t.page.Visible = false
                Tween(t.button, 0.15, { BackgroundColor3 = Theme.SURFACE, TextColor3 = Theme.SUBTEXT })
            end
            page.Visible = true
            Tween(tabBtn, 0.15, { BackgroundColor3 = Theme.ACCENT, TextColor3 = Theme.TEXT })
        end

        tabBtn.MouseButton1Click:Connect(selectTab)

        table.insert(Window.Tabs, { button = tabBtn, page = page })
        if firstTab then
            firstTab = false
            selectTab()
        end

        local Tab = {}

        function Tab:CreateSection(scfg)
            scfg = scfg or {}
            local holder = New("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
            })
            New("TextLabel", {
                Parent = holder,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = Theme.ACCENT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = (scfg.Text or "Section"):upper(),
            })
            New("Frame", {
                Parent = holder,
                Position = UDim2.new(0, 0, 1, -2),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.STROKE,
                BorderSizePixel = 0,
            })
            return holder
        end

        function Tab:CreateButton(bcfg)
            bcfg = bcfg or {}
            local row = New("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, bcfg.Description and 58 or 44),
                BackgroundColor3 = Theme.SURFACE,
            })
            Round(row, 10)
            Stroke(row, Theme.STROKE, 1)
            Pad(row, 10)

            New("TextLabel", {
                Parent = row,
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextColor3 = Theme.TEXT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = bcfg.Title or "Button",
            })

            if bcfg.Description then
                New("TextLabel", {
                    Parent = row,
                    Position = UDim2.new(0, 0, 0, 20),
                    Size = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Theme.SUBTEXT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = bcfg.Description,
                })
            end

            local click = New("TextButton", {
                Parent = row,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
            })

            local confirming = false
            local function run()
                if bcfg.Confirmation and not confirming then
                    confirming = true
                    Tween(row, 0.12, { BackgroundColor3 = Theme.ACCENT_2 })
                    task.delay(2.5, function()
                        confirming = false
                        Tween(row, 0.12, { BackgroundColor3 = Theme.SURFACE })
                    end)
                    return
                end
                confirming = false
                Tween(row, 0.1, { BackgroundColor3 = Theme.SURFACE_2 })
                task.delay(0.12, function()
                    Tween(row, 0.15, { BackgroundColor3 = Theme.SURFACE })
                end)
                if bcfg.Callback then bcfg.Callback() end
            end

            click.MouseButton1Click:Connect(run)

            return row
        end

        function Tab:CreateToggle(tcfg2)
            tcfg2 = tcfg2 or {}
            local state = tcfg2.Default or false

            local row = New("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.SURFACE,
            })
            Round(row, 10)
            Stroke(row, Theme.STROKE, 1)
            Pad(row, 10)

            New("TextLabel", {
                Parent = row,
                Size = UDim2.new(1, -60, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Theme.TEXT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = tcfg2.Title or "Toggle",
            })

            local track = New("TextButton", {
                Parent = row,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(44, 24),
                BackgroundColor3 = state and Theme.ACCENT or Theme.SURFACE_2,
                Text = "",
                AutoButtonColor = false,
            })
            Round(track, 12)

            local knob = New("Frame", {
                Parent = track,
                Size = UDim2.fromOffset(18, 18),
                Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
                BackgroundColor3 = Theme.TEXT,
            })
            Round(knob, 9)

            local function apply()
                Tween(track, 0.15, { BackgroundColor3 = state and Theme.ACCENT or Theme.SURFACE_2 })
                Tween(knob, 0.15, { Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) })
            end

            local function flip()
                state = not state
                apply()
                if tcfg2.Callback then tcfg2.Callback(state) end
            end

            track.MouseButton1Click:Connect(flip)

            if tcfg2.Default then
                task.defer(function()
                    if tcfg2.Callback then tcfg2.Callback(true) end
                end)
            end

            return row
        end

        function Tab:CreateSlider(scfg2)
            scfg2 = scfg2 or {}
            local min = scfg2.Min or 0
            local max = scfg2.Max or 100
            local value = scfg2.Default or min

            local row = New("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 56),
                BackgroundColor3 = Theme.SURFACE,
            })
            Round(row, 10)
            Stroke(row, Theme.STROKE, 1)
            Pad(row, 10)

            local label = New("TextLabel", {
                Parent = row,
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextColor3 = Theme.TEXT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = (scfg2.Title or "Slider") .. ": " .. tostring(value),
            })

            local bar = New("Frame", {
                Parent = row,
                Position = UDim2.new(0, 0, 0, 30),
                Size = UDim2.new(1, 0, 0, IsMobile and 18 or 12),
                BackgroundColor3 = Theme.SURFACE_2,
            })
            Round(bar, 8)

            local fill = New("Frame", {
                Parent = bar,
                Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0),
                BackgroundColor3 = Theme.ACCENT,
            })
            Round(fill, 8)

            local handleSize = IsMobile and 24 or 16
            local handle = New("Frame", {
                Parent = bar,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new((value - min) / math.max(max - min, 1), 0, 0.5, 0),
                Size = UDim2.fromOffset(handleSize, handleSize),
                BackgroundColor3 = Theme.TEXT,
                ZIndex = 2,
            })
            Round(handle, handleSize / 2)

            local dragging = false

            local function setFromX(x)
                local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                value = math.floor(min + (max - min) * rel)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                handle.Position = UDim2.new(rel, 0, 0.5, 0)
                label.Text = (scfg2.Title or "Slider") .. ": " .. tostring(value)
                if scfg2.Callback then scfg2.Callback(value) end
            end

            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromX(input.Position.X)
                end
            end)
            bar.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            UIS.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end)

            if scfg2.Callback then
                task.defer(function() scfg2.Callback(value) end)
            end

            return row
        end

        function Tab:CreateDropdown(dcfg)
            dcfg = dcfg or {}
            local options = dcfg.Options or {}
            local multiple = dcfg.Multiple or false
            local selected = multiple and {} or nil
            local selectedSingle = nil

            local row = New("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.SURFACE,
                ClipsDescendants = true,
            })
            Round(row, 10)
            Stroke(row, Theme.STROKE, 1)

            local head = New("TextButton", {
                Parent = row,
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
            })
            Pad(head, 10)

            New("TextLabel", {
                Parent = head,
                Size = UDim2.new(1, -20, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Theme.TEXT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = dcfg.Title or "Dropdown",
            })

            local chevron = New("TextLabel", {
                Parent = head,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = Theme.SUBTEXT,
                Text = "▾",
            })

            local list = New("Frame", {
                Parent = row,
                Position = UDim2.new(0, 0, 0, 44),
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
            })
            local listLayout = New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4) })
            Pad(list, 8)

            local optionHeight = IsMobile and 38 or 32
            local open = false

            local function refreshHeight()
                local count = #options
                local target = open and (44 + count * (optionHeight + 4) + 12) or 44
                Tween(row, 0.18, { Size = UDim2.new(1, 0, 0, target) })
            end

            local function fireCallback()
                if not dcfg.Callback then return end
                if multiple then
                    dcfg.Callback(selected)
                else
                    dcfg.Callback(selectedSingle)
                end
            end

            for _, optName in ipairs(options) do
                local optBtn = New("TextButton", {
                    Parent = list,
                    Size = UDim2.new(1, 0, 0, optionHeight),
                    BackgroundColor3 = Theme.SURFACE_2,
                    Text = optName,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Theme.SUBTEXT,
                    AutoButtonColor = false,
                })
                Round(optBtn, 8)

                local function toggleOption()
                    if multiple then
                        local idx = table.find(selected, optName)
                        if idx then
                            table.remove(selected, idx)
                            Tween(optBtn, 0.12, { BackgroundColor3 = Theme.SURFACE_2, TextColor3 = Theme.SUBTEXT })
                        else
                            table.insert(selected, optName)
                            Tween(optBtn, 0.12, { BackgroundColor3 = Theme.ACCENT, TextColor3 = Theme.TEXT })
                        end
                    else
                        selectedSingle = optName
                        for _, child in ipairs(list:GetChildren()) do
                            if child:IsA("TextButton") then
                                Tween(child, 0.12, { BackgroundColor3 = Theme.SURFACE_2, TextColor3 = Theme.SUBTEXT })
                            end
                        end
                        Tween(optBtn, 0.12, { BackgroundColor3 = Theme.ACCENT, TextColor3 = Theme.TEXT })
                    end
                    fireCallback()
                end

                optBtn.MouseButton1Click:Connect(toggleOption)
            end

            local function toggleOpen()
                open = not open
                Tween(chevron, 0.18, { Rotation = open and 180 or 0 })
                refreshHeight()
            end

            head.MouseButton1Click:Connect(toggleOpen)

            return row
        end

        function Tab:CreateTextBox(tbcfg)
            tbcfg = tbcfg or {}
            local row = New("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.SURFACE,
            })
            Round(row, 10)
            Stroke(row, Theme.STROKE, 1)

            New("TextLabel", {
                Parent = row,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(0.45, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Theme.TEXT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = tbcfg.Title or "Input",
            })

            local box = New("TextBox", {
                Parent = row,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0.45, 0, 0, 30),
                BackgroundColor3 = Theme.SURFACE_2,
                Text = tbcfg.Default or "",
                PlaceholderText = tbcfg.Placeholder or "",
                PlaceholderColor3 = Theme.MUTED,
                TextColor3 = Theme.TEXT,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                ClearTextOnFocus = false,
            })
            Round(box, 8)
            Pad(box, 6)

            if tbcfg.MaxLength then
                box:GetPropertyChangedSignal("Text"):Connect(function()
                    if #box.Text > tbcfg.MaxLength then
                        box.Text = box.Text:sub(1, tbcfg.MaxLength)
                    end
                end)
            end

            box.FocusLost:Connect(function()
                if tbcfg.Callback then tbcfg.Callback(box.Text) end
            end)

            if tbcfg.Default and tbcfg.Callback then
                task.defer(function() tbcfg.Callback(tbcfg.Default) end)
            end

            return row
        end

        return Tab
    end

    return Window
end

local Lib = Library.new()
local CargarHub  -- forward declaration

local KS = Lib:CreateKeySystem({
    Title = "Lil Script — Key Required",
    Theme = "Purple",
    Size  = Vector2.new(440, 270),
})

KS:CreateButton({
    Description = "Get Key",
    Callback = function()
        setclipboard("https://direct-link.net/1345178/ETFfDrgEXXDA")
        KS:Notify({ Title = "Link copiado!", Description = "Pega el link en tu navegador para conseguir la key.", Duration = 4 })
    end,
})

KS:CreateButton({
    Description = "Verify Key",
    Callback = function()
        if KS:GetText() == "LILBOSS" then
            KS:Destroy()
            CargarHub()
        else
            KS:Notify({ Title = "Invalid Key", Description = "The key is incorrect.", Duration = 3 })
        end
    end,
})

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local Wins = player:WaitForChild("leaderstats"):WaitForChild("Wins")
local enMovimiento = false
local autofarmActivo = false
local SPEED = 120
local PAUSA = 0

local Rutas = {
    ["1 Win"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(-19.410326, 10.769637, 282.502197, -0.125670, -0.000000, 0.992072, 0.000000, 1.000000, 0.000000, -0.992072, 0.000000, -0.125670)
    },
    ["3 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.190294, 10.887565, 507.164642, 0.815260, -0.000036, 0.579095, -0.000007, 1.000000, 0.000072, -0.579095, -0.000062, 0.815260)
    },
    ["10 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(-16.488636, 75.1460419, 774.375122, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["20 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-16.488636, 75.1460419, 1108.35461, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["50 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-16.488636, 75.1460419, 1411.3446, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["100 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-538.371643, 52.5018692, 1447.88953, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["150 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1007.7088, 52.5018692, 1447.88953, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["300 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1123.46582, 294.501862, 1447.88953, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["500 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-2970.3374, 294.501709, 1447.88977, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["1000 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-3937.848877, 296.499420, 1465.380493, 0.025371, 0.000000, 0.999678, 0.000000, 1.000000, -0.000000, -0.999678, 0.000000, 0.025371),
        CFrame.new(-3938.4209, 294.501709, 1447.88977, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["2500 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-3937.848877, 296.499420, 1465.380493, 0.025371, 0.000000, 0.999678, 0.000000, 1.000000, -0.000000, -0.999678, 0.000000, 0.025371),
        CFrame.new(-4301.579102, 296.499420, 1467.375610, -0.017453, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, -0.017453),
        CFrame.new(-4314.133789, 488.080109, 1531.266846, 0.026179, 0.000000, 0.999657, -0.000000, 1.000000, -0.000000, -0.999657, -0.000000, 0.026179),
        CFrame.new(-4367.535156, 471.008453, 1529.886353, 0.026178, -0.000000, 0.999657, 0.000000, 1.000000, 0.000000, -0.999657, 0.000000, 0.026178),
        CFrame.new(-4368.3374, 469.010712, 1512.42175, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["10000 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-3937.848877, 296.499420, 1465.380493, 0.025371, 0.000000, 0.999678, 0.000000, 1.000000, -0.000000, -0.999678, 0.000000, 0.025371),
        CFrame.new(-4301.579102, 296.499420, 1467.375610, -0.017453, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, -0.017453),
        CFrame.new(-4314.133789, 488.080109, 1531.266846, 0.026179, 0.000000, 0.999657, -0.000000, 1.000000, -0.000000, -0.999657, -0.000000, 0.026179),
        CFrame.new(-4367.535156, 471.008453, 1529.886353, 0.026178, -0.000000, 0.999657, 0.000000, 1.000000, 0.000000, -0.999657, 0.000000, 0.026178),
        CFrame.new(-4578.034180, 470.726501, 1536.877930, 0.230500, -0.000000, 0.973072, 0.000000, 1.000000, 0.000000, -0.973072, -0.000000, 0.230500),
        CFrame.new(-4584.960938, 470.726501, 1351.298218, 0.999666, 0.000000, -0.025828, 0.000000, 1.000000, 0.000000, 0.025828, -0.000000, 0.999666),
        CFrame.new(-4460.708984, 470.726501, 1457.977905, 0.784710, -0.000000, -0.619863, -0.000000, 1.000000, -0.000000, 0.619863, 0.000000, 0.784710),
        CFrame.new(-4471.077148, 470.726501, 1146.280518, 0.965328, 0.000000, -0.261039, -0.000000, 1.000000, 0.000000, 0.261039, -0.000000, 0.965328),
        CFrame.new(-4733.200684, 470.726501, 1145.707886, -0.012899, -0.000000, 0.999917, -0.000000, 1.000000, 0.000000, -0.999917, -0.000000, -0.012899),
        CFrame.new(-4730.936523, 470.726501, 1400.858276, 0.207911, -0.000000, 0.978148, -0.000000, 1.000000, 0.000000, -0.978148, -0.000000, 0.207911),
        CFrame.new(-4937.211914, 470.726501, 1387.689453, 0.146862, 0.000000, 0.989157, 0.000000, 1.000000, -0.000000, -0.989157, 0.000000, 0.146862),
        CFrame.new(-4931.974609, 470.726501, 1616.516235, -0.997783, 0.000000, -0.066552, -0.000000, 1.000000, 0.000000, 0.066552, 0.000000, -0.997783),
        CFrame.new(-5051.075195, 470.726501, 1621.422119, 0.160648, 0.000000, 0.987012, -0.000000, 1.000000, -0.000000, -0.987012, -0.000000, 0.160648),
        CFrame.new(-5085.067871, 470.726501, 1128.176636, 0.214987, -0.000000, 0.976617, -0.000000, 1.000000, 0.000000, -0.976617, -0.000000, 0.214987),
        CFrame.new(-5143.350586, 470.726501, 1337.229858, -0.719340, -0.000000, 0.694658, 0.000000, 1.000000, 0.000000, -0.694658, 0.000000, -0.719340),
        CFrame.new(-5341.335449, 470.608429, 1476.304810, -0.000000, 0.000000, 1.000000, 0.000000, 1.000000, -0.000000, -1.000000, 0.000000, -0.000000),
        CFrame.new(-5342.9375, 468.610718, 1457.1217, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["25000 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-3937.848877, 296.499420, 1465.380493, 0.025371, 0.000000, 0.999678, 0.000000, 1.000000, -0.000000, -0.999678, 0.000000, 0.025371),
        CFrame.new(-4301.579102, 296.499420, 1467.375610, -0.017453, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, -0.017453),
        CFrame.new(-4314.133789, 488.080109, 1531.266846, 0.026179, 0.000000, 0.999657, -0.000000, 1.000000, -0.000000, -0.999657, -0.000000, 0.026179),
        CFrame.new(-4367.535156, 471.008453, 1529.886353, 0.026178, -0.000000, 0.999657, 0.000000, 1.000000, 0.000000, -0.999657, 0.000000, 0.026178),
        CFrame.new(-4578.034180, 470.726501, 1536.877930, 0.230500, -0.000000, 0.973072, 0.000000, 1.000000, 0.000000, -0.973072, -0.000000, 0.230500),
        CFrame.new(-4584.960938, 470.726501, 1351.298218, 0.999666, 0.000000, -0.025828, 0.000000, 1.000000, 0.000000, 0.025828, -0.000000, 0.999666),
        CFrame.new(-4460.708984, 470.726501, 1457.977905, 0.784710, -0.000000, -0.619863, -0.000000, 1.000000, -0.000000, 0.619863, 0.000000, 0.784710),
        CFrame.new(-4471.077148, 470.726501, 1146.280518, 0.965328, 0.000000, -0.261039, -0.000000, 1.000000, 0.000000, 0.261039, -0.000000, 0.965328),
        CFrame.new(-4733.200684, 470.726501, 1145.707886, -0.012899, -0.000000, 0.999917, -0.000000, 1.000000, 0.000000, -0.999917, -0.000000, -0.012899),
        CFrame.new(-4730.936523, 470.726501, 1400.858276, 0.207911, -0.000000, 0.978148, -0.000000, 1.000000, 0.000000, -0.978148, -0.000000, 0.207911),
        CFrame.new(-4937.211914, 470.726501, 1387.689453, 0.146862, 0.000000, 0.989157, 0.000000, 1.000000, -0.000000, -0.989157, 0.000000, 0.146862),
        CFrame.new(-4931.974609, 470.726501, 1616.516235, -0.997783, 0.000000, -0.066552, -0.000000, 1.000000, 0.000000, 0.066552, 0.000000, -0.997783),
        CFrame.new(-5051.075195, 470.726501, 1621.422119, 0.160648, 0.000000, 0.987012, -0.000000, 1.000000, -0.000000, -0.987012, -0.000000, 0.160648),
        CFrame.new(-5085.067871, 470.726501, 1128.176636, 0.214987, -0.000000, 0.976617, -0.000000, 1.000000, 0.000000, -0.976617, -0.000000, 0.214987),
        CFrame.new(-5143.350586, 470.726501, 1337.229858, -0.719340, -0.000000, 0.694658, 0.000000, 1.000000, 0.000000, -0.694658, 0.000000, -0.719340),
        CFrame.new(-5341.335449, 470.608429, 1476.304810, -0.000000, 0.000000, 1.000000, 0.000000, 1.000000, -0.000000, -1.000000, 0.000000, -0.000000),
        CFrame.new(-5390.317871, 479.863220, 1477.194458, -0.008727, 0.000000, 0.999962, -0.000000, 1.000000, -0.000000, -0.999962, -0.000000, -0.008727),
        CFrame.new(-5659.083496, 489.795929, 1339.460815, -0.333807, 0.000000, 0.942641, 0.000000, 1.000000, -0.000000, -0.942641, -0.000000, -0.333807),
        CFrame.new(-5887.706055, 489.871765, 1570.058594, 0.258817, 0.000000, 0.965926, -0.000000, 1.000000, -0.000000, -0.965926, -0.000000, 0.258817),
        CFrame.new(-6189.955078, 489.859314, 1428.377441, 0.173651, 0.000000, 0.984807, 0.000000, 1.000000, -0.000000, -0.984807, 0.000000, 0.173651),
        CFrame.new(-6475.855957, 489.004242, 1384.150635, -0.008727, -0.000000, 0.999962, -0.000000, 1.000000, 0.000000, -0.999962, -0.000000, -0.008727),
        CFrame.new(-6811.497070, 521.608459, 1486.857422, 0.017455, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, 0.017455),
        CFrame.new(-6809.9375, 519.610718, 1469.1217, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["50000 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-3937.848877, 296.499420, 1465.380493, 0.025371, 0.000000, 0.999678, 0.000000, 1.000000, -0.000000, -0.999678, 0.000000, 0.025371),
        CFrame.new(-4301.579102, 296.499420, 1467.375610, -0.017453, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, -0.017453),
        CFrame.new(-4314.133789, 488.080109, 1531.266846, 0.026179, 0.000000, 0.999657, -0.000000, 1.000000, -0.000000, -0.999657, -0.000000, 0.026179),
        CFrame.new(-4367.535156, 471.008453, 1529.886353, 0.026178, -0.000000, 0.999657, 0.000000, 1.000000, 0.000000, -0.999657, 0.000000, 0.026178),
        CFrame.new(-4578.034180, 470.726501, 1536.877930, 0.230500, -0.000000, 0.973072, 0.000000, 1.000000, 0.000000, -0.973072, -0.000000, 0.230500),
        CFrame.new(-4584.960938, 470.726501, 1351.298218, 0.999666, 0.000000, -0.025828, 0.000000, 1.000000, 0.000000, 0.025828, -0.000000, 0.999666),
        CFrame.new(-4460.708984, 470.726501, 1457.977905, 0.784710, -0.000000, -0.619863, -0.000000, 1.000000, -0.000000, 0.619863, 0.000000, 0.784710),
        CFrame.new(-4471.077148, 470.726501, 1146.280518, 0.965328, 0.000000, -0.261039, -0.000000, 1.000000, 0.000000, 0.261039, -0.000000, 0.965328),
        CFrame.new(-4733.200684, 470.726501, 1145.707886, -0.012899, -0.000000, 0.999917, -0.000000, 1.000000, 0.000000, -0.999917, -0.000000, -0.012899),
        CFrame.new(-4730.936523, 470.726501, 1400.858276, 0.207911, -0.000000, 0.978148, -0.000000, 1.000000, 0.000000, -0.978148, -0.000000, 0.207911),
        CFrame.new(-4937.211914, 470.726501, 1387.689453, 0.146862, 0.000000, 0.989157, 0.000000, 1.000000, -0.000000, -0.989157, 0.000000, 0.146862),
        CFrame.new(-4931.974609, 470.726501, 1616.516235, -0.997783, 0.000000, -0.066552, -0.000000, 1.000000, 0.000000, 0.066552, 0.000000, -0.997783),
        CFrame.new(-5051.075195, 470.726501, 1621.422119, 0.160648, 0.000000, 0.987012, -0.000000, 1.000000, -0.000000, -0.987012, -0.000000, 0.160648),
        CFrame.new(-5085.067871, 470.726501, 1128.176636, 0.214987, -0.000000, 0.976617, -0.000000, 1.000000, 0.000000, -0.976617, -0.000000, 0.214987),
        CFrame.new(-5143.350586, 470.726501, 1337.229858, -0.719340, -0.000000, 0.694658, 0.000000, 1.000000, 0.000000, -0.694658, 0.000000, -0.719340),
        CFrame.new(-5341.335449, 470.608429, 1476.304810, -0.000000, 0.000000, 1.000000, 0.000000, 1.000000, -0.000000, -1.000000, 0.000000, -0.000000),
        CFrame.new(-5390.317871, 479.863220, 1477.194458, -0.008727, 0.000000, 0.999962, -0.000000, 1.000000, -0.000000, -0.999962, -0.000000, -0.008727),
        CFrame.new(-5659.083496, 489.795929, 1339.460815, -0.333807, 0.000000, 0.942641, 0.000000, 1.000000, -0.000000, -0.942641, -0.000000, -0.333807),
        CFrame.new(-5887.706055, 489.871765, 1570.058594, 0.258817, 0.000000, 0.965926, -0.000000, 1.000000, -0.000000, -0.965926, -0.000000, 0.258817),
        CFrame.new(-6189.955078, 489.859314, 1428.377441, 0.173651, 0.000000, 0.984807, 0.000000, 1.000000, -0.000000, -0.984807, 0.000000, 0.173651),
        CFrame.new(-6475.855957, 489.004242, 1384.150635, -0.008727, -0.000000, 0.999962, -0.000000, 1.000000, 0.000000, -0.999962, -0.000000, -0.008727),
        CFrame.new(-6811.497070, 521.608459, 1486.857422, 0.017455, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, 0.017455),
        CFrame.new(-6844.388672, 548.550293, 1484.577515, 0.099105, 0.000001, 0.995077, -0.000001, 1.000000, -0.000001, -0.995077, -0.000001, 0.099105),
        CFrame.new(-8309.657227, 541.999573, 1487.250854, 0.019163, 0.000000, 0.999816, 0.000000, 1.000000, -0.000000, -0.999816, 0.000000, 0.019163),
        CFrame.new(-8351.170898, 484.491943, 1489.551514, 0.034900, 0.000000, 0.999391, 0.000000, 1.000000, -0.000000, -0.999391, 0.000000, 0.034900),
        CFrame.new(-8353.04883, 482.494202, 1468.88794, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    },
    ["150000 Wins"] = {
        CFrame.new(3.724555, 8.855168, 193.431976, -0.999962, -0.000000, -0.008727, -0.000000, 1.000000, -0.000000, 0.008727, -0.000000, -0.999962),
        CFrame.new(1.352123, 8.855168, 282.143616, -0.995821, -0.000000, 0.091329, -0.000000, 1.000000, -0.000000, -0.091329, -0.000000, -0.995821),
        CFrame.new(42.972214, 8.293296, 415.022919, -0.831100, 0.023244, 0.555637, 0.011123, 0.999621, -0.025181, -0.556012, -0.014748, -0.831044),
        CFrame.new(-4.558566, 9.054776, 505.519196, 0.167640, -0.239556, 0.956300, -0.103845, 0.960340, 0.258773, -0.980364, -0.142688, 0.136115),
        CFrame.new(-16.056606, 9.600780, 564.325012, -0.999955, -0.000000, -0.009521, -0.000000, 1.000000, 0.000000, 0.009521, 0.000000, -0.999955),
        CFrame.new(-15.988174, 76.708076, 748.993652, -0.999337, 0.000000, 0.036406, 0.000000, 1.000000, 0.000000, -0.036406, 0.000000, -0.999337),
        CFrame.new(19.948849, 77.144051, 797.479492, -0.997564, -0.000000, 0.069757, -0.000000, 1.000000, 0.000000, -0.069757, 0.000000, -0.997564),
        CFrame.new(19.080624, 77.144051, 925.895569, -0.999657, -0.000000, 0.026177, -0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(2.041210, 77.144066, 1107.006226, -0.999226, -0.000000, 0.039341, -0.000000, 1.000000, 0.000000, -0.039341, 0.000000, -0.999226),
        CFrame.new(-0.205942, 77.144066, 1411.537354, -0.993030, -0.000000, 0.117859, -0.000000, 1.000000, 0.000000, -0.117859, 0.000000, -0.993030),
        CFrame.new(-21.650433, 77.144066, 1435.441406, -0.695624, 0.000000, 0.718406, -0.000000, 1.000000, -0.000000, -0.718406, -0.000000, -0.695624),
        CFrame.new(-48.912415, 54.499607, 1467.607178, -0.634508, -0.000000, 0.772917, 0.000000, 1.000000, 0.000000, -0.772917, 0.000000, -0.634508),
        CFrame.new(-537.982178, 54.499607, 1467.443237, -0.017454, -0.000000, 0.999848, -0.000000, 1.000000, 0.000000, -0.999848, -0.000000, -0.017454),
        CFrame.new(-1011.253296, 54.499607, 1466.683594, 0.002477, -0.000000, 0.999997, -0.000000, 1.000000, 0.000000, -0.999997, -0.000000, 0.002477),
        CFrame.new(-1076.595459, 54.499607, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1076.595459, 331.424377, 1466.115723, 0.008630, 0.000000, 0.999963, -0.000000, 1.000000, -0.000000, -0.999963, -0.000000, 0.008630),
        CFrame.new(-1119.756470, 296.499573, 1465.996338, -0.012123, 0.000000, 0.999927, 0.000000, 1.000000, -0.000000, -0.999927, 0.000000, -0.012123),
        CFrame.new(-1247.566650, 303.352692, 1470.086426, 0.008896, 0.000101, 0.999960, 0.000001, 1.000000, -0.000101, -0.999960, 0.000002, 0.008896),
        CFrame.new(-2525.851074, 321.746185, 1464.357300, 0.013233, -0.009617, 0.999866, 0.002209, 0.999952, 0.009589, -0.999910, 0.002082, 0.013254),
        CFrame.new(-2787.927002, 306.244843, 1465.268066, 0.782422, 0.051349, 0.620628, 0.051457, 0.987856, -0.146604, -0.620619, 0.146642, 0.770278),
        CFrame.new(-2972.629883, 295.320007, 1465.910034, 0.998923, 0.011630, 0.044924, 0.000000, 0.968084, -0.250626, -0.046405, 0.250356, 0.967041),
        CFrame.new(-3937.848877, 296.499420, 1465.380493, 0.025371, 0.000000, 0.999678, 0.000000, 1.000000, -0.000000, -0.999678, 0.000000, 0.025371),
        CFrame.new(-4301.579102, 296.499420, 1467.375610, -0.017453, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, -0.017453),
        CFrame.new(-4314.133789, 488.080109, 1531.266846, 0.026179, 0.000000, 0.999657, -0.000000, 1.000000, -0.000000, -0.999657, -0.000000, 0.026179),
        CFrame.new(-4367.535156, 471.008453, 1529.886353, 0.026178, -0.000000, 0.999657, 0.000000, 1.000000, 0.000000, -0.999657, 0.000000, 0.026178),
        CFrame.new(-4578.034180, 470.726501, 1536.877930, 0.230500, -0.000000, 0.973072, 0.000000, 1.000000, 0.000000, -0.973072, -0.000000, 0.230500),
        CFrame.new(-4584.960938, 470.726501, 1351.298218, 0.999666, 0.000000, -0.025828, 0.000000, 1.000000, 0.000000, 0.025828, -0.000000, 0.999666),
        CFrame.new(-4460.708984, 470.726501, 1457.977905, 0.784710, -0.000000, -0.619863, -0.000000, 1.000000, -0.000000, 0.619863, 0.000000, 0.784710),
        CFrame.new(-4471.077148, 470.726501, 1146.280518, 0.965328, 0.000000, -0.261039, -0.000000, 1.000000, 0.000000, 0.261039, -0.000000, 0.965328),
        CFrame.new(-4733.200684, 470.726501, 1145.707886, -0.012899, -0.000000, 0.999917, -0.000000, 1.000000, 0.000000, -0.999917, -0.000000, -0.012899),
        CFrame.new(-4730.936523, 470.726501, 1400.858276, 0.207911, -0.000000, 0.978148, -0.000000, 1.000000, 0.000000, -0.978148, -0.000000, 0.207911),
        CFrame.new(-4937.211914, 470.726501, 1387.689453, 0.146862, 0.000000, 0.989157, 0.000000, 1.000000, -0.000000, -0.989157, 0.000000, 0.146862),
        CFrame.new(-4931.974609, 470.726501, 1616.516235, -0.997783, 0.000000, -0.066552, -0.000000, 1.000000, 0.000000, 0.066552, 0.000000, -0.997783),
        CFrame.new(-5051.075195, 470.726501, 1621.422119, 0.160648, 0.000000, 0.987012, -0.000000, 1.000000, -0.000000, -0.987012, -0.000000, 0.160648),
        CFrame.new(-5085.067871, 470.726501, 1128.176636, 0.214987, -0.000000, 0.976617, -0.000000, 1.000000, 0.000000, -0.976617, -0.000000, 0.214987),
        CFrame.new(-5143.350586, 470.726501, 1337.229858, -0.719340, -0.000000, 0.694658, 0.000000, 1.000000, 0.000000, -0.694658, 0.000000, -0.719340),
        CFrame.new(-5341.335449, 470.608429, 1476.304810, -0.000000, 0.000000, 1.000000, 0.000000, 1.000000, -0.000000, -1.000000, 0.000000, -0.000000),
        CFrame.new(-5390.317871, 479.863220, 1477.194458, -0.008727, 0.000000, 0.999962, -0.000000, 1.000000, -0.000000, -0.999962, -0.000000, -0.008727),
        CFrame.new(-5659.083496, 489.795929, 1339.460815, -0.333807, 0.000000, 0.942641, 0.000000, 1.000000, -0.000000, -0.942641, -0.000000, -0.333807),
        CFrame.new(-5887.706055, 489.871765, 1570.058594, 0.258817, 0.000000, 0.965926, -0.000000, 1.000000, -0.000000, -0.965926, -0.000000, 0.258817),
        CFrame.new(-6189.955078, 489.859314, 1428.377441, 0.173651, 0.000000, 0.984807, 0.000000, 1.000000, -0.000000, -0.984807, 0.000000, 0.173651),
        CFrame.new(-6475.855957, 489.004242, 1384.150635, -0.008727, -0.000000, 0.999962, -0.000000, 1.000000, 0.000000, -0.999962, -0.000000, -0.008727),
        CFrame.new(-6811.497070, 521.608459, 1486.857422, 0.017455, -0.000000, 0.999848, 0.000000, 1.000000, 0.000000, -0.999848, 0.000000, 0.017455),
        CFrame.new(-6844.388672, 548.550293, 1484.577515, 0.099105, 0.000001, 0.995077, -0.000001, 1.000000, -0.000001, -0.995077, -0.000001, 0.099105),
        CFrame.new(-8309.657227, 541.999573, 1487.250854, 0.019163, 0.000000, 0.999816, 0.000000, 1.000000, -0.000000, -0.999816, 0.000000, 0.019163),
        CFrame.new(-8351.170898, 484.491943, 1489.551514, 0.034900, 0.000000, 0.999391, 0.000000, 1.000000, -0.000000, -0.999391, 0.000000, 0.034900),
        CFrame.new(-8525.848633, 484.492828, 1488.387085, -0.061048, 0.000000, 0.998135, -0.000000, 1.000000, -0.000000, -0.998135, -0.000000, -0.061048),
        CFrame.new(-8587.150391, 502.785645, 1490.730469, 0.033304, 0.000000, 0.999445, 0.000000, 1.000000, -0.000000, -0.999445, 0.000000, 0.033304),
        CFrame.new(-8923.205078, 504.212799, 1487.559692, -0.000425, 0.000000, 1.000000, 0.000000, 1.000000, -0.000000, -1.000000, 0.000000, -0.000425),
        CFrame.new(-9591.251953, 504.216797, 1488.299072, -0.052331, 0.000000, 0.998630, -0.000000, 1.000000, -0.000000, -0.998630, -0.000000, -0.052331),
        CFrame.new(-9651.062500, 523.018494, 1488.864990, 0.056338, -0.000000, 0.998412, 0.000000, 1.000000, 0.000000, -0.998412, 0.000000, 0.056338),
        CFrame.new(-9907.130859, 502.487335, 1486.333740, 0.102778, 0.000000, 0.994704, 0.000000, 1.000000, -0.000000, -0.994704, 0.000000, 0.102778),
        CFrame.new(-10162.776367, 502.315582, 1484.347778, -0.186657, -0.000000, 0.982425, 0.000000, 1.000000, 0.000000, -0.982425, 0.000000, -0.186657),
        CFrame.new(-10289.917969, 532.210999, 1483.757812, -0.908372, -0.000000, 0.418164, -0.000000, 1.000000, 0.000000, -0.418164, 0.000000, -0.908372),
        CFrame.new(-10289.917969, 438.909119, 1483.757812, -0.908372, 0.000000, 0.418164, 0.000000, 1.000000, -0.000000, -0.418164, -0.000000, -0.908372),
        CFrame.new(-10427.486328, 438.909119, 1506.536743, -0.006018, -0.000000, 0.999982, 0.000000, 1.000000, 0.000000, -0.999982, 0.000000, -0.006018),
        CFrame.new(-10426.624023, 439.803040, 1777.026978, -0.997995, 0.000000, 0.063297, -0.000000, 1.000000, -0.000000, -0.063297, -0.000000, -0.997995),
        CFrame.new(-10427.655273, 750.533264, 3438.095215, -0.999033, -0.000000, 0.043962, -0.000000, 1.000000, -0.000000, -0.043962, -0.000000, -0.999033),
        CFrame.new(-10428.574219, 750.554260, 3581.039551, -0.999346, -0.000000, 0.036163, 0.000000, 1.000000, 0.000000, -0.036163, 0.000000, -0.999346),
        CFrame.new(-10752.800781, 750.554260, 3579.792236, 0.007145, 0.000000, 0.999974, -0.000000, 1.000000, -0.000000, -0.999974, -0.000000, 0.007145),
        CFrame.new(-10752.800781, 818.973816, 3579.792236, 0.007145, -0.000000, 0.999974, 0.000000, 1.000000, 0.000000, -0.999974, 0.000000, 0.007145),
        CFrame.new(-12183.653320, 842.466064, 3582.743652, -0.005908, 0.000000, 0.999983, 0.000000, 1.000000, -0.000000, -0.999983, 0.000000, -0.005908),
        CFrame.new(-12183.653320, 750.554260, 3582.743652, -0.005908, 0.000000, 0.999983, 0.000000, 1.000000, -0.000000, -0.999983, 0.000000, -0.005908),
        CFrame.new(-13211.908203, 750.538818, 3576.945801, 0.000001, -0.000000, 1.000000, -0.000000, 1.000000, 0.000000, -1.000000, -0.000000, 0.000001),
        CFrame.new(-13211.033203, 750.538818, 3680.751953, -0.999909, -0.000000, 0.013483, -0.000000, 1.000000, -0.000000, -0.013483, -0.000000, -0.999909),
        CFrame.new(-13412.917969, 750.538818, 3672.262207, 0.080482, 0.000000, 0.996756, -0.000000, 1.000000, -0.000000, -0.996756, 0.000000, 0.080482),
        CFrame.new(-13411.466797, 750.538818, 3373.227539, 0.980381, -0.000000, 0.197110, 0.000000, 1.000000, 0.000000, -0.197110, -0.000000, 0.980381),
        CFrame.new(-13630.740234, 750.538818, 3357.879395, 0.073613, 0.000000, 0.997287, 0.000000, 1.000000, -0.000000, -0.997287, 0.000000, 0.073613),
        CFrame.new(-13618.987305, 750.538818, 3189.217041, 0.997598, -0.000000, -0.069272, 0.000000, 1.000000, -0.000000, 0.069272, 0.000000, 0.997598),
        CFrame.new(-13876.544922, 750.538818, 3194.942383, -0.026168, 0.000000, 0.999658, 0.000000, 1.000000, -0.000000, -0.999658, -0.000000, -0.026168),
        CFrame.new(-13723.979492, 750.538818, 3449.570312, -1.000000, -0.000000, -0.000000, -0.000000, 1.000000, 0.000000, 0.000000, 0.000000, -1.000000),
        CFrame.new(-13709.855469, 750.538818, 3765.020264, -0.977503, -0.000000, 0.210922, -0.000000, 1.000000, 0.000000, -0.210922, 0.000000, -0.977503),
        CFrame.new(-13616.228516, 750.538818, 3959.182861, -0.911588, -0.000000, 0.411106, -0.000000, 1.000000, -0.000000, -0.411106, -0.000000, -0.911588),
        CFrame.new(-14000.331055, 750.538818, 3963.955566, -0.151057, -0.000000, 0.988525, -0.000000, 1.000000, 0.000000, -0.988525, -0.000000, -0.151057),
        CFrame.new(-14000.948242, 750.538818, 3106.454102, 1.000000, -0.000000, -0.000001, 0.000000, 1.000000, 0.000000, 0.000001, -0.000000, 1.000000),
        CFrame.new(-14001.9141, 749.77887, 3067.99707, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
}

local Rutas2 = {
    ["250k Win"] = {
        CFrame.new(-394.537415, 504.153198, -7.344885, -0.999750, -0.000000, -0.022381, -0.000000, 1.000000, 0.000000, 0.022381, 0.000000, -0.999750),
        CFrame.new(-399.417389, 504.246063, 60.364544, -0.992546, -0.000000, 0.121870, -0.000000, 1.000000, 0.000000, -0.121870, 0.000000, -0.992546),
        CFrame.new(-401.827881, 503.944946, 124.788803, -0.999657, 0.000000, 0.026177, 0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(-397.381500, 500.320435, 188.375931, -0.999657, 0.000000, 0.026177, 0.000000, 1.000000, -0.000000, -0.026177, -0.000000, -0.999657),
        CFrame.new(-413.971985, 498.170471, 189.874847, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["400k Win"] = {
        CFrame.new(-394.537415, 504.153198, -7.344885, -0.999750, -0.000000, -0.022381, -0.000000, 1.000000, 0.000000, 0.022381, 0.000000, -0.999750),
        CFrame.new(-399.417389, 504.246063, 60.364544, -0.992546, -0.000000, 0.121870, -0.000000, 1.000000, 0.000000, -0.121870, 0.000000, -0.992546),
        CFrame.new(-401.827881, 503.944946, 124.788803, -0.999657, 0.000000, 0.026177, 0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(-397.381500, 500.320435, 188.375931, -0.999657, 0.000000, 0.026177, 0.000000, 1.000000, -0.000000, -0.026177, -0.000000, -0.999657),
        CFrame.new(-395.447266, 500.320435, 432.300598, -0.997204, 0.000000, 0.074729, -0.000000, 1.000000, -0.000000, -0.074729, -0.000000, -0.997204),
        CFrame.new(-414.599762, 498.170471, 433.411469, 0, 0, 1, 0, 1, 0, -1, 0, 0)
    },
    ["600k Win"] = {
        CFrame.new(-394.537415, 504.153198, -7.344885, -0.999750, -0.000000, -0.022381, -0.000000, 1.000000, 0.000000, 0.022381, 0.000000, -0.999750),
        CFrame.new(-399.417389, 504.246063, 60.364544, -0.992546, -0.000000, 0.121870, -0.000000, 1.000000, 0.000000, -0.121870, 0.000000, -0.992546),
        CFrame.new(-401.827881, 503.944946, 124.788803, -0.999657, 0.000000, 0.026177, 0.000000, 1.000000, 0.000000, -0.026177, 0.000000, -0.999657),
        CFrame.new(-397.381500, 500.320435, 188.375931, -0.999657, 0.000000, 0.026177, 0.000000, 1.000000, -0.000000, -0.026177, -0.000000, -0.999657),
        CFrame.new(-395.447266, 500.320435, 432.300598, -0.997204, 0.000000, 0.074729, -0.000000, 1.000000, -0.000000, -0.074729, -0.000000, -0.997204),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-417.131653, 605.895508, 606.915039, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["1m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-418.131653, 605.458008, 841.595093, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["1.5m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-417.271027, 605.456604, 1261.27368, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["2.5m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-417.271027, 621.228455, 2415.65137, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["4m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-417.271027, 621.413269, 2650.78271, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["6m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-417.271027, 621.228455, 3158.65137, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["10m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(-59.9252052, 621.228455, 3883.21021, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["15m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(1228.957031, 623.854553, 3864.849609, -0.052334, 0.000000, -0.998630, -0.000000, 1.000000, 0.000000, 0.998630, 0.000000, -0.052334),
        CFrame.new(1228.42297, 621.591309, 3908.9353, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["25m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(1228.957031, 623.854553, 3864.849609, -0.052334, 0.000000, -0.998630, -0.000000, 1.000000, 0.000000, 0.998630, 0.000000, -0.052334),
        CFrame.new(1285.483887, 623.893921, 3865.760498, -0.413727, -0.000000, -0.910401, -0.000000, 1.000000, -0.000000, 0.910401, 0.000000, -0.413727),
        CFrame.new(1313.448730, 615.678467, 3865.413086, -0.226306, -0.000000, -0.974056, -0.000000, 1.000000, -0.000000, 0.974056, -0.000000, -0.226306),
        CFrame.new(1562.323364, 611.810669, 3794.923340, 0.962112, 0.000003, -0.272656, -0.000001, 1.000000, 0.000007, 0.272656, -0.000007, 0.962112),
        CFrame.new(1759.683838, 629.388123, 3933.649658, 0.405095, -0.000007, 0.914274, 0.000001, 1.000000, 0.000007, -0.914274, -0.000002, 0.405095),
        CFrame.new(1962.168457, 620.205078, 3774.527588, -0.911729, 0.000000, 0.410793, 0.000000, 1.000000, -0.000000, -0.410793, -0.000000, -0.911729),
        CFrame.new(2096.351318, 630.247986, 3982.022217, 0.810655, 0.000000, 0.585525, -0.000000, 1.000000, -0.000000, -0.585525, 0.000000, 0.810655),
        CFrame.new(2298.798828, 626.476440, 3858.692139, -0.980698, 0.000000, 0.195530, 0.000000, 1.000000, -0.000000, -0.195530, -0.000000, -0.980698),
        CFrame.new(2399.847900, 627.855530, 3869.578857, -0.133801, 0.000000, -0.991008, 0.000000, 1.000000, 0.000000, 0.991008, -0.000000, -0.133801),
        CFrame.new(2400.20679, 625.536072, 3887.9353, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["40m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(1228.957031, 623.854553, 3864.849609, -0.052334, 0.000000, -0.998630, -0.000000, 1.000000, 0.000000, 0.998630, 0.000000, -0.052334),
        CFrame.new(1285.483887, 623.893921, 3865.760498, -0.413727, -0.000000, -0.910401, -0.000000, 1.000000, -0.000000, 0.910401, 0.000000, -0.413727),
        CFrame.new(1313.448730, 615.678467, 3865.413086, -0.226306, -0.000000, -0.974056, -0.000000, 1.000000, -0.000000, 0.974056, -0.000000, -0.226306),
        CFrame.new(1562.323364, 611.810669, 3794.923340, 0.962112, 0.000003, -0.272656, -0.000001, 1.000000, 0.000007, 0.272656, -0.000007, 0.962112),
        CFrame.new(1759.683838, 629.388123, 3933.649658, 0.405095, -0.000007, 0.914274, 0.000001, 1.000000, 0.000007, -0.914274, -0.000002, 0.405095),
        CFrame.new(1962.168457, 620.205078, 3774.527588, -0.911729, 0.000000, 0.410793, 0.000000, 1.000000, -0.000000, -0.410793, -0.000000, -0.911729),
        CFrame.new(2096.351318, 630.247986, 3982.022217, 0.810655, 0.000000, 0.585525, -0.000000, 1.000000, -0.000000, -0.585525, 0.000000, 0.810655),
        CFrame.new(2298.798828, 626.476440, 3858.692139, -0.980698, 0.000000, 0.195530, 0.000000, 1.000000, -0.000000, -0.195530, -0.000000, -0.980698),
        CFrame.new(2399.847900, 627.855530, 3869.578857, -0.133801, 0.000000, -0.991008, 0.000000, 1.000000, 0.000000, 0.991008, -0.000000, -0.133801),
        CFrame.new(2489.549805, 639.401123, 3869.065918, 0.030428, -0.000000, -0.999537, 0.000000, 1.000000, -0.000000, 0.999537, -0.000000, 0.030428),
        CFrame.new(2739.078125, 647.017273, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2739.078125, 575.781555, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2842.287354, 577.455383, 3872.845703, -0.014983, 0.000000, -0.999888, -0.000000, 1.000000, 0.000000, 0.999888, 0.000000, -0.014983),
        CFrame.new(2914.543945, 604.127075, 3872.842285, -0.003051, -0.000000, -0.999995, -0.000000, 1.000000, -0.000000, 0.999995, 0.000000, -0.003051),
        CFrame.new(3006.660889, 576.788025, 3873.023193, -0.000733, 0.000000, -1.000000, -0.000000, 1.000000, 0.000000, 1.000000, 0.000000, -0.000733),
        CFrame.new(3270.609619, 592.782532, 3873.023193, -0.000001, -0.000000, -1.000000, 0.000000, 1.000000, -0.000000, 1.000000, -0.000000, -0.000001),
        CFrame.new(3269.20679, 590.632568, 3887.9353, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["60m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(1228.957031, 623.854553, 3864.849609, -0.052334, 0.000000, -0.998630, -0.000000, 1.000000, 0.000000, 0.998630, 0.000000, -0.052334),
        CFrame.new(1285.483887, 623.893921, 3865.760498, -0.413727, -0.000000, -0.910401, -0.000000, 1.000000, -0.000000, 0.910401, 0.000000, -0.413727),
        CFrame.new(1313.448730, 615.678467, 3865.413086, -0.226306, -0.000000, -0.974056, -0.000000, 1.000000, -0.000000, 0.974056, -0.000000, -0.226306),
        CFrame.new(1562.323364, 611.810669, 3794.923340, 0.962112, 0.000003, -0.272656, -0.000001, 1.000000, 0.000007, 0.272656, -0.000007, 0.962112),
        CFrame.new(1759.683838, 629.388123, 3933.649658, 0.405095, -0.000007, 0.914274, 0.000001, 1.000000, 0.000007, -0.914274, -0.000002, 0.405095),
        CFrame.new(1962.168457, 620.205078, 3774.527588, -0.911729, 0.000000, 0.410793, 0.000000, 1.000000, -0.000000, -0.410793, -0.000000, -0.911729),
        CFrame.new(2096.351318, 630.247986, 3982.022217, 0.810655, 0.000000, 0.585525, -0.000000, 1.000000, -0.000000, -0.585525, 0.000000, 0.810655),
        CFrame.new(2298.798828, 626.476440, 3858.692139, -0.980698, 0.000000, 0.195530, 0.000000, 1.000000, -0.000000, -0.195530, -0.000000, -0.980698),
        CFrame.new(2399.847900, 627.855530, 3869.578857, -0.133801, 0.000000, -0.991008, 0.000000, 1.000000, 0.000000, 0.991008, -0.000000, -0.133801),
        CFrame.new(2489.549805, 639.401123, 3869.065918, 0.030428, -0.000000, -0.999537, 0.000000, 1.000000, -0.000000, 0.999537, -0.000000, 0.030428),
        CFrame.new(2739.078125, 647.017273, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2739.078125, 575.781555, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2842.287354, 577.455383, 3872.845703, -0.014983, 0.000000, -0.999888, -0.000000, 1.000000, 0.000000, 0.999888, 0.000000, -0.014983),
        CFrame.new(2914.543945, 604.127075, 3872.842285, -0.003051, -0.000000, -0.999995, -0.000000, 1.000000, -0.000000, 0.999995, 0.000000, -0.003051),
        CFrame.new(3006.660889, 576.788025, 3873.023193, -0.000733, 0.000000, -1.000000, -0.000000, 1.000000, 0.000000, 1.000000, 0.000000, -0.000733),
        CFrame.new(3270.609619, 592.782532, 3873.023193, -0.000001, -0.000000, -1.000000, 0.000000, 1.000000, -0.000000, 1.000000, -0.000000, -0.000001),
        CFrame.new(3330.605225, 662.762329, 3864.807617, -0.005144, 0.000000, -0.999987, 0.000000, 1.000000, 0.000000, 0.999987, -0.000000, -0.005144),
        CFrame.new(3349.341309, 675.039185, 5132.775879, -0.934360, 0.000000, 0.356331, 0.000000, 1.000000, -0.000000, -0.356331, -0.000000, -0.934360),
        CFrame.new(4600.018066, 670.672302, 5139.960938, -0.010524, -0.000000, -0.999945, -0.000000, 1.000000, -0.000000, 0.999945, 0.000000, -0.010524),
        CFrame.new(4633.071777, 567.889771, 5142.104492, -0.038378, -0.000000, -0.999263, -0.000000, 1.000000, -0.000000, 0.999263, 0.000000, -0.038378),
        CFrame.new(4634.11133, 565.739807, 5159.40625, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["100m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(1228.957031, 623.854553, 3864.849609, -0.052334, 0.000000, -0.998630, -0.000000, 1.000000, 0.000000, 0.998630, 0.000000, -0.052334),
        CFrame.new(1285.483887, 623.893921, 3865.760498, -0.413727, -0.000000, -0.910401, -0.000000, 1.000000, -0.000000, 0.910401, 0.000000, -0.413727),
        CFrame.new(1313.448730, 615.678467, 3865.413086, -0.226306, -0.000000, -0.974056, -0.000000, 1.000000, -0.000000, 0.974056, -0.000000, -0.226306),
        CFrame.new(1562.323364, 611.810669, 3794.923340, 0.962112, 0.000003, -0.272656, -0.000001, 1.000000, 0.000007, 0.272656, -0.000007, 0.962112),
        CFrame.new(1759.683838, 629.388123, 3933.649658, 0.405095, -0.000007, 0.914274, 0.000001, 1.000000, 0.000007, -0.914274, -0.000002, 0.405095),
        CFrame.new(1962.168457, 620.205078, 3774.527588, -0.911729, 0.000000, 0.410793, 0.000000, 1.000000, -0.000000, -0.410793, -0.000000, -0.911729),
        CFrame.new(2096.351318, 630.247986, 3982.022217, 0.810655, 0.000000, 0.585525, -0.000000, 1.000000, -0.000000, -0.585525, 0.000000, 0.810655),
        CFrame.new(2298.798828, 626.476440, 3858.692139, -0.980698, 0.000000, 0.195530, 0.000000, 1.000000, -0.000000, -0.195530, -0.000000, -0.980698),
        CFrame.new(2399.847900, 627.855530, 3869.578857, -0.133801, 0.000000, -0.991008, 0.000000, 1.000000, 0.000000, 0.991008, -0.000000, -0.133801),
        CFrame.new(2489.549805, 639.401123, 3869.065918, 0.030428, -0.000000, -0.999537, 0.000000, 1.000000, -0.000000, 0.999537, -0.000000, 0.030428),
        CFrame.new(2739.078125, 647.017273, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2739.078125, 575.781555, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2842.287354, 577.455383, 3872.845703, -0.014983, 0.000000, -0.999888, -0.000000, 1.000000, 0.000000, 0.999888, 0.000000, -0.014983),
        CFrame.new(2914.543945, 604.127075, 3872.842285, -0.003051, -0.000000, -0.999995, -0.000000, 1.000000, -0.000000, 0.999995, 0.000000, -0.003051),
        CFrame.new(3006.660889, 576.788025, 3873.023193, -0.000733, 0.000000, -1.000000, -0.000000, 1.000000, 0.000000, 1.000000, 0.000000, -0.000733),
        CFrame.new(3270.609619, 592.782532, 3873.023193, -0.000001, -0.000000, -1.000000, 0.000000, 1.000000, -0.000000, 1.000000, -0.000000, -0.000001),
        CFrame.new(3330.605225, 662.762329, 3864.807617, -0.005144, 0.000000, -0.999987, 0.000000, 1.000000, 0.000000, 0.999987, -0.000000, -0.005144),
        CFrame.new(3349.341309, 675.039185, 5132.775879, -0.934360, 0.000000, 0.356331, 0.000000, 1.000000, -0.000000, -0.356331, -0.000000, -0.934360),
        CFrame.new(4608.634766, 664.437256, 5145.000000, 0.896450, -0.000073, -0.443144, -0.000001, 1.000000, -0.000165, 0.443144, 0.000148, 0.896450),
        CFrame.new(4633.071777, 567.889771, 5142.104492, -0.038378, -0.000000, -0.999263, -0.000000, 1.000000, -0.000000, 0.999263, 0.000000, -0.038378),
        CFrame.new(4914.834961, 568.090027, 5137.088379, 0.865863, 0.000000, 0.500281, 0.000000, 1.000000, -0.000000, -0.500281, 0.000000, 0.865863),
        CFrame.new(4915.774414, 568.090027, 5032.125000, 0.999424, 0.000000, 0.033941, 0.000000, 1.000000, -0.000000, -0.033941, 0.000000, 0.999424),
        CFrame.new(4916.163086, 694.776062, 5025.153809, 0.998900, -0.000000, 0.046889, 0.000000, 1.000000, 0.000000, -0.046889, -0.000000, 0.998900),
        CFrame.new(4911.554199, 674.889954, 5049.761230, -0.194324, 0.000000, 0.980937, -0.000000, 1.000000, -0.000000, -0.980937, -0.000000, -0.194324),
        CFrame.new(4680.507812, 674.889893, 5044.118652, 0.338869, 0.000000, 0.940833, 0.000000, 1.000000, -0.000000, -0.940833, 0.000000, 0.338869),
        CFrame.new(4678.230469, 674.889893, 5256.398926, 0.571169, -0.000000, -0.820833, 0.000000, 1.000000, 0.000000, 0.820833, -0.000000, 0.571169),
        CFrame.new(4989.735840, 684.065247, 5145.431641, 0.982345, -0.000000, 0.187080, 0.000000, 1.000000, 0.000000, -0.187080, -0.000000, 0.982345),
        CFrame.new(4989.196289, 557.884766, 5140.689941, 0.983356, -0.000000, 0.181690, 0.000000, 1.000000, 0.000000, -0.181690, -0.000000, 0.983356),
        CFrame.new(5031.648438, 557.892395, 5142.913086, 0.013188, -0.000000, -0.999913, -0.000000, 1.000000, -0.000000, 0.999913, 0.000000, 0.013188),
        CFrame.new(5033.11133, 555.684509, 5159.02393, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["150m Win"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440),
        CFrame.new(-399.266602, 500.032410, 468.069519, -0.989533, -0.000000, -0.144308, -0.000000, 1.000000, -0.000000, 0.144308, -0.000000, -0.989533),
        CFrame.new(-346.711365, 500.032410, 475.916107, -0.948263, -0.000000, -0.317485, -0.000000, 1.000000, 0.000000, 0.317485, 0.000000, -0.948263),
        CFrame.new(-348.992889, 526.503845, 563.001526, 0.997282, -0.000000, 0.073673, 0.000000, 1.000000, -0.000000, -0.073673, 0.000000, 0.997282),
        CFrame.new(-455.098694, 527.101440, 575.907593, 0.048843, -0.000000, 0.998806, -0.000000, 1.000000, 0.000000, -0.998806, -0.000000, 0.048843),
        CFrame.new(-454.332062, 554.082153, 478.809631, -0.813140, 0.000000, 0.582069, -0.000000, 1.000000, -0.000000, -0.582069, -0.000000, -0.813140),
        CFrame.new(-349.346741, 554.101440, 477.595062, -0.928580, 0.000000, -0.371132, 0.000000, 1.000000, 0.000000, 0.371132, 0.000000, -0.928580),
        CFrame.new(-350.053223, 581.169006, 565.820557, 0.298919, 0.000000, 0.954278, 0.000000, 1.000000, -0.000000, -0.954278, 0.000000, 0.298919),
        CFrame.new(-453.963562, 581.169006, 565.560974, 0.729117, -0.000000, 0.684389, 0.000000, 1.000000, 0.000000, -0.684389, 0.000000, 0.729117),
        CFrame.new(-449.429260, 608.015564, 479.553223, 0.999562, -0.000000, 0.029586, 0.000000, 1.000000, -0.000000, -0.029586, 0.000000, 0.999562),
        CFrame.new(-398.216309, 608.169006, 481.353027, 0.470771, -0.000000, -0.882255, -0.000000, 1.000000, -0.000000, 0.882255, 0.000000, 0.470771),
        CFrame.new(-399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672),
        CFrame.new(-400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693),
        CFrame.new(-397.850922, 607.672913, 1259.856567, -0.997229, 0.000000, 0.074397, 0.000000, 1.000000, -0.000000, -0.074397, -0.000000, -0.997229),
        CFrame.new(-402.148468, 617.889832, 1328.341919, -0.998053, 0.000000, 0.062365, 0.000000, 1.000000, 0.000000, -0.062365, 0.000000, -0.998053),
        CFrame.new(-389.678192, 608.548401, 1480.209961, -0.939693, -0.000000, -0.342019, -0.000000, 1.000000, -0.000000, 0.342019, -0.000000, -0.939693),
        CFrame.new(-361.716675, 628.462891, 1544.503052, -0.998629, 0.000000, 0.052337, -0.000000, 1.000000, -0.000000, -0.052337, -0.000000, -0.998629),
        CFrame.new(-362.081940, 628.462891, 1600.222290, -0.999922, -0.000000, -0.012529, -0.000000, 1.000000, -0.000000, 0.012529, -0.000000, -0.999922),
        CFrame.new(-362.471466, 605.594421, 1756.540527, -0.999991, 0.000000, -0.004348, 0.000000, 1.000000, -0.000000, 0.004348, -0.000000, -0.999991),
        CFrame.new(-361.869904, 616.840454, 1790.927246, -0.999915, -0.000000, -0.013049, -0.000000, 1.000000, 0.000000, 0.013049, 0.000000, -0.999915),
        CFrame.new(-401.990143, 607.671265, 1921.545532, -0.995396, 0.000000, 0.095846, 0.000000, 1.000000, -0.000000, -0.095846, -0.000000, -0.995396),
        CFrame.new(-400.180786, 618.547852, 1956.252197, -0.999998, 0.000000, -0.001799, 0.000000, 1.000000, -0.000000, 0.001799, -0.000000, -0.999998),
        CFrame.new(-401.302124, 607.684753, 2103.694092, -0.999962, -0.000000, 0.008727, -0.000000, 1.000000, 0.000000, -0.008727, 0.000000, -0.999962),
        CFrame.new(-400.410919, 618.839417, 2138.031494, -0.999398, -0.000000, 0.034688, -0.000000, 1.000000, 0.000000, -0.034688, 0.000000, -0.999398),
        CFrame.new(-399.392334, 623.614563, 2412.341553, -0.998135, 0.000000, 0.061049, -0.000000, 1.000000, -0.000000, -0.061049, -0.000000, -0.998135),
        CFrame.new(-400.611725, 623.563232, 2652.665283, -0.999914, -0.000000, -0.013091, -0.000000, 1.000000, -0.000000, 0.013091, -0.000000, -0.999914),
        CFrame.new(-402.091583, 623.586426, 3156.047852, -0.999109, 0.000000, 0.042201, 0.000000, 1.000000, 0.000000, -0.042201, 0.000000, -0.999109),
        CFrame.new(-407.748566, 623.586487, 3323.787354, -0.994069, 0.000000, 0.108748, 0.000000, 1.000000, -0.000000, -0.108748, -0.000000, -0.994069),
        CFrame.new(-185.036850, 623.586487, 3331.813965, 0.022235, 0.000000, -0.999753, -0.000000, 1.000000, 0.000000, 0.999753, -0.000000, 0.022235),
        CFrame.new(-101.998528, 623.586487, 3220.691406, -0.998516, 0.000000, -0.054450, 0.000000, 1.000000, 0.000000, 0.054450, 0.000000, -0.998516),
        CFrame.new(-106.595871, 623.586487, 3434.463135, -0.999860, 0.000000, -0.016749, 0.000000, 1.000000, 0.000000, 0.016749, 0.000000, -0.999860),
        CFrame.new(-262.635681, 623.586487, 3434.463623, -0.001067, -0.000000, 0.999999, -0.000000, 1.000000, 0.000000, -0.999999, -0.000000, -0.001067),
        CFrame.new(-262.430420, 623.586487, 3619.084229, -0.999960, -0.000000, 0.008994, -0.000000, 1.000000, 0.000000, -0.008994, 0.000000, -0.999960),
        CFrame.new(-538.839050, 623.586487, 3620.724121, -0.007861, 0.000000, 0.999969, 0.000000, 1.000000, -0.000000, -0.999969, 0.000000, -0.007861),
        CFrame.new(-540.731201, 623.586487, 3804.175781, -0.999763, 0.000000, 0.021750, 0.000000, 1.000000, -0.000000, -0.021750, -0.000000, -0.999763),
        CFrame.new(-154.868347, 623.586487, 3802.911865, 0.002282, 0.000000, -0.999997, 0.000000, 1.000000, 0.000000, 0.999997, -0.000000, 0.002282),
        CFrame.new(-60.804108, 623.652832, 3867.018066, -0.182238, 0.000000, -0.983254, 0.000000, 1.000000, -0.000000, 0.983254, -0.000000, -0.182238),
        CFrame.new(1228.957031, 623.854553, 3864.849609, -0.052334, 0.000000, -0.998630, -0.000000, 1.000000, 0.000000, 0.998630, 0.000000, -0.052334),
        CFrame.new(1285.483887, 623.893921, 3865.760498, -0.413727, -0.000000, -0.910401, -0.000000, 1.000000, -0.000000, 0.910401, 0.000000, -0.413727),
        CFrame.new(1313.448730, 615.678467, 3865.413086, -0.226306, -0.000000, -0.974056, -0.000000, 1.000000, -0.000000, 0.974056, -0.000000, -0.226306),
        CFrame.new(1562.323364, 611.810669, 3794.923340, 0.962112, 0.000003, -0.272656, -0.000001, 1.000000, 0.000007, 0.272656, -0.000007, 0.962112),
        CFrame.new(1759.683838, 629.388123, 3933.649658, 0.405095, -0.000007, 0.914274, 0.000001, 1.000000, 0.000007, -0.914274, -0.000002, 0.405095),
        CFrame.new(1962.168457, 620.205078, 3774.527588, -0.911729, 0.000000, 0.410793, 0.000000, 1.000000, -0.000000, -0.410793, -0.000000, -0.911729),
        CFrame.new(2096.351318, 630.247986, 3982.022217, 0.810655, 0.000000, 0.585525, -0.000000, 1.000000, -0.000000, -0.585525, 0.000000, 0.810655),
        CFrame.new(2298.798828, 626.476440, 3858.692139, -0.980698, 0.000000, 0.195530, 0.000000, 1.000000, -0.000000, -0.195530, -0.000000, -0.980698),
        CFrame.new(2399.847900, 627.855530, 3869.578857, -0.133801, 0.000000, -0.991008, 0.000000, 1.000000, 0.000000, 0.991008, -0.000000, -0.133801),
        CFrame.new(2489.549805, 639.401123, 3869.065918, 0.030428, -0.000000, -0.999537, 0.000000, 1.000000, -0.000000, 0.999537, -0.000000, 0.030428),
        CFrame.new(2739.078125, 647.017273, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2739.078125, 575.781555, 3872.845215, -0.890378, 0.000000, -0.455222, 0.000000, 1.000000, 0.000000, 0.455222, -0.000000, -0.890378),
        CFrame.new(2842.287354, 577.455383, 3872.845703, -0.014983, 0.000000, -0.999888, -0.000000, 1.000000, 0.000000, 0.999888, 0.000000, -0.014983),
        CFrame.new(2914.543945, 604.127075, 3872.842285, -0.003051, -0.000000, -0.999995, -0.000000, 1.000000, -0.000000, 0.999995, 0.000000, -0.003051),
        CFrame.new(3006.660889, 576.788025, 3873.023193, -0.000733, 0.000000, -1.000000, -0.000000, 1.000000, 0.000000, 1.000000, 0.000000, -0.000733),
        CFrame.new(3270.609619, 592.782532, 3873.023193, -0.000001, -0.000000, -1.000000, 0.000000, 1.000000, -0.000000, 1.000000, -0.000000, -0.000001),
        CFrame.new(3330.605225, 662.762329, 3864.807617, -0.005144, 0.000000, -0.999987, 0.000000, 1.000000, 0.000000, 0.999987, -0.000000, -0.005144),
        CFrame.new(3349.341309, 675.039185, 5132.775879, -0.934360, 0.000000, 0.356331, 0.000000, 1.000000, -0.000000, -0.356331, -0.000000, -0.934360),
        CFrame.new(4608.634766, 664.437256, 5145.000000, 0.896450, -0.000073, -0.443144, -0.000001, 1.000000, -0.000165, 0.443144, 0.000148, 0.896450),
        CFrame.new(4633.071777, 567.889771, 5142.104492, -0.038378, -0.000000, -0.999263, -0.000000, 1.000000, -0.000000, 0.999263, 0.000000, -0.038378),
        CFrame.new(4914.834961, 568.090027, 5137.088379, 0.865863, 0.000000, 0.500281, 0.000000, 1.000000, -0.000000, -0.500281, 0.000000, 0.865863),
        CFrame.new(4915.774414, 568.090027, 5032.125000, 0.999424, 0.000000, 0.033941, 0.000000, 1.000000, -0.000000, -0.033941, 0.000000, 0.999424),
        CFrame.new(4916.163086, 694.776062, 5025.153809, 0.998900, -0.000000, 0.046889, 0.000000, 1.000000, 0.000000, -0.046889, -0.000000, 0.998900),
        CFrame.new(4911.554199, 674.889954, 5049.761230, -0.194324, 0.000000, 0.980937, -0.000000, 1.000000, -0.000000, -0.980937, -0.000000, -0.194324),
        CFrame.new(4680.507812, 674.889893, 5044.118652, 0.338869, 0.000000, 0.940833, 0.000000, 1.000000, -0.000000, -0.940833, 0.000000, 0.338869),
        CFrame.new(4678.230469, 674.889893, 5256.398926, 0.571169, -0.000000, -0.820833, 0.000000, 1.000000, 0.000000, 0.820833, -0.000000, 0.571169),
        CFrame.new(4989.735840, 684.065247, 5145.431641, 0.982345, -0.000000, 0.187080, 0.000000, 1.000000, 0.000000, -0.187080, -0.000000, 0.982345),
        CFrame.new(4989.196289, 557.884766, 5140.689941, 0.983356, -0.000000, 0.181690, 0.000000, 1.000000, 0.000000, -0.181690, -0.000000, 0.983356),
        CFrame.new(5031.648438, 557.892395, 5142.913086, 0.013188, -0.000000, -0.999913, -0.000000, 1.000000, -0.000000, 0.999913, 0.000000, 0.013188),
        CFrame.new(6224.155273, 557.746582, 5143.761230, -0.003275, -0.000000, -0.999995, 0.000000, 1.000000, -0.000000, 0.999995, -0.000000, -0.003275),
        CFrame.new(6228.785645, 557.746582, 5081.337402, 0.993643, -0.000000, -0.112577, 0.000000, 1.000000, -0.000000, 0.112577, 0.000000, 0.993643),
        CFrame.new(6357.708984, 591.772339, 5081.111816, 0.436250, -0.000000, -0.899825, 0.000000, 1.000000, -0.000000, 0.899825, -0.000000, 0.436250),
        CFrame.new(6354.913086, 591.772339, 5192.856445, -0.997620, 0.000000, 0.068949, 0.000000, 1.000000, -0.000000, -0.068949, -0.000000, -0.997620),
        CFrame.new(6236.571777, 625.711548, 5097.673340, 0.999941, 0.000000, 0.010822, -0.000000, 1.000000, 0.000000, -0.010822, -0.000000, 0.999941),
        CFrame.new(6352.888184, 659.735596, 5100.101562, -0.077019, 0.000000, -0.997030, -0.000000, 1.000000, 0.000000, 0.997030, 0.000000, -0.077019),
        CFrame.new(6351.253906, 659.735596, 5187.146973, 0.401625, 0.000000, -0.915804, 0.000000, 1.000000, 0.000000, 0.915804, -0.000000, 0.401625),
        CFrame.new(6240.217773, 693.674805, 5142.436035, 0.961475, -0.000000, -0.274893, 0.000000, 1.000000, -0.000000, 0.274893, 0.000000, 0.961475),
        CFrame.new(6444.738770, 693.669434, 5144.001465, -0.034571, 0.000000, -0.999402, 0.000000, 1.000000, 0.000000, 0.999402, 0.000000, -0.034571),
        CFrame.new(6537.124512, 714.453613, 5102.266113, 0.296994, 0.000000, -0.954879, -0.000000, 1.000000, 0.000000, 0.954879, 0.000000, 0.296994),
        CFrame.new(6635.208496, 734.674500, 5100.308594, -0.043303, 0.000000, -0.999062, 0.000000, 1.000000, 0.000000, 0.999062, -0.000000, -0.043303),
        CFrame.new(6671.007324, 680.811523, 5103.399902, 0.045209, 0.000000, -0.998978, 0.000000, 1.000000, 0.000000, 0.998978, -0.000000, 0.045209),
        CFrame.new(7050.884277, 703.673828, 5107.985352, -0.003471, -0.000000, -0.999994, -0.000000, 1.000000, -0.000000, 0.999994, 0.000000, -0.003471),
        CFrame.new(7291.736328, 709.562500, 5107.985352, 0.000000, 0.000000, -1.000000, 0.000000, 1.000000, 0.000000, 1.000000, -0.000000, 0.000000),
        CFrame.new(7614.695801, 721.867859, 5146.940918, 0.017438, 0.000000, 0.999848, -0.000000, 1.000000, -0.000000, -0.999848, 0.000000, 0.017438),
        CFrame.new(7614.695801, 666.500183, 5146.940918, 0.017438, 0.000000, 0.999848, -0.000000, 1.000000, -0.000000, -0.999848, 0.000000, 0.017438),
        CFrame.new(7826.973633, 711.907593, 5144.003906, -0.066449, 0.000000, -0.997790, 0.000000, 1.000000, 0.000000, 0.997790, -0.000000, -0.066449),
        CFrame.new(7953.806641, 712.456787, 5143.740234, 0.053341, 0.000000, -0.998576, 0.000000, 1.000000, 0.000000, 0.998576, -0.000000, 0.053341),
        CFrame.new(7987.46631, 710.306824, 5143.42285, -1.1920929e-07, 0, 1.00000012, 0, 1, 0, -1.00000012, 0, -1.1920929e-07)
    }
}

local Rutas3 = {
    ["300m Win"] = {
        CFrame.new(-1432.720703, -159.273773, -879.229370, -0.990567, -0.000000, 0.137029, -0.000000, 1.000000, 0.000000, -0.137029, 0.000000, -0.990567),
        CFrame.new(-1430.168457, -156.144562, -830.335022, -0.975363, 0.000000, 0.220604, 0.000000, 1.000000, 0.000000, -0.220604, 0.000000, -0.975363),
        CFrame.new(-1429.785156, -125.437531, -732.686279, -0.994522, -0.000000, 0.104525, -0.000000, 1.000000, 0.000000, -0.104525, 0.000000, -0.994522),
        CFrame.new(-1431.064819, -92.677711, -628.509766, -0.963630, -0.000000, 0.267238, -0.000000, 1.000000, -0.000000, -0.267238, -0.000000, -0.963630),
        CFrame.new(-1430.362183, -69.386772, -528.781860, -0.961186, 0.000000, -0.275901, 0.000000, 1.000000, 0.000000, 0.275901, 0.000000, -0.961186),
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134),
        CFrame.new(-1481.83105, -71.6486893, -515.770508, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["500m Win"] = {
        CFrame.new(-1432.720703, -159.273773, -879.229370, -0.990567, -0.000000, 0.137029, -0.000000, 1.000000, 0.000000, -0.137029, 0.000000, -0.990567),
        CFrame.new(-1430.168457, -156.144562, -830.335022, -0.975363, 0.000000, 0.220604, 0.000000, 1.000000, 0.000000, -0.220604, 0.000000, -0.975363),
        CFrame.new(-1429.785156, -125.437531, -732.686279, -0.994522, -0.000000, 0.104525, -0.000000, 1.000000, 0.000000, -0.104525, 0.000000, -0.994522),
        CFrame.new(-1431.064819, -92.677711, -628.509766, -0.963630, -0.000000, 0.267238, -0.000000, 1.000000, -0.000000, -0.267238, -0.000000, -0.963630),
        CFrame.new(-1430.362183, -69.386772, -528.781860, -0.961186, 0.000000, -0.275901, 0.000000, 1.000000, 0.000000, 0.275901, 0.000000, -0.961186),
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134),
        CFrame.new(-1455.348267, -58.998470, -396.893402, -0.999656, 0.000000, -0.026242, 0.000000, 1.000000, 0.000000, 0.026242, 0.000000, -0.999656),
        CFrame.new(-1456.244019, -56.886787, -194.005432, -0.999657, 0.000000, 0.026175, 0.000000, 1.000000, -0.000000, -0.026175, -0.000000, -0.999657),
        CFrame.new(-1454.050537, -57.144634, -20.910961, -0.999787, -0.000000, 0.020627, -0.000000, 1.000000, 0.000000, -0.020627, 0.000000, -0.999787),
        CFrame.new(-1480.75891, -59.4065361, -15.8134289, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["800m Win"] = {
        CFrame.new(-1432.720703, -159.273773, -879.229370, -0.990567, -0.000000, 0.137029, -0.000000, 1.000000, 0.000000, -0.137029, 0.000000, -0.990567),
        CFrame.new(-1430.168457, -156.144562, -830.335022, -0.975363, 0.000000, 0.220604, 0.000000, 1.000000, 0.000000, -0.220604, 0.000000, -0.975363),
        CFrame.new(-1429.785156, -125.437531, -732.686279, -0.994522, -0.000000, 0.104525, -0.000000, 1.000000, 0.000000, -0.104525, 0.000000, -0.994522),
        CFrame.new(-1431.064819, -92.677711, -628.509766, -0.963630, -0.000000, 0.267238, -0.000000, 1.000000, -0.000000, -0.267238, -0.000000, -0.963630),
        CFrame.new(-1430.362183, -69.386772, -528.781860, -0.961186, 0.000000, -0.275901, 0.000000, 1.000000, 0.000000, 0.275901, 0.000000, -0.961186),
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134),
        CFrame.new(-1455.348267, -58.998470, -396.893402, -0.999656, 0.000000, -0.026242, 0.000000, 1.000000, 0.000000, 0.026242, 0.000000, -0.999656),
        CFrame.new(-1456.244019, -56.886787, -194.005432, -0.999657, 0.000000, 0.026175, 0.000000, 1.000000, -0.000000, -0.026175, -0.000000, -0.999657),
        CFrame.new(-1454.050537, -57.144634, -20.910961, -0.999787, -0.000000, 0.020627, -0.000000, 1.000000, 0.000000, -0.020627, 0.000000, -0.999787),
        CFrame.new(-1453.642090, -56.894630, 62.750778, -0.999976, -0.000000, 0.006950, 0.000000, 1.000000, 0.000000, -0.006950, 0.000000, -0.999976),
        CFrame.new(-1453.968140, 223.768494, 85.884483, 0.999882, 0.000000, 0.015367, -0.000000, 1.000000, 0.000000, -0.015367, -0.000000, 0.999882),
        CFrame.new(-1455.083984, 222.489151, 175.389389, -0.997603, 0.000000, 0.069199, -0.000000, 1.000000, -0.000000, -0.069199, -0.000000, -0.997603),
        CFrame.new(-1456.110962, 214.865356, 331.975708, -1.000000, -0.000000, 0.000001, -0.000000, 1.000000, -0.000000, -0.000001, -0.000000, -1.000000),
        CFrame.new(-1480.76941, 212.603485, 332.140778, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["1.25b Win"] = {
        CFrame.new(-1432.720703, -159.273773, -879.229370, -0.990567, -0.000000, 0.137029, -0.000000, 1.000000, 0.000000, -0.137029, 0.000000, -0.990567),
        CFrame.new(-1430.168457, -156.144562, -830.335022, -0.975363, 0.000000, 0.220604, 0.000000, 1.000000, 0.000000, -0.220604, 0.000000, -0.975363),
        CFrame.new(-1429.785156, -125.437531, -732.686279, -0.994522, -0.000000, 0.104525, -0.000000, 1.000000, 0.000000, -0.104525, 0.000000, -0.994522),
        CFrame.new(-1431.064819, -92.677711, -628.509766, -0.963630, -0.000000, 0.267238, -0.000000, 1.000000, -0.000000, -0.267238, -0.000000, -0.963630),
        CFrame.new(-1430.362183, -69.386772, -528.781860, -0.961186, 0.000000, -0.275901, 0.000000, 1.000000, 0.000000, 0.275901, 0.000000, -0.961186),
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134),
        CFrame.new(-1455.348267, -58.998470, -396.893402, -0.999656, 0.000000, -0.026242, 0.000000, 1.000000, 0.000000, 0.026242, 0.000000, -0.999656),
        CFrame.new(-1456.244019, -56.886787, -194.005432, -0.999657, 0.000000, 0.026175, 0.000000, 1.000000, -0.000000, -0.026175, -0.000000, -0.999657),
        CFrame.new(-1454.050537, -57.144634, -20.910961, -0.999787, -0.000000, 0.020627, -0.000000, 1.000000, 0.000000, -0.020627, 0.000000, -0.999787),
        CFrame.new(-1453.642090, -56.894630, 62.750778, -0.999976, -0.000000, 0.006950, 0.000000, 1.000000, 0.000000, -0.006950, 0.000000, -0.999976),
        CFrame.new(-1453.968140, 223.768494, 85.884483, 0.999882, 0.000000, 0.015367, -0.000000, 1.000000, 0.000000, -0.015367, -0.000000, 0.999882),
        CFrame.new(-1455.083984, 222.489151, 175.389389, -0.997603, 0.000000, 0.069199, -0.000000, 1.000000, -0.000000, -0.069199, -0.000000, -0.997603),
        CFrame.new(-1456.110962, 214.865356, 331.975708, -1.000000, -0.000000, 0.000001, -0.000000, 1.000000, -0.000000, -0.000001, -0.000000, -1.000000),
        CFrame.new(-1452.121338, 214.865356, 622.063904, -0.990664, -0.000000, -0.136325, 0.000000, 1.000000, -0.000000, 0.136325, -0.000000, -0.990664),
        CFrame.new(-1453.310547, 368.878418, 618.495544, -0.745594, -0.000000, 0.666401, -0.000000, 1.000000, -0.000000, -0.666401, -0.000000, -0.745594),
        CFrame.new(-1456.194824, 360.065369, 496.716949, 0.999997, -0.000000, -0.002394, 0.000000, 1.000000, -0.000000, 0.002394, 0.000000, 0.999997),
        CFrame.new(-1327.640625, 361.792694, 493.324860, 0.010847, -0.000000, -0.999941, -0.000000, 1.000000, -0.000000, 0.999941, 0.000000, 0.010847),
        CFrame.new(-1247.714111, 333.808014, 495.830719, -0.367180, -0.000000, -0.930150, -0.000000, 1.000000, -0.000000, 0.930150, 0.000000, -0.367180),
        CFrame.new(-1238.616943, 322.544586, 596.694946, -0.995401, -0.000000, -0.095797, 0.000000, 1.000000, -0.000000, 0.095797, -0.000000, -0.995401),
        CFrame.new(-1234.626221, 328.705811, 657.543701, -0.998574, -0.000000, -0.053377, -0.000000, 1.000000, 0.000000, 0.053377, 0.000000, -0.998574),
        CFrame.new(-1218.170410, 344.652130, 828.388000, -0.995396, -0.000000, -0.095846, -0.000000, 1.000000, -0.000000, 0.095846, -0.000000, -0.995396),
        CFrame.new(-1363.507080, 363.765625, 841.644653, -0.069756, -0.000000, 0.997564, -0.000000, 1.000000, 0.000000, -0.997564, 0.000000, -0.069756),
        CFrame.new(-1400.548950, 361.551300, 821.816467, 0.980001, 0.000000, -0.198991, -0.000000, 1.000000, 0.000000, 0.198991, -0.000000, 0.980001),
        CFrame.new(-1402.886230, 373.848053, 726.604065, 0.999020, -0.000000, 0.044260, 0.000000, 1.000000, 0.000000, -0.044260, -0.000000, 0.999020),
        CFrame.new(-1403.974731, 552.304443, 728.641296, 0.993672, -0.000000, 0.112321, -0.000000, 1.000000, 0.000001, -0.112321, -0.000001, 0.993672),
        CFrame.new(-1405.482056, 532.876953, 753.763611, -0.998630, -0.000000, 0.052336, -0.000000, 1.000000, -0.000000, -0.052336, -0.000000, -0.998630),
        CFrame.new(-1431.33264, 530.615051, 759.624756, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["2b Win"] = {
        CFrame.new(-1432.720703, -159.273773, -879.229370, -0.990567, -0.000000, 0.137029, -0.000000, 1.000000, 0.000000, -0.137029, 0.000000, -0.990567),
        CFrame.new(-1430.168457, -156.144562, -830.335022, -0.975363, 0.000000, 0.220604, 0.000000, 1.000000, 0.000000, -0.220604, 0.000000, -0.975363),
        CFrame.new(-1429.785156, -125.437531, -732.686279, -0.994522, -0.000000, 0.104525, -0.000000, 1.000000, 0.000000, -0.104525, 0.000000, -0.994522),
        CFrame.new(-1431.064819, -92.677711, -628.509766, -0.963630, -0.000000, 0.267238, -0.000000, 1.000000, -0.000000, -0.267238, -0.000000, -0.963630),
        CFrame.new(-1430.362183, -69.386772, -528.781860, -0.961186, 0.000000, -0.275901, 0.000000, 1.000000, 0.000000, 0.275901, 0.000000, -0.961186),
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134),
        CFrame.new(-1455.348267, -58.998470, -396.893402, -0.999656, 0.000000, -0.026242, 0.000000, 1.000000, 0.000000, 0.026242, 0.000000, -0.999656),
        CFrame.new(-1456.244019, -56.886787, -194.005432, -0.999657, 0.000000, 0.026175, 0.000000, 1.000000, -0.000000, -0.026175, -0.000000, -0.999657),
        CFrame.new(-1454.050537, -57.144634, -20.910961, -0.999787, -0.000000, 0.020627, -0.000000, 1.000000, 0.000000, -0.020627, 0.000000, -0.999787),
        CFrame.new(-1453.642090, -56.894630, 62.750778, -0.999976, -0.000000, 0.006950, 0.000000, 1.000000, 0.000000, -0.006950, 0.000000, -0.999976),
        CFrame.new(-1453.968140, 223.768494, 85.884483, 0.999882, 0.000000, 0.015367, -0.000000, 1.000000, 0.000000, -0.015367, -0.000000, 0.999882),
        CFrame.new(-1455.083984, 222.489151, 175.389389, -0.997603, 0.000000, 0.069199, -0.000000, 1.000000, -0.000000, -0.069199, -0.000000, -0.997603),
        CFrame.new(-1456.110962, 214.865356, 331.975708, -1.000000, -0.000000, 0.000001, -0.000000, 1.000000, -0.000000, -0.000001, -0.000000, -1.000000),
        CFrame.new(-1452.121338, 214.865356, 622.063904, -0.990664, -0.000000, -0.136325, 0.000000, 1.000000, -0.000000, 0.136325, -0.000000, -0.990664),
        CFrame.new(-1453.310547, 368.878418, 618.495544, -0.745594, -0.000000, 0.666401, -0.000000, 1.000000, -0.000000, -0.666401, -0.000000, -0.745594),
        CFrame.new(-1456.194824, 360.065369, 496.716949, 0.999997, -0.000000, -0.002394, 0.000000, 1.000000, -0.000000, 0.002394, 0.000000, 0.999997),
        CFrame.new(-1327.640625, 361.792694, 493.324860, 0.010847, -0.000000, -0.999941, -0.000000, 1.000000, -0.000000, 0.999941, 0.000000, 0.010847),
        CFrame.new(-1247.714111, 333.808014, 495.830719, -0.367180, -0.000000, -0.930150, -0.000000, 1.000000, -0.000000, 0.930150, 0.000000, -0.367180),
        CFrame.new(-1238.616943, 322.544586, 596.694946, -0.995401, -0.000000, -0.095797, 0.000000, 1.000000, -0.000000, 0.095797, -0.000000, -0.995401),
        CFrame.new(-1234.626221, 328.705811, 657.543701, -0.998574, -0.000000, -0.053377, -0.000000, 1.000000, 0.000000, 0.053377, 0.000000, -0.998574),
        CFrame.new(-1218.170410, 344.652130, 828.388000, -0.995396, -0.000000, -0.095846, -0.000000, 1.000000, -0.000000, 0.095846, -0.000000, -0.995396),
        CFrame.new(-1363.507080, 363.765625, 841.644653, -0.069756, -0.000000, 0.997564, -0.000000, 1.000000, 0.000000, -0.997564, 0.000000, -0.069756),
        CFrame.new(-1400.548950, 361.551300, 821.816467, 0.980001, 0.000000, -0.198991, -0.000000, 1.000000, 0.000000, 0.198991, -0.000000, 0.980001),
        CFrame.new(-1402.886230, 373.848053, 726.604065, 0.999020, -0.000000, 0.044260, 0.000000, 1.000000, 0.000000, -0.044260, -0.000000, 0.999020),
        CFrame.new(-1403.974731, 552.304443, 728.641296, 0.993672, -0.000000, 0.112321, -0.000000, 1.000000, 0.000001, -0.112321, -0.000001, 0.993672),
        CFrame.new(-1405.482056, 532.876953, 753.763611, -0.998630, -0.000000, 0.052336, -0.000000, 1.000000, -0.000000, -0.052336, -0.000000, -0.998630),
        CFrame.new(-1406.810059, 532.875732, 1324.752686, -1.000000, 0.000000, -0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, -1.000000),
        CFrame.new(-1431.45251, 530.613953, 1329.82703, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["3.5b Win"] = {
        CFrame.new(-1432.720703, -159.273773, -879.229370, -0.990567, -0.000000, 0.137029, -0.000000, 1.000000, 0.000000, -0.137029, 0.000000, -0.990567),
        CFrame.new(-1430.168457, -156.144562, -830.335022, -0.975363, 0.000000, 0.220604, 0.000000, 1.000000, 0.000000, -0.220604, 0.000000, -0.975363),
        CFrame.new(-1429.785156, -125.437531, -732.686279, -0.994522, -0.000000, 0.104525, -0.000000, 1.000000, 0.000000, -0.104525, 0.000000, -0.994522),
        CFrame.new(-1431.064819, -92.677711, -628.509766, -0.963630, -0.000000, 0.267238, -0.000000, 1.000000, -0.000000, -0.267238, -0.000000, -0.963630),
        CFrame.new(-1430.362183, -69.386772, -528.781860, -0.961186, 0.000000, -0.275901, 0.000000, 1.000000, 0.000000, 0.275901, 0.000000, -0.961186),
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134),
        CFrame.new(-1455.348267, -58.998470, -396.893402, -0.999656, 0.000000, -0.026242, 0.000000, 1.000000, 0.000000, 0.026242, 0.000000, -0.999656),
        CFrame.new(-1456.244019, -56.886787, -194.005432, -0.999657, 0.000000, 0.026175, 0.000000, 1.000000, -0.000000, -0.026175, -0.000000, -0.999657),
        CFrame.new(-1454.050537, -57.144634, -20.910961, -0.999787, -0.000000, 0.020627, -0.000000, 1.000000, 0.000000, -0.020627, 0.000000, -0.999787),
        CFrame.new(-1453.642090, -56.894630, 62.750778, -0.999976, -0.000000, 0.006950, 0.000000, 1.000000, 0.000000, -0.006950, 0.000000, -0.999976),
        CFrame.new(-1453.968140, 223.768494, 85.884483, 0.999882, 0.000000, 0.015367, -0.000000, 1.000000, 0.000000, -0.015367, -0.000000, 0.999882),
        CFrame.new(-1455.083984, 222.489151, 175.389389, -0.997603, 0.000000, 0.069199, -0.000000, 1.000000, -0.000000, -0.069199, -0.000000, -0.997603),
        CFrame.new(-1456.110962, 214.865356, 331.975708, -1.000000, -0.000000, 0.000001, -0.000000, 1.000000, -0.000000, -0.000001, -0.000000, -1.000000),
        CFrame.new(-1452.121338, 214.865356, 622.063904, -0.990664, -0.000000, -0.136325, 0.000000, 1.000000, -0.000000, 0.136325, -0.000000, -0.990664),
        CFrame.new(-1453.310547, 368.878418, 618.495544, -0.745594, -0.000000, 0.666401, -0.000000, 1.000000, -0.000000, -0.666401, -0.000000, -0.745594),
        CFrame.new(-1456.194824, 360.065369, 496.716949, 0.999997, -0.000000, -0.002394, 0.000000, 1.000000, -0.000000, 0.002394, 0.000000, 0.999997),
        CFrame.new(-1327.640625, 361.792694, 493.324860, 0.010847, -0.000000, -0.999941, -0.000000, 1.000000, -0.000000, 0.999941, 0.000000, 0.010847),
        CFrame.new(-1247.714111, 333.808014, 495.830719, -0.367180, -0.000000, -0.930150, -0.000000, 1.000000, -0.000000, 0.930150, 0.000000, -0.367180),
        CFrame.new(-1238.616943, 322.544586, 596.694946, -0.995401, -0.000000, -0.095797, 0.000000, 1.000000, -0.000000, 0.095797, -0.000000, -0.995401),
        CFrame.new(-1234.626221, 328.705811, 657.543701, -0.998574, -0.000000, -0.053377, -0.000000, 1.000000, 0.000000, 0.053377, 0.000000, -0.998574),
        CFrame.new(-1218.170410, 344.652130, 828.388000, -0.995396, -0.000000, -0.095846, -0.000000, 1.000000, -0.000000, 0.095846, -0.000000, -0.995396),
        CFrame.new(-1363.507080, 363.765625, 841.644653, -0.069756, -0.000000, 0.997564, -0.000000, 1.000000, 0.000000, -0.997564, 0.000000, -0.069756),
        CFrame.new(-1400.548950, 361.551300, 821.816467, 0.980001, 0.000000, -0.198991, -0.000000, 1.000000, 0.000000, 0.198991, -0.000000, 0.980001),
        CFrame.new(-1402.886230, 373.848053, 726.604065, 0.999020, -0.000000, 0.044260, 0.000000, 1.000000, 0.000000, -0.044260, -0.000000, 0.999020),
        CFrame.new(-1403.974731, 552.304443, 728.641296, 0.993672, -0.000000, 0.112321, -0.000000, 1.000000, 0.000001, -0.112321, -0.000001, 0.993672),
        CFrame.new(-1405.482056, 532.876953, 753.763611, -0.998630, -0.000000, 0.052336, -0.000000, 1.000000, -0.000000, -0.052336, -0.000000, -0.998630),
        CFrame.new(-1406.810059, 532.875732, 1324.752686, -1.000000, 0.000000, -0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, -1.000000),
        CFrame.new(-1405.749146, 547.737915, 1484.722046, -0.999877, 0.000000, 0.015661, -0.000000, 1.000000, -0.000000, -0.015661, -0.000000, -0.999877),
        CFrame.new(-2049.893311, 524.537476, 1488.737427, -0.916527, -0.000000, 0.399973, -0.000000, 1.000000, -0.000000, -0.399973, -0.000000, -0.916527),
        CFrame.new(-2063.399170, 442.874390, 1486.122559, 0.033163, -0.000000, 0.999450, -0.000000, 1.000000, 0.000000, -0.999450, -0.000000, 0.033163),
        CFrame.new(-2062.37305, 440.612579, 1459.37183, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
}

local Stages = {
    ["Stage 1"] = {
        0.138840705, 6.70080185, 281.923065, 1, 0, 0, 0, 1, 0, 0, 0, 1
    },
    ["Stage 2"] = {
        2.86721277, 6.70080185, 506.785583, 1, 0, 0, 0, 1, 0, 0, 0, 1
    },
    ["Stage 3"] = {
        2.86721277, 74.9521561, 774.464844, 1, 0, 0, 0, 1, 0, 0, 0, 1
    },
    ["Stage 4"] = {
        0.138840705, 74.9521561, 1108.45337, 1, 0, 0, 0, 1, 0, 0, 0, 1
    },
    ["Stage 5"] = {
        -16.488636, 75.1460419, 1411.3446, 0, 0, 1, 0, 1, -0, -1, 0, 0
    },
    ["Stage 6"] = {
        -538.371643, 52.5018692, 1447.88953, 1, 0, 0, 0, 1, 0, 0, 0, 1
    },
    ["Stage 7"] = {
        -1007.7088, 52.5018692, 1447.88953, 1, 0, 0, 0, 1, 0, 0, 0, 1
    },
    ["Stage 8"] = {
        -1121.188965, 296.499573, 1468.097534, 0.055997, 0.000000, 0.998431, -0.000000, 1.000000, -0.000000, -0.998431, -0.000000, 0.055997
    },
    ["Stage 9"] = {
        -2967.117920, 296.370331, 1466.448975, 0.034899, -0.222795, 0.974241, -0.000000, 0.974834, 0.222930, -0.999391, -0.007780, 0.034021
    },
    ["Stage 10"] = {
        -3938.45679, 294.307556, 1464.93298, 0, 0, -1, 0, 1, 0, 1, 0, 0
    },
    ["Stage 11"] = {
        -4365.778809, 471.008453, 1532.216553, 0.013772, -0.000000, 0.999905, -0.000000, 1.000000, 0.000000, -0.999905, -0.000000, 0.013772
    },
    ["Stage 12"] = {
        -5339.299316, 471.481995, 1475.814941, 0.241386, -0.000000, 0.970429, -0.000000, 1.000000, 0.000000, -0.970429, -0.000000, 0.241386
    },
    ["Stage 13"] = {
        -6810.799316, 521.608459, 1486.826660, 0.978335, -0.000000, 0.207027, 0.000000, 1.000000, -0.000000, -0.207027, 0.000000, 0.978335
    },
    ["Stage 14"] = {
        -8318.119141, 484.499542, 1486.029907, -0.267991, 0.000000, -0.963421, -0.000000, 1.000000, 0.000000, 0.963421, 0.000000, -0.267991
    },
    ["Stage 15"] = {
        -14002.008789, 750.538818, 3111.993408, 0.951365, 0.000000, -0.308067, -0.000000, 1.000000, 0.000000, 0.308067, -0.000000, 0.951365
    }
}

local Stages2 = {
    ["Stage 1"] = {
        CFrame.new(-395.560150, 504.093903, -8.602631, -0.978374, -0.000000, 0.206845, 0.000000, 1.000000, 0.000000, -0.206845, 0.000000, -0.978374),
        CFrame.new(-399.743286, 504.045685, 60.839767, -0.999892, -0.000000, -0.014694, -0.000000, 1.000000, -0.000000, 0.014694, -0.000000, -0.999892),
        CFrame.new(-402.380066, 504.094238, 123.113060, -0.902059, 0.000000, -0.431613, 0.000000, 1.000000, 0.000000, 0.431613, -0.000000, -0.902059),
        CFrame.new(-396.371033, 500.168457, 188.798355, -0.785217, 0.000000, -0.619220, -0.000000, 1.000000, 0.000000, 0.619220, 0.000000, -0.785217),
        CFrame.new(-413.971985, 498.170471, 189.874847, 0, 0, 1, 0, 1, -0, -1, 0, 0)
    },
    ["Stage 2"] = {
        -396.985016, 500.168457, 435.910126, -0.090440, 0.000000, 0.995902, 0.000000, 1.000000, -0.000000, -0.995902, 0.000000, -0.090440
    },
    ["Stage 3"] = {
        -399.709167, 607.959900, 607.869141, -0.104672, 0.000000, -0.994507, 0.000000, 1.000000, 0.000000, 0.994507, -0.000000, -0.104672
    },
    ["Stage 4"] = {
        -400.676025, 607.522400, 841.158142, 0.637693, -0.000000, 0.770291, 0.000000, 1.000000, 0.000000, -0.770291, 0.000000, 0.637693
    },
    ["Stage 5"] = {
        -400.729980, 607.520935, 1260.843750, -0.907554, -0.000000, 0.419936, -0.000000, 1.000000, 0.000000, -0.419936, 0.000000, -0.907554
    },
    ["Stage 6"] = {
        -401.315063, 623.462585, 2415.285156, -0.999830, 0.000000, -0.018421, 0.000000, 1.000000, 0.000000, 0.018421, 0.000000, -0.999830
    },
    ["Stage 7"] = {
        -401.271088, 623.411255, 2647.996338, 1.000000, -0.000000, -0.000002, 0.000000, 1.000000, 0.000000, 0.000002, -0.000000, 1.000000
    },
    ["Stage 8"] = {
        -401.480743, 623.434448, 3155.082031, -0.999127, -0.000000, 0.041769, -0.000000, 1.000000, -0.000000, -0.041769, -0.000000, -0.999127
    },
    ["Stage 9"] = {
        -60.498600, 623.500854, 3866.338135, -0.738058, -0.000000, 0.674737, -0.000000, 1.000000, 0.000000, -0.674737, -0.000000, -0.738058
    },
    ["Stage 10"] = {
        1231.359131, 623.702576, 3868.461914, -0.054888, 0.000000, -0.998492, -0.000000, 1.000000, 0.000000, 0.998492, 0.000000, -0.054888
    },
    ["Stage 11"] = {
        2400.065186, 627.703552, 3872.232178, 0.225889, 0.000000, -0.974153, -0.000000, 1.000000, 0.000000, 0.974153, 0.000000, 0.225889
    },
    ["Stage 12"] = {
        3271.226807, 592.630554, 3870.791504, 0.999979, -0.000000, -0.006480, 0.000000, 1.000000, -0.000000, 0.006480, 0.000000, 0.999979
    },
    ["Stage 13"] = {
        4632.284668, 567.737793, 5143.072266, 0.998903, -0.000000, -0.046834, 0.000000, 1.000000, -0.000000, 0.046834, 0.000000, 0.998903
    },
    ["Stage 14"] = {
        5032.313965, 557.740417, 5141.516113, -0.025702, -0.000000, -0.999670, -0.000000, 1.000000, -0.000000, 0.999670, 0.000000, -0.025702
    },
    ["Stage 15"] = {
        7943.649414, 712.304810, 5142.520508, 0.716562, -0.000000, -0.697523, 0.000000, 1.000000, -0.000000, 0.697523, -0.000000, 0.716562
    }
}

local Stages3 = {
    ["Stage 1"] = {
        CFrame.new(-1453.146973, -69.386772, -517.623596, -0.497134, 0.000000, 0.867674, 0.000000, 1.000000, 0.000000, -0.867674, 0.000000, -0.497134)
    },
    ["Stage 2"] = {
        CFrame.new(-1454.050537, -57.144634, -20.910961, -0.999787, -0.000000, 0.020627, -0.000000, 1.000000, 0.000000, -0.020627, 0.000000, -0.999787)
    },
    ["Stage 3"] = {
        CFrame.new(-1456.110962, 214.865356, 331.975708, -1.000000, -0.000000, 0.000001, -0.000000, 1.000000, -0.000000, -0.000001, -0.000000, -1.000000)
    },
    ["Stage 4"] = {
        CFrame.new(-1405.482056, 532.876953, 753.763611, -0.998630, -0.000000, 0.052336, -0.000000, 1.000000, -0.000000, -0.052336, -0.000000, -0.998630)
    },
    ["Stage 5"] = {
        CFrame.new(-1406.810059, 532.875732, 1324.752686, -1.000000, 0.000000, -0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, -1.000000)
    },
    ["Stage 6"] = {
        CFrame.new(-2063.399170, 442.874390, 1486.122559, 0.033163, -0.000000, 0.999450, -0.000000, 1.000000, 0.000000, -0.999450, -0.000000, 0.033163)
    }
}

local rutasSeleccionadas = {}
local indiceRuta = 1

local currentRuta = Rutas["1 Win"]
local rutaSeleccionada = "1 Win"

local MundoActual = 1

local currentStage = Stages["Stage 1"]
local selectedStage = "Stage 1"

local currentStage2 = Stages2["Stage 1"]
local selectedStage2 = "Stage 1"

local currentStage3 = Stages3["Stage 1"]
local selectedStage3 = "Stage 1"

local currentTween

local DEBUG = false

local function DebugPrint(...)
    if DEBUG then
        print("[AutoFarm]", ...)
    end
end

local function TweenTo(rootPart, targetCF, index)

    DebugPrint("Moviéndose al punto #" .. index)

    local distance = (targetCF.Position - rootPart.Position).Magnitude
    local duration = distance / SPEED

    if currentTween then
        movingByTween = false
        currentTween:Cancel()
        currentTween = nil
    end

    currentTween = TweenService:Create(
        rootPart,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = targetCF}
    )

    movingByTween = true
    currentTween:Play()

    local terminado = false

    local connection
    connection = currentTween.Completed:Connect(function()
        terminado = true
    end)

    while not terminado do

        if not autofarmActivo then
            DebugPrint("Tween cancelado")

            movingByTween = false

            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end

            connection:Disconnect()
            return false
        end

        if not player.Character or not rootPart.Parent then
            DebugPrint("Character perdido")

            movingByTween = false

            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end

            connection:Disconnect()
            return false
        end

        task.wait()
    end

    connection:Disconnect()

    movingByTween = false
    currentTween = nil

    DebugPrint("Llegó al punto #" .. index)

    return true
end

local function cancelCurrentTween()
    if currentTween then
        movingByTween = false
        DebugPrint("Cancelando Tween")
        currentTween:Cancel()
        currentTween = nil
    end
end

local function resetCharacterMotion(character)
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")

    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    if hum then
        hum:Move(Vector3.zero, false)
    end
end

local RunService = game:GetService("RunService")
 
local camera = workspace.CurrentCamera
 
local autoWalking = false
local humanoid = nil
local heartbeatConn = nil

local function getHumanoid()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("Humanoid")
end

local stopAutoWalk
local startAutoWalk
 
stopAutoWalk = function()
	if not autoWalking then return end
	autoWalking = false
 
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
 
	if humanoid then
		humanoid:Move(Vector3.new(0, 0, 0), false)
	end
end

local movingByTween = false
local lastPosition = nil
local lastMoveTime = tick()

local MOVEMENT_THRESHOLD = 0.15
local STUCK_TIME = 0.4
 
startAutoWalk = function()

	if autoWalking then return end

	humanoid = getHumanoid()
	if not humanoid then return end

	autoWalking = true

	heartbeatConn = RunService.Heartbeat:Connect(function()

		if not autoWalking or not humanoid or humanoid.Health <= 0 then
			stopAutoWalk()
			return
		end

		if movingByTween and (tick() - lastMoveTime) < STUCK_TIME then
			humanoid:Move(Vector3.zero, false)
			return
		end

		local camCF = camera.CFrame
		local forward = camCF.LookVector
		forward = Vector3.new(forward.X, 0, forward.Z)

		if forward.Magnitude > 0 then
			forward = forward.Unit
		end

		humanoid:Move(forward, false)

	end)

end

local function stopAutoFarm()
    stopAutoWalk()
    cancelCurrentTween()

    enMovimiento = false

    resetCharacterMotion(player.Character)
end

local function esperarTimer()
    local npcFolder = workspace:WaitForChild("NPC & Piege", 5)
    if not npcFolder then return end

    local tsunami = npcFolder:WaitForChild("Tsunami1", 5)
    if not tsunami then return end

    local timerPart = tsunami:WaitForChild("TimerPart", 5)
    if not timerPart then return end

    local stageGui = timerPart:WaitForChild("StageGui", 5)
    if not stageGui then return end

    local timerLabel = stageGui:WaitForChild("Timer", 5)
    if not timerLabel then return end

    while true do
        local text = timerLabel.ContentText
        local number = tonumber(string.match(text, "%d+%.?%d*"))

        if number and number <= 0.01 then
            break
        end

        task.wait()
    end
end

local spawnCF

local function buscarSpawn(obj)
    for _, v in ipairs(obj:GetDescendants()) do
        if v:IsA("SpawnLocation") then
            return v
        end
    end
end

local function actualizarSpawn()
    local spawn = buscarSpawn(workspace)

    if spawn then
        spawnCF = spawn.CFrame + Vector3.new(0,5,0)
        return
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    spawnCF = hrp.CFrame
end

actualizarSpawn()

player.CharacterAdded:Connect(function(character)
    task.wait(0.5)

    local hrp = character:WaitForChild("HumanoidRootPart",5)

    if hrp then
        spawnCF = hrp.CFrame
    end
end)

local function esperarWins()

    local winsIniciales = Wins.Value

    DebugPrint("Wins iniciales:", winsIniciales)

    local tiempoInicio = tick()

    while autofarmActivo do

        if Wins.Value ~= winsIniciales then

            local ganadas = Wins.Value - winsIniciales

            DebugPrint("Cambio de wins:", ganadas)

            return true
        end

        if tick() - tiempoInicio >= 3 then

            DebugPrint("No llegaron wins en 3 segundos")

            local character = player.Character

            if character and spawnCF then
                DebugPrint("Teleport al spawn")
                character:PivotTo(spawnCF)
            end

            task.wait(1)

            return false
        end

        task.wait(.1)
    end

    DebugPrint("esperarWins cancelado")

    return false
end

local function iniciarRecorrido()

    if enMovimiento then
        return
    end

    enMovimiento = true

    DebugPrint("========== NUEVA RUTA ==========")

    if #rutasSeleccionadas == 0 then
        return
    end

    local datosRuta = rutasSeleccionadas[indiceRuta]

    rutaSeleccionada = datosRuta.Nombre
    currentRuta = datosRuta.Ruta

    local waitedTimer = false
    local usarTimer = (MundoActual == 1)

    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    for i, target in ipairs(currentRuta) do

        if not autofarmActivo then
            DebugPrint("Ruta cancelada")
            break
        end

        local ok = TweenTo(rootPart, target, i)

        if not ok then
            DebugPrint("Tween devolvió false")
            break
        end

        local wins = tonumber(string.match(rutaSeleccionada, "%d+"))

        if usarTimer and not waitedTimer and i == 10 and wins and wins >= 100 then

            waitedTimer = true

            DebugPrint("Esperando timer...")

            esperarTimer()

            DebugPrint("Timer terminado")

        else

            task.wait(PAUSA)

        end

    end

    DebugPrint("Fin de ruta")

if autofarmActivo then

    local obtuvo = esperarWins()

    DebugPrint("Resultado esperarWins =", obtuvo)

end

    if #rutasSeleccionadas > 1 then

        indiceRuta += 1

        if indiceRuta > #rutasSeleccionadas then
            indiceRuta = 1
        end

    end

enMovimiento = false

end

task.spawn(function()

    while true do

        if autofarmActivo and not enMovimiento then
            iniciarRecorrido()
        end

        task.wait(0.5)
    end

end)

local function eliminarObstaculosWorld1()
    -- Modelos del Workspace
    for _, modelName in ipairs({
        "NPC10",
        "NPC12",
        "NPC15"
    }) do
        local model = workspace:FindFirstChild(modelName)
        if model then
            model:Destroy()
        end
    end

    -- Modelos dentro de "NPC & Piege"
    local npcFolder = workspace:FindFirstChild("NPC & Piege")
    if npcFolder then
        for _, modelName in ipairs({
            "CorridorTrap",
            "CorridorTrap2",
            "LavaTower"
        }) do
            local model = npcFolder:FindFirstChild(modelName)
            if model then
                model:Destroy()
            end
        end
    end
end

local eliminandoObstaculosWorld2 = false

local function eliminarObstaculosWorld2()

    if eliminandoObstaculosWorld2 then
        return
    end

    eliminandoObstaculosWorld2 = true

    task.spawn(function()
        while eliminandoObstaculosWorld2 do

            local world2 = workspace:FindFirstChild("WORLD 2")
            if world2 then
                for _, obj in ipairs(world2:GetDescendants()) do
                    if obj:IsA("Model") and obj.Name == "MovingWalls" then
                        print("Eliminando:", obj:GetFullName())
                        obj:Destroy()
                    end
                end
            end

            local nombres = {
                "Pieges & Lava",
                "NPC_MacaronMonster",
                "NPC9",
                "NPC15_World2"
            }

            for _, nombre in ipairs(nombres) do
                local obj = workspace:FindFirstChild(nombre)
                if obj then
                    print("Eliminando:", obj:GetFullName())
                    obj:Destroy()
                end
            end

            task.wait(5)
        end
    end)

end

local function detenerEliminarObstaculosWorld2()
    eliminandoObstaculosWorld2 = false
end

local function eliminarObstaculosWorld3()

    local carpeta = workspace:FindFirstChild("NPC & Piege")

    if carpeta then
        print("Eliminando:", carpeta:GetFullName())
        carpeta:Destroy()
    else
        warn("No se encontró la carpeta NPC & Pieges")
    end

end

CargarHub = function()
    local Window = Lib:CreateWindow({
        Title = "Lil Script",
        Subtitle = "+1 Speed Keyboard Escape",
        Icon = "rbxassetid://110461677380547",
        Theme = "Purple",
        Size = Vector2.new(520, 380),
        MinSize = Vector2.new(380, 250),
        MaxSize = Vector2.new(900, 650),
        AutoSave = true,
        AutoLoad = true,
    
        DefaultLanguage = "English",
        DefaultFps      = true,
        DefaultPing     = true,
        DefaultProfile  = true,
    
        TitleConfig = {
            Words    = { "Lil", "Script" },
            Gradient = true,
            Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 0, 255) },
        },
        FloatButton = {
            Shape = "Square",
            Color = "Black",
            Size  = 50,
            Icon  = "rbxassetid://110461677380547",
        },
        Acrylic = {
            Enabled = false,
            Opacity = 0.55,
        },
        ConfigPanel = {
            Enabled    = true,
            Acrylic    = true,
            Theme      = true,
            Fps        = true,
            Ping       = true,
            Profile    = true,
            HideNotify = true,
            Language   = false,
        },
    })
    
    local MainTab = Window:CreateTab({ Title = "Main", Icon = "rbxassetid://0" })
    
    MainTab:CreateButton({
        Title = "Canal de WhatsApp",
        Description = "Unete a nuestro canal para novedades",
        Callback = function()
            setclipboard("https://whatsapp.com/channel/0029VbAxbVhDeOMzL30HNU2G")
            Window:Notify({ Title = "Link copiado!", Description = "Pega el link en tu navegador.", Duration = 4 })
        end,
    })
    
    local AutoFarmTab = Window:CreateTab({ Title = "Auto Farm", Icon = "rbxassetid://0" })
    
    AutoFarmTab:CreateSection({ Text = "Configs" })
    
    local warnedHighSpeed = false
    
    local SpeedSlider = AutoFarmTab:CreateSlider({
        Title    = "Speed",
        Min      = 10,
        Max      = 250,
        Default  = 120,
        Callback = function(val)
            SPEED = val
    
            if val > 150 and not warnedHighSpeed then
                warnedHighSpeed = true
    
                Window:Notify({
                    Title = "WARNING",
                    Description = "Speed may cause you bugs.",
                    Duration = 5
                })
            elseif val <= 150 then
                warnedHighSpeed = false
            end
        end,
    })
    
    local RebirthEvent = game:GetService("ReplicatedStorage").Remotes.Rebirth
    local AutoRebirth = false
    
    AutoFarmTab:CreateToggle({
        Title = "Auto Rebirth",
        Default = false,
        Callback = function(val)
            AutoRebirth = val
    
            if AutoRebirth then
                task.spawn(function()
                    while AutoRebirth do
                        pcall(function()
                            RebirthEvent:FireServer()
                        end)
    
                        task.wait(10)
                    end
                end)
            end
        end,
    })
    
    AutoFarmTab:CreateToggle({
        Title = "Debug (World 1 & 2)",
        Default = false,
        Callback = function(v)
    
            DEBUG = v
    
            if DEBUG then
                print("[AutoFarm] Debug ACTIVADO")
            else
                print("[AutoFarm] Debug DESACTIVADO")
            end
    
        end
    })
    
    AutoFarmTab:CreateSection({ Text = "Auto Farm World 1" })
    
    local function GetSpeedLevel()
        return tonumber(
            game.Players.LocalPlayer.PlayerGui
                .SpeedGameUI
                .Frames
                .LevelFrame
                .ProgressBg
                .LevelText.Text:match("%d+")
        ) or 0
    end
    
    AutoFarmTab:CreateDropdown({
        Title = "Select Wins (World 1)",
        Multiple = false,
        Options = {
            "1 Win",
            "3 Wins",
            "10 Wins",
            "20 Wins",
            "50 Wins",
            "100 Wins",
            "150 Wins",
            "300 Wins",
            "500 Wins",
            "1000 Wins",
            "2500 Wins",
            "10000 Wins",
            "25000 Wins",
            "50000 Wins",
            "150000 Wins"
        },
        Callback = function(valor)
    
            MundoActual = 1
    
            local Nivel = tonumber(
                game.Players.LocalPlayer.PlayerGui
                .SpeedGameUI
                .Frames
                .LevelFrame
                .ProgressBg
                .LevelText.Text:match("%d+")
            ) or 0
    
            if valor == "50000 Wins" and Nivel < 110 then
                Window:Notify({
                    Title = "WARNING",
                    Description = "Low level detected, change your wins.",
                    Duration = 3
                })
            elseif valor == "150000 Wins" and Nivel < 120 then
                Window:Notify({
                    Title = "WARNING",
                    Description = "Low level detected, change your wins.",
                    Duration = 3
                })
            end
    
            table.clear(rutasSeleccionadas)
    
            table.insert(rutasSeleccionadas, {
                Nombre = valor,
                Ruta = Rutas[valor]
            })
    
            indiceRuta = 1
    
        end
    })
    
    AutoFarmTab:CreateToggle({
        Title = "Auto Farm Wins (World 1)",
        Default = false,
        Callback = function(v)
    
            autofarmActivo = v
    
            if v then
    
                DebugPrint("AutoFarm ACTIVADO")
    
                eliminarObstaculosWorld1()
                startAutoWalk()
    
            else
    
                DebugPrint("AutoFarm DESACTIVADO")
                stopAutoFarm()
            end
        end
    })
    
    AutoFarmTab:CreateSection({ Text = "Auto Farm World 2" })
    
    AutoFarmTab:CreateDropdown({
        Title = "Select Wins (World 2)",
        Multiple = false,
        Options = {
            "250k Win",
            "400k Win",
            "600k Win",
            "1m Win",
            "1.5m Win",
            "2.5m Win",
            "4m Win",
            "6m Win",
            "10m Win",
            "15m Win",
            "25m Win",
            "40m Win",
            "60m Win",
            "100m Win",
            "150m Win"
        },
        Callback = function(valor)
    
            MundoActual = 2
    
            local Nivel = tonumber(
                game.Players.LocalPlayer.PlayerGui
                .SpeedGameUI
                .Frames
                .LevelFrame
                .ProgressBg
                .LevelText.Text:match("%d+")
            ) or 0
    
            if (valor == "100m Win" or valor == "150m Win") and Nivel < 500 then
                Window:Notify({
                    Title = "WARNING",
                    Description = "Low level detected, change your wins.",
                    Duration = 3
                })
            end
    
            table.clear(rutasSeleccionadas)
    
            table.insert(rutasSeleccionadas, {
                Nombre = valor,
                Ruta = Rutas2[valor]
            })
    
            indiceRuta = 1
    
        end
    })
    
    AutoFarmTab:CreateToggle({
        Title = "Auto Farm Wins (World 2)",
        Default = false,
        Callback = function(v)
    
            autofarmActivo = v
    
            if v then
    
                DebugPrint("AutoFarm ACTIVADO")
    
                eliminarObstaculosWorld2()
                startAutoWalk()
    
            else
    
                DebugPrint("AutoFarm DESACTIVADO")
                detenerEliminarObstaculosWorld2()
                stopAutoFarm()
            end
        end
    })
    
    AutoFarmTab:CreateSection({ Text = "Auto Farm World 3" })
    
    AutoFarmTab:CreateDropdown({
        Title = "Select Wins (World 3)",
        Multiple = true,
        Options = {
            "300m Win",
            "500m Win",
            "800m Win",
            "1.25b Win",
            "2b Win",
            "3.5b Win",
        },
        Callback = function(valores)
    
            MundoActual = 3
    
            table.clear(rutasSeleccionadas)
    
            for _, nombre in ipairs(valores) do
                table.insert(rutasSeleccionadas,{
                    Nombre = nombre,
                    Ruta = Rutas3[nombre]
                })
            end
    
            indiceRuta = 1
    
        end
    })
    
    AutoFarmTab:CreateToggle({
        Title = "Auto Farm Wins (World 3)",
        Default = false,
        Callback = function(v)
    
            autofarmActivo = v
    
            if v then
    
                DebugPrint("AutoFarm ACTIVADO")
    
                eliminarObstaculosWorld3()
                startAutoWalk()
    
            else
    
                DebugPrint("AutoFarm DESACTIVADO")
                stopAutoFarm()
            end
        end
    })
    
    local ShopTab = Window:CreateTab({ Title = "Shop", Icon = "rbxassetid://0" })
    
    ShopTab:CreateSection({ Text = "Shop" })
    
    local Event = game:GetService("ReplicatedStorage").Packages._Index["littensy_remo@1.5.3"].remo.container.BuyWins
    
    local AutoBuyRarities = false
    local SelectedRarities = {}
    local Quantity = 1
    local Cooldown = 10
    
    ShopTab:CreateDropdown({
        Title = "Rarities",
        Multiple = true,
        Options = { "Common", "Uncommon", "Rare", "Mysterious" },
        Callback = function(val)
            SelectedRarities = val
        end,
    })
    
    ShopTab:CreateTextBox({
        Title = "Cooldown (Seconds)",
        Placeholder = "10",
        Default = "10",
        MaxLength = 4,
        Callback = function(text)
            local num = tonumber(text)
    
            if num and num > 0 then
                Cooldown = num
            else
                Cooldown = 10
            end
        end,
    })
    
    ShopTab:CreateTextBox({
        Title = "Quantity",
        Placeholder = "1",
        Default = "1",
        MaxLength = 3,
        Callback = function(text)
            local num = tonumber(text)
    
            if num then
                Quantity = math.max(1, math.floor(num))
            else
                Quantity = 1
            end
        end,
    })
    
    ShopTab:CreateToggle({
        Title = "Auto Buy Rarities",
        Default = false,
        Callback = function(state)
            AutoBuyRarities = state
    
            if state then
                task.spawn(function()
                    while AutoBuyRarities do
    
                        for _, rarity in ipairs(SelectedRarities) do
                            for i = 1, Quantity do
                                if not AutoBuyRarities then
                                    break
                                end
    
                                Event:FireServer(rarity)
                                task.wait(0.15)
                            end
                        end
    
                        local elapsed = 0
                        while AutoBuyRarities and elapsed < Cooldown do
                            task.wait(0.1)
                            elapsed += 0.1
                        end
    
                    end
                end)
            end
        end,
    })
    
    ShopTab:CreateSection({ Text = "Trails & Auras" })
    
    local BuyTrail = game:GetService("ReplicatedStorage").Remotes.BuyTrail
    
    local AutoBuyTrails = false
    local SelectedTrails = {}
    
    local TrailPrices = {
        GreenTrail = 500,
        BlueTrail = 1500,
        PurpleTrail = 5000,
        RedTrail = 25000,
        RainbowTrail = 100000,
        CosmicTrail = 5000000,
        VoidTrail = 50000000,
        SupernovaTrail = 500000000,
        GodlikeTrail = 5000000000,
        DivineTrail = 10000000000,
        CelestialTrail = 20000000000,
        EternalTrail = 50000000000,
        AscendantTrail = 75000000000,
        TranscendentTrail = 150000000000
    }
    
    ShopTab:CreateDropdown({
        Title = "Select Trails",
        Multiple = true,
        Options = {
            "GreenTrail","BlueTrail","PurpleTrail","RedTrail",
            "RainbowTrail","CosmicTrail","VoidTrail","SupernovaTrail",
            "GodlikeTrail","DivineTrail","CelestialTrail",
            "EternalTrail","AscendantTrail","TranscendentTrail"
        },
        Callback = function(val)
            SelectedTrails = val
    
            table.sort(SelectedTrails,function(a,b)
                return TrailPrices[a] < TrailPrices[b]
            end)
        end,
    })
    
    ShopTab:CreateToggle({
        Title = "Auto Buy Trails",
        Default = false,
        Callback = function(state)
            AutoBuyTrails = state
    
            if state then
                task.spawn(function()
    
                    local Current = 1
    
                    while AutoBuyTrails do
    
                        local Wins = game.Players.LocalPlayer.leaderstats.Wins.Value
    
                        local Trail = SelectedTrails[Current]
    
                        if Trail then
                            local Price = TrailPrices[Trail]
    
                            if Wins >= Price then
                                BuyTrail:InvokeServer(Trail,"Wins")
    
                                Current += 1
    
                                task.wait(0.5)
                            end
                        else
                            break
                        end
    
                        task.wait(0.1)
                    end
    
                    AutoBuyTrails = false
    
                end)
            end
        end,
    })
    
    local BuyAura = game:GetService("ReplicatedStorage").Remotes.BuyAura
    
    local AutoBuyAuras = false
    local SelectedAuras = {}
    
    local AuraPrices = {
        GlowAura = 1000000,
        WindAura = 5000000,
        WaterAura = 10000000,
        FireAura = 25000000,
        ElectricAura = 50000000,
    }
    
    ShopTab:CreateDropdown({
        Title = "Select Auras",
        Multiple = true,
        Options = {
            "GlowAura",
            "WindAura",
            "WaterAura",
            "FireAura",
            "ElectricAura",
        },
        Callback = function(val)
            SelectedAuras = val
    
            table.sort(SelectedAuras, function(a, b)
                return AuraPrices[a] < AuraPrices[b]
            end)
        end,
    })
    
    ShopTab:CreateToggle({
        Title = "Auto Buy Auras",
        Default = false,
        Callback = function(state)
            AutoBuyAuras = state
    
            if state then
                task.spawn(function()
    
                    local Current = 1
    
                    while AutoBuyAuras do
    
                        local Wins = game.Players.LocalPlayer.leaderstats.Wins.Value
    
                        local Aura = SelectedAuras[Current]
    
                        if Aura then
                            local Price = AuraPrices[Aura]
    
                            if Price and Wins >= Price then
                                pcall(function()
                                    BuyAura:InvokeServer(Aura, "Wins")
                                end)
    
                                Current += 1
                                task.wait(0.5)
                            end
                        else
                            break
                        end
    
                        task.wait(0.1)
                    end
    
                    AutoBuyAuras = false
                end)
            end
        end,
    })
    
    local TeleportTab = Window:CreateTab({ Title = "Teleport", Icon = "rbxassetid://0" })
    
    TeleportTab:CreateSection({ Text = "Worlds" })
    
    TeleportTab:CreateButton({
        Title        = "Teleport to World 1",
        Confirmation = true,
        Callback     = function()
            TeleportService:Teleport(95082159892680, game.Players.LocalPlayer)
        end,
    })
    
    TeleportTab:CreateButton({
        Title        = "Teleport to World 2",
        Confirmation = true,
        Callback     = function()
            TeleportService:Teleport(118941584817777, game.Players.LocalPlayer)
        end,
    })
    
    TeleportTab:CreateButton({
        Title        = "Teleport to World 3",
        Confirmation = true,
        Callback     = function()
            TeleportService:Teleport(93411036959889, game.Players.LocalPlayer)
        end,
    })
    
    TeleportTab:CreateSection({ Text = "Stages of World 1" })
    
    TeleportTab:CreateDropdown({
        Title = "Select Stage (World 1)",
        Options = {
            "Stage 1",
            "Stage 2",
            "Stage 3",
            "Stage 4",
            "Stage 5",
            "Stage 6",
            "Stage 7",
            "Stage 8",
            "Stage 9",
            "Stage 10",
            "Stage 11",
            "Stage 12",
            "Stage 13",
            "Stage 14",
            "Stage 15"
        },
        Callback = function(valor)
            selectedStage = valor
            currentStage = Stages[valor] or Stages["Stage 1"]
        end
    })
    
    local function StageToCFrame(stage)
        if typeof(stage) == "CFrame" then
            return stage
        end
    
        if type(stage) == "table" then
            if #stage > 0 and typeof(stage[1]) == "CFrame" then
                return stage[1]
            end
    
            return CFrame.new(unpack(stage))
        end
    
        return CFrame.new()
    end
    
    TeleportTab:CreateButton({
        Title = "Teleport",
        Callback = function()
    
            local character = player.Character or player.CharacterAdded:Wait()
            local rootPart = character:WaitForChild("HumanoidRootPart")
    
            if currentStage then
                rootPart.CFrame = StageToCFrame(currentStage)
            end
    
        end,
    })
    
    TeleportTab:CreateSection({ Text = "Stages of World 2" })
    
    TeleportTab:CreateDropdown({
        Title = "Select Stage (World 2)",
        Options = {
            "Stage 1",
            "Stage 2",
            "Stage 3",
            "Stage 4",
            "Stage 5",
            "Stage 6",
            "Stage 7",
            "Stage 8",
            "Stage 9",
            "Stage 10",
            "Stage 11",
            "Stage 12",
            "Stage 13",
            "Stage 14",
            "Stage 15"
        },
    
        Callback = function(valor)
    
            selectedStage2 = valor
            currentStage2 = Stages2[valor] or Stages2["Stage 1"]
    
        end
    })
    
    TeleportTab:CreateButton({
        Title = "Teleport",
    
        Callback = function()
    
            local character = player.Character or player.CharacterAdded:Wait()
            local rootPart = character:WaitForChild("HumanoidRootPart")
    
            if currentStage2 then
                rootPart.CFrame = StageToCFrame(currentStage2)
            end
    
        end,
    })
    
    TeleportTab:CreateSection({ Text = "Stages of World 3" })
    
    TeleportTab:CreateDropdown({
        Title = "Select Stage (World 3)",
        Options = {
            "Stage 1",
            "Stage 2",
            "Stage 3",
            "Stage 4",
            "Stage 5",
            "Stage 6"
        },
    
        Callback = function(valor)
    
            selectedStage3 = valor
            currentStage3 = Stages3[valor] or Stages3["Stage 1"]
    
        end
    })
    
    TeleportTab:CreateButton({
        Title = "Teleport",
    
        Callback = function()
    
            local character = player.Character or player.CharacterAdded:Wait()
            local rootPart = character:WaitForChild("HumanoidRootPart")
    
            if currentStage3 then
                rootPart.CFrame = StageToCFrame(currentStage3)
            end
    
        end,
    })
    
    local AdminAbuseTab = Window:CreateTab({ Title = "Admin Abuse", Icon = "rbxassetid://0" })
    
    AdminAbuseTab:CreateSection({ Text = "Automations For Admin Abuse" })
    
    local AutoCoins = false
    local TPDelay = 1
    
    AdminAbuseTab:CreateTextBox({
        Title = "Delay Between TP",
        Placeholder = "1",
        Default = "1",
        MaxLength = 3,
        Callback = function(text)
            local num = tonumber(text)
    
            if num and num >= 0 then
                TPDelay = num
            end
        end,
    })
    
    AdminAbuseTab:CreateToggle({
        Title = "Auto Collect Coins",
        Default = false,
        Callback = function(state)
            AutoCoins = state
    
            if state then
                task.spawn(function()
                    while AutoCoins do
                        local folder = workspace:FindFirstChild("CoinBattleCoins")
    
                        if folder then
                            local character = game.Players.LocalPlayer.Character
                            local root = character and character:FindFirstChild("HumanoidRootPart")
    
                            if root then
                                for _, model in ipairs(folder:GetChildren()) do
                                    if not AutoCoins then
                                        break
                                    end
    
                                    local part = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) or model
    
                                    if part and part:IsA("BasePart") then
                                        root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                                        task.wait(TPDelay)
                                    end
                                end
                            end
                        end
    
                        task.wait()
                    end
                end)
            end
        end,
    })
    
    AdminAbuseTab:CreateToggle({
        Title = "Auto Team Battle",
        Default = false,
        Callback = function(v)
    
            autofarmActivo = v
    
            if v then
    
                table.clear(rutasSeleccionadas)
    
                MundoActual = 1
    
                if game.PlaceId == 95082159892680 then
                    MundoActual = 1
                    table.insert(rutasSeleccionadas, {
                        Nombre = "150000 Wins",
                        Ruta = Rutas["150000 Wins"]
                    })
    
                elseif game.PlaceId == 118941584817777 then
                    MundoActual = 2
                    table.insert(rutasSeleccionadas, {
                        Nombre = "150m Win",
                        Ruta = Rutas2["150m Win"]
                    })
    
                elseif game.PlaceId == 93411036959889 then
                    MundoActual = 3
                    table.insert(rutasSeleccionadas, {
                        Nombre = "3.5b Win",
                        Ruta = Rutas3["3.5b Win"]
                    })
    
                else
                    warn("PlaceId no soportado:", game.PlaceId)
                    autofarmActivo = false
                    return
                end
    
                indiceRuta = 1
    
                DebugPrint("AutoFarm ACTIVADO")
    
                if MundoActual == 1 then
                    eliminarObstaculosWorld1()
                elseif MundoActual == 2 then
                    eliminarObstaculosWorld2()
                elseif MundoActual == 3 then
                    eliminarObstaculosWorld3()
                end
    
                startAutoWalk()
    
            else
    
                DebugPrint("AutoFarm DESACTIVADO")
                stopAutoFarm()
    
            end
        end
    })
    
    Window:Notify({
        Title       = "Lil Script",
        Description = "Loaded Succesfully.",
        Duration    = 3
    })
end
