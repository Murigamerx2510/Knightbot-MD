-- Visuals: constroi os modelos 3D de plantas, brotos, frutos, sprinklers, ovos,
-- lanternas, gnomos e os efeitos (raios, meteoros, estrelas, tornado, tiros das defesas).
--
-- Modelos feitos no Blender: importe-os para ReplicatedStorage/Modelos com os nomes
--   Planta_<IdDaSemente>  (ex.: Planta_Carrot)  -> corpo da planta
--   Fruto_<IdDaSemente>   (ex.: Fruto_Apple)    -> fruto de plantas de varias colheitas
--   Sprinkler_<IdDoItem>  (ex.: Sprinkler_CommonSprinkler)
--   Ovo_<IdDoOvo>         (ex.: Ovo_CommonEgg)
--   Gnomo, Lanterna
-- Se o modelo nao existir, o jogo cria um modelo com Parts automaticamente.
-- Partes cujo nome contem "Produto" mudam de cor com as mutacoes e ao amadurecer.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))

local Visuals = {}

local STEM_COLOR = Color3.fromRGB(85, 140, 60)
local WOOD_COLOR = Color3.fromRGB(115, 78, 48)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(20, 20, 20)
local DIRT = Color3.fromRGB(110, 72, 45)
local RAINBOW = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 230, 60),
	Color3.fromRGB(90, 220, 90),
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(170, 90, 255),
}

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

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
	return light
end

-- Petalas caindo da copa (Cerejeira)
local function addPetals(part: BasePart)
	local petals = Instance.new("ParticleEmitter")
	petals.Name = "Petalas"
	petals.Color = ColorSequence.new(Color3.fromRGB(255, 190, 220))
	petals.Size = NumberSequence.new(0.18)
	petals.Lifetime = NumberRange.new(3, 4.5)
	petals.Speed = NumberRange.new(0.5, 1.2)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0.6, -1.4, 0.3)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-60, 60)
	petals.Rate = 5
	petals.Parent = part
	return petals
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

-- Marca as partes "Produto" de um modelo importado (se nao houver nenhuma e
-- markAllIfNone for true, o modelo inteiro conta como fruto).
-- A textura do Blender fica guardada no atributo "Texture": ela aparece no fruto maduro
-- e some quando o fruto precisa de outra cor (verde, variante ou mutacao).
local function markLibraryProduce(model: Model, markAllIfNone: boolean, color: Color3)
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "produto", 1, true) then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 and markAllIfNone then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	for _, part in parts do
		if part:IsA("MeshPart") and part.TextureID ~= "" then
			part:SetAttribute("Texture", part.TextureID)
		end
		part.Color = color
		markProduce(part)
	end
end

local function showTexture(part: BasePart, visible: boolean)
	local texture = part:GetAttribute("Texture")
	if part:IsA("MeshPart") and type(texture) == "string" then
		part.TextureID = if visible then texture else ""
	end
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
	local leaf = seed.leafColor
	cylinder(model, "Caule", h * 0.3, 0.25, CFrame.new(0, h * 0.15, 0), STEM_COLOR)
	sphere(model, "Folhagem", Vector3.new(h * 0.85, h * 0.65, h * 0.85), CFrame.new(0, h * 0.5, 0), leaf)
	local tufts = {
		{ Vector3.new(0.2, 0.72, -0.1), Vector3.new(0.5, 0.45, 0.5), 0.08 },
		{ Vector3.new(-0.22, 0.62, 0.15), Vector3.new(0.45, 0.4, 0.45), 0.04 },
		{ Vector3.new(0.05, 0.55, 0.28), Vector3.new(0.42, 0.36, 0.42), -0.06 },
		{ Vector3.new(-0.2, 0.5, -0.25), Vector3.new(0.42, 0.36, 0.42), 0.05 },
		{ Vector3.new(0, 0.84, 0), Vector3.new(0.34, 0.3, 0.34), 0.12 },
	}
	for _, tuft in tufts do
		local color = if tuft[3] >= 0 then leaf:Lerp(WHITE, tuft[3]) else leaf:Lerp(BLACK, -tuft[3])
		sphere(model, "Folhagem", tuft[2] * h, CFrame.new(tuft[1] * h), color)
	end
	local id = seed.id
	if id == "Strawberry" or id == "Blueberry" then -- florzinhas brancas
		for i = 1, 3 do
			local angle = i * 2.1 + 0.6
			local center = Vector3.new(math.cos(angle) * h * 0.36, h * 0.68, math.sin(angle) * h * 0.36)
			sphere(model, "Flor", Vector3.new(0.34, 0.1, 0.34), CFrame.new(center), WHITE)
			sphere(model, "Miolo", Vector3.new(0.12, 0.08, 0.12), CFrame.new(center + Vector3.new(0, 0.05, 0)), Color3.fromRGB(255, 220, 80))
		end
	elseif id == "Tomato" or id == "Pepper" or id == "GhostPepper" or id == "InfernoPepper" then -- estaca de madeira
		local stake = block(model, "Estaca", Vector3.new(0.12, h * 0.95, 0.12), CFrame.new(h * 0.38, h * 0.475, h * 0.12), WOOD_COLOR:Lerp(WHITE, 0.15))
		stake.Material = Enum.Material.Wood
		block(model, "Amarra", Vector3.new(0.18, 0.06, 0.18), CFrame.new(h * 0.38, h * 0.6, h * 0.12), Color3.fromRGB(230, 210, 150))
	end
	if id == "InfernoPepper" then -- brasas
		for i = 1, 3 do
			local ember = sphere(model, "Brasa", Vector3.new(0.14, 0.14, 0.14), CFrame.new(math.cos(i * 2.1) * h * 0.25, h * (0.95 + (i % 2) * 0.05), math.sin(i * 2.1) * h * 0.25), Color3.fromRGB(255, 140, 40))
			ember.Material = Enum.Material.Neon
		end
	end
end

