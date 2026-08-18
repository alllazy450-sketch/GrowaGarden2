-- ============================================================
--  W424HUB-GAG2 | V.3.0 (Kairo UI)
--  Grow a Garden 2 – All-in-One
-- ============================================================
print("=== LOADING W424HUB-GAG2 V.3.0 ===")

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")

-- ===== LOAD KAIRO UI =====
local Kairo = loadstring(game:HttpGet("https://raw.githubusercontent.com/Itzzavi335/Kairo-Ui-Library/refs/heads/main/source.luau"))()
if not Kairo then error("Kairo UI gagal dimuat") end

local Window = Kairo:CreateWindow({
    Title = "W424HUB-GAG2 | V.3.0",
    Theme = "Midnight",
    -- Cek ukuran layar device
local ScreenSize = workspace.CurrentCamera.ViewportSize
-- Hitung lebar (sisihkan 20px), dan tinggi (sisihkan 80px untuk tombol atas bawah Roblox)
local MobileWidth = math.clamp(ScreenSize.X - 20, 280, 400)
local MobileHeight = math.clamp(ScreenSize.Y - 80, 380, 480)

Size = UDim2.fromOffset(MobileWidth, MobileHeight),
    Center = true,
    Draggable = true,
    Resize = false,
    Badges = {"GAG2", "V.3.0"},
    MinimizeKey = Enum.KeyCode.RightShift,
    MinimizeButton = true,
    MinimizeButton_Image = "rbxassetid://116850882259653",
    Config = { Enabled = true, Folder = "W424HUB_GAG2", AutoLoad = true }
})

-- ============================================================
--  ITEM DATABASE
-- ============================================================
local SEEDS = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple",
    "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean",
    "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Poison Apple",
    "Venom Spitter", "Moon Bloom", "Hypno Bloom", "Dragon's Breath"
}

local GEARS = {
    "Common Watering Can", "Common Sprinkler", "Sign", "Uncommon Sprinkler",
    "Trowel", "Rare Sprinkler", "Jump Mushroom", "Speed Mushroom",
    "Lantern", "Shrink Mushroom", "Supersize Mushroom", "Gnome",
    "Flashbang", "Basic Pot", "Legendary Sprinkler", "Invisibility Mushroom",
    "Teleporter", "Wheelbarrow", "Super Watering Can", "Super Sprinkler"
}

local CRATES = {
    "Ladder Crate", "Bench Crate", "Light Crate", "Sign Crate",
    "Arch Crate", "Roleplay Crate", "Bridge Crate", "Spring Crate",
    "Seesaw Crate", "Conveyor Crate", "Owner Door Crate", "Bear Trap Crate",
    "Fence Crate", "Teleporter Pad Crate"
}

-- ============================================================
--  MODUL DAN FUNGSI INTI
-- ============================================================
local Networking, SeedData, FruitValueCalc, PlantLifecycleHandler, StealFlags

pcall(function()
    Networking = require(ReplicatedStorage.SharedModules.Networking)
end)
if not Networking then
    warn("⚠️ Networking module gagal dimuat, beberapa fitur mungkin gak jalan")
end

pcall(function()
    SeedData = require(ReplicatedStorage.SharedModules.SeedData)
end)
pcall(function()
    FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
end)
pcall(function()
    PlantLifecycleHandler = require(LocalPlayer.PlayerScripts.Controllers.PlantLifecycleHandler)
end)
pcall(function()
    StealFlags = require(ReplicatedStorage.SharedModules.Flags.StealFlags)
end)

local Gardens = Workspace:FindFirstChild("Gardens")
local Night = ReplicatedStorage:FindFirstChild("Night")

