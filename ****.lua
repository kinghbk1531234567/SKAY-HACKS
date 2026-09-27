-- SKAY

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
assert(LP, "Run this on the client.")

local previous = _G.TrapBuildJob
if type(previous) == "table" and type(previous.close) == "function" then
    pcall(previous.close)
end

_G.TrapBuildJob = nil
_G.InfiniteRampJob = nil
_G.TrapSupportJob = nil

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "SKAY",
    LoadingTitle = "SKAY",
    LoadingSubtitle = "Building, weapons and movement",
    ShowText = "SKAY",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = true,
    KeySettings = {
        Title = "SKAY",
        Subtitle = "Password Required",
        Note = "Enter the password to open the panel.",
        FileName = "SKAY_Password",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"Fortnite67!"},
    },
})

local job = {
    active = true,
    auto = true,
    interval = 10,
    nextDue = 0,
    pending = false,
    busy = false,
    epoch = 0,
    lastSent = 0,
    totalSent = 0,
}
_G.TrapBuildJob = job

local killState = {
    auto = false,
    pending = false,
    busy = false,
    interval = 2,
    nextDue = 0,
    epoch = 0,
}

local flags = {
    silentAim = false,
    infiniteAmmo = false,
    noRecoil = false,
    noSpread = false,
    fastFire = false,
    autoGuns = false,
    esp = false,
    noclip = false,
    jump = false,
    speed = false,
    fly = false,
    infiniteJump = false,
}

local jumpPower, walkSpeed, flySpeed, flingPower = 100, 60, 80, 150
local BaseWeapon, flight, trackedCharacter
local speedHumanoid, savedWalkSpeed, lastTeleport
local hooks, connections, espObjects = {}, {}, {}
local savedCollisions, movementToggles, waypoints = {}, {}, {}

local espFolder = Instance.new("Folder")
espFolder.Name = "SKAY_ESP"
espFolder.Parent = workspace

local function alive()
    return job.active and _G.TrapBuildJob == job
end

local function notify(message)
    if alive() then
        Rayfield:Notify({
            Title = "SKAY",
            Content = tostring(message),
            Duration = 5,
        })
    end
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end

local function characterParts()
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health <= 0
        or not root or not root:IsA("BasePart") then
        return nil
    end

    return character, humanoid, root
end

local function stopBuilding()
    job.auto = false
    job.pending = false
    job.epoch = job.epoch + 1
end

local function stopKillall()
    killState.auto = false
    killState.pending = false
    killState.epoch = killState.epoch + 1
end

local function removeESP(player)
    local entry = espObjects[player]
    if not entry then return end

    entry.highlight:Destroy()
    entry.billboard:Destroy()
    espObjects[player] = nil
end

local function clearESP()
    for player in pairs(espObjects) do
        removeESP(player)
    end
end

local function restoreCollisions()
    for part, value in pairs(savedCollisions) do
        if part.Parent then
            pcall(function()
                part.CanCollide = value
            end)
        end
    end

    table.clear(savedCollisions)
    trackedCharacter = nil
end

local function restoreSpeed()
    if speedHumanoid and speedHumanoid.Parent and savedWalkSpeed ~= nil then
        pcall(function()
            speedHumanoid.WalkSpeed = savedWalkSpeed
        end)
    end

    speedHumanoid, savedWalkSpeed = nil, nil
end
