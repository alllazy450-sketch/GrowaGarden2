-- ============================================================
--  W424HUB ULTIMATE – Kairo UI (Ocean Theme)
--  Grow a Garden 2 – All-in-One Script
-- ============================================================
print("=== LOADING W424HUB ULTIMATE ===")

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ===== LOAD KAIRO UI =====
local Kairo = loadstring(game:HttpGet("https://raw.githubusercontent.com/Itzzavi335/Kairo-Ui-Library/refs/heads/main/source.luau"))()
if not Kairo then error("Kairo UI gagal dimuat") end

local Window = Kairo:CreateWindow({
    Title = "W424HUB",
    Theme = "Ocean",
    Size = UDim2.fromOffset(600, 540),
    Center = true,
    Draggable = true,
    Resize = true,
    Badges = {"Ultimate", "Kairo"},
    MinimizeKey = Enum.KeyCode.RightShift,
    MinimizeButton = true,
    Config = { Enabled = true, Folder = "W424HUB_Ultimate", AutoLoad = true }
})

-- ===== FLOATING BUBBLE (Logo W) – FIXED =====
local function createBubble()
    -- Hapus bubble lama kalau ada
    local oldGui = CoreGui:FindFirstChild("W424Bubble")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "W424Bubble"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui

    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0, 56, 0, 56)
    btn.Position = UDim2.new(0, 15, 0, 150)
    btn.BackgroundColor3 = Color3.fromRGB(0, 130, 200)
    btn.BackgroundTransparency = 0.25
    btn.BorderSizePixel = 0
    btn.ZIndex = 10
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = btn

    -- Shadow (opsional)
    local shadow = Instance.new("UIShadow")
    shadow.Color = Color3.fromRGB(0, 0, 0)
    shadow.Transparency = 0.5
    shadow.Offset = Vector2.new(2, 2)
    shadow.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "W"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 32
    label.ZIndex = 11
    label.Parent = btn

    -- Toggle Window on click
    btn.MouseButton1Click:Connect(function()
        Window:ToggleVisibility()
    end)

    -- Drag logic
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
        end
    end)

    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and startPos then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then
            dragging = false
            dragInput = nil
        end
    end)

    -- Optional: tahan untuk prevent drag keluar layar
    btn:GetPropertyChangedSignal("Position"):Connect(function()
        local pos = btn.Position
        local offsetX = pos.X.Offset
        local offsetY = pos.Y.Offset
        local maxX = 200
        local maxY = 200
        if offsetX < 0 then offsetX = 0 end
        if offsetY < 0 then offsetY = 0 end
        if offsetX > maxX then offsetX = maxX end
        if offsetY > maxY then offsetY = maxY end
        btn.Position = UDim2.new(pos.X.Scale, offsetX, pos.Y.Scale, offsetY)
    end)
end
createBubble()

-- ============================================================
--  MODUL DAN FUNGSI INTI (TETAP SAMA – TIDAK DIUBAH)
-- ============================================================
local Networking = require(ReplicatedStorage.SharedModules.Networking)
local SeedData = require(ReplicatedStorage.SharedModules.SeedData)
local FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
local PlantLifecycleHandler = require(LocalPlayer.PlayerScripts.Controllers.PlantLifecycleHandler)
local StealFlags = require(ReplicatedStorage.SharedModules.Flags.StealFlags)

local Gardens = workspace:WaitForChild("Gardens")
local Night = ReplicatedStorage:WaitForChild("Night")

local function getMyPlot()
    for _, plot in ipairs(Gardens:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.Name then return plot end
    end
    return nil
end

local function isNightTime() return Night and Night.Value == true end

local function getChar() return LocalPlayer.Character end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end

local function teleportTo(targetCF, speed)
    speed = speed or 35
    local hrp = getHRP()
    if not hrp or not targetCF then return end
    local start = hrp.CFrame
    local dist = (targetCF.Position - start.Position).Magnitude
    local duration = dist / speed
    local con
    local elapsed = 0
    con = RunService.RenderStepped:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            if hrp and hrp.Parent then hrp.CFrame = targetCF end
            if con then con:Disconnect() end
            return
        end
        local alpha = elapsed / duration
        if hrp and hrp.Parent then
            hrp.CFrame = start:Lerp(targetCF, alpha)
        else
            if con then con:Disconnect() end
        end
    end)
    task.wait(duration + 0.5)
    if con and con.Connected then con:Disconnect() end