function builders.flower(model: Model, seed)
	local h, fs = seed.height, seed.fruitSize
	cylinder(model, "Caule", h * 0.75, 0.16, CFrame.new(0, h * 0.375, 0), STEM_COLOR)
	for i = 1, 3 do
		local cf = CFrame.new(0, h * 0.1, 0) * CFrame.Angles(0, i * 2.1, 0) * CFrame.Angles(math.rad(22), 0, 0) * CFrame.new(0, h * 0.2, 0)
		sphere(model, "Folha", Vector3.new(0.4, h * 0.45, 0.1), cf, seed.leafColor:Lerp(WHITE, (i % 2) * 0.06))
	end
	local headY = h * 0.75 + fs.Y * 0.4
	if seed.id == "Daffodil" then -- 6 petalas abertas + trombeta
		local head = CFrame.new(0, headY, 0) * CFrame.Angles(math.rad(-30), 0, 0)
		for i = 1, 6 do
			local petal = head * CFrame.Angles(0, 0, i * math.pi / 3) * CFrame.new(0, fs.X * 0.3, 0)
			markProduce(sphere(model, "Produto", Vector3.new(fs.X * 0.34, fs.X * 0.62, 0.08), petal, seed.fruitColor))
		end
		markProduce(cylinder(model, "ProdutoTrombeta", fs.X * 0.35, fs.X * 0.34, head * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, fs.X * 0.16, 0), seed.fruitColor:Lerp(Color3.fromRGB(255, 150, 30), 0.55)))
	else -- tulipa: taca de 6 petalas
		markProduce(sphere(model, "Produto", fs * 0.55, CFrame.new(0, headY - fs.Y * 0.1, 0), seed.fruitColor))
		for i = 1, 6 do
			local inner = i % 2 == 0
			local cf = CFrame.new(0, headY, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0, fs.Z * (if inner then 0.16 else 0.22)) * CFrame.Angles(math.rad(if inner then 9 else 17), 0, 0)
			markProduce(sphere(model, "Produto", Vector3.new(fs.X * 0.56, fs.Y * 0.92, fs.Z * 0.22), cf, if inner then seed.fruitColor else seed.fruitColor:Lerp(BLACK, 0.07)))
		end
	end
end

function builders.tall(model: Model, seed)
	local h = seed.height
	local stalk = seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.15)
	cylinder(model, "Caule", h, 0.35, CFrame.new(0, h / 2, 0), stalk)
	for i = 1, 3 do
		cylinder(model, "No", 0.08, 0.42, CFrame.new(0, h * 0.22 * i, 0), stalk:Lerp(BLACK, 0.12))
	end
	for i = 1, 6 do
		local y = h * (0.15 + 0.11 * i)
		local cf = CFrame.new(0, y, 0) * CFrame.Angles(0, i * 2.4, 0) * CFrame.Angles(math.rad(48), 0, 0) * CFrame.new(0, h * 0.2, 0)
		block(model, "Folha", Vector3.new(0.1, h * 0.42, 0.45), cf, seed.leafColor:Lerp(WHITE, (i % 3) * 0.04))
	end
	for i = 1, 5 do
		local cf = CFrame.new(0, h, 0) * CFrame.Angles(0, i * 1.26, 0) * CFrame.Angles(math.rad(if i == 1 then 0 else 28), 0, 0) * CFrame.new(0, 0.3, 0)
		block(model, "Pendao", Vector3.new(0.08, 0.6, 0.08), cf, Color3.fromRGB(230, 200, 120))
	end
end

