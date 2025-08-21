-- // Tokyo UI Library (No Config Version) // --

local UserInputService = game:GetService("UserInputService")

local library = {
    flags = {},
    binds = {},
    cheatname = "Tokyo",
    gamename = "Da Hood"
}

-- // Init
function library:init()
    print(self.cheatname .. " | " .. self.gamename .. " loaded.")
end

-- // Window
function library.NewWindow(args)
    local window = {}
    window.tabs = {}

    function window:AddTab(name)
        local tab = {}
        tab.sections = {}

        function tab:AddSection(secName, side)
            local section = {}
            section.name = secName

            function section:AddToggle(name, flag, default, callback)
                library.flags[flag] = default or false
                if callback then callback(library.flags[flag]) end
            end

            function section:AddSlider(name, flag, min, max, default, callback)
                library.flags[flag] = default or min
                if callback then callback(library.flags[flag]) end
            end

            function section:AddDropdown(name, flag, options, default, callback)
                library.flags[flag] = default or options[1]
                if callback then callback(library.flags[flag]) end
            end

            function section:AddTextbox(name, flag, default, callback)
                library.flags[flag] = default or ""
                if callback then callback(library.flags[flag]) end
            end

            function section:AddBind(name, flag, default, callback)
                library.binds[flag] = default
                UserInputService.InputBegan:Connect(function(input, gp)
                    if not gp and input.KeyCode == default then
                        if callback then callback() end
                    end
                end)
            end

            tab.sections[secName] = section
            return section
        end

        window.tabs[name] = tab
        return tab
    end

    return window
end

-- // Settings Tab placeholder (no configs)
function library:CreateSettingsTab(window)
    local tab = window:AddTab("Settings")
    local sec = tab:AddSection("General", 1)
    sec:AddToggle("Watermark", "watermark", true, function(val)
        print("Watermark toggle:", val)
    end)
    return tab
end

-- // Watermark
function library:Watermark()
    local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
    local TextLabel = Instance.new("TextLabel", ScreenGui)
    TextLabel.Size = UDim2.new(0, 250, 0, 25)
    TextLabel.Position = UDim2.new(0, 10, 0, 10)
    TextLabel.BackgroundTransparency = 0.5
    TextLabel.Text = self.cheatname .. " | " .. self.gamename
    TextLabel.TextColor3 = Color3.new(1, 1, 1)
    TextLabel.TextScaled = true
end

-- // Keybind List
function library:KeybindList()
    local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 200, 0, 300)
    Frame.Position = UDim2.new(1, -210, 0.5, -150)
    Frame.BackgroundTransparency = 0.3

    local list = Instance.new("UIListLayout", Frame)

    for flag, bind in pairs(self.binds) do
        local label = Instance.new("TextLabel", Frame)
        label.Size = UDim2.new(1, 0, 0, 25)
        label.Text = flag .. " : " .. tostring(bind.Name)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundTransparency = 1
    end
end

return library
