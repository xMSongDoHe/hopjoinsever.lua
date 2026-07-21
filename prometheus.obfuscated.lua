-- [[ สคริปต์ V28 (Fix 100%): All-in-One + Timer UI + Workspace Cooldown Sync ]]

--------------------------------------------------
-- ⚙️ CONFIGURATION: ตั้งค่าการทำงาน
--------------------------------------------------
_G.AutoSyncConfig = _G.AutoSyncConfig or {
    MainUsername = "Famasuna49836", -- ⚠️ เปลี่ยนเป็น Username ของไอดี Main ตรงนี้!
    CheckIntervalMinutes = 1,      -- ⏱️ ตั้งเวลาเช็คคนในห้อง (หน่วยเป็นนาที)
    MaxOtherPlayers = 2,            -- 👥 จำนวน "คนนอก" (ไม่ใช่ไอดีตัวเอง) สูงสุดที่ยอมให้อยู่ในเซิฟก่อนหาห้องใหม่
    OwnAccountUsernames = {         -- 🧑‍🤝‍🧑 รายชื่อไอดีรอง (Alt) ทุกตัวของตัวเอง
        "Ylthar64258hue",
        "Calon25585piej",
    },

    -- 🧑‍🌾 HelperNameList: ตั้งค่าเกี่ยวกับตัวช่วยฟาร์ม (ยังไม่ถูกใช้งานจริงในสคริปต์ตอนนี้ เตรียมไว้สำหรับต่อยอด)
    HelperNameList = {
        V4FarmList = {           -- 🎯 รายชื่อตัวฟาร์ม (มอนสเตอร์) ที่ต้องการให้เล็ง ใส่ชื่อเป็น string ทีละตัว
            -- "ชื่อมอนสเตอร์ 1",
            -- "ชื่อมอนสเตอร์ 2",
        },
        AutoFindFarmList = false, -- ปรับเป็น true จะหาตัวฟาร์มเองโดยไม่ต้องเติมชื่อใน V4FarmList
                                   -- แต่อาจฟาร์มช้าลงเพราะสุ่มตำแหน่งฟาร์มเอง
        TaskAfterTier10 = function() -- 🏁 เรียกใช้เมื่อถึง Tier 10 แล้ว ถ้าไม่ต้องการให้ทำอะไรให้ปล่อยว่างไว้
            -- ตัวอย่าง: game.Players.LocalPlayer:Kick("ถึง Tier 10 แล้ว")
            -- ตัวอย่าง: _G.Horst_AccountChangeDone()
        end,
    },
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

-- 📁 เก็บไฟล์ทั้งหมดของสคริปต์นี้ไว้ในโฟลเดอร์เดียว ไม่ให้ปนกับไฟล์อื่นใน workspace
local DATA_FOLDER = "AutoSyncData"
pcall(function()
    if not isfolder(DATA_FOLDER) then makefolder(DATA_FOLDER) end
end)
local function dataPath(filename)
    return DATA_FOLDER .. "/" .. filename
end

local isMain = (LocalPlayer.Name == _G.AutoSyncConfig.MainUsername)

-- 🎨 ชุดสีธีมหลัก
local Theme = {
    BgTop        = Color3.fromRGB(30, 32, 42),
    BgBottom     = Color3.fromRGB(20, 21, 28),
    HeaderTop    = Color3.fromRGB(114, 88, 235),
    HeaderBottom = Color3.fromRGB(82, 58, 209),
    Accent       = Color3.fromRGB(140, 118, 255),
    Card         = Color3.fromRGB(38, 40, 52),
    CardStroke   = Color3.fromRGB(58, 60, 78),
    TextMain     = Color3.fromRGB(240, 240, 245),
    TextDim      = Color3.fromRGB(160, 162, 178),
    Danger       = Color3.fromRGB(235, 82, 96),
    DangerHover  = Color3.fromRGB(210, 60, 74),
    Info         = Color3.fromRGB(72, 156, 235),
    InfoHover    = Color3.fromRGB(52, 132, 210),
    Success      = Color3.fromRGB(87, 214, 140),
    Main         = Color3.fromRGB(255, 200, 87),
}

-- ==========================================
-- 🛠️ ชุดฟังก์ชันควบคุมเมาส์และ Hub (ที่เคยขาดหายไป)
-- ==========================================
local function virtualClick(element)
    pcall(function()
        local inset = GuiService:GetGuiInset()
        local x = element.AbsolutePosition.X + (element.AbsoluteSize.X / 2) + inset.X
        local y = element.AbsolutePosition.Y + (element.AbsoluteSize.Y / 2) + inset.Y
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.1)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
end

local function getCardFrame(element)
    local current = element
    while current do
        if current:IsA("Frame") and current.Parent and current.Parent:IsA("ScrollingFrame") then
            return current
        end
        current = current.Parent
    end
    return element.Parent
end

local function findTeddyHubUI()
    local roots = {}
    for _, g in pairs(CoreGui:GetChildren()) do table.insert(roots, g) end
    if LocalPlayer:FindFirstChild("PlayerGui") then
        for _, g in pairs(LocalPlayer.PlayerGui:GetChildren()) do table.insert(roots, g) end
    end
    
    for _, g in pairs(roots) do
        if g:IsA("ScreenGui") then
            local uiName = g.Name:lower()
            if string.find(uiName, "teddy") or string.find(uiName, "macaw") then
                return g
            end
            -- เผื่อ Hub เปลี่ยนชื่อ หาจากข้อความ Discord ด้านในเอาชัวร์ๆ
            local found = false
            pcall(function()
                for _, v in pairs(g:GetDescendants()) do
                    if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text then
                        if string.find(v.Text:lower(), "6uddwybuh7") then
                            found = true
                            break
                        end
                    end
                end
            end)
            if found then return g end
        end
    end
    return nil
end

local function isReallyVisible(obj)
    local current = obj
    while current and current:IsA("GuiObject") do
        if not current.Visible then return false end
        current = current.Parent
    end
    return true
end

local function adjustScrollToElement(element)
    local current = element.Parent
    while current do
        if current:IsA("ScrollingFrame") then
            local elementY = element.AbsolutePosition.Y
            local frameTop = current.AbsolutePosition.Y
            local frameBottom = frameTop + current.AbsoluteSize.Y
            if elementY > frameBottom - 35 then
                current.CanvasPosition = Vector2.new(0, current.CanvasPosition.Y + 50)
                return false
            elseif elementY < frameTop + 35 then
                current.CanvasPosition = Vector2.new(0, math.max(0, current.CanvasPosition.Y - 50))
                return false
            else return true end
        end
        current = current.Parent
    end
    return true
end

-- ==========================================
-- 📁 ระบบไฟล์ Workspace
-- ==========================================
local function resetTimer()
    pcall(function() writefile(dataPath("LastCheckTime.txt"), tostring(os.time())) end)
end

local function updateStatus(text)
    if _G.AutoSyncStatusLabel then
        pcall(function() _G.AutoSyncStatusLabel.Text = tostring(text) end)
    end
    pcall(function()
        local role = isMain and "MAIN" or "ALT"
        writefile(dataPath("Status_" .. LocalPlayer.Name .. ".txt"), table.concat({ tostring(os.time()), role, tostring(text) }, "|"))
    end)
end

-- ไอดีที่ auto-detect ผ่านไฟล์ Status ต้อง "ตอบสนองล่าสุด" ภายในกี่วิ ถึงจะนับว่าออนไลน์อยู่จริง
-- (ไม่นับไอดีที่ปิดสคริปต์ไปนานแล้ว/ไฟล์ค้างเก่าๆ ว่าเป็นไอดีตัวเองที่ยัง active อยู่)
local OWN_ACCOUNT_FRESH_SECONDS = 90

local function getOwnAccountNames()
    local names = {}
    -- ไอดีตัวเอง, Main, และไอดีที่ใส่ไว้ใน config มือ ให้นับว่าเป็นของตัวเองเสมอ
    -- ไม่ว่าจะออนไลน์/ตอบสนองอยู่ตอนนี้หรือไม่ก็ตาม (เชื่อตามที่ผู้ใช้ระบุไว้)
    names[LocalPlayer.Name] = true
    names[_G.AutoSyncConfig.MainUsername] = true
    for _, username in pairs(_G.AutoSyncConfig.OwnAccountUsernames or {}) do
        names[username] = true
    end
    -- ส่วนที่ตรวจจับอัตโนมัติจากไฟล์ Status (ไม่ได้ใส่ไว้ใน config เอง)
    -- จะนับว่าเป็นไอดีตัวเองก็ต่อเมื่อไฟล์นั้น "อัปเดตล่าสุด" ไม่เกิน OWN_ACCOUNT_FRESH_SECONDS วิ
    -- (แปลว่ายังออนไลน์/ตอบสนองอยู่จริง) ถ้าไฟล์ค้างเก่าเกินไปจะไม่นับ เว้นแต่จะใส่ชื่อไว้ใน config แล้ว
    pcall(function()
        if listfiles then
            for _, path in pairs(listfiles(DATA_FOLDER)) do
                local fname = path:match("[^/\\]+$")
                local username = fname and fname:match("^Status_(.+)%.txt$")
                if username and not names[username] then
                    local ok, content = pcall(readfile, path)
                    if ok and content then
                        local ts = content:match("^(%d+)|")
                        if ts and (os.time() - tonumber(ts)) <= OWN_ACCOUNT_FRESH_SECONDS then
                            names[username] = true
                        end
                    end
                end
            end
        end
    end)
    return names
end

local function isOwnAccount(name, ownNames)
    ownNames = ownNames or getOwnAccountNames()
    return ownNames[name] == true
end

local function canHop()
    if isfile(dataPath("HopCooldown.txt")) then
        local cooldownEnd = tonumber(readfile(dataPath("HopCooldown.txt")))
        if cooldownEnd and os.time() < cooldownEnd then return false end
    end
    return true 
end

local function setHopCooldown(seconds)
    pcall(function() writefile(dataPath("HopCooldown.txt"), tostring(os.time() + seconds)) end)
end

local function isMainOnline()
    local recent = false
    pcall(function()
        local path = dataPath("Status_" .. _G.AutoSyncConfig.MainUsername .. ".txt")
        if isfile(path) then
            local content = readfile(path)
            local ts = content:match("^(%d+)|")
            if ts and (os.time() - tonumber(ts)) < 20 then recent = true end
        end
    end)
    return recent
end

local function canAltJoin()
    local path = dataPath("AltJoinCooldown_" .. LocalPlayer.Name .. ".txt")
    if isfile(path) then
        local cooldownEnd = tonumber(readfile(path))
        if cooldownEnd and os.time() < cooldownEnd then return false end
    end
    return true
end

local function setAltJoinCooldown(seconds)
    pcall(function() writefile(dataPath("AltJoinCooldown_" .. LocalPlayer.Name .. ".txt"), tostring(os.time() + seconds)) end)
end

-- ==========================================
-- 🏆 ระบบ "Tier 5 ไม่ต้องตาม"
-- ==========================================
local function getSkipHopPath(username)
    return dataPath("SkipHop_" .. (username or LocalPlayer.Name) .. ".txt")
end

local function getSkipHop(username)
    local path = getSkipHopPath(username)
    if isfile(path) then
        local ok, content = pcall(readfile, path)
        return ok and content == "true"
    end
    return false
end

local function setSkipHop(value, username)
    pcall(function() writefile(getSkipHopPath(username), value and "true" or "false") end)
end

local function joinServer(jobId)
    local viaBrowser = false
    pcall(function()
        local browser = ReplicatedStorage:FindFirstChild("__ServerBrowser")
        if browser and browser:IsA("RemoteFunction") then
            browser:InvokeServer("teleport", jobId)
            viaBrowser = true
        end
    end)
    if not viaBrowser then
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end)
    end
    return viaBrowser