function builders.ground(model: Model, seed)
	local fs = seed.fruitSize
	if seed.id == "Pumpkin" then -- abobora com gomos
		markProduce(sphere(model, "Produto", fs * 0.9, CFrame.new(0, fs.Y / 2, 0), seed.fruitColor:Lerp(BLACK, 0.06)))
		for i = 1, 6 do
			local cf = CFrame.new(0, fs.Y / 2, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(fs.X * 0.2, 0, 0)
			markProduce(sphere(model, "Produto", Vector3.new(fs.X * 0.6, fs.Y, fs.Z * 0.36), cf, seed.fruitColor))
		end
	else
		markProduce(sphere(model, "Produto", fs, CFrame.new(0, fs.Y / 2, 0), seed.fruitColor))
		if seed.id == "Watermelon" then -- listras
			for i = 1, 4 do
				local cf = CFrame.new(0, fs.Y / 2, 0) * CFrame.Angles(i * math.pi / 4, 0, 0)
				markProduce(sphere(model, "ProdutoListra", Vector3.new(fs.X * 1.01, fs.Y * 1.01, fs.Z * 0.12), cf, seed.fruitColor:Lerp(BLACK, 0.4)))
			end
		end
	end
	cylinder(model, "Cabo", 0.5, 0.22, CFrame.new(0, fs.Y + 0.15, 0), Color3.fromRGB(100, 120, 50))
	-- folhas grandes e irregulares no chao
	local leaves = { { 0.3, 1.7 }, { 1.6, 1.35 }, { 2.9, 1.85 }, { 4.1, 1.25 }, { 5.2, 1.55 } }
	for i, leafInfo in leaves do
		local angle, length = leafInfo[1], leafInfo[2]
		local cf = CFrame.Angles(0, angle, 0) * CFrame.new(fs.X * 0.42 + length * 0.35, 0.1, 0) * CFrame.Angles(0, 0, math.rad(4 + (i % 3) * 3))
		local color = seed.leafColor:Lerp(WHITE, (i % 3) * 0.04)
		sphere(model, "Folha", Vector3.new(length, 0.12, length * 0.62), cf, color)
		sphere(model, "Folha", Vector3.new(length * 0.6, 0.11, length * 0.45), cf * CFrame.new(length * 0.08, 0.01, length * 0.2) * CFrame.Angles(0, math.rad(40), 0), color)
	end
end

function builders.tree(model: Model, seed)
	local h = seed.height
	local trunk = cylinder(model, "Tronco", h * 0.55, h * 0.12, CFrame.new(0, h * 0.275, 0), WOOD_COLOR)
	trunk.Material = Enum.Material.Wood
	for i = 1, 3 do -- raizes
		local angle = i * math.pi * 2 / 3 + 0.3
		sphere(model, "Raiz", Vector3.new(h * 0.12, h * 0.06, h * 0.06), CFrame.new(math.cos(angle) * h * 0.06, h * 0.02, math.sin(angle) * h * 0.06) * CFrame.Angles(0, -angle, 0), WOOD_COLOR:Lerp(BLACK, 0.1))
	end
	local leaf = seed.leafColor
	local blobs = {
		{ Vector3.new(0, 0.68, 0), Vector3.new(0.75, 0.55, 0.75), 0 },
		{ Vector3.new(0.22, 0.82, 0), Vector3.new(0.45, 0.4, 0.45), 0.07 },
		{ Vector3.new(-0.2, 0.78, 0.15), Vector3.new(0.42, 0.38, 0.42), 0.03 },
		{ Vector3.new(0.05, 0.8, -0.22), Vector3.new(0.4, 0.36, 0.4), -0.05 },
		{ Vector3.new(-0.14, 0.6, -0.16), Vector3.new(0.4, 0.34, 0.4), -0.08 },
		{ Vector3.new(0, 0.9, 0), Vector3.new(0.36, 0.28, 0.36), 0.1 },
	}
	for _, blob in blobs do
		local color = if blob[3] >= 0 then leaf:Lerp(WHITE, blob[3]) else leaf:Lerp(BLACK, -blob[3])
		sphere(model, "Copa", blob[2] * h, CFrame.new(blob[1] * h), color)
	end
	if seed.id == "GalaxyFruit" then -- estrelinhas brilhando na copa
		for i = 1, 6 do
			local angle = i * 1.05
			local star = sphere(model, "Estrela", Vector3.new(0.22, 0.22, 0.22), CFrame.new(math.cos(angle) * h * 0.38, h * (0.62 + (i % 3) * 0.1), math.sin(angle) * h * 0.38), Color3.fromRGB(255, 250, 200))
			star.Material = Enum.Material.Neon
		end
	end
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
	local segments = 6
	local topY = h * 0.85
	local banana = seed.id == "Banana"
	local trunkColor = if banana then WOOD_COLOR:Lerp(seed.leafColor, 0.45) else WOOD_COLOR
	for i = 1, segments do
		local trunk = cylinder(model, "Tronco", topY / segments * 1.02, 0.6 - i * 0.04, CFrame.new(0, topY / segments * (i - 0.5), 0), trunkColor:Lerp(WHITE, (i % 2) * 0.08))
		trunk.Material = Enum.Material.Wood
	end
	sphere(model, "Topo", Vector3.new(0.7, 0.45, 0.7), CFrame.new(0, topY, 0), seed.leafColor:Lerp(BLACK, 0.15))
	local count = if banana then 6 else 7
	local width = if banana then 1.2 else 0.85
	for i = 1, count do -- folhas que sobem e depois caem
		local base = CFrame.new(0, topY, 0) * CFrame.Angles(0, i * math.pi * 2 / count, 0)
		local color = seed.leafColor:Lerp(WHITE, (i % 3) * 0.05)
		block(model, "Folha", Vector3.new(width, h * 0.26, 0.12), base * CFrame.Angles(math.rad(-70), 0, 0) * CFrame.new(0, h * 0.13, 0), color)
		block(model, "Folha", Vector3.new(width * 0.8, h * 0.22, 0.12), base * CFrame.new(0, h * 0.06, -h * 0.24) * CFrame.Angles(math.rad(-120), 0, 0) * CFrame.new(0, h * 0.11, 0), color)
	end
	block(model, "FolhaNova", Vector3.new(0.25, h - topY, 0.12), CFrame.new(0, (topY + h) / 2, 0), seed.leafColor:Lerp(WHITE, 0.08))
	if banana then -- coracao da bananeira
		sphere(model, "Coracao", Vector3.new(0.38, 0.6, 0.38), CFrame.new(0.38, topY - 0.75, 0), Color3.fromRGB(120, 40, 80))
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
	-- espinhos
	for i = 1, 8 do
		local cf = CFrame.new(0, h * (0.15 + 0.07 * i), 0) * CFrame.Angles(0, i * 2.4, 0) * CFrame.new(h * 0.13, 0, 0)
		block(model, "Espinho", Vector3.new(0.18, 0.04, 0.04), cf, Color3.fromRGB(245, 240, 200))
	end
	-- flor no topo
	local flowerColor = seed.fruitColor:Lerp(WHITE, 0.3)
	for i = 1, 5 do
		local cf = CFrame.new(0, h * 0.86, 0) * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.Angles(math.rad(55), 0, 0) * CFrame.new(0, h * 0.04, 0)
		sphere(model, "Flor", Vector3.new(h * 0.05, h * 0.09, 0.05), cf, flowerColor)
	end
	sphere(model, "Miolo", Vector3.new(h * 0.05, h * 0.04, h * 0.05), CFrame.new(0, h * 0.86, 0), Color3.fromRGB(255, 220, 90))
end

function builders.mushroom(model: Model, seed)
	local h, fs = seed.height, seed.fruitSize
	cylinder(model, "Caule", h * 0.5, 0.7, CFrame.new(0, h * 0.25, 0), seed.leafColor)
	local capY = h * 0.5 + fs.Y * 0.25
	cylinder(model, "Lamelas", 0.1, fs.X * 0.78, CFrame.new(0, capY - fs.Y * 0.18, 0), seed.leafColor:Lerp(BLACK, 0.12))
	markProduce(sphere(model, "Produto", fs, CFrame.new(0, capY, 0), seed.fruitColor))
	for i = 1, 5 do
		local cf = CFrame.new(0, capY, 0) * CFrame.Angles(0, i * 1.25, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, fs.Y * 0.46, 0)
		sphere(model, "Pinta", Vector3.new(0.35, 0.12, 0.35), cf, WHITE)
	end
	-- cogumelinhos ao lado
	for _, info in { { 0.75, -0.35, 0.35 }, { -0.6, 0.55, 0.28 } } do
		local x, z, scale = info[1], info[2], info[3]
		local stemHeight = h * 0.32 * scale / 0.35
		cylinder(model, "Caule", stemHeight, 0.25 * scale / 0.35, CFrame.new(x, stemHeight / 2, z), seed.leafColor)
		markProduce(sphere(model, "Produto", Vector3.new(fs.X * scale, fs.Y * scale * 0.8, fs.Z * scale), CFrame.new(x, stemHeight, z), seed.fruitColor))
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
	-- castelinho nas nuvens
	local stone, roof = Color3.fromRGB(200, 200, 210), Color3.fromRGB(90, 110, 200)
	block(model, "Castelo", Vector3.new(0.8, 0.4, 0.6), CFrame.new(0, h + 0.85, 0), stone)
	for _, x in { -0.42, 0.42 } do
		cylinder(model, "Torre", 0.6, 0.3, CFrame.new(x, h + 0.95, 0), stone)
		block(model, "Telhado", Vector3.new(0.36, 0.3, 0.36), CFrame.new(x, h + 1.4, 0), roof)
	end
end

-- Trepadeira em trelica de madeira (Uva, Feijao Verde, Hera Venenosa)
function builders.vine(model: Model, seed)
	local h = seed.height
	for _, x in { -0.9, 0.9 } do
		local post = cylinder(model, "Estaca", h, 0.15, CFrame.new(x, h / 2, 0), WOOD_COLOR)
		post.Material = Enum.Material.Wood
	end
	for _, y in { 0.4, 0.7, 0.95 } do
		local bar = block(model, "Trelica", Vector3.new(1.9, 0.08, 0.08), CFrame.new(0, h * y, 0), WOOD_COLOR)
		bar.Material = Enum.Material.Wood
	end
	for i = 1, 3 do
		local cf = CFrame.new(-0.6 + (i - 1) * 0.6, h * 0.45, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 12 else -12))
		cylinder(model, "Ramo", h * 0.9, 0.09, cf, STEM_COLOR)
	end
	for i = 1, 12 do
		local x = -0.8 + ((i * 0.37) % 1) * 1.6
		local y = h * (0.25 + ((i * 0.53) % 1) * 0.7)
		local z = if i % 2 == 0 then 0.12 else -0.12
		sphere(model, "Folha", Vector3.new(0.45, 0.35, 0.12), CFrame.new(x, y, z) * CFrame.Angles(0, 0, i), seed.leafColor:Lerp(WHITE, (i % 3) * 0.05))
	end
