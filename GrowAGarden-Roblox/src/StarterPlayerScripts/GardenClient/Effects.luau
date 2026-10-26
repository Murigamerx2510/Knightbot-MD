-- Effects: efeitos visuais so do cliente.
--  * frutos Arco-iris trocando de cor
--  * chuva/neve/relampagos
--  * pets seguindo os jogadores
--  * esconder os botoes "Colher" dos jardins de outros jogadores
--  * dica ao passar o mouse nas plantas

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))

local Effects = {}

local player = Players.LocalPlayer

local function localPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, sphere: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = cf
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

---------------------------------------------------------------------
-- Arco-iris
---------------------------------------------------------------------

local function startRainbow()
	RunService.Heartbeat:Connect(function()
		local hue = (os.clock() * 0.25) % 1
		for index, part in CollectionService:GetTagged("RainbowFruit") do
			if part:IsA("BasePart") then
				part.Color = Color3.fromHSV((hue + index * 0.07) % 1, 0.75, 1)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Clima
---------------------------------------------------------------------

local function startWeather()
	local holder = localPart(workspace, "ClimaLocal", Vector3.new(120, 1, 120), CFrame.new(0, 100, 0), Color3.new(1, 1, 1), false)
	holder.Transparency = 1

	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Chuva"
	rain.Enabled = false
	rain.Rate = 500
	rain.Lifetime = NumberRange.new(1, 1.3)
	rain.Speed = NumberRange.new(60, 70)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Size = NumberSequence.new(0.18)
	rain.Squash = NumberSequence.new(2.5)
	rain.Transparency = NumberSequence.new(0.25)
	rain.Color = ColorSequence.new(Color3.fromRGB(175, 205, 255))
	rain.LightEmission = 0.3
	rain.Parent = holder

	local snow = Instance.new("ParticleEmitter")
	snow.Name = "Neve"
	snow.Enabled = false
	snow.Rate = 160
	snow.Lifetime = NumberRange.new(6, 8)
	snow.Speed = NumberRange.new(5, 9)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(25, 25)
	snow.Acceleration = Vector3.new(1, -1, 0)
	snow.Size = NumberSequence.new(0.35)
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.LightEmission = 0.5
	snow.RotSpeed = NumberRange.new(-90, 90)
	snow.Parent = holder

	local function apply()
		local weather = workspace:GetAttribute("Weather")
		rain.Enabled = weather == "Rain" or weather == "Thunderstorm"
		snow.Enabled = weather == "Frost"
	end
	workspace:GetAttributeChangedSignal("Weather"):Connect(apply)
	apply()

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
		end
	end)

	-- clarao quando cai um raio
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ClaraoLocal"
	flash.Brightness = 0
	flash.Parent = Lighting
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Raio" then
			flash.Brightness = 0.45
			TweenService:Create(flash, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		end
	end)
end

---------------------------------------------------------------------
-- Pets
---------------------------------------------------------------------

local PET_OFFSETS = {
	Vector3.new(-2.8, 0, 3),
	Vector3.new(2.8, 0, 3),
	Vector3.new(0, 0, 5),
}

local function buildPet(info): Model
	local model = Instance.new("Model")
	model.Name = info.name
	local s = info.size
	local body = localPart(model, "Corpo", Vector3.new(1.4, 1.1, 1.6) * s, CFrame.new(), info.color, true)
	localPart(model, "Cabeca", Vector3.new(1.1, 1.1, 1.1) * s, CFrame.new(0, 0.55 * s, -0.85 * s), info.color, true)
	for _, x in { -0.22, 0.22 } do
		localPart(model, "Olho", Vector3.new(0.18, 0.22, 0.12) * s, CFrame.new(x * s, 0.68 * s, -1.38 * s), Color3.fromRGB(20, 20, 20), true)
	end
	localPart(model, "Nariz", Vector3.new(0.22, 0.18, 0.12) * s, CFrame.new(0, 0.45 * s, -1.4 * s), info.accent, true)
	local earSize = if info.id == "Bunny" then Vector3.new(0.22, 0.9, 0.14) else Vector3.new(0.28, 0.45, 0.16)
	for _, x in { -0.3, 0.3 } do
		localPart(model, "Orelha", earSize * s, CFrame.new(x * s, (1.05 + earSize.Y * 0.3) * s, -0.8 * s), info.accent, false)
	end
	localPart(model, "Rabo", Vector3.new(0.4, 0.4, 0.4) * s, CFrame.new(0, 0.2 * s, 0.85 * s), info.accent, true)
	if info.id == "Unicorn" then
		local horn = localPart(model, "Chifre", Vector3.new(0.15, 0.7, 0.15) * s, CFrame.new(0, 1.3 * s, -1.05 * s) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(255, 220, 90), false)
		horn.Material = Enum.Material.Neon
	end
	if info.id == "Dragon" or info.id == "Phoenix" or info.id == "Owl" or info.id == "Chicken" then
		for _, side in { -1, 1 } do
			localPart(model, "Asa", Vector3.new(1.2, 0.12, 0.8) * s, CFrame.new(side * 0.95 * s, 0.35 * s, 0) * CFrame.Angles(0, 0, side * math.rad(25)), info.accent, false)
		end
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 24)
	gui.StudsOffset = Vector3.new(0, 1.6 * s, 0)
	gui.MaxDistance = 50
	gui.Adornee = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Config.Rarities[info.rarity].color
	label.TextStrokeTransparency = 0.3
	label.Text = info.name
	label.Parent = gui
	gui.Parent = model
	return model