end

local function handleTeleportError()
    local clicked = false
    local errorCode = nil
    pcall(function()
        local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if promptGui then
            local errorFound = false
            for _, desc in pairs(promptGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible then
                    if string.find(desc.Text, "772") or string.find(desc.Text, "full") or string.find(desc.Text, "Teleport Failed") then
                        errorFound = true
                    end
                    local code = desc.Text:match("Error Code:%s*(%d+)")
                    if code then errorCode = code end
                end
                if errorFound and desc:IsA("TextButton") and (desc.Text == "OK" or desc.Text == "Ok") and desc.Visible and not clicked then
                    virtualClick(desc) -- [แก้] บังคับคลิกเลยไม่ต้องเช็คปลอดภัย
                    clicked = true
                    task.wait(1)
                    pcall(function() GuiService:ClearError() end)
                end
            end
        end
    end)
    return clicked, errorCode
end


--------------------------------------------------
-- 🔵 โหมด NORMAL (ผู้ตาม)
--------------------------------------------------
if not isMain then
    print("🚀 [Normal] เริ่มโหมดผู้ตาม")
    local oldAltUi = CoreGui:FindFirstChild("AutoSyncAltStatusUI")
    if oldAltUi then oldAltUi:Destroy() end

    local AltScreenGui = Instance.new("ScreenGui")
    AltScreenGui.Name = "AutoSyncAltStatusUI"
    AltScreenGui.ResetOnSpawn = false
    AltScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    AltScreenGui.Parent = CoreGui

    local AltFrame = Instance.new("Frame")
    AltFrame.Name = "AltFrame"
    AltFrame.Size = UDim2.new(0, 240, 0, 88)
    AltFrame.Position = UDim2.new(0.5, -120, 0, 20)
    AltFrame.BackgroundColor3 = Theme.BgTop
    AltFrame.BorderSizePixel = 0
    AltFrame.Parent = AltScreenGui

    local AltCorner = Instance.new("UICorner")
    AltCorner.CornerRadius = UDim.new(0, 12)
    AltCorner.Parent = AltFrame

    local AltGradient = Instance.new("UIGradient")
    AltGradient.Rotation = 90
    AltGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.BgTop), ColorSequenceKeypoint.new(1, Theme.BgBottom) })
    AltGradient.Parent = AltFrame

    local AltSideBar = Instance.new("Frame")
    AltSideBar.BorderSizePixel = 0
    AltSideBar.Size = UDim2.new(0, 4, 1, -14)
    AltSideBar.Position = UDim2.new(0, 6, 0, 7)
    AltSideBar.BackgroundColor3 = Theme.Accent
    AltSideBar.Parent = AltFrame

    local AltBadge = Instance.new("TextLabel")
    AltBadge.BackgroundTransparency = 1
    AltBadge.Size = UDim2.new(1, -24, 0, 14)
    AltBadge.Position = UDim2.new(0, 18, 0, 6)
    AltBadge.Text = "🔹 ID รอง • " .. LocalPlayer.Name
    AltBadge.TextColor3 = Theme.Accent
    AltBadge.Font = Enum.Font.GothamBold
    AltBadge.TextSize = 11
    AltBadge.TextXAlignment = Enum.TextXAlignment.Left
    AltBadge.Parent = AltFrame

    local AltStatusLabel = Instance.new("TextLabel")
    AltStatusLabel.BackgroundTransparency = 1
    AltStatusLabel.Size = UDim2.new(1, -24, 0, 24)
    AltStatusLabel.Position = UDim2.new(0, 18, 0, 22)
    AltStatusLabel.Text = "🔵 รอเชื่อมต่อ..."
    AltStatusLabel.TextColor3 = Theme.TextMain
    AltStatusLabel.Font = Enum.Font.Gotham
    AltStatusLabel.TextSize = 12
    AltStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    AltStatusLabel.Parent = AltFrame

    _G.AutoSyncStatusLabel = AltStatusLabel

    local Tier5Btn = Instance.new("TextButton")
    Tier5Btn.Size = UDim2.new(1, -24, 0, 28)
    Tier5Btn.Position = UDim2.new(0, 12, 0, 50)
    Tier5Btn.AutoButtonColor = false
    Tier5Btn.Font = Enum.Font.GothamBold
    Tier5Btn.TextSize = 12
    Tier5Btn.Parent = AltFrame
    Instance.new("UICorner", Tier5Btn).CornerRadius = UDim.new(0, 8)

    local function refreshTier5Btn()
        if getSkipHop() then
            Tier5Btn.BackgroundColor3 = Theme.Success
            Tier5Btn.Text = "✅ Auto: Tier 6+ แล้ว • หยุดตาม"
            Tier5Btn.TextColor3 = Color3.fromRGB(15, 40, 25)
        else
            Tier5Btn.BackgroundColor3 = Theme.Card
            Tier5Btn.Text = "⏳ กำลังออโต้เช็ค Tier เผ่า..."
            Tier5Btn.TextColor3 = Theme.TextMain
        end
    end
    refreshTier5Btn()

    Tier5Btn.MouseButton1Click:Connect(function()
        setSkipHop(not getSkipHop())
        refreshTier5Btn()
        updateStatus(getSkipHop() and "🏆 (กดมือ) หยุดตาม Main" or "🔵 กลับมาตาม Main ตามปกติ")
    end)

    -- Auto check tier
    task.spawn(function()
        while task.wait(5) do
            if getSkipHop() then continue end
            local isTier6OrMore = false
            pcall(function()
                local player = game:GetService("Players").LocalPlayer
                local bananaUI = findTeddyHubUI() -- Use same finder just in case
                if bananaUI then
                    for _, v in pairs(bananaUI:GetDescendants()) do
                        if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Visible then
                            local tierNum = v.Text:match("[Tt]iers%s*%-?%s*V4%s*:%s*(%d+)")
                            if tierNum and tonumber(tierNum) >= 6 then isTier6OrMore = true; break end
                        end
                    end
                end
                if not isTier6OrMore then
                    local data = player:FindFirstChild("Data")
                    if data then
                        if data:FindFirstChild("RaceV4") and tonumber(data.RaceV4.Value) and tonumber(data.RaceV4.Value) >= 6 then isTier6OrMore = true end
                        if data:FindFirstChild("Tier") and tonumber(data.Tier.Value) and tonumber(data.Tier.Value) >= 6 then isTier6OrMore = true end
                    end
                end
            end)
            if isTier6OrMore then
                setSkipHop(true)
                refreshTier5Btn()
                updateStatus("🏆 ระบบตรวจพบ Tier 6+! หยุดตามอัตโนมัติ")
            end
        end
    end)

    -- Drag UI
    local altDragging, altDragInput, altDragStart, altStartPos
    AltFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            altDragging = true; altDragStart = input.Position; altStartPos = AltFrame.Position
        end
    end)
    AltFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then altDragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == altDragInput and altDragging then
            local delta = input.Position - altDragStart
            AltFrame.Position = UDim2.new(altStartPos.X.Scale, altStartPos.X.Offset + delta.X, altStartPos.Y.Scale, altStartPos.Y.Offset + delta.Y)
        end
    end)
    AltFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then altDragging = false end
    end)

    updateStatus("🔵 เริ่มทำงาน รอ JobId จาก Main")
    task.spawn(function()
        while task.wait(15) do
            pcall(function()
                if getSkipHop() then updateStatus("🏆 Tier สูงแล้ว หยุดตาม Main"); return end
                if isfile(dataPath("MainServer.txt")) then
                    local targetJobId = readfile(dataPath("MainServer.txt"))
                    if targetJobId and targetJobId ~= "" and game.JobId ~= targetJobId then
                        if not isMainOnline() then updateStatus("⏳ รอ Main ยืนยันว่ายังอยู่เซิฟก่อนตาม")
                        elseif not canAltJoin() then updateStatus("⏳ ติดคูลดาวน์การตาม Main รอสักครู่")
                        else
                            updateStatus("🚀 กำลังเดินทางตาม Main ไปเซิฟใหม่")
                            setAltJoinCooldown(15)
                            if joinServer(targetJobId) then updateStatus("🚀 สั่งเทเลพอร์ตผ่านเมนูเกม (server browser)") end
                        end
                    else updateStatus("🟢 อยู่เซิฟเดียวกับ Main แล้ว") end
                else updateStatus("⌛ ยังไม่พบไฟล์ JobId ของ Main") end
            end)
        end
    end)

    task.spawn(function()
        while task.wait(5) do
            local clicked, errorCode = handleTeleportError()
            if clicked then
                if errorCode == "772" then
                    updateStatus("⚠️ เจอเซิฟเต็ม กำลังแจ้ง Main ให้หาห้องใหม่")
                    pcall(function() writefile(dataPath("ForceMainReset.txt"), "true") end)
                    setAltJoinCooldown(20)
                elseif errorCode == "773" then
                    updateStatus("🚫 เข้าห้องไม่ได้ (ถูกจำกัดสิทธิ์ Error 773) กำลังรอแล้วลองใหม่")
                    setAltJoinCooldown(30)
                else
                    updateStatus("⚠️ เทเลพอร์ตล้มเหลว กำลังลองใหม่")
                    setAltJoinCooldown(15)
                end
            end
        end
    end)
    return -- จบจอรอง