end

-- Samambaia (Samambaia de Fogo)
function builders.fern(model: Model, seed)
	local h = seed.height
	sphere(model, "Base", Vector3.new(0.7, 0.3, 0.7), CFrame.new(0, 0.1, 0), seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.3))
	for i = 1, 8 do
		local tilt = if i % 2 == 0 then 35 else 55
		local cf = CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, h * 0.35, 0)
		sphere(model, "Fronde", Vector3.new(0.35, h * 0.7, 0.08), cf, seed.leafColor)
		local tip = sphere(model, "Ponta", Vector3.new(0.18, 0.18, 0.18), cf * CFrame.new(0, h * 0.35, 0), seed.fruitColor)
		tip.Material = Enum.Material.Neon
	end
end

-- Dioneia: hastes com "bocas" que mordem ladroes
local TRAP_COUNT = 5
function builders.flytrap(model: Model, seed)
	local h = seed.height
	sphere(model, "Base", Vector3.new(1.2, 0.3, 1.2), CFrame.new(0, 0.12, 0), seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.2))
	for k = 0, TRAP_COUNT - 1 do
		local angle = k * (math.pi * 2 / TRAP_COUNT) + 0.4
		local headPos = Vector3.new(math.cos(angle) * h * 0.36, h * 0.72, math.sin(angle) * h * 0.36)
		local stemMid = headPos / 2
		local stem = block(model, "Haste", Vector3.new(0.12, 0.12, headPos.Magnitude), CFrame.lookAt(stemMid, headPos, Vector3.xAxis), STEM_COLOR)
		stem.Name = "Haste"
		local head = CFrame.lookAt(headPos, headPos + Vector3.new(math.cos(angle), 0.3, math.sin(angle)), Vector3.yAxis)
		for _, side in { 1, -1 } do
			local jaw = head * CFrame.Angles(math.rad(25 * side), 0, 0) * CFrame.new(0, 0.18 * side, -0.2)
			sphere(model, "Mandibula", Vector3.new(0.7, 0.18, 0.6), jaw, seed.leafColor)
			sphere(model, "Boca", Vector3.new(0.6, 0.1, 0.5), jaw * CFrame.new(0, -0.05 * side, 0), Color3.fromRGB(200, 40, 50))
			for t = 1, 4 do
				block(model, "Dente", Vector3.new(0.05, 0.16, 0.05), jaw * CFrame.new(-0.27 + t * 0.11, 0.08 * side, -0.3), WHITE)
			end
		end
	end
end

