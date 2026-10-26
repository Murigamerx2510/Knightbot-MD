-- Visuals: constroi os modelos 3D de plantas, frutos, sprinklers e ovos.
--
-- Modelos feitos no Blender: importe-os para ReplicatedStorage/Modelos com os nomes
--   Planta_<IdDaSemente>  (ex.: Planta_Carrot)  -> corpo da planta
--   Fruto_<IdDaSemente>   (ex.: Fruto_Apple)    -> fruto de plantas de varias colheitas
--   Sprinkler_<IdDoItem>  (ex.: Sprinkler_BasicSprinkler)
--   Ovo_<IdDoOvo>         (ex.: Ovo_CommonEgg)
-- Se o modelo nao existir, o jogo cria um modelo com Parts automaticamente.
-- Partes cujo nome contem "Produto" mudam de cor com as mutacoes.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Visuals = {}

local STEM_COLOR = Color3.fromRGB(85, 140, 60)
local WOOD_COLOR = Color3.fromRGB(115, 78, 48)
local WHITE = Color3.fromRGB(255, 255, 255)

-- Mutacoes de clima so "tingem" a cor original do fruto
local BLEND = { Wet = 0.45, Chilled = 0.55 }

local function basePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
	return part
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return basePart(parent, name, size, cf, color)
end

-- Elipsoide (bola que pode ser esticada)
local function sphere(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local part = basePart(parent, name, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cilindro em pe (eixo vertical) centrado em cf
local function cylinder(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3): Part
	return basePart(parent, name, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder)
end

local function markProduce(part: BasePart)
	part:SetAttribute("Produce", true)
	part:SetAttribute("BaseColor", part.Color)
	part:SetAttribute("BaseMaterial", part.Material.Name)
end

Visuals.block = block
Visuals.sphere = sphere
Visuals.cylinder = cylinder

---------------------------------------------------------------------
-- Modelos importados (Blender)
---------------------------------------------------------------------

local function findLibraryModel(name: string): Instance?
	local library = ReplicatedStorage:FindFirstChild("Modelos")
	if not library then
		return nil
	end
	return library:FindFirstChild(name)
end

local function prepareModel(source: Instance): Model?
	local clone = source:Clone()
	local model: Model
	if clone:IsA("Model") then
		model = clone
	elseif clone:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = clone.Name
		clone.Parent = model
	else
		clone:Destroy()
		return nil
	end
	local firstPart: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			if not firstPart then
				firstPart = descendant
			end
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	if not firstPart then
		model:Destroy()
		return nil
	end
	if not model.PrimaryPart then
		model.PrimaryPart = firstPart
	end
	return model
end

-- Ajusta a altura do modelo e coloca o pivot na base (baseAtBottom) ou no centro
local function normalize(model: Model, targetSize: number, useHeight: boolean, baseAtBottom: boolean)
	local _, size = model:GetBoundingBox()
	local current = if useHeight then size.Y else math.max(size.X, size.Y, size.Z)
	if current > 0.001 and targetSize > 0 then
		model:ScaleTo(model:GetScale() * (targetSize / current))
	end
	local cf, newSize = model:GetBoundingBox()
	local pivot = if baseAtBottom then cf.Position - Vector3.new(0, newSize.Y / 2, 0) else cf.Position
	model.WorldPivot = CFrame.new(pivot)
	model:PivotTo(CFrame.new())
end

local function fromLibrary(name: string, targetSize: number, useHeight: boolean, baseAtBottom: boolean): Model?
	local source = findLibraryModel(name)
	if not source then
		return nil
	end
	local model = prepareModel(source)
	if not model then
		return nil
	end
	normalize(model, targetSize, useHeight, baseAtBottom)
	return model
end

---------------------------------------------------------------------
-- Plantas feitas com Parts
---------------------------------------------------------------------

local builders = {}

function builders.root(model: Model, seed)
	local h, fs = seed.height, seed.fruitSize
	markProduce(sphere(model, "Produto", fs, CFrame.new(0, fs.Y * 0.15, 0), seed.fruitColor))
	for i = 1, 3 do
		local angle = i * (math.pi * 2 / 3)
		local cf = CFrame.new(0, fs.Y * 0.55, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(18), 0, 0) * CFrame.new(0, h * 0.3, 0)
		block(model, "Folha", Vector3.new(0.15, h * 0.6, 0.4), cf, seed.leafColor)
	end
end

function builders.bush(model: Model, seed)
	local h = seed.height
	cylinder(model, "Caule", h * 0.3, 0.25, CFrame.new(0, h * 0.15, 0), STEM_COLOR)
	sphere(model, "Folhagem", Vector3.new(h * 0.85, h * 0.65, h * 0.85), CFrame.new(0, h * 0.5, 0), seed.leafColor)
	sphere(model, "Folhagem", Vector3.new(h * 0.5, h * 0.45, h * 0.5), CFrame.new(h * 0.2, h * 0.72, -h * 0.1), seed.leafColor:Lerp(WHITE, 0.08))
	sphere(model, "Folhagem", Vector3.new(h * 0.45, h * 0.4, h * 0.45), CFrame.new(-h * 0.22, h * 0.62, h * 0.15), seed.leafColor:Lerp(WHITE, 0.04))
end

function builders.flower(model: Model, seed)
	local h, fs = seed.height, seed.fruitSize
	cylinder(model, "Caule", h * 0.75, 0.18, CFrame.new(0, h * 0.375, 0), STEM_COLOR)
	for i = 1, 2 do
		local cf = CFrame.new(0, h * 0.12, 0) * CFrame.Angles(0, i * math.pi, 0) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, h * 0.18, 0)
		block(model, "Folha", Vector3.new(0.12, h * 0.4, 0.5), cf, seed.leafColor)
	end
	local headY = h * 0.75 + fs.Y * 0.4
	markProduce(sphere(model, "Produto", fs * 0.8, CFrame.new(0, headY, 0), seed.fruitColor))
	for i = 1, 4 do
		local cf = CFrame.new(0, headY, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, fs.Z * 0.32) * CFrame.Angles(math.rad(-15), 0, 0)
		markProduce(sphere(model, "Produto", Vector3.new(fs.X * 0.6, fs.Y, fs.Z * 0.3), cf, seed.fruitColor))
	end
end

function builders.tall(model: Model, seed)
	local h = seed.height
	cylinder(model, "Caule", h, 0.35, CFrame.new(0, h / 2, 0), seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.15))
	for i = 1, 4 do
		local y = h * (0.25 + 0.12 * i)
		local cf = CFrame.new(0, y, 0) * CFrame.Angles(0, i * 1.7, 0) * CFrame.Angles(math.rad(40), 0, 0) * CFrame.new(0, h * 0.2, 0)
		block(model, "Folha", Vector3.new(0.1, h * 0.42, 0.45), cf, seed.leafColor)
	end
	block(model, "Pendao", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, h + 0.3, 0), Color3.fromRGB(230, 200, 120))