end

local function startPets()
	local folder = Instance.new("Folder")
	folder.Name = "PetsLocais"
	folder.Parent = workspace
	local followers: { [Player]: { key: string, models: { Model }, current: { CFrame } } } = {}

	local function rebuild(owner: Player)
		local old = followers[owner]
		if old then
			for _, model in old.models do
				model:Destroy()
			end
			followers[owner] = nil
		end
		local key = owner:GetAttribute("EquippedPets")
		if type(key) ~= "string" or key == "" then
			return
		end
		local entry = { key = key, models = {}, current = {} }
		for _, petId in string.split(key, ",") do
			local info = Config.Pets[petId]
			if info and #entry.models < #PET_OFFSETS then
				local model = buildPet(info)
				model.Parent = folder
				table.insert(entry.models, model)
			end
		end
		followers[owner] = entry
	end

	local function watch(owner: Player)
		owner:GetAttributeChangedSignal("EquippedPets"):Connect(function()
			rebuild(owner)
		end)
		rebuild(owner)
	end

	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner)
		local entry = followers[owner]
		if entry then
			for _, model in entry.models do
				model:Destroy()
			end
			followers[owner] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for owner, entry in followers do
			local character = owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local rootCF = root.CFrame
				local flat = CFrame.lookAt(rootCF.Position, rootCF.Position + Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z + 1e-4))
				for index, model in entry.models do
					local offset = PET_OFFSETS[index]
					local bob = math.sin(t * 5 + index) * 0.2
					local target = flat * CFrame.new(offset.X, -2.3 + bob, offset.Z)
					local current = entry.current[index] or target
					current = current:Lerp(target, math.min(1, dt * 7))
					entry.current[index] = current
					model:PivotTo(current)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Botoes "Colher" so no seu jardim
---------------------------------------------------------------------

local function startPromptFilter()
	local function check(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			local owner = instance:GetAttribute("OwnerUserId")
			if type(owner) == "number" and owner ~= 0 and owner ~= player.UserId then
				instance.Enabled = false
			end
		end
	end
	workspace.DescendantAdded:Connect(check)
	for _, descendant in workspace:GetDescendants() do
		check(descendant)
	end
end

---------------------------------------------------------------------
-- Dica ao passar o mouse
---------------------------------------------------------------------

local function describe(target: Instance): string?
	local fruitModel: Instance? = nil
	local plantModel: Instance? = nil
	local node: Instance? = target
	while node and node ~= workspace do
		if node:IsA("Model") then
			if node:GetAttribute("SeedId") ~= nil then
				plantModel = node
				break
			elseif fruitModel == nil and node:GetAttribute("Weight") ~= nil then
				fruitModel = node
			end
		end
		node = node.Parent
	end
	if not plantModel then
		return nil
	end
	local seed = Config.Seeds[plantModel:GetAttribute("SeedId")]
	if not seed then
		return nil
	end
	local source = fruitModel or plantModel
	local lines = { seed.name }
	local weight = source:GetAttribute("Weight")
	if type(weight) == "number" then
		lines[1] = seed.name .. " • " .. Formulas.formatWeight(weight)
	end
	local mutations = source:GetAttribute("Mutations")
	if type(mutations) == "string" and mutations ~= "" then
		table.insert(lines, "✨ " .. mutations)
	end
	if source:GetAttribute("Ripe") then
		table.insert(lines, "Pronto! Aperte E para colher")
	elseif fruitModel then
		table.insert(lines, "Fruto crescendo...")
	else
		local progress = plantModel:GetAttribute("Progress")
		if type(progress) == "number" and progress >= 100 then
			table.insert(lines, "Produzindo frutos")
		else
			table.insert(lines, "Crescendo: " .. tostring(progress or 0) .. "%")
		end
	end
	return table.concat(lines, "\n")
end

local function startTooltip(interface)
	local mouse = player:GetMouse()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local target = mouse.Target
		local message = if target and not interface.isPanelOpen() then describe(target) else nil
		interface.setTooltip(message, mouse.X, mouse.Y)
	end)
end

function Effects.start(interface)
	startRainbow()
	startWeather()
	startPets()
	startPromptFilter()
	startTooltip(interface)
end

return Effects