end

--------------------------------------------------
-- 🔴 โหมด MAIN (ผู้นำ + สร้าง UI)
--------------------------------------------------
print("🌕 [Main] เริ่มโหมดผู้นำ พร้อม UI นับเวลา")
updateStatus("🌕 เริ่มทำงานโหมด Main")

_G.ForceFindNewServer = false 
if not _G.FullMoonLastReload then _G.FullMoonLastReload = 0 end

local oldUi = CoreGui:FindFirstChild("AutoSyncTimerUI")
if oldUi then oldUi:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoSyncTimerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 250, 0, 320)
MainFrame.Position = UDim2.new(0.5, -125, 0, 20)
MainFrame.BackgroundColor3 = Theme.BgTop
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3 = Theme.HeaderTop
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)

local HeaderMask = Instance.new("Frame")
HeaderMask.BackgroundColor3 = Theme.HeaderTop
HeaderMask.BorderSizePixel = 0
HeaderMask.Size = UDim2.new(1, 0, 0, 14)
HeaderMask.Position = UDim2.new(0, 0, 1, -14)
HeaderMask.ZIndex = Header.ZIndex
HeaderMask.Parent = Header

local TitleIcon = Instance.new("TextLabel")
TitleIcon.BackgroundTransparency = 1
TitleIcon.Size = UDim2.new(0, 26, 0, 20)
TitleIcon.Position = UDim2.new(0, 12, 0, 8)
TitleIcon.Text = "🌕"
TitleIcon.TextSize = 18
TitleIcon.Font = Enum.Font.GothamBold
TitleIcon.Parent = Header

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Size = UDim2.new(1, -80, 0, 14)
SubTitleLabel.Position = UDim2.new(0, 34, 0, 6)
SubTitleLabel.Text = "AUTO SYNC SYSTEM"
SubTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SubTitleLabel.TextTransparency = 0.35
SubTitleLabel.Font = Enum.Font.GothamBold
SubTitleLabel.TextSize = 11
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLabel.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size = UDim2.new(1, -80, 0, 22)
TitleLabel.Position = UDim2.new(0, 34, 0, 20)
TitleLabel.Text = "⏱️ รอเช็คห้อง: --:--"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -34, 0, 14)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.BackgroundTransparency = 0.85
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = Header
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 7)