end

function builders.ground(model: Model, seed)
	local fs = seed.fruitSize
	markProduce(sphere(model, "Produto", fs, CFrame.new(0, fs.Y / 2, 0), seed.fruitColor))
	cylinder(model, "Cabo", 0.5, 0.22, CFrame.new(0, fs.Y + 0.15, 0), Color3.fromRGB(100, 120, 50))
	for i = 1, 3 do
		local cf = CFrame.Angles(0, i * 2.1, 0) * CFrame.new(fs.X * 0.6, 0.1, 0)
		sphere(model, "Folha", Vector3.new(1.4, 0.15, 1), cf, seed.leafColor)
	end
end

function builders.tree(model: Model, seed)
	local h = seed.height
	local trunk = cylinder(model, "Tronco", h * 0.55, h * 0.11, CFrame.new(0, h * 0.275, 0), WOOD_COLOR)
	trunk.Material = Enum.Material.Wood
	sphere(model, "Copa", Vector3.new(h * 0.75, h * 0.55, h * 0.75), CFrame.new(0, h * 0.68, 0), seed.leafColor)
	sphere(model, "Copa", Vector3.new(h * 0.45, h * 0.4, h * 0.45), CFrame.new(h * 0.22, h * 0.82, 0), seed.leafColor:Lerp(WHITE, 0.07))
	sphere(model, "Copa", Vector3.new(h * 0.42, h * 0.38, h * 0.42), CFrame.new(-h * 0.2, h * 0.78, h * 0.15), seed.leafColor:Lerp(WHITE, 0.03))