local function getMyPlot()
    if not Gardens then return nil end
    for _, plot in ipairs(Gardens:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.Name then return plot end
    end
    return nil
end

local function isNightTime()
    return Night and Night.Value == true
end

local function getChar() return LocalPlayer.Character end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end

local function teleportTo(targetCF, speed)
    speed = speed or 35
    local hrp = getHRP()
    if not hrp or not targetCF then return end
    local start = hrp.CFrame
    local dist = (targetCF.Position - start.Position).Magnitude
    if dist < 2 then return end
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

-- Helper function to check multiple selections
local function isSelected(items, name)
    if not items then return false end
    if type(items) == "table" then
        -- Kairo can pass arrays {1 = "Carrot"} or dicts {Carrot = true}
        for k, v in pairs(items) do
            if v == "All" or k == "All" then return true end
            if v == name or k == name then return true end
        end
        return false
    elseif type(items) == "string" then
        return items == "All" or items == name
    end
    return false
end

-- ============================================================
--  FUNGSI UTAMA
-- ============================================================
local Selected = {
    harvestItem = {},
    plantItem = {},
    buyItem = {},
}

local function harvestSpecific(items)
    local plot = getMyPlot()
    if not plot or not Networking then return 0 end
    local plants = plot:FindFirstChild("Plants")
    if not plants then return 0 end
    local count = 0
    
    for _, plant in ipairs(plants:GetChildren()) do
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            for _, fruit in ipairs(fruits:GetChildren()) do
                if fruit:IsA("Model") then
                    local seedName = fruit:GetAttribute("SeedName") or fruit:GetAttribute("CorePartName")
                    local shouldHarvest = isSelected(items, seedName)
                    
                    if shouldHarvest then
                        local age = fruit:GetAttribute("Age") or 0
                        local maxAge = fruit:GetAttribute("MaxAge") or 0
                        if age >= maxAge then
                            local pid = fruit:GetAttribute("PlantId")
                            local fid = fruit:GetAttribute("FruitId") or ""
                            if pid then
                                pcall(function() Networking.Garden.CollectFruit:Fire(pid, fid) end)
                                count = count + 1
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end
        else
            local seedName = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName")
            local shouldHarvest = isSelected(items, seedName)
            
            if shouldHarvest then
                local age = plant:GetAttribute("Age") or 0
                local maxAge = plant:GetAttribute("MaxAge") or 0
                if age >= maxAge then
                    local pid = plant:GetAttribute("PlantId")
                    if pid then
                        pcall(function() Networking.Garden.CollectFruit:Fire(pid, "") end)
                        count = count + 1
                        task.wait(0.05)
                    end
                end
            end
        end
    end
    return count
end

local function sellAll()
    if Networking then
        pcall(function() Networking.NPCS.SellAll:Fire() end)
    end
end

local function buySpecific(items)
    if not Networking then return end
    if isSelected(items, "All") then
        buyItems()
        return
    end
    
    pcall(function()
        local seedStock = ReplicatedStorage.StockValues.SeedShop.Items
        for _, item in ipairs(seedStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 and isSelected(items, item.Name) then
                Networking.SeedShop.PurchaseSeed:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local gearStock = ReplicatedStorage.StockValues.GearShop.Items
        for _, item in ipairs(gearStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 and isSelected(items, item.Name) then
                Networking.GearShop.PurchaseGear:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local crateStock = ReplicatedStorage.StockValues.CrateShop.Items
        for _, item in ipairs(crateStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 and isSelected(items, item.Name) then
                Networking.CrateShop.PurchaseCrate:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
end

local function buyItems()
    if not Networking then return end
    pcall(function()
        local seedStock = ReplicatedStorage.StockValues.SeedShop.Items
        for _, item in ipairs(seedStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 then
                Networking.SeedShop.PurchaseSeed:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local gearStock = ReplicatedStorage.StockValues.GearShop.Items
        for _, item in ipairs(gearStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 then
                Networking.GearShop.PurchaseGear:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local crateStock = ReplicatedStorage.StockValues.CrateShop.Items
        for _, item in ipairs(crateStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 then
                Networking.CrateShop.PurchaseCrate:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
end

-- Fixed Auto Plant Logic
local function plantSpecific(items)
    local plot = getMyPlot()
    if not plot or not Networking then return end
    
    local inv = LocalPlayer:GetAttribute("Inventory")
    if not inv or not inv.Seeds then return end
    local seeds = inv.Seeds

    local freeSpots = {}
    -- Lebih agresif nyari spot kosong
    local function addSpotsFromArea(area)
        local size = area.Size
        local step = 6
        for x = -size.X/2 + 3, size.X/2 - 3, step do
            for z = -size.Z/2 + 3, size.Z/2 - 3, step do
                local pos = area.CFrame * CFrame.new(x, 0.5, z)
                table.insert(freeSpots, pos.Position)
            end
        end
    end

    -- Cek di Plot langsung
    for _, area in ipairs(plot:GetDescendants()) do
        if area:IsA("BasePart") and (area.Name == "PlantArea" or area.Name == "Soil") then
            addSpotsFromArea(area)
        end
    end
    -- Cek via CollectionService
    for _, area in ipairs(CollectionService:GetTagged("PlantArea")) do
        if area:IsDescendantOf(plot) then
            addSpotsFromArea(area)
        end
    end

    if #freeSpots == 0 then return end

    local planted = 0
    for seed, count in pairs(seeds) do
        if count > 0 and planted < 40 then
            local shouldPlant = isSelected(items, seed)
            
            if shouldPlant then
                for i = 1, math.min(count, 5) do
                    if planted >= #freeSpots then break end
                    local pos = freeSpots[planted + 1]
                    pcall(function()
                        Networking.Plant.PlantSeed:Fire(pos, seed, plot)
                    end)
                    planted = planted + 1
                    task.wait(0.1)
                end
            end
        end
    end
end

local function openItems(category)
    if not Networking then return end
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

local function performSteal()
    if not isNightTime() or not Networking then return end
    local target = nil
    for _, plot in ipairs(Gardens:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local fruits = plant:FindFirstChild("Fruits")
                if fruits then
                    for _, fruit in ipairs(fruits:GetChildren()) do
                        if fruit:IsA("Model") then
                            local seedName = fruit:GetAttribute("SeedName") or fruit:GetAttribute("CorePartName")
                            if seedName and StealFlags and StealFlags.IsPlantStealable and StealFlags.IsPlantStealable(seedName) then
                                local ownerId = fruit:GetAttribute("UserId")
                                if ownerId then
                                    local owner = Players:GetPlayerByUserId(tonumber(ownerId))
                                    if owner and owner ~= LocalPlayer and not owner:GetAttribute("IsInOwnGarden") then
                                        target = fruit
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                if target then break end
            end
        end
        if target then break end
    end
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
    pcall(function()
        Networking.Steal.BeginSteal:Fire(tonumber(ownerId), plantId, fruitId)
    end)
    task.wait(0.1)
    pcall(function()
        Networking.Steal.CompleteSteal:Fire()
    end)
    task.wait(0.5)
    teleportTo(home, 33)
end

-- ============================================================
--  STATE
-- ============================================================
local S = {
    autoHarvest = false,
    autoSell = false,
    autoSteal = false,
    autoBuy = false,
    autoPlant = false,
    sellInterval = 60,
    stealInterval = 5,
    plantInterval = 10,
    buyInterval = 30,
    antiAfk = true,
    optimize = false,
}

-- Safe Number Input Function
local function AddNumberInput(tab, title, desc, default, callback, flag)
    if Window.AddInput then
        Window:AddInput(tab, title, desc, tostring(default), function(v)
            local num = tonumber(v)
            if num then callback(num) else callback(default) end
        end, flag)
    elseif Window.AddTextbox then
        Window:AddTextbox(tab, title, desc, tostring(default), function(v)
            local num = tonumber(v)
            if num then callback(num) else callback(default) end
        end, flag)
    else
        warn("Kairo UI does not support Input Boxes. Using default for " .. title)
        callback(default)
    end
end

-- ============================================================
--  UI – KAIRO (FULLY WORKING)
-- ============================================================

-- ===== TAB: FARM =====
local FarmTab = Window:CreateTab("Farm", "rbxassetid://16932740082")

Window:AddParagraph(FarmTab, "Auto Farm", "Panen & Tanam Otomatis")

Window:AddToggle(FarmTab, "Auto Harvest", "Panen otomatis tanpa jeda", false, function(v)
    S.autoHarvest = v
end, "AutoHarvest")

Window:AddToggle(FarmTab, "Auto Sell", "Jual semua buah otomatis", false, function(v)
    S.autoSell = v
end, "AutoSell")

AddNumberInput(FarmTab, "Sell Interval", "Jeda antar jual (detik)", 60, function(v)
    S.sellInterval = v
end, "SellInterval")

Window:AddToggle(FarmTab, "Auto Plant", "Tanam bibit dari inventory", false, function(v)
    S.autoPlant = v
end, "AutoPlant")

AddNumberInput(FarmTab, "Plant Interval", "Jeda antar tanam (detik)", 10, function(v)
    S.plantInterval = v
end, "PlantInterval")

-- Dropdown Harvest Item (MULTIPLE CHOICE)
local harvestOptions = {"All"}
for _, seed in ipairs(SEEDS) do table.insert(harvestOptions, seed) end

Window:AddDropdown(FarmTab, "Harvest Item", "Pilih tanaman (Bisa lebih dari 1)", harvestOptions, true, {}, function(v)
    Selected.harvestItem = v
end, "HarvestItem")

-- Dropdown Plant Item (MULTIPLE CHOICE)
local plantOptions = {"All"}
for _, seed in ipairs(SEEDS) do table.insert(plantOptions, seed) end

Window:AddDropdown(FarmTab, "Plant Item", "Pilih bibit (Bisa lebih dari 1)", plantOptions, true, {}, function(v)
    Selected.plantItem = v
end, "PlantItem")

Window:AddButton(FarmTab, "Harvest Now", "Panen sekali sekarang", "rbxassetid://16932740082", function()
    local count = harvestSpecific(Selected.harvestItem)
    Window:Notify({Title = "Harvest", Description = "Panen " .. count .. " tanaman", Content = "Selesai", Color = Color3.fromRGB(0,200,100), Delay = 2})
end)

Window:AddButton(FarmTab, "Sell Now", "Jual semua sekarang", "rbxassetid://16932740082", function()
    sellAll()
    Window:Notify({Title = "Sell", Description = "Semua terjual!", Content = "", Color = Color3.fromRGB(255,200,0), Delay = 2})
end)

Window:AddButton(FarmTab, "Plant Now", "Tanam sekali sekarang", "rbxassetid://16932740082", function()
    plantSpecific(Selected.plantItem)
    Window:Notify({Title = "Plant", Description = "Menanam bibit terpilih", Content = "", Color = Color3.fromRGB(0,200,50), Delay = 2})
end)

-- ===== TAB: SHOP =====
local ShopTab = Window:CreateTab("Shop", "rbxassetid://16932740082")

Window:AddParagraph(ShopTab, "Auto Shop", "Beli & Buka Item")

Window:AddToggle(ShopTab, "Auto Buy", "Beli item otomatis", false, function(v)
    S.autoBuy = v
end, "AutoBuy")

AddNumberInput(ShopTab, "Buy Interval", "Jeda antar beli (detik)", 30, function(v)
    S.buyInterval = v
end, "BuyInterval")

-- Dropdown Buy Item (MULTIPLE CHOICE)
local buyOptions = {"All"}
for _, seed in ipairs(SEEDS) do table.insert(buyOptions, seed) end
for _, gear in ipairs(GEARS) do table.insert(buyOptions, gear) end
for _, crate in ipairs(CRATES) do table.insert(buyOptions, crate) end

Window:AddDropdown(ShopTab, "Buy Item", "Pilih item (Bisa lebih dari 1)", buyOptions, true, {}, function(v)
    Selected.buyItem = v
end, "BuyItem")

Window:AddButton(ShopTab, "Buy Now", "Beli sekarang", "rbxassetid://16932740082", function()
    buySpecific(Selected.buyItem)
    Window:Notify({Title = "Buy", Description = "Membeli item terpilih", Content = "", Color = Color3.fromRGB(0,150,255), Delay = 2})
end)

Window:AddDivider(ShopTab, "")

Window:AddButton(ShopTab, "Open All Eggs", "Buka semua telur", "rbxassetid://16932740082", function()
    openItems("Eggs")
    Window:Notify({Title = "Open", Description = "Semua telur dibuka!", Content = "", Color = Color3.fromRGB(255,150,0), Delay = 2})
end)

Window:AddButton(ShopTab, "Open All Crates", "Buka semua crate", "rbxassetid://16932740082", function()
    openItems("Crates")
    Window:Notify({Title = "Open", Description = "Semua crate dibuka!", Content = "", Color = Color3.fromRGB(255,150,0), Delay = 2})
end)

Window:AddButton(ShopTab, "Open All Seed Packs", "Buka semua seed pack", "rbxassetid://16932740082", function()
    openItems("SeedPacks")
    Window:Notify({Title = "Open", Description = "Semua seed pack dibuka!", Content = "", Color = Color3.fromRGB(255,150,0), Delay = 2})
end)

-- ===== TAB: STEAL =====
local StealTab = Window:CreateTab("Steal", "rbxassetid://16932740082")

Window:AddParagraph(StealTab, "Auto Steal", "Curi buah saat malam")

Window:AddToggle(StealTab, "Auto Steal", "Curi otomatis saat malam", false, function(v)
    S.autoSteal = v
end, "AutoSteal")

AddNumberInput(StealTab, "Steal Interval", "Jeda antar curi (detik)", 5, function(v)
    S.stealInterval = v
end, "StealInterval")

Window:AddButton(StealTab, "Steal Now", "Coba curi sekali sekarang", "rbxassetid://16932740082", function()
    performSteal()
    Window:Notify({Title = "Steal", Description = "Mencoba mencuri...", Content = "", Color = Color3.fromRGB(150,100,255), Delay = 2})
end)

-- ===== TAB: MISC =====
local MiscTab = Window:CreateTab("Misc", "rbxassetid://16932740082")

Window:AddParagraph(MiscTab, "Lainnya", "Fitur tambahan")

Window:AddToggle(MiscTab, "Anti-AFK", "Cegah idle kick", true, function(v)
    S.antiAfk = v
end, "AntiAfk")

Window:AddToggle(MiscTab, "Optimize (FPS)", "Kurangi grafis untuk FPS tinggi", false, function(v)
    S.optimize = v
    if v then
        Lighting.GlobalShadows = false
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, e in ipairs(Lighting:GetDescendants()) do
            if e:IsA("PostEffect") or e:IsA("Atmosphere") then
                pcall(function() e.Enabled = false end)
            end
        end
    else
        Lighting.GlobalShadows = true
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end
end, "Optimize")

Window:AddButton(MiscTab, "Unload Script", "Hapus UI dan stop script", "rbxassetid://16932740082", function()
    Window:Destroy()
end)

-- ============================================================
--  MAIN LOOPS
-- ============================================================

task.spawn(function()
    while true do
        task.wait(1) -- Fixed fast loop for Auto Harvest
        if S.autoHarvest then
            harvestSpecific(Selected.harvestItem)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.sellInterval or 60)
        if S.autoSell then
            sellAll()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.plantInterval or 10)
        if S.autoPlant then
            plantSpecific(Selected.plantItem)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.buyInterval or 30)
        if S.autoBuy then
            buySpecific(Selected.buyItem)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.stealInterval or 5)
        if S.autoSteal and isNightTime() then
            performSteal()
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if S.antiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

Window:Notify({
    Title = "W424HUB-GAG2",
    Description = "V.3.0 – Grow a Garden 2",
    Content = "Press RightShift to toggle",
    Color = Color3.fromRGB(30, 30, 60),
    Delay = 5
})

print("✅ W424HUB-GAG2 V.3.0 (Kairo UI) loaded!")