-- Flor gigante brilhante (Flor da Lua, Flor do Sol, Flor do Eclipse, Flor Hipnotica, Semente Arco-iris)
function builders.bloom(model: Model, seed)
	local h = seed.height
	cylinder(model, "Caule", h * 0.6, 0.3, CFrame.new(0, h * 0.3, 0), STEM_COLOR)
	for i = 1, 3 do
		local cf = CFrame.new(0, h * 0.12, 0) * CFrame.Angles(0, i * 2.1 + 0.5, 0) * CFrame.Angles(math.rad(60), 0, 0) * CFrame.new(0, h * 0.18, 0)
		sphere(model, "Folha", Vector3.new(0.9, h * 0.45, 0.12), cf, seed.leafColor:Lerp(WHITE, (i % 2) * 0.06))
	end
	local headY = h * 0.66
	local special = seed.special or {}
	for layer = 1, 2 do -- duas camadas de petalas
		local tilt = if layer == 1 then 62 else 38
		local length = h * (if layer == 1 then 0.32 else 0.22)
		local width = h * (if layer == 1 then 0.16 else 0.11)
		for i = 1, 8 do
			local petalColor
			if special.rainbowPetals then
				petalColor = RAINBOW[(i - 1) % #RAINBOW + 1]
				if layer == 2 then
					petalColor = petalColor:Lerp(WHITE, 0.3)
				end
			else
				petalColor = if layer == 1 then seed.fruitColor:Lerp(WHITE, 0.25) else seed.fruitColor
			end
			local cf = CFrame.new(0, headY, 0) * CFrame.Angles(0, i * math.pi / 4 + (layer - 1) * math.pi / 8, 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, length * 0.5, 0)
			sphere(model, "Petala", Vector3.new(width, length, 0.1), cf, petalColor)
		end
	end
	local center = sphere(model, "Centro", Vector3.new(h * 0.18, h * 0.12, h * 0.18), CFrame.new(0, headY + 0.05, 0), seed.fruitColor)
	center.Material = Enum.Material.Neon
	-- orbe magico flutuando sobre a flor
	local orb = sphere(model, "Orbe", Vector3.new(h * 0.14, h * 0.14, h * 0.14), CFrame.new(0, h * 0.93, 0), if special.rainbowPetals then WHITE else seed.fruitColor:Lerp(WHITE, 0.35))
	orb.Material = Enum.Material.Neon
	if special.glow then
		addLight(orb, seed.fruitColor, 12, 1.5)
	end
end

-- Girassol
function builders.sunflower(model: Model, seed)
	local h = seed.height
	cylinder(model, "Caule", h * 0.85, 0.28, CFrame.new(0, h * 0.425, 0), STEM_COLOR)
	for i = 1, 3 do
		local cf = CFrame.new(0, h * (0.2 + 0.18 * i), 0) * CFrame.Angles(0, i * 2.2, 0) * CFrame.Angles(math.rad(55), 0, 0) * CFrame.new(0, 0.4, 0)
		sphere(model, "Folha", Vector3.new(0.6, 0.9, 0.08), cf, seed.leafColor)
	end
	local head = CFrame.new(0, h * 0.88, 0) * CFrame.Angles(math.rad(-15), 0, 0)
	cylinder(model, "Miolo", 0.25, h * 0.26, head * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(110, 70, 30))
	for i = 1, 12 do
		local cf = head * CFrame.Angles(0, 0, i * math.pi / 6) * CFrame.new(0, h * 0.2, 0)
		sphere(model, "Petala", Vector3.new(h * 0.08, h * 0.16, 0.08), cf, Color3.fromRGB(255, 205, 40))
	end
end

-- Cuspidor (Cuspidor de Veneno, Sopro do Dragao)
function builders.spitter(model: Model, seed)
	local h = seed.height
	sphere(model, "Corpo", Vector3.new(h * 0.55, h * 0.5, h * 0.55), CFrame.new(0, h * 0.3, 0), seed.leafColor)
	for i = 1, 4 do
		local cf = CFrame.Angles(0, i * math.pi / 2 + 0.4, 0) * CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(0, h * 0.25, 0)
		sphere(model, "Folha", Vector3.new(0.5, h * 0.5, 0.1), cf, seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.15))
	end
	local neck = CFrame.new(0, h * 0.62, -h * 0.08) * CFrame.Angles(math.rad(-35), 0, 0)
	cylinder(model, "Pescoco", h * 0.35, h * 0.16, neck, seed.leafColor)
	local mouth = neck * CFrame.new(0, h * 0.2, 0)
	cylinder(model, "Boca", 0.2, h * 0.22, mouth, seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.25))
	local inside = cylinder(model, "Garganta", 0.05, h * 0.15, mouth * CFrame.new(0, 0.11, 0), seed.fruitColor)
	inside.Material = Enum.Material.Neon
	for i = 1, 6 do
		local cf = CFrame.new(0, h * 0.3, 0) * CFrame.Angles(0, i * 1.05, 0) * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.new(0, h * 0.27, 0)
		block(model, "Espinho", Vector3.new(0.12, 0.35, 0.12), cf, seed.fruitColor:Lerp(WHITE, 0.3))
	end
end

-- Picole Foguete (fruto unico, colhido inteiro)
function builders.popsicle(model: Model, seed)
	local fs = seed.fruitSize
	local stick = block(model, "Palito", Vector3.new(0.16, 0.7, 0.06), CFrame.new(0, 0.35, 0), Color3.fromRGB(220, 190, 130))
	stick.Material = Enum.Material.Wood
	local layer = fs.Y / 3
	local colors = { Color3.fromRGB(60, 110, 230), WHITE, seed.fruitColor }
	for i = 1, 3 do
		local cf = CFrame.new(0, 0.7 + layer * (i - 0.5), 0)
		markProduce(block(model, "Produto", Vector3.new(fs.X, layer, fs.Z), cf, colors[i]))
	end
	for i = 1, 2 do
		local cf = CFrame.Angles(0, i * math.pi, 0) * CFrame.Angles(math.rad(50), 0, 0) * CFrame.new(0, 0.3, 0)
		sphere(model, "Folha", Vector3.new(0.3, 0.6, 0.08), cf, seed.leafColor)
	end
end

-- Abacaxi
function builders.pineapple(model: Model, seed)
	local h = seed.height
	for i = 1, 10 do
		local tilt = if i % 2 == 0 then 30 else 55
		local cf = CFrame.Angles(0, i * math.pi / 5, 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, h * 0.25, 0)
		block(model, "Folha", Vector3.new(0.18, h * 0.5, 0.05), cf, seed.leafColor:Lerp(WHITE, (i % 3) * 0.06))
	end
	cylinder(model, "Caule", h * 0.3, 0.3, CFrame.new(0, h * 0.15, 0), seed.leafColor:Lerp(Color3.new(0, 0, 0), 0.2))
end