end

function builders.stalk(model: Model, seed)
	local fs = seed.fruitSize
	local segments = 4
	local segmentHeight = fs.Y / segments
	for i = 1, segments do
		markProduce(cylinder(model, "Produto", segmentHeight * 0.95, fs.X, CFrame.new(0, segmentHeight * (i - 0.5), 0), seed.fruitColor))
		markProduce(cylinder(model, "ProdutoNo", 0.12, fs.X * 1.15, CFrame.new(0, segmentHeight * i, 0), seed.fruitColor:Lerp(Color3.new(0, 0, 0), 0.2)))
	end
	for i = 1, 3 do
		local cf = CFrame.new(0, fs.Y * 0.85, 0) * CFrame.Angles(0, i * 2.1, 0) * CFrame.Angles(math.rad(55), 0, 0) * CFrame.new(0, 0.6, 0)
		block(model, "Folha", Vector3.new(0.08, 1.2, 0.35), cf, seed.leafColor)
	end
end

function builders.palm(model: Model, seed)
	local h = seed.height
	local segments = 5
	local topY = h * 0.85
	for i = 1, segments do
		local trunk = cylinder(model, "Tronco", topY / segments * 1.02, 0.55 - i * 0.03, CFrame.new(0, topY / segments * (i - 0.5), 0), WOOD_COLOR:Lerp(WHITE, (i % 2) * 0.08))
		trunk.Material = Enum.Material.Wood
	end
	for i = 1, 6 do
		local cf = CFrame.new(0, topY, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -h * 0.2)
		block(model, "Folha", Vector3.new(0.9, 0.12, h * 0.42), cf, seed.leafColor)
	end
end

function builders.cactus(model: Model, seed)
	local h = seed.height
	local color = seed.leafColor
	cylinder(model, "Corpo", h * 0.75, h * 0.25, CFrame.new(0, h * 0.375, 0), color)
	sphere(model, "Topo", Vector3.new(h * 0.25, h * 0.25, h * 0.25), CFrame.new(0, h * 0.75, 0), color)
	for _, side in { 1, -1 } do
		local armY = if side == 1 then h * 0.4 else h * 0.5
		cylinder(model, "Braco", h * 0.18, h * 0.13, CFrame.new(side * h * 0.17, armY, 0) * CFrame.Angles(0, 0, math.pi / 2), color)
		cylinder(model, "Braco", h * 0.22, h * 0.13, CFrame.new(side * h * 0.25, armY + h * 0.1, 0), color)
		sphere(model, "Braco", Vector3.new(h * 0.13, h * 0.13, h * 0.13), CFrame.new(side * h * 0.25, armY + h * 0.21, 0), color)
	end
end

function builders.mushroom(model: Model, seed)
	local h, fs = seed.height, seed.fruitSize
	cylinder(model, "Caule", h * 0.5, 0.7, CFrame.new(0, h * 0.25, 0), seed.leafColor)
	local capY = h * 0.5 + fs.Y * 0.25
	markProduce(sphere(model, "Produto", fs, CFrame.new(0, capY, 0), seed.fruitColor))
	for i = 1, 5 do
		local cf = CFrame.new(0, capY, 0) * CFrame.Angles(0, i * 1.25, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, fs.Y * 0.46, 0)
		sphere(model, "Pinta", Vector3.new(0.35, 0.12, 0.35), cf, WHITE)
	end
end

function builders.beanstalk(model: Model, seed)
	local h = seed.height
	local segments = 8
	local segmentHeight = h / segments
	for i = 1, segments do
		local x = math.cos(i * 0.8) * 0.3
		local z = math.sin(i * 0.8) * 0.3
		cylinder(model, "Caule", segmentHeight * 1.1, 0.5, CFrame.new(x, segmentHeight * (i - 0.5), z), seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.1))
		local leafCF = CFrame.new(x, segmentHeight * (i - 0.3), z) * CFrame.Angles(0, i * 1.9, 0) * CFrame.new(0.6, 0, 0)
		sphere(model, "Folha", Vector3.new(1, 0.12, 0.6), leafCF, seed.leafColor)
	end
	for i = 1, 4 do
		local cf = CFrame.new(0, h + 0.4, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0.7, 0, 0)
		sphere(model, "Nuvem", Vector3.new(1.4, 0.9, 1.2), cf, WHITE)
	end