local Body = Instance.new("Frame")
Body.BackgroundTransparency = 1
Body.Size = UDim2.new(1, 0, 1, -54)
Body.Position = UDim2.new(0, 0, 0, 54)
Body.Parent = MainFrame

local function styleButton(btn, baseColor, hoverColor)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = baseColor
    btn.MouseEnter:Connect(function() game:GetService("TweenService"):Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play() end)
    btn.MouseLeave:Connect(function() game:GetService("TweenService"):Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = baseColor}):Play() end)
end

local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(0.5, -16, 0, 34)
ResetBtn.Position = UDim2.new(0, 12, 0, 10)
ResetBtn.Text = "🔄 รีเซ็ตเวลา"
ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.TextSize = 13
ResetBtn.Parent = Body
styleButton(ResetBtn, Theme.Danger, Theme.DangerHover)

local FindServerBtn = Instance.new("TextButton")
FindServerBtn.Size = UDim2.new(0.5, -16, 0, 34)
FindServerBtn.Position = UDim2.new(0.5, 4, 0, 10)
FindServerBtn.Text = "🔎 หาเซิฟ"
FindServerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FindServerBtn.Font = Enum.Font.GothamBold
FindServerBtn.TextSize = 13
FindServerBtn.Parent = Body
styleButton(FindServerBtn, Theme.Info, Theme.InfoHover)