-- Cogumelos brilhantes
function builders.glowshroom(model: Model, seed)
	local h = seed.height
	local spots = {
		{ Vector3.new(0, 0, 0), 0.5, 1 },
		{ Vector3.new(0.45, 0, 0.2), 0.35, 0.7 },
		{ Vector3.new(-0.35, 0, -0.3), 0.25, 0.55 },
	}
	for index, info in spots do
		local pos, stemHeight, capScale = info[1], h * info[2], info[3]
		cylinder(model, "Caule", stemHeight, 0.22 * capScale + 0.1, CFrame.new(pos.X, stemHeight / 2, pos.Z), seed.leafColor)
		local cap = sphere(model, "Chapeu", Vector3.new(0.9, 0.45, 0.9) * capScale, CFrame.new(pos.X, stemHeight, pos.Z), seed.fruitColor)
		cap.Material = Enum.Material.Neon
		if index == 1 then
			addLight(cap, seed.fruitColor, 10, 1.2)
		end
	end
end

-- Cerejeira (Cherry Blossom): copa rosa com petalas caindo
function builders.blossom(model: Model, seed)
	local h = seed.height
	local trunk1 = cylinder(model, "Tronco", h * 0.35, h * 0.09, CFrame.new(0, h * 0.175, 0) * CFrame.Angles(0, 0, math.rad(6)), Color3.fromRGB(90, 55, 40))
	trunk1.Material = Enum.Material.Wood
	local trunk2 = cylinder(model, "Tronco", h * 0.3, h * 0.07, CFrame.new(-h * 0.04, h * 0.45, 0) * CFrame.Angles(0, 0, math.rad(-10)), Color3.fromRGB(90, 55, 40))
	trunk2.Material = Enum.Material.Wood
	local canopy = sphere(model, "Copa", Vector3.new(h * 0.8, h * 0.5, h * 0.8), CFrame.new(0, h * 0.7, 0), seed.leafColor)
	sphere(model, "Copa", Vector3.new(h * 0.5, h * 0.38, h * 0.5), CFrame.new(h * 0.25, h * 0.8, h * 0.05), seed.leafColor:Lerp(WHITE, 0.15))
	sphere(model, "Copa", Vector3.new(h * 0.45, h * 0.35, h * 0.45), CFrame.new(-h * 0.24, h * 0.76, -h * 0.12), seed.leafColor:Lerp(Color3.fromRGB(255, 120, 170), 0.2))
	local extra = {
		{ Vector3.new(0.05, 0.74, 0.26), Vector3.new(0.45, 0.34, 0.45), 0.1 },
		{ Vector3.new(-0.1, 0.86, 0.2), Vector3.new(0.4, 0.3, 0.4), 0.18 },
		{ Vector3.new(0.18, 0.66, -0.22), Vector3.new(0.42, 0.32, 0.42), -0.06 },
		{ Vector3.new(0, 0.9, 0), Vector3.new(0.4, 0.22, 0.4), 0.22 },
	}
	for _, blob in extra do
		local color = if blob[3] >= 0 then seed.leafColor:Lerp(WHITE, blob[3]) else seed.leafColor:Lerp(Color3.fromRGB(255, 120, 170), -blob[3] * 3)
		sphere(model, "Copa", blob[2] * h, CFrame.new(blob[1] * h), color)
	end
	for i = 1, 6 do -- petalas caidas no chao
		local angle = i * 2.4
		local radius = h * (0.14 + (i % 3) * 0.05)
		sphere(model, "PetalaChao", Vector3.new(0.18, 0.03, 0.12), CFrame.new(math.cos(angle) * radius, 0.03, math.sin(angle) * radius) * CFrame.Angles(0, i, 0), seed.leafColor:Lerp(WHITE, (i % 2) * 0.2))
	end
	addPetals(canopy)
end

-- Broto que aparece no inicio do crescimento
function Visuals.buildSprout(seed): Model
	local model = Instance.new("Model")
	model.Name = "Broto"
	sphere(model, "Monte", Vector3.new(0.9, 0.28, 0.9), CFrame.new(0, 0.05, 0), DIRT)
	cylinder(model, "Caule", 0.4, 0.07, CFrame.new(0, 0.25, 0), STEM_COLOR)
	for _, side in { 1, -1 } do
		local cf = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(35 * side)) * CFrame.new(0.14 * side, 0, 0)
		sphere(model, "Folhinha", Vector3.new(0.3, 0.08, 0.18), cf, seed.leafColor)
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function decorate(model: Model, seed)
	local special = seed.special or {}
	if special.ghostly then
		for _, part in Visuals.produceParts(model) do
			part.Transparency = 0.35
		end
	end
end

-- Modelos do Blender: a parte "Brilho" ganha luz e a "Copa" da Cerejeira solta petalas
local function decorateLibrary(model: Model, seed)
	local glow, canopy = nil, nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = string.lower(descendant.Name)
			if not glow and string.find(name, "brilho", 1, true) then
				glow = descendant
			elseif not canopy and string.find(name, "copa", 1, true) then
				canopy = descendant
			end
		end
	end
	if glow then
		addLight(glow, seed.fruitColor, 12, 1.5)
	end
	if canopy and (seed.special or {}).petals then
		addPetals(canopy)
	end
end

-- Constroi o corpo de uma planta (pivot na base)
function Visuals.buildPlant(seed): Model
	local model = fromLibrary("Planta_" .. seed.id, seed.height, true, true)
	if model then
		model.Name = "Corpo"
		markLibraryProduce(model, not seed.multiHarvest, seed.fruitColor)
		decorateLibrary(model, seed)
		decorate(model, seed)
		return model
	end
	model = Instance.new("Model")
	model.Name = "Corpo"
	local builder = builders[seed.plantType] or builders.bush
	builder(model, seed)
	decorate(model, seed)
	model.WorldPivot = CFrame.new()
	return model
end