end

-- Marca as partes "Produto" de um modelo importado (se nao houver nenhuma e
-- markAllIfNone for true, o modelo inteiro conta como fruto)
local function markLibraryProduce(model: Model, markAllIfNone: boolean)
	local found = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "produto", 1, true) then
			markProduce(descendant)
			found = true
		end
	end
	if not found and markAllIfNone then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				markProduce(descendant)
			end
		end
	end
end

-- Constroi o corpo de uma planta (pivot na base)
function Visuals.buildPlant(seed): Model
	local model = fromLibrary("Planta_" .. seed.id, seed.height, true, true)
	if model then
		model.Name = "Corpo"
		markLibraryProduce(model, not seed.multiHarvest)
		return model
	end
	model = Instance.new("Model")
	model.Name = "Corpo"
	local builder = builders[seed.plantType] or builders.bush
	builder(model, seed)
	model.WorldPivot = CFrame.new()
	return model
end

-- Constroi um fruto (pivot no centro)
function Visuals.buildFruit(seed): Model
	local fs = seed.fruitSize
	local model = fromLibrary("Fruto_" .. seed.id, math.max(fs.X, fs.Y, fs.Z), false, false)
	if model then
		model.Name = "Fruto"
		markLibraryProduce(model, true)
		return model
	end
	model = Instance.new("Model")
	model.Name = "Fruto"
	local main = sphere(model, "Produto", fs, CFrame.new(), seed.fruitColor)
	markProduce(main)
	block(model, "Cabo", Vector3.new(0.1, 0.25, 0.1), CFrame.new(0, fs.Y / 2 + 0.08, 0), STEM_COLOR)
	model.PrimaryPart = main
	model.WorldPivot = CFrame.new()
	return model
end

-- Posicoes dos frutos em relacao a base da planta adulta
function Visuals.fruitOffsets(seed): { Vector3 }
	local h = seed.height
	local count = seed.maxFruits or 1
	local offsets = {}
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2 + 0.4
		local radius, y
		local t = seed.plantType
		if t == "bush" then
			radius = h * 0.42
			y = h * (if i % 2 == 0 then 0.68 else 0.42)
		elseif t == "tree" then
			radius = h * 0.37
			y = h * (0.52 + 0.06 * (i % 3))
		elseif t == "palm" then
			radius = 0.6
			y = h * 0.8
		elseif t == "tall" then
			radius = 0.35
			y = h * (0.4 + 0.12 * (i - 1))
		elseif t == "cactus" then
			radius = h * 0.15
			y = h * (0.45 + 0.08 * (i - 1))
		elseif t == "beanstalk" then
			radius = 0.85
			y = h * (0.2 + 0.7 * (i - 1) / math.max(count - 1, 1))
		else
			radius = h * 0.4
			y = h * 0.5
		end
		offsets[i] = Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
	end
	return offsets
end

function Visuals.produceParts(root: Instance): { BasePart }
	local parts = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Produce") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Muda a aparencia das partes do fruto conforme as mutacoes
function Visuals.applyMutations(parts: { BasePart }, mutations: { string })
	local top: string? = nil
	for _, id in Config.MutationVisualPriority do
		if table.find(mutations, id) then
			top = id
			break
		end
	end
	for _, part in parts do
		local old = part:FindFirstChild("EfeitoMutacao")
		if old then
			old:Destroy()
		end
		CollectionService:RemoveTag(part, "RainbowFruit")
		local baseColor = part:GetAttribute("BaseColor")
		if typeof(baseColor) ~= "Color3" then
			baseColor = part.Color
		end
		if top then
			local mutation = Config.Mutations[top]
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
			if appearance then
				appearance:Destroy()
			end
			local blend = BLEND[top]
			part.Color = if blend then baseColor:Lerp(mutation.color, blend) else mutation.color
			part.Material = Enum.Material[mutation.material]
			if top == "Rainbow" then
				CollectionService:AddTag(part, "RainbowFruit")
			end
			if top == "Gold" or top == "Rainbow" or top == "Shocked" or top == "Frozen" then
				local sparkles = Instance.new("Sparkles")
				sparkles.Name = "EfeitoMutacao"
				sparkles.SparkleColor = mutation.color
				sparkles.Parent = part
			end
		else
			part.Color = baseColor
			local materialName = part:GetAttribute("BaseMaterial")
			if type(materialName) == "string" then
				local ok, material = pcall(function()
					return Enum.Material[materialName]
				end)
				if ok and material then
					part.Material = material
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Sprinklers e ovos
---------------------------------------------------------------------