local StatusTitle = Instance.new("TextLabel")
StatusTitle.Size = UDim2.new(1, -24, 0, 18)
StatusTitle.Position = UDim2.new(0, 12, 0, 52)
StatusTitle.BackgroundTransparency = 1
StatusTitle.Text = "📋 สถานะไอดีทั้งหมด (0)"
StatusTitle.TextColor3 = Theme.TextDim
StatusTitle.Font = Enum.Font.GothamBold
StatusTitle.TextSize = 12
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.Parent = Body

local StatusScroll = Instance.new("ScrollingFrame")
StatusScroll.Size = UDim2.new(1, -24, 1, -84)
StatusScroll.Position = UDim2.new(0, 12, 0, 76)
StatusScroll.BackgroundColor3 = Theme.Card
StatusScroll.BorderSizePixel = 0
StatusScroll.ScrollBarThickness = 3
StatusScroll.ScrollBarImageColor3 = Theme.Accent
StatusScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
StatusScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
StatusScroll.Parent = Body
Instance.new("UICorner", StatusScroll).CornerRadius = UDim.new(0, 10)
local slayout = Instance.new("UIListLayout", StatusScroll)
slayout.SortOrder = Enum.SortOrder.Name
slayout.Padding = UDim.new(0, 4)
local spad = Instance.new("UIPadding", StatusScroll)
spad.PaddingTop, spad.PaddingBottom, spad.PaddingLeft, spad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)