-- Constroi um fruto (pivot no centro)
function Visuals.buildFruit(seed): Model
	local fs = seed.fruitSize
	local model = fromLibrary("Fruto_" .. seed.id, math.max(fs.X, fs.Y, fs.Z), false, false)
	if model then
		model.Name = "Fruto"
		markLibraryProduce(model, true, seed.fruitColor)
		decorate(model, seed)
		return model
	end
	model = Instance.new("Model")
	model.Name = "Fruto"
	local main
	if seed.id == "Grape" then
		-- cacho de uvas
		main = sphere(model, "Produto", fs * 0.55, CFrame.new(0, fs.Y * 0.15, 0), seed.fruitColor)
		for i = 1, 5 do
			local cf = CFrame.Angles(0, i * 1.26, 0) * CFrame.new(fs.X * 0.25, -fs.Y * 0.12 - (i % 2) * fs.Y * 0.12, 0)
			markProduce(sphere(model, "Produto", fs * 0.4, cf, seed.fruitColor))
		end
	else
		main = sphere(model, "Produto", fs, CFrame.new(), seed.fruitColor)
	end
	markProduce(main)
	block(model, "Cabo", Vector3.new(0.1, 0.25, 0.1), CFrame.new(0, fs.Y / 2 + 0.08, 0), STEM_COLOR)
	local special = seed.special or {}
	if special.ghostly then
		for _, part in Visuals.produceParts(model) do
			part.Transparency = 0.35
		end
	end
	if special.glow then
		main.Material = Enum.Material.Neon
		main:SetAttribute("BaseMaterial", "Neon")
	end
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
		elseif t == "tree" or t == "blossom" then
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
		elseif t == "vine" then
			local x = -0.6 + 1.2 * (i - 1) / math.max(count - 1, 1)
			offsets[i] = Vector3.new(x, h * (0.35 + ((i * 0.37) % 1) * 0.45), if i % 2 == 0 then 0.32 else -0.32)
			continue
		elseif t == "fern" then
			radius = h * 0.38
			y = h * (0.45 + 0.12 * (i % 2))
		elseif t == "flytrap" then
			-- dentro das bocas
			angle = (i - 1) * (math.pi * 2 / TRAP_COUNT) + 0.4
			radius = h * 0.36
			y = h * 0.72
		elseif t == "bloom" then
			radius = h * 0.36
			y = h * (0.66 + 0.08 * (i % 2))
		elseif t == "sunflower" then
			radius = 0.5
			y = h * (0.55 + 0.1 * (i % 2))
		elseif t == "spitter" then
			radius = h * 0.32
			y = h * 0.32
		elseif t == "pineapple" then
			radius = 0.3
			y = h * 0.42
		elseif t == "glowshroom" then
			radius = h * 0.42
			y = h * (0.25 + 0.15 * (i % 3))
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

-- Variante de cor (ex.: Morango Branco) ou de Cristal
function Visuals.applyVariant(parts: { BasePart }, seed, variantId: string?)
	local variant = Formulas.variantInfo(seed, variantId)
	if not variant then
		return
	end
	for _, part in parts do
		part:SetAttribute("BaseColor", variant.color)
		part:SetAttribute("Variant", variant.id)
		part.Color = variant.color
		showTexture(part, false)
		if variant.id == Config.CrystalVariant.id then
			part.Material = Enum.Material.Glass
			part.Transparency = 0.25
			part:SetAttribute("BaseMaterial", "Glass")
		end
	end
end

-- Frutos nascem verdes e mudam para a cor final conforme amadurecem
function Visuals.setRipeness(parts: { BasePart }, alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	for _, part in parts do
		if not part:GetAttribute("Mutated") then
			local base = part:GetAttribute("BaseColor")
			if typeof(base) == "Color3" then
				part.Color = Config.Growth.unripeColor:Lerp(base, alpha)
			end
			showTexture(part, alpha >= 1 and part:GetAttribute("Variant") == nil)
		end
	end
end

-- Muda a aparencia das partes do fruto conforme as mutacoes
function Visuals.applyMutations(parts: { BasePart }, mutations: { string })
	local top = Formulas.topMutation(mutations)
	local hasRainbow = table.find(mutations, "Rainbow") ~= nil
	for _, part in parts do
		local old = part:FindFirstChild("EfeitoMutacao")
		while old do
			old:Destroy()
			old = part:FindFirstChild("EfeitoMutacao")
		end
		CollectionService:RemoveTag(part, "RainbowFruit")
		local baseColor = part:GetAttribute("BaseColor")
		if typeof(baseColor) ~= "Color3" then
			baseColor = part.Color
		end
		if top then
			local mutation = Config.Mutations[top]
			part:SetAttribute("Mutated", true)
			showTexture(part, false)
			local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
			if appearance then
				appearance:Destroy()
			end
			part.Color = if mutation.blend then baseColor:Lerp(mutation.color, mutation.blend) else mutation.color
			part.Material = Enum.Material[mutation.material]
			if hasRainbow and (top == "Rainbow" or Config.Mutations[top].kind == "growth") then
				CollectionService:AddTag(part, "RainbowFruit")
			end
			if mutation.effect == "sparkles" then
				local sparkles = Instance.new("Sparkles")
				sparkles.Name = "EfeitoMutacao"
				sparkles.SparkleColor = mutation.color
				sparkles.Parent = part
			elseif mutation.effect == "fire" then
				local fire = Instance.new("Fire")
				fire.Name = "EfeitoMutacao"
				fire.Color = mutation.color
				fire.SecondaryColor = mutation.color:Lerp(WHITE, 0.4)
				fire.Size = 2
				fire.Heat = 4
				fire.Parent = part
			elseif mutation.effect == "smoke" then
				local smoke = Instance.new("Smoke")
				smoke.Name = "EfeitoMutacao"
				smoke.Color = mutation.color
				smoke.Opacity = 0.08
				smoke.RiseVelocity = 1
				smoke.Size = 0.6
				smoke.Parent = part
			end
		else
			part:SetAttribute("Mutated", nil)
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
-- Sprinklers, ovos, lanternas e gnomos
---------------------------------------------------------------------

function Visuals.buildSprinkler(gear): Model
	local model = fromLibrary("Sprinkler_" .. gear.id, 2.4, true, true)
	if not model then
		model = Instance.new("Model")
		cylinder(model, "Base", 0.4, 1.4, CFrame.new(0, 0.2, 0), Color3.fromRGB(90, 90, 100))
		cylinder(model, "Cano", 1.6, 0.3, CFrame.new(0, 1, 0), Color3.fromRGB(150, 150, 160))
		local head = sphere(model, "Cabeca", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 1.9, 0), gear.color)
		for i = 1, 4 do
			block(model, "Bico", Vector3.new(0.35, 0.12, 0.12), CFrame.new(0, 1.95, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0.45, 0, 0), gear.color)
		end
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