function Visuals.buildSprinkler(gear): Model
	local model = fromLibrary("Sprinkler_" .. gear.id, 2.4, true, true)
	if not model then
		model = Instance.new("Model")
		cylinder(model, "Base", 0.4, 1.4, CFrame.new(0, 0.2, 0), Color3.fromRGB(90, 90, 100))
		cylinder(model, "Cano", 1.6, 0.3, CFrame.new(0, 1, 0), Color3.fromRGB(150, 150, 160))
		local head = sphere(model, "Cabeca", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 1.9, 0), gear.color)
		model.PrimaryPart = head
		model.WorldPivot = CFrame.new()
	end
	model.Name = gear.name
	local ring = cylinder(model, "Alcance", 0.05, gear.radius * 2, CFrame.new(0, 0.03, 0), Color3.fromRGB(100, 180, 255))
	ring.Transparency = 0.85
	ring.CanQuery = false
	-- a agua sai da "Cabeca" (no modelo do Blender: Cabeca_<IdDoItem>)
	local emitterPart: BasePart = model.PrimaryPart or ring
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "cabeca", 1, true) then
			emitterPart = descendant
			break
		end
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Agua"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 190, 255))
	emitter.LightEmission = 0.2
	emitter.Rate = 25
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Speed = NumberRange.new(6, 9)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.Size = NumberSequence.new(0.25)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Parent = emitterPart
	return model
end

function Visuals.buildEgg(egg): (Model, TextLabel)
	local model = fromLibrary("Ovo_" .. egg.id, 2, true, true)
	if not model then
		model = Instance.new("Model")
		local shell = sphere(model, "Casca", Vector3.new(1.6, 2, 1.6), CFrame.new(0, 1, 0), egg.color)
		for i = 1, 4 do
			local cf = CFrame.new(0, 1, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.Angles(math.rad(20 * (i % 2)), 0, 0) * CFrame.new(0, 0.1, 0.72)
			sphere(model, "Pinta", Vector3.new(0.4, 0.4, 0.15), cf, egg.color:Lerp(Color3.new(0, 0, 0), 0.25))
		end
		model.PrimaryPart = shell
		model.WorldPivot = CFrame.new()
	end
	model.Name = egg.name
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 70
	gui.Adornee = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Name = "Texto"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.3
	label.Text = egg.name
	label.Parent = gui
	gui.Parent = model
	return model, label
end

---------------------------------------------------------------------
-- Efeitos
---------------------------------------------------------------------

function Visuals.splash(position: Vector3, radius: number)
	local ball = sphere(workspace, "Respingo", Vector3.new(1, 1, 1), CFrame.new(position), Color3.fromRGB(90, 170, 255))
	ball.Transparency = 0.4
	ball.CanQuery = false
	local tween = TweenService:Create(ball, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, 1, radius * 2),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ball, 0.8)
end

function Visuals.lightning(target: Vector3)
	local model = Instance.new("Model")
	model.Name = "Raio"
	local points = {}
	local steps = 7
	for i = 0, steps do
		local alpha = i / steps
		local offset = if i == 0 or i == steps then Vector3.zero else Vector3.new(math.random(-30, 30) / 10, 0, math.random(-30, 30) / 10)
		table.insert(points, target + Vector3.new(0, 120 * (1 - alpha), 0) + offset)
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local segment = block(model, "Segmento", Vector3.new(0.5, 0.5, length), CFrame.lookAt((a + b) / 2, b, Vector3.xAxis), Color3.fromRGB(170, 230, 255))
		segment.Material = Enum.Material.Neon
		segment.CanQuery = false
	end
	local flash = Instance.new("PointLight")
	flash.Brightness = 8
	flash.Range = 40
	flash.Color = Color3.fromRGB(170, 230, 255)
	flash.Parent = model:FindFirstChildWhichIsA("BasePart")
	model.Parent = workspace
	Debris:AddItem(model, 0.4)
end

return Visuals