-- Dragging
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local minimized = false
local expandedSize = MainFrame.Size
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MinimizeBtn.Text = "+"
        game:GetService("TweenService"):Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(expandedSize.X.Scale, expandedSize.X.Offset, 0, 54)}):Play()
    else
        MinimizeBtn.Text = "—"
        game:GetService("TweenService"):Create(MainFrame, TweenInfo.new(0.2), {Size = expandedSize}):Play()
    end
end)

ResetBtn.MouseButton1Click:Connect(function()
    resetTimer()
    TitleLabel.Text = "⏱️ รีเซ็ตเวลาแล้ว!"
end)

FindServerBtn.MouseButton1Click:Connect(function()
    if canHop() then
        _G.ForceFindNewServer = true
        TitleLabel.Text = "⏱️ กำลังหาห้อง..."
        updateStatus("🔍 กดหาเซิฟด้วยตนเอง")
    else
        TitleLabel.Text = "⏳ ติดคูลดาวน์ รอสักครู่..."
    end
end)

-- Main logic
task.spawn(function()
    while task.wait(5) do
        if game.JobId ~= "" then pcall(function() writefile(dataPath("MainServer.txt"), tostring(game.JobId)) end) end
    end
end)

local function checkCount()
    local ownNames = getOwnAccountNames()
    local otherCount, ownCount = 0, 0
    for _, player in pairs(Players:GetPlayers()) do
        if isOwnAccount(player.Name, ownNames) then ownCount = ownCount + 1 else otherCount = otherCount + 1 end
    end
    if otherCount > (_G.AutoSyncConfig.MaxOtherPlayers or 2) then
        if canHop() then
            _G.ForceFindNewServer = true
            updateStatus("⚠️ คนนอกเกิน " .. otherCount .. " เปิดหาห้องใหม่")
        else
            updateStatus("⏳ คนนอกเกิน " .. otherCount .. " แต่ติดคูลดาวน์")
        end
    else
        _G.ForceFindNewServer = false
    end
end

if not isfile(dataPath("LastCheckTime.txt")) then resetTimer() end
checkCount()
Players.PlayerAdded:Connect(function() task.wait(2); checkCount() end)
Players.PlayerRemoving:Connect(function() task.wait(2); checkCount() end)