local function infoLabel(model: Model, text: string, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, height, 0)
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
	label.Text = text
	label.Parent = gui
	gui.Parent = model
	return label
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
	return model, infoLabel(model, egg.name, 3)
end

function Visuals.buildLantern(gear): Model
	local model = fromLibrary("Lanterna", 3.4, true, true)
	local glass: BasePart
	if model then
		-- a luz fica no vidro (no modelo do Blender: Vidro_Lanterna)
		glass = model.PrimaryPart :: BasePart
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "vidro", 1, true) then
				glass = descendant
				break
			end
		end
	else
		model = Instance.new("Model")
		local post = cylinder(model, "Poste", 3, 0.2, CFrame.new(0, 1.5, 0), Color3.fromRGB(60, 60, 70))
		post.Material = Enum.Material.Metal
		block(model, "Braco", Vector3.new(0.8, 0.12, 0.12), CFrame.new(0.35, 3, 0), Color3.fromRGB(60, 60, 70))
		glass = block(model, "Vidro", Vector3.new(0.5, 0.65, 0.5), CFrame.new(0.65, 2.6, 0), gear.color)
		glass.Material = Enum.Material.Neon
		block(model, "Tampa", Vector3.new(0.6, 0.12, 0.6), CFrame.new(0.65, 2.98, 0), Color3.fromRGB(60, 60, 70))
		model.PrimaryPart = glass
		model.WorldPivot = CFrame.new()
	end
	model.Name = gear.name
	addLight(glass, Color3.fromRGB(255, 210, 140), gear.radius, 2)
	return model
end

function Visuals.buildGnome(gear): (Model, TextLabel)
	local model = fromLibrary("Gnomo", 2.4, true, true)
	if not model then
		model = Instance.new("Model")
		local body = cylinder(model, "Corpo", 0.9, 0.9, CFrame.new(0, 0.45, 0), Color3.fromRGB(60, 100, 200))
		sphere(model, "Cabeca", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.15, 0), Color3.fromRGB(255, 205, 170))
		sphere(model, "Barba", Vector3.new(0.6, 0.55, 0.35), CFrame.new(0, 0.95, -0.15), WHITE)
		sphere(model, "Nariz", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 1.15, -0.3), Color3.fromRGB(255, 160, 140))
		for i = 1, 4 do
			local size = 0.75 - i * 0.16
			cylinder(model, "Chapeu", 0.22, size, CFrame.new(0, 1.35 + i * 0.2, 0), gear.color)
		end
		model.PrimaryPart = body
		model.WorldPivot = CFrame.new()
	end
	model.Name = gear.name
	return model, infoLabel(model, gear.name, 3)
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

-- Algo que cai do ceu ate o alvo (meteoro ou estrela)
local function fallingObject(target: Vector3, size: number, color: Color3, time: number, withFire: boolean)
	local start = target + Vector3.new(25, 90, 15)
	local ball = sphere(workspace, if withFire then "Meteoro" else "Estrela", Vector3.new(size, size, size), CFrame.new(start), color)
	ball.Material = Enum.Material.Neon
	ball.CanQuery = false
	if withFire then
		local fire = Instance.new("Fire")
		fire.Size = size * 2
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = ball
	else
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = ball
	end
	addLight(ball, color, 20, 3)
	TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target) }):Play()
	Debris:AddItem(ball, time + 0.4)
end

function Visuals.meteor(target: Vector3)
	fallingObject(target, 2.2, Color3.fromRGB(255, 150, 80), 0.9, true)
end

function Visuals.star(target: Vector3)
	fallingObject(target, 0.9, Color3.fromRGB(255, 240, 150), 0.8, false)
end

function Visuals.tornado(target: Vector3)
	local model = Instance.new("Model")
	model.Name = "Tornado"
	for i = 1, 7 do
		local ring = cylinder(model, "Funil", 2.2, 1.2 + i * 1.1, CFrame.new(target + Vector3.new(0, i * 2.1, 0)), Color3.fromRGB(170, 170, 165))
		ring.Transparency = 0.45
		ring.CanQuery = false
	end
	model.Parent = workspace
	Debris:AddItem(model, 2)
end

-- Tiro das plantas de defesa (veneno, fogo, morango)
function Visuals.projectile(from: Vector3, to: Vector3, color: Color3)
	local ball = sphere(workspace, "Tiro", Vector3.new(0.6, 0.6, 0.6), CFrame.new(from), color)
	ball.Material = Enum.Material.Neon
	ball.CanQuery = false
	TweenService:Create(ball, TweenInfo.new(0.3, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) }):Play()
	Debris:AddItem(ball, 0.4)
end

function Visuals.ring(position: Vector3, color: Color3, radius: number)
	local ring = cylinder(workspace, "Anel", 0.1, 1, CFrame.new(position), color)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.CanQuery = false
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.1, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.6)
end

-- Fruto roubado flutuando em cima da cabeca do ladrao
function Visuals.carryVisual(root: BasePart, seed, variantId: string?): BasePart
	local variant = Formulas.variantInfo(seed, variantId)
	local color = if variant then variant.color else seed.fruitColor
	local ball = Instance.new("Part")
	ball.Name = "FrutoRoubado"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.3, 1.3, 1.3)
	ball.Color = color
	ball.Material = Enum.Material.Neon
	ball.Anchored = false
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.Massless = true
	ball.CFrame = root.CFrame * CFrame.new(0, 3.6, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ball
	weld.Parent = ball
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = color
	sparkles.Parent = ball
	ball.Parent = root.Parent
	return ball
end

return Visuals