end

local function getPlantValue(model)
    local seedName = model:GetAttribute("SeedName") or model:GetAttribute("CorePartName")
    if not seedName then return 0 end
    local mutation = model:GetAttribute("Mutation") or ""
    local size = model:GetAttribute("SizeMulti") or 1
    local decay = 0
    pcall(function() decay = PlantLifecycleHandler:GetDecayAlpha(model:GetAttribute("PlantId")) or 0 end)
    local ok, val = pcall(FruitValueCalc, seedName, size, mutation, LocalPlayer, decay)
    return ok and val or 0
end

local function canStealFrom(player)
    if not player then return false end
    return not player:GetAttribute("IsInOwnGarden")
end

local function getBestStealTarget()
    local best, bestVal = nil, -1
    for _, plot in ipairs(Gardens:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local fruits = plant:FindFirstChild("Fruits")
                if fruits then
                    for _, fruit in ipairs(fruits:GetChildren()) do
                        if fruit:IsA("Model") then
                            local seedName = fruit:GetAttribute("SeedName") or fruit:GetAttribute("CorePartName")
                            if seedName and StealFlags.IsPlantStealable(seedName) then
                                local ownerId = fruit:GetAttribute("UserId")
                                if ownerId then
                                    local owner = Players:GetPlayerByUserId(tonumber(ownerId))
                                    if owner and canStealFrom(owner) then
                                        local val = getPlantValue(fruit)
                                        if val > bestVal then bestVal = val; best = fruit end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestVal
end

local function performSteal()
    if not isNightTime() then return end
    local target, val = getBestStealTarget()
    if not target then return end
    local ownerId = target:GetAttribute("UserId")
    local plantId = target:GetAttribute("PlantId")
    local fruitId = target:GetAttribute("FruitId") or ""
    if not (ownerId and plantId) then return end
    local plot = getMyPlot()
    if not plot then return end
    local ref = plot:FindFirstChild("PlotSizeReference")
    if not ref then return end
    local home = ref.CFrame
    local bp = target:FindFirstChildWhichIsA("BasePart")
    if not bp then return end
    local targetCF = bp.CFrame + Vector3.new(0, 3, 0)
    teleportTo(targetCF, 33)
    task.wait(0.5)
    Networking.Steal.BeginSteal:Fire(tonumber(ownerId), plantId, fruitId)
    task.wait(0.1)
    Networking.Steal.CompleteSteal:Fire()
    task.wait(0.5)
    teleportTo(home, 33)
end

local function harvestAll()
    local plot = getMyPlot()
    if not plot then return 0 end
    local plants = plot:FindFirstChild("Plants")
    if not plants then return 0 end
    local count = 0
    for _, plant in ipairs(plants:GetChildren()) do
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            for _, fruit in ipairs(fruits:GetChildren()) do
                if fruit:IsA("Model") then
                    local age = fruit:GetAttribute("Age") or 0
                    local maxAge = fruit:GetAttribute("MaxAge") or 0
                    if age >= maxAge then
                        local pid = fruit:GetAttribute("PlantId")
                        local fid = fruit:GetAttribute("FruitId") or ""
                        if pid then
                            Networking.Garden.CollectFruit:Fire(pid, fid)
                            count = count + 1
                            task.wait(0.05)
                        end
                    end
                end
            end
        else
            -- direct plant harvest (no fruits folder)
            local age = plant:GetAttribute("Age") or 0
            local maxAge = plant:GetAttribute("MaxAge") or 0
            if age >= maxAge then
                local pid = plant:GetAttribute("PlantId")
                if pid then
                    Networking.Garden.CollectFruit:Fire(pid, "")
                    count = count + 1
                    task.wait(0.05)
                end
            end
        end
    end
    return count
end

local function sellAll()
    Networking.NPCS.SellAll:Fire()
end

local function buyItems()
    -- Buy seeds
    local seedStock = ReplicatedStorage.StockValues.SeedShop.Items
    for _, item in ipairs(seedStock:GetChildren()) do
        if item:IsA("ValueBase") and item.Value > 0 then
            pcall(function() Networking.SeedShop.PurchaseSeed:Fire(item.Name) end)
            task.wait(0.05)
        end
    end
    -- Buy gears
    local gearStock = ReplicatedStorage.StockValues.GearShop.Items
    for _, item in ipairs(gearStock:GetChildren()) do
        if item:IsA("ValueBase") and item.Value > 0 then
            pcall(function() Networking.GearShop.PurchaseGear:Fire(item.Name) end)
            task.wait(0.05)
        end
    end
    -- Buy crates
    local crateStock = ReplicatedStorage.StockValues.CrateShop.Items
    for _, item in ipairs(crateStock:GetChildren()) do
        if item:IsA("ValueBase") and item.Value > 0 then
            pcall(function() Networking.CrateShop.PurchaseCrate:Fire(item.Name) end)
            task.wait(0.05)
        end
    end
end

local function openItems(category)
    local inv = LocalPlayer:GetAttribute("Inventory") or {}
    local pkt
    if category == "Eggs" then pkt = Networking.Egg.OpenEgg
    elseif category == "Crates" then pkt = Networking.Crate.OpenCrate
    elseif category == "SeedPacks" then pkt = Networking.SeedPack.OpenSeedPack
    else return end
    for name, count in pairs(inv[category] or {}) do
        for i = 1, count do
            pcall(function() pkt:Fire(name) end)
            task.wait(0.1)
        end
    end
end

local function autoPlant()
    local plot = getMyPlot()
    if not plot then return end
    local seeds = LocalPlayer:GetAttribute("Inventory") and LocalPlayer:GetAttribute("Inventory").Seeds or {}
    local freeSpots = {}
    -- cari plant area
    for _, area in ipairs(CollectionService:GetTagged("PlantArea")) do
        if area:IsDescendantOf(plot) then
            -- sederhana: ambil posisi acak di area
            local size = area.Size
            local step = 6
            for x = -size.X/2 + 3, size.X/2 - 3, step do
                for z = -size.Z/2 + 3, size.Z/2 - 3, step do
                    local pos = area.CFrame * CFrame.new(x, 0.5, z)
                    table.insert(freeSpots, pos.Position)
                end
            end
        end
    end
    if #freeSpots == 0 then return end
    local planted = 0
    for seed, count in pairs(seeds) do
        if count > 0 and planted < 40 then
            for i = 1, math.min(count, 5) do
                if planted >= #freeSpots then break end
                local pos = freeSpots[planted + 1]
                Networking.Plant.PlantSeed:Fire(pos, seed, plot)
                planted = planted + 1
                task.wait(0.1)
            end
        end
    end
end

-- ============================================================
--  UI – TABS & ELEMEN (TETAP SAMA)
-- ============================================================
local function addToggle(tab, name, desc, key, default, cb)
    return tab:AddToggle(name, desc or "", default or false, function(v)
        S[key] = v
        if cb then cb(v) end
    end, key)
end
local function addSlider(tab, name, desc, min, max, default, key, cb)
    return tab:AddLineSlider(name, desc or "", min, max, default or min, function(v)
        S[key] = v
        if cb then cb(v) end
    end, key)
end
local function addButton(tab, name, desc, icon, cb)
    return tab:AddButton(name, desc or "", icon or "", cb)
end
local function addDropdown(tab, name, desc, options, multi, default, key, cb)
    return tab:AddDropdown(name, desc or "", options, multi or false, default or options[1], function(v)
        S[key] = v
        if cb then cb(v) end
    end, key)
end

local S = {
    autoHarvest = false, autoSell = false, autoSteal = false,
    autoBuy = false, autoPlant = false, autoOpen = false,
    sellInterval = 60, harvestInterval = 2, stealInterval = 5,
    plantInterval = 10, buyInterval = 30,
    antiAfk = true, optimize = false,
}

-- Tabs
local FarmTab = Window:CreateTab("Farm")
local StealTab = Window:CreateTab("Steal")
local ShopTab = Window:CreateTab("Shop")
local MiscTab = Window:CreateTab("Misc")

-- Farm Tab
addToggle(FarmTab, "Auto Harvest", "Harvest ready crops", "autoHarvest", false)
addSlider(FarmTab, "Harvest Interval (s)", "Delay between harvest cycles", 1, 30, 2, "harvestInterval")
addToggle(FarmTab, "Auto Sell", "Sell all fruits", "autoSell", false)
addSlider(FarmTab, "Sell Interval (s)", "Delay between sells", 10, 300, 60, "sellInterval")
addButton(FarmTab, "Harvest Now", "Harvest once", "", function() harvestAll() end)
addButton(FarmTab, "Sell Now", "Sell now", "", function() sellAll() end)
addToggle(FarmTab, "Auto Plant", "Plant seeds from inventory", "autoPlant", false)
addSlider(FarmTab, "Plant Interval (s)", "Delay between planting", 5, 120, 10, "plantInterval")

-- Steal Tab
addToggle(StealTab, "Auto Steal", "Steal during night", "autoSteal", false)
addSlider(StealTab, "Steal Interval (s)", "Delay between steal attempts", 3, 30, 5, "stealInterval")
addButton(StealTab, "Steal Now", "Attempt one steal", "", function() performSteal() end)

-- Shop Tab
addToggle(ShopTab, "Auto Buy", "Buy seeds, gears, crates", "autoBuy", false)
addSlider(ShopTab, "Buy Interval (s)", "Delay between buy cycles", 10, 300, 30, "buyInterval")
addButton(ShopTab, "Buy Now", "Buy all available", "", function() buyItems() end)
addButton(ShopTab, "Open All Eggs", "", "", function() openItems("Eggs") end)
addButton(ShopTab, "Open All Crates", "", "", function() openItems("Crates") end)
addButton(ShopTab, "Open All Seed Packs", "", "", function() openItems("SeedPacks") end)

-- Misc Tab
addToggle(MiscTab, "Anti-AFK", "Prevent idle kick", "antiAfk", true)
addToggle(MiscTab, "Optimize (FPS)", "Reduce graphics", "optimize", false, function(v)
    if v then
        Lighting.GlobalShadows = false
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, e in ipairs(Lighting:GetDescendants()) do
            if e:IsA("PostEffect") or e:IsA("Atmosphere") then pcall(function() e.Enabled = false end) end
        end
    else
        Lighting.GlobalShadows = true
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end
end)
addButton(MiscTab, "Unload Script", "", "", function() Window:Destroy() end)

-- ============================================================
--  MAIN LOOPS
-- ============================================================
task.spawn(function()
    while true do
        task.wait(S.harvestInterval or 2)
        if S.autoHarvest then harvestAll() end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.sellInterval or 60)
        if S.autoSell then sellAll() end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.stealInterval or 5)
        if S.autoSteal and isNightTime() then performSteal() end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.buyInterval or 30)
        if S.autoBuy then buyItems() end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.plantInterval or 10)
        if S.autoPlant then autoPlant() end
    end
end)

-- Anti-AFK
local vu = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if S.antiAfk then
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)

-- ============================================================
--  NOTIFIKASI AWAL
-- ============================================================
Window:Notify({
    Title = "W424HUB Ultimate",
    Description = "All-in-One Grow a Garden 2 Script",
    Content = "Press RightShift to toggle",
    Color = Color3.fromRGB(0, 130, 200),
    Delay = 5
})

print("✅ W424HUB Ultimate loaded.")