-- ตัวนับเวลาที่แก้บั๊กคูลดาวน์แล้ว [สำคัญมาก]
task.spawn(function()
    local intervalSeconds = _G.AutoSyncConfig.CheckIntervalMinutes * 60
    local lastStatusPush = 0
    while task.wait(1) do
        pcall(function()
            if isfile(dataPath("LastCheckTime.txt")) then
                local lastTime = tonumber(readfile(dataPath("LastCheckTime.txt")))
                if lastTime then
                    local timePassed = os.time() - lastTime
                    local timeLeft = intervalSeconds - timePassed
                    
                    if timeLeft > 0 then
                        local mins, secs = math.floor(timeLeft / 60), timeLeft % 60
                        TitleLabel.Text = string.format("⏱️ รอเช็คห้อง: %02d:%02d", mins, secs)
                        if tick() - lastStatusPush > 5 then
                            updateStatus(string.format("⏱️ รอเช็คห้อง %02d:%02d", mins, secs))
                            lastStatusPush = tick()
                        end
                    else
                        if canHop() then
                            -- [แก้ 1] ลบคำสั่งเปิดคูลดาวน์ตรงนี้ออก ให้มันไปเปิดตอนกดเจอเซิฟสำเร็จเท่านั้น
                            TitleLabel.Text = "⏱️ หมดเวลา! กำลังหาห้อง..."
                            _G.ForceFindNewServer = true
                            resetTimer() -- รีเซ็ตเวลาเพื่อเริ่มลูปสแกนเซิฟเวอร์ใหม่
                            updateStatus("🔍 หมดเวลา กำลังหาห้องใหม่")
                        else
                            TitleLabel.Text = "⏳ ติดคูลดาวน์..."
                            updateStatus("⏳ ติดคูลดาวน์ รอย้ายเซิฟ")
                        end
                    end
                end
            else
                resetTimer()
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(3) do
        if handleTeleportError() then _G.ForceFindNewServer = true end
        pcall(function()
            if isfile(dataPath("ForceMainReset.txt")) and readfile(dataPath("ForceMainReset.txt")) == "true" then
                _G.ForceFindNewServer = true
                writefile(dataPath("ForceMainReset.txt"), "false")
            end
        end)
    end
end)

-- [5] ลูปค้นหาเซิฟเวอร์ (Teddy Hub) - ฉบับทะลวงกด
local isProcessing = false 

task.spawn(function()
    while task.wait(3) do
        if isProcessing or not _G.ForceFindNewServer then continue end
        updateStatus("🔎 กำลังหาปุ่มเปลี่ยนเซิร์ฟ...")
        
        local teddyUI = findTeddyHubUI()
        if not teddyUI then updateStatus("⚠️ ไม่เจอหน้าต่าง Teddy Hub!"); continue end
        
        local elements = teddyUI:GetDescendants()
        local onFullMoonTab = false
        
        -- เช็คว่าอยู่หน้า FullMoon หรือยัง
        for _, v in pairs(elements) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                local text = v.Text
                if text and (string.find(text, "Reload server new") or string.find(text, "Refresh server with FullMoon")) and isReallyVisible(v) then
                    onFullMoonTab = true; break
                end
            end
        end
        
        -- ถ้ายังไม่อยู่ ให้หาปุ่มกดเข้าหน้า FullMoon
        if not onFullMoonTab then
            for _, v in pairs(elements) do
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    if v.Text == "FullMoon" and v.Parent.Name ~= "Header" and isReallyVisible(v) then
                        if adjustScrollToElement(v) then virtualClick(v); task.wait(2); break end
                    end
                end
            end
            elements = teddyUI:GetDescendants()
        end
        
        -- เมื่ออยู่หน้า FullMoon แล้ว ให้เริ่มสแกนคนน้อย
        if onFullMoonTab then
            local joined = false
            local serverCount = 0
            
            for _, v in pairs(elements) do
                if v:IsA("TextLabel") and string.find(v.Text, "Players:") and isReallyVisible(v) then
                    serverCount = serverCount + 1
                    local infoText = v.Text
                    
                    if (string.find(infoText, "Players: 1 ") or string.find(infoText, "Players: 2 ") or string.find(infoText, "Players: 1 |") or string.find(infoText, "Players: 2 |") or string.find(infoText, "Players: 1/") or string.find(infoText, "Players: 2/")) and not string.find(infoText, "Different Sea") then
                        print("🎯 [Main] เจอเซิร์ฟเวอร์คนน้อยแล้ว! กำลังมุดเข้าห้อง...")
                        local mainCard = getCardFrame(v)

                        pcall(function()
                            isProcessing = true
                            task.wait(0.5)
                            -- [แก้ 2] บังคับกดเมาส์ลงตรงนั้นเลยโดยไม่ต้องเช็คปลอดภัย กัน Hub ซ่อนปุ่ม
                            virtualClick(mainCard)
                            joined = true
                        end)
                        if joined then break end
                    end
                    if serverCount >= 3 then break end
                end
            end
            
            if joined then 
                print("🚀 [Main] สั่งเข้าห้องสำเร็จ รอโหลดและรีเซ็ตเวลาใหม่...")
                updateStatus("🚀 เข้าห้องใหม่สำเร็จ กำลังโหลด...")
                _G.ForceFindNewServer = false
                resetTimer()
                
                -- [แก้ 3] เมื่อกดเจอปุ่มเข้าห้องสำเร็จแล้วเท่านั้น ถึงค่อยล็อกคูลดาวน์ 120 วิ 
                setHopCooldown(120) 
                
                task.wait(45) 
                isProcessing = false 
                updateStatus("🟢 อยู่ในห้องปัจจุบัน")
            else
                if tick() - _G.FullMoonLastReload > 5 then
                    for _, v in pairs(elements) do
                        if v:IsA("TextLabel") or v:IsA("TextButton") then
                            if v.Text and string.find(v.Text, "Reload server new") and isReallyVisible(v) then
                                virtualClick(v)
                                _G.FullMoonLastReload = tick()
                                task.wait(3); break
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- UI Status Rendering (ลดรูปให้กระชับ)
local statusRows = {}
local function getOrCreateStatusRow(username, isMainRow)
    if statusRows[username] then return statusRows[username] end
    local card = Instance.new("Frame", StatusScroll)
    card.Name = username; card.Size = UDim2.new(1, 0, 0, 34); card.BackgroundColor3 = Theme.BgTop; card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local sideBar = Instance.new("Frame", card); sideBar.Size = UDim2.new(0, 3, 1, -10); sideBar.Position = UDim2.new(0, 0, 0, 5); sideBar.BackgroundColor3 = isMainRow and Theme.Main or Theme.Accent; sideBar.BorderSizePixel = 0
    Instance.new("UICorner", sideBar).CornerRadius = UDim.new(1, 0)
    local roleIcon = Instance.new("TextLabel", card); roleIcon.BackgroundTransparency = 1; roleIcon.Size = UDim2.new(0, 22, 1, 0); roleIcon.Position = UDim2.new(0, 8, 0, 0); roleIcon.Text = isMainRow and "👑" or "🔹"; roleIcon.TextSize = 14; roleIcon.Font = Enum.Font.GothamBold
    local nameLabel = Instance.new("TextLabel", card); nameLabel.BackgroundTransparency = 1; nameLabel.Size = UDim2.new(1, -38, 0, 15); nameLabel.Position = UDim2.new(0, 32, 0, 3); nameLabel.Text = username; nameLabel.TextColor3 = Theme.TextMain; nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextSize = 12; nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    local badge = Instance.new("TextLabel", card); badge.BackgroundColor3 = isMainRow and Theme.Main or Theme.Accent; badge.BackgroundTransparency = 0.82; badge.Size = UDim2.new(0, isMainRow and 40 or 52, 0, 14); badge.Position = UDim2.new(1, isMainRow and -46 or -58, 0, 4); badge.Text = isMainRow and "MAIN" or "ID รอง"; badge.TextColor3 = isMainRow and Theme.Main or Theme.Accent; badge.Font = Enum.Font.GothamBold; badge.TextSize = 9
    Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
    local statusLabel = Instance.new("TextLabel", card); statusLabel.BackgroundTransparency = 1; statusLabel.Size = UDim2.new(1, -38, 0, 14); statusLabel.Position = UDim2.new(0, 32, 0, 18); statusLabel.Text = ""; statusLabel.TextColor3 = Theme.TextDim; statusLabel.Font = Enum.Font.Gotham; statusLabel.TextSize = 11; statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusRows[username] = { Card = card, StatusLabel = statusLabel, Badge = badge }
    return statusRows[username]
end

task.spawn(function()
    while task.wait(3) do
        pcall(function()
            local seen = {}
            local totalCount = 0

            -- รายชื่อที่ผู้ใช้ "ระบุไว้เองใน config" (Main + OwnAccountUsernames) จะแสดง/นับเสมอ
            -- แม้จะไม่ตอบสนอง ณ ตอนนี้ก็ตาม ส่วนไอดีที่ auto-detect เจอเฉยๆ (ไม่ได้ใส่ config)
            -- ถ้าไม่ตอบสนอง (ไฟล์ค้างเก่า) จะไม่โชว์/ไม่นับ ตามที่ตั้งไว้
            local configuredNames = { [_G.AutoSyncConfig.MainUsername] = true }
            for _, username in pairs(_G.AutoSyncConfig.OwnAccountUsernames or {}) do
                configuredNames[username] = true
            end

            if isfile(dataPath("Status_" .. LocalPlayer.Name .. ".txt")) then
                local content = readfile(dataPath("Status_" .. LocalPlayer.Name .. ".txt"))
                local ts, role, txt = content:match("^(%d+)|(%a+)|(.+)$")
                if ts and txt then
                    local row = getOrCreateStatusRow(LocalPlayer.Name, true)
                    row.Card.LayoutOrder = 0; row.StatusLabel.Text = txt; row.StatusLabel.TextColor3 = Theme.TextDim; seen[LocalPlayer.Name] = true; totalCount = totalCount + 1
                end
            end
            if listfiles then
                for _, path in pairs(listfiles(DATA_FOLDER)) do
                    local fname = path:match("[^/\\]+$")
                    local username = fname and fname:match("^Status_(.+)%.txt$")
                    if username and username ~= LocalPlayer.Name and isfile(path) then
                        local content = readfile(path)
                        local ts, role, txt = content:match("^(%d+)|(%a+)|(.+)$")
                        if ts and txt then
                            local ago = os.time() - tonumber(ts)
                            local isMainRow = (role == "MAIN")
                            local stale = ago > 60

                            -- ไม่ได้อยู่ใน config และไม่ตอบสนองแล้ว -> ข้ามไปเลย ไม่โชว์ ไม่นับ
                            if stale and not configuredNames[username] then
                                if statusRows[username] then statusRows[username].Card:Destroy(); statusRows[username] = nil end
                            else
                                local row = getOrCreateStatusRow(username, isMainRow)
                                row.Card.LayoutOrder = isMainRow and 0 or 1; row.StatusLabel.Text = stale and (txt .. "  ⚠️ ไม่ตอบสนอง") or txt; row.StatusLabel.TextColor3 = stale and Theme.Danger or Theme.TextDim; row.Badge.BackgroundTransparency = stale and 0.5 or 0.82; seen[username] = true; totalCount = totalCount + 1
                            end
                        end
                    end
                end
            end
            for username, row in pairs(statusRows) do
                if not seen[username] then row.Card:Destroy(); statusRows[username] = nil end
            end
            StatusTitle.Text = string.format("📋 สถานะไอดีทั้งหมด (%d)", totalCount)
        end)
    end
end)
