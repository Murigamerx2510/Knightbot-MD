-- MapBuilder: cria o mapa inteiro (chao, rua, praca com chafariz, 6 jardins, lojas,
-- decoracao e iluminacao). Tudo e gerado por codigo, entao o jogo funciona mesmo em um
-- lugar vazio.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

-- Medidas de cada jardim (coordenadas locais do jardim; -Z aponta para a rua)
MapBuilder.Layout = {
	plotHalfX = 28,
	plotHalfZ = 34,
	bedInner = 3, -- distancia do centro ate o inicio de cada canteiro
	bedOuter = 25, -- distancia do centro ate o fim de cada canteiro
	bedZMin = -26,
	bedZMax = 30,
	bedTop = 0.25, -- altura da terra
	columns = { -80, 0, 80 },
	rowZ = 56,
}

local SMOOTH = Enum.SurfaceType.Smooth
local WOOD = Color3.fromRGB(150, 105, 65)
local WOOD_DARK = Color3.fromRGB(115, 78, 48)
local WOOD_LIGHT = Color3.fromRGB(205, 160, 105)
local STONE = Color3.fromRGB(205, 200, 190)
local STONE_DARK = Color3.fromRGB(150, 145, 140)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(20, 20, 20)
local WATER = Color3.fromRGB(90, 175, 255)
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(100, 170, 255),
	Color3.fromRGB(255, 140, 50),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Peca so de enfeite: nao bate, nao lanca sombra pequena demais
local function decor(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cf, color, material)
	p.CanCollide = false
	p.CanTouch = false
	return p
end

-- Cilindro em pe
local function cylinderPart(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = parent
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = decor(parent, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function surfaceText(target: BasePart, text: string, textColor: Color3, face: Enum.NormalId?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.6
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = target
	return label
end

-- plaquinha com nome (e funcao) em cima dos vendedores
local function billboard(adornee: BasePart, title: string, subtitle: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 56)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 120
	gui.Adornee = adornee
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	frame.BackgroundTransparency = 0.2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = frame
	local name = Instance.new("TextLabel")
	name.Name = "Nome"
	name.Size = UDim2.new(1, -12, 0.6, 0)
	name.Position = UDim2.fromOffset(6, 2)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.4
	name.Text = title
	name.Parent = frame
	local role = Instance.new("TextLabel")
	role.Name = "Funcao"
	role.Size = UDim2.new(1, -12, 0.36, 0)
	role.Position = UDim2.new(0, 6, 0.6, 0)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.FredokaOne
	role.TextScaled = true
	role.TextColor3 = color
	role.Text = subtitle
	role.Parent = frame
	frame.Parent = gui
	gui.Parent = adornee
end

-- florzinha: cabinho + petalas + miolo (so 3 pecas, porque sao muitas)
local function flower(parent: Instance, position: Vector3, color: Color3, size: number)
	local stem = decor(parent, "Cabinho", Vector3.new(0.12, 0.9, 0.12) * size, CFrame.new(position + Vector3.new(0, 0.45 * size, 0)), Color3.fromRGB(70, 150, 55))
	stem.CastShadow = false
	local top = position + Vector3.new(0, 0.95 * size, 0)
	ball(parent, "Petalas", Vector3.new(0.75, 0.22, 0.75) * size, CFrame.new(top), color).CastShadow = false
	ball(parent, "Miolo", Vector3.new(0.26, 0.2, 0.26) * size, CFrame.new(top + Vector3.new(0, 0.06, 0) * size), Color3.fromRGB(255, 215, 70)).CastShadow = false
end

local function flowerBox(parent: Instance, cf: CFrame, length: number, rng: Random)
	decor(parent, "Floreira", Vector3.new(length, 1, 1.4), cf * CFrame.new(0, 0.5, 0), WOOD, Enum.Material.WoodPlanks)
	decor(parent, "Terra", Vector3.new(length - 0.3, 0.1, 1.1), cf * CFrame.new(0, 1.02, 0), Color3.fromRGB(100, 66, 40), Enum.Material.Ground)
	local count = math.max(2, math.floor(length / 1.2))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count
		flower(parent, (cf * CFrame.new(x, 1, rng:NextNumber(-0.25, 0.25))).Position, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], 1.1)
	end
end

---------------------------------------------------------------------
-- Jardins
---------------------------------------------------------------------

local function buildPlot(index: number, center: Vector3, rotation: number, parent: Instance, rng: Random)
	local L = MapBuilder.Layout
	local cf = CFrame.new(center) * CFrame.Angles(0, rotation, 0)
	local model = Instance.new("Model")
	model.Name = "Jardim" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	part(model, "Base", Vector3.new(L.plotHalfX * 2, 0.2, L.plotHalfZ * 2), at(0, 0, 0), Color3.fromRGB(110, 185, 80), Enum.Material.Grass)
	local bedWidth = L.bedOuter - L.bedInner
	local bedLength = L.bedZMax - L.bedZMin
	local bedCenterZ = (L.bedZMax + L.bedZMin) / 2
	for _, side in { -1, 1 } do
		local bedX = side * (L.bedInner + bedWidth / 2)
		local bed = part(model, "Canteiro", Vector3.new(bedWidth, 0.5, bedLength), at(bedX, 0, bedCenterZ), Color3.fromRGB(125, 82, 50), Enum.Material.Ground)
		bed:SetAttribute("Canteiro", true)
		-- moldura de madeira em volta do canteiro
		for _, dz in { -1, 1 } do
			decor(model, "Moldura", Vector3.new(bedWidth + 0.9, 0.7, 0.45), at(bedX, 0.25, bedCenterZ + dz * (bedLength / 2 + 0.22)), WOOD_DARK, Enum.Material.Wood)
		end
		for _, dx in { -1, 1 } do
			decor(model, "Moldura", Vector3.new(0.45, 0.7, bedLength), at(bedX + dx * (bedWidth / 2 + 0.22), 0.25, bedCenterZ), WOOD_DARK, Enum.Material.Wood)
		end
		-- sulcos na terra
		for i = 1, 4 do
			local x = bedX - bedWidth / 2 + i * bedWidth / 5
			decor(model, "Sulco", Vector3.new(0.35, 0.04, bedLength - 1), at(x, 0.27, bedCenterZ), Color3.fromRGB(105, 68, 40), Enum.Material.Ground)
		end
	end
	part(model, "Caminho", Vector3.new(L.bedInner * 2, 0.3, L.plotHalfZ * 2 - 1), at(0, 0, 0), Color3.fromRGB(215, 190, 140), Enum.Material.Sand)
	-- pedrinhas no caminho
	for z = -L.plotHalfZ + 3, L.plotHalfZ - 3, 4 do
		local stone = cylinderPart(model, "Pedra", 0.12, 2.4 + rng:NextNumber(-0.3, 0.3), at(rng:NextNumber(-0.5, 0.5), 0.2, z), STONE, Enum.Material.Slate)
		stone.CastShadow = false
	end

	-- cerca
	-- skipStart/skipEnd evitam dois postes no mesmo canto
	local function fence(x1: number, z1: number, x2: number, z2: number, skipStart: boolean?, skipEnd: boolean?)
		local a = Vector3.new(x1, 0, z1)
		local b = Vector3.new(x2, 0, z2)
		local length = (b - a).Magnitude
		local mid = (a + b) / 2
		for _, y in { 1.1, 2.2 } do
			part(model, "Cerca", Vector3.new(0.35, 0.35, length), cf * CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(b.X, y, b.Z)), WOOD, Enum.Material.Wood)
		end
		local posts = math.max(1, math.floor(length / 6))
		for i = 0, posts do
			if not ((i == 0 and skipStart) or (i == posts and skipEnd)) then
				local p = a:Lerp(b, i / posts)
				part(model, "Poste", Vector3.new(0.6, 3, 0.6), at(p.X, 1.5, p.Z), WOOD, Enum.Material.Wood)
				decor(model, "Tampa", Vector3.new(0.8, 0.25, 0.8), at(p.X, 3.1, p.Z), WOOD_LIGHT, Enum.Material.Wood)
			end
		end
	end
	local hx, hz = L.plotHalfX, L.plotHalfZ
	fence(-hx, -hz, -hx, hz)
	fence(hx, -hz, hx, hz)
	fence(-hx, hz, hx, hz, true, true)
	fence(-hx, -hz, -5, -hz, true, false)
	fence(5, -hz, hx, -hz, false, true)

	-- arco de entrada com a placa do dono
	for _, x in { -5.4, 5.4 } do
		part(model, "PosteArco", Vector3.new(0.9, 8, 0.9), at(x, 4, -hz), WOOD_DARK, Enum.Material.Wood)
		decor(model, "Tampa", Vector3.new(1.2, 0.35, 1.2), at(x, 8.15, -hz), WOOD_LIGHT, Enum.Material.Wood)
		for i = 1, 5 do -- trepadeira com florzinhas no poste
			local y = 1.2 + i * 1.25
			ball(model, "Folha", Vector3.new(0.7, 0.55, 0.45), at(x + (if i % 2 == 0 then 0.42 else -0.42), y, -hz - 0.35), Color3.fromRGB(70, 160, 60))
			if i % 2 == 1 then
				ball(model, "Flor", Vector3.new(0.3, 0.3, 0.3), at(x, y + 0.3, -hz - 0.55), FLOWER_COLORS[(index + i) % #FLOWER_COLORS + 1])
			end
		end
	end
	decor(model, "Viga", Vector3.new(12.4, 0.7, 0.9), at(0, 7.4, -hz), WOOD_DARK, Enum.Material.Wood)
	local board = part(model, "Placa", Vector3.new(11, 2.8, 0.4), at(0, 9.3, -hz - 0.1), WOOD_LIGHT, Enum.Material.WoodPlanks)
	board.CanCollide = false
	for _, x in { -5.6, 5.6 } do
		decor(model, "Moldura", Vector3.new(0.3, 3.1, 0.55), at(x, 9.3, -hz - 0.1), WOOD_DARK, Enum.Material.Wood)
	end
	for _, y in { 7.85, 10.75 } do
		decor(model, "Moldura", Vector3.new(11.5, 0.3, 0.55), at(0, y, -hz - 0.1), WOOD_DARK, Enum.Material.Wood)
	end
	local signLabel = surfaceText(board, "Jardim Livre", Color3.fromRGB(70, 45, 20))
	signLabel.TextStrokeTransparency = 1
	-- floreiras dos dois lados da entrada
	for _, x in { -9, 9 } do
		flowerBox(model, at(x, 0, -hz - 1.6), 5, rng)
	end
	-- carrinho de mao e saco de adubo perto da entrada (dentro do jardim, fora dos canteiros)
	decor(model, "Carrinho", Vector3.new(1.8, 0.8, 2.6), at(-22, 1, -hz + 3), Color3.fromRGB(70, 120, 200), Enum.Material.Metal)
	cylinderPart(model, "Roda", 0.3, 1, at(-22, 0.5, -hz + 1.4) * CFrame.Angles(0, 0, math.pi / 2), BLACK)
	decor(model, "Saco", Vector3.new(1.4, 1.6, 1), at(22, 0.9, -hz + 3) * CFrame.Angles(0, 0.3, 0.1), Color3.fromRGB(190, 160, 110), Enum.Material.Fabric)

	local plantsFolder = Instance.new("Folder")
	plantsFolder.Name = "Plantas"
	plantsFolder.Parent = model
	model.Parent = parent

	return {
		index = index,
		model = model,
		cframe = cf,
		plantsFolder = plantsFolder,
		signLabel = signLabel,
		spawnCFrame = cf * CFrame.new(0, 3, -hz + 3) * CFrame.Angles(0, math.pi, 0),
		owner = nil :: Player?,
	}
end

---------------------------------------------------------------------
-- Lojas
---------------------------------------------------------------------

-- NPC com avatar no estilo Roblox (cabeca, tronco, bracos, pernas, cabelo, chapeu, roupa)
local function buildNpc(parent: Instance, cf: CFrame, look, name: string, role: string)
	local npc = Instance.new("Model")
	npc.Name = "NPC_" .. name
	local pieces = {}
	local function add(piece: BasePart)
		piece.CanCollide = false
		table.insert(pieces, piece)
		return piece
	end
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local skin = look.skin
	-- pernas e sapatos
	for _, x in { -0.5, 0.5 } do
		add(part(npc, if x < 0 then "PernaEsquerda" else "PernaDireita", Vector3.new(1, 2, 1), at(x, 1, 0), look.pants))
		add(part(npc, "Sapato", Vector3.new(1.05, 0.35, 1.15), at(x, 0.18, -0.05), look.shoes))
	end
	add(part(npc, "Tronco", Vector3.new(2, 2, 1), at(0, 3, 0), look.shirt))
	add(part(npc, "BracoEsquerdo", Vector3.new(1, 2, 1), at(-1.5, 3, 0), look.sleeves or look.shirt))
	add(part(npc, "BracoDireito", Vector3.new(1, 2, 1), at(1.5, 3, 0), look.sleeves or look.shirt))
	for _, x in { -1.5, 1.5 } do
		add(part(npc, "Mao", Vector3.new(0.95, 0.45, 0.95), at(x, 1.85, 0), skin))
	end
	local head = add(part(npc, "Cabeca", Vector3.new(2, 1, 1), at(0, 4.5, 0), skin))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	-- rosto
	for _, x in { -0.25, 0.25 } do
		add(ball(npc, "Olho", Vector3.new(0.2, 0.28, 0.08), at(x, 4.62, -0.6), BLACK))
		add(ball(npc, "Brilho", Vector3.new(0.07, 0.08, 0.04), at(x + 0.04, 4.68, -0.64), WHITE))
		add(part(npc, "Sobrancelha", Vector3.new(0.28, 0.06, 0.04), at(x, 4.86, -0.61), look.hair))
	end
	add(part(npc, "Sorriso", Vector3.new(0.36, 0.07, 0.04), at(0, 4.27, -0.62), BLACK))
	for _, x in { -0.2, 0.2 } do
		add(part(npc, "Sorriso", Vector3.new(0.1, 0.07, 0.04), at(x, 4.31, -0.62), BLACK))
		add(ball(npc, "Bochecha", Vector3.new(0.2, 0.12, 0.04), at(x * 2.1, 4.4, -0.58), Color3.fromRGB(255, 160, 160)))
	end
	-- cabelo
	if look.hairStyle ~= "bald" then
		add(part(npc, "Cabelo", Vector3.new(1.32, 0.35, 1.3), at(0, 5.12, 0.02), look.hair))
		add(part(npc, "Cabelo", Vector3.new(1.32, 0.9, 0.3), at(0, 4.72, 0.52), look.hair))
		if look.hairStyle == "long" then
			add(part(npc, "Cabelo", Vector3.new(1.45, 1.9, 0.35), at(0, 4.05, 0.58), look.hair))
			for _, x in { -0.68, 0.68 } do
				add(part(npc, "Cabelo", Vector3.new(0.18, 1.4, 0.9), at(x, 4.35, 0.12), look.hair))
			end
		end
	end
	if look.beard then
		add(ball(npc, "Barba", Vector3.new(1.05, 0.65, 0.5), at(0, 4.1, -0.42), look.beard))
		add(part(npc, "Bigode", Vector3.new(0.6, 0.12, 0.1), at(0, 4.36, -0.64), look.beard))
	end
	if look.glasses then
		for _, x in { -0.25, 0.25 } do
			local lens = add(ball(npc, "Lente", Vector3.new(0.38, 0.32, 0.05), at(x, 4.62, -0.66), Color3.fromRGB(40, 40, 50)))
			lens.Transparency = 0.45
		end
		add(part(npc, "Armacao", Vector3.new(0.22, 0.05, 0.05), at(0, 4.64, -0.67), BLACK))
	end
	-- chapeu
	if look.hat == "straw" then
		add(cylinderPart(npc, "Chapeu", 0.12, 2.7, at(0, 5.28, 0), look.hatColor))
		add(cylinderPart(npc, "Chapeu", 0.6, 1.4, at(0, 5.6, 0), look.hatColor))
		add(cylinderPart(npc, "Fita", 0.16, 1.43, at(0, 5.38, 0), Color3.fromRGB(200, 60, 50)))
	elseif look.hat == "hardhat" then
		add(ball(npc, "Capacete", Vector3.new(1.5, 0.8, 1.5), at(0, 5.18, 0), look.hatColor))
		add(cylinderPart(npc, "Aba", 0.08, 1.75, at(0, 4.98, 0), look.hatColor))
	elseif look.hat == "cap" then
		add(ball(npc, "Bone", Vector3.new(1.38, 0.62, 1.38), at(0, 5.15, 0), look.hatColor))
		add(part(npc, "Aba", Vector3.new(1, 0.08, 0.65), at(0, 5, -0.78), look.hatColor))
	elseif look.hat == "bow" then
		for _, x in { -0.32, 0.32 } do
			add(ball(npc, "Laco", Vector3.new(0.5, 0.42, 0.2), at(x, 5.32, 0.35), look.hatColor))
		end
		add(ball(npc, "Laco", Vector3.new(0.22, 0.22, 0.22), at(0, 5.32, 0.35), look.hatColor))
	end
	-- roupa por cima
	if look.outfit == "overalls" then
		add(part(npc, "Macacao", Vector3.new(1.5, 1.0, 0.12), at(0, 2.7, -0.52), look.outfitColor))
		for _, x in { -0.55, 0.55 } do
			add(part(npc, "Alca", Vector3.new(0.22, 1.1, 0.1), at(x, 3.45, -0.53), look.outfitColor))
			add(ball(npc, "Botao", Vector3.new(0.12, 0.12, 0.05), at(x, 3.05, -0.6), Color3.fromRGB(240, 200, 60)))
		end
	elseif look.outfit == "apron" then
		add(part(npc, "Avental", Vector3.new(1.6, 2.1, 0.1), at(0, 2.55, -0.55), look.outfitColor))
		add(part(npc, "Bolso", Vector3.new(0.8, 0.4, 0.06), at(0, 2.2, -0.62), look.outfitColor:Lerp(Color3.new(0, 0, 0), 0.15)))
	elseif look.outfit == "vest" then
		for _, x in { -0.6, 0.6 } do
			add(part(npc, "Colete", Vector3.new(0.75, 2, 0.1), at(x, 3, -0.53), look.outfitColor))
			add(part(npc, "Faixa", Vector3.new(0.75, 0.12, 0.06), at(x, 2.6, -0.6), Color3.fromRGB(230, 230, 230)))
		end
		add(part(npc, "Cinto", Vector3.new(2.05, 0.25, 1.05), at(0, 2.1, 0), Color3.fromRGB(90, 60, 40)))
	elseif look.outfit == "dress" then
		add(part(npc, "Vestido", Vector3.new(2.3, 1.7, 1.3), at(0, 1.45, 0), look.outfitColor))
	end
	for _, piece in pieces do
		piece.CastShadow = true
	end
	npc.PrimaryPart = head
	npc:SetAttribute("Npc", name)
	CollectionService:AddTag(npc, "LojaNpc")
	npc.Parent = parent
	billboard(head, name, role, look.tagColor or Color3.fromRGB(255, 220, 90), 3)
	return npc
end

-- enfeites tematicos de cada loja (prateleiras no fundo e coisas na frente)
local function stallGoods(model: Model, cf: CFrame, info, rng: Random)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- prateleiras no fundo
	for _, y in { 4.3, 6.3 } do
		decor(model, "Prateleira", Vector3.new(12, 0.3, 1.2), at(0, y, 3.9), WOOD_DARK, Enum.Material.Wood)
		for i = 1, 8 do
			local x = -5.6 + (i - 1) * 1.6
			local color = info.goods[(i + math.floor(y)) % #info.goods + 1]
			if info.id == "Seeds" then -- pacotinhos de semente
				decor(model, "Pacote", Vector3.new(0.9, 1.2, 0.15), at(x, y + 0.75, 3.75) * CFrame.Angles(math.rad(-8), 0, 0), color)
				decor(model, "Etiqueta", Vector3.new(0.7, 0.35, 0.05), at(x, y + 0.95, 3.66) * CFrame.Angles(math.rad(-8), 0, 0), WHITE)
			elseif info.id == "Sell" then -- potes e frutas
				ball(model, "Fruta", Vector3.new(0.85, 0.85, 0.85), at(x, y + 0.55, 3.8), color)
			else -- regadores e ferramentas
				decor(model, "Ferramenta", Vector3.new(0.9, 0.8, 0.6), at(x, y + 0.55, 3.8), color, Enum.Material.Metal)
				decor(model, "Bico", Vector3.new(0.5, 0.12, 0.12), at(x + 0.55, y + 0.75, 3.8) * CFrame.Angles(0, 0, math.rad(30)), color, Enum.Material.Metal)
			end
		end
	end
	-- caixotes e barris na frente da loja
	for index, x in { -9.6, 9.6 } do
		decor(model, "Caixote", Vector3.new(2.6, 1.8, 2.6), at(x, 0.9, -4) * CFrame.Angles(0, math.rad(index * 7), 0), WOOD, Enum.Material.WoodPlanks)
		for i = 1, 4 do
			local color = info.goods[(i + index) % #info.goods + 1]
			if info.id == "Gear" then
				decor(model, "Saco", Vector3.new(1, 1.2, 0.8), at(x - 0.6 + (i % 2) * 1.2, 2.2, -4.6 + math.floor((i - 1) / 2) * 1.2), Color3.fromRGB(190, 160, 110), Enum.Material.Fabric)
			else
				ball(model, "Produto", Vector3.new(1, 1, 1), at(x - 0.6 + (i % 2) * 1.2, 2, -4.6 + math.floor((i - 1) / 2) * 1.2), color)
			end
		end
		local barrel = cylinderPart(model, "Barril", 2.2, 1.9, at(x, 1.1, -1.2), WOOD_DARK, Enum.Material.Wood)
		barrel.CastShadow = true
		for _, y in { 0.45, 1.75 } do
			cylinderPart(model, "Aro", 0.18, 1.96, at(x, y, -1.2), Color3.fromRGB(80, 80, 90), Enum.Material.Metal)
		end
	end
	if info.id == "Sell" then -- balanca e moedas no balcao
		decor(model, "Balanca", Vector3.new(0.3, 1.4, 0.3), at(5, 4.1, -3), Color3.fromRGB(200, 170, 60), Enum.Material.Metal)
		decor(model, "Braco", Vector3.new(2.4, 0.15, 0.15), at(5, 4.8, -3), Color3.fromRGB(200, 170, 60), Enum.Material.Metal)
		for _, dx in { -1.1, 1.1 } do
			cylinderPart(model, "Prato", 0.12, 0.9, at(5 + dx, 4.4, -3), Color3.fromRGB(220, 190, 80), Enum.Material.Metal)
		end
		for i = 1, 5 do
			cylinderPart(model, "Moeda", 0.12, 0.6, at(-5 + rng:NextNumber(-0.3, 0.3), 3.45 + i * 0.13, -3), Color3.fromRGB(255, 205, 50), Enum.Material.Metal)
		end
	end
end

local function buildStall(parent: Instance, info, rng: Random)
	local cf = CFrame.new(info.position) * CFrame.Angles(0, info.rotation, 0)
	local model = Instance.new("Model")
	model.Name = "Loja_" .. info.id

	-- piso de madeira
	part(model, "Piso", Vector3.new(16, 0.3, 11), cf * CFrame.new(0, 0.15, 0.2), WOOD_LIGHT, Enum.Material.WoodPlanks)
	local counter = part(model, "Balcao", Vector3.new(14, 3, 3), cf * CFrame.new(0, 1.5, -3), WOOD, Enum.Material.WoodPlanks)
	part(model, "Tampo", Vector3.new(14.6, 0.4, 3.6), cf * CFrame.new(0, 3.2, -3), WOOD_LIGHT, Enum.Material.Wood)
	-- faixa colorida na frente do balcao
	decor(model, "Faixa", Vector3.new(14.1, 0.8, 0.1), cf * CFrame.new(0, 2.2, -4.55), info.roofA)
	for _, x in { -7, 7 } do
		for _, z in { -4.5, 4.5 } do
			part(model, "Pilar", Vector3.new(0.7, 8.5, 0.7), cf * CFrame.new(x, 4.25, z), WOOD, Enum.Material.Wood)
		end
	end
	part(model, "Fundo", Vector3.new(14, 8, 0.5), cf * CFrame.new(0, 4, 4.5), WOOD_LIGHT, Enum.Material.WoodPlanks)
	for i = 0, 7 do
		local color = if i % 2 == 0 then info.roofA else info.roofB
		part(model, "Telhado", Vector3.new(1.9, 0.4, 11), cf * CFrame.new(-6.65 + i * 1.9, 8.8, 0) * CFrame.Angles(math.rad(-8), 0, 0), color)
		-- babado do toldo
		ball(model, "Babado", Vector3.new(1.9, 1.1, 0.35), cf * CFrame.new(-6.65 + i * 1.9, 9.25 - 5.45 * math.sin(math.rad(8)) - 0.45, -5.45), color)
	end
	-- placa com moldura
	local sign = part(model, "Placa", Vector3.new(12, 2.4, 0.4), cf * CFrame.new(0, 10.6, -4.8), WHITE)
	sign.CanCollide = false
	for _, x in { -6.15, 6.15 } do
		decor(model, "Moldura", Vector3.new(0.3, 2.7, 0.55), cf * CFrame.new(x, 10.6, -4.8), WOOD_DARK, Enum.Material.Wood)
	end
	for _, y in { 9.3, 11.9 } do
		decor(model, "Moldura", Vector3.new(12.6, 0.3, 0.55), cf * CFrame.new(0, y, -4.8), WOOD_DARK, Enum.Material.Wood)
	end
	surfaceText(sign, info.icon .. " " .. info.title, info.roofA)
	-- lampioes pendurados nos pilares da frente
	for _, x in { -7, 7 } do
		decor(model, "Gancho", Vector3.new(0.12, 0.8, 0.12), cf * CFrame.new(x, 7.6, -5.1), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		local lamp = decor(model, "Lampiao", Vector3.new(0.7, 0.9, 0.7), cf * CFrame.new(x, 6.8, -5.1), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
		lamp.CastShadow = false
		decor(model, "TampaLampiao", Vector3.new(0.9, 0.2, 0.9), cf * CFrame.new(x, 7.3, -5.1), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	end

	-- produtos decorativos no balcao
	for i = 1, 5 do
		local color = info.goods[(i - 1) % #info.goods + 1]
		ball(model, "Produto", Vector3.new(1, 1, 1), cf * CFrame.new(-5 + i * 1.7, 3.9, -3), color)
	end
	stallGoods(model, cf, info, rng)

	buildNpc(model, cf * CFrame.new(0, 0, 0.8), info.look, info.npc, info.title)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AbrirLoja"
	prompt.ActionText = info.action
	prompt.ObjectText = info.title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Shop", info.id)
	prompt.Parent = counter

	model.Parent = parent
	return cf * CFrame.new(0, 3, -9) * CFrame.Angles(0, math.pi, 0)
end

---------------------------------------------------------------------
-- Estufa de vidro (decoracao no 4o canto das lojas)
---------------------------------------------------------------------

local function buildGreenhouse(parent: Instance, position: Vector3, rotation: number, rng: Random)
	local cf = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	local model = Instance.new("Model")
	model.Name = "Estufa"
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local frame = Color3.fromRGB(245, 245, 240)
	local glassColor = Color3.fromRGB(190, 230, 245)
	local function glass(size: Vector3, where: CFrame)
		local pane = decor(model, "Vidro", size, where, glassColor, Enum.Material.Glass)
		pane.Transparency = 0.6
		pane.CastShadow = false
		return pane
	end
	part(model, "Piso", Vector3.new(14, 0.3, 11), at(0, 0.15, 0), Color3.fromRGB(200, 190, 170), Enum.Material.Slate)
	-- paredes de vidro (com porta na frente) e armacao branca
	glass(Vector3.new(14, 6, 0.15), at(0, 3.3, 5.4))
	glass(Vector3.new(0.15, 6, 11), at(-7, 3.3, 0))
	glass(Vector3.new(0.15, 6, 11), at(7, 3.3, 0))
	glass(Vector3.new(4.6, 6, 0.15), at(-4.7, 3.3, -5.4))
	glass(Vector3.new(4.6, 6, 0.15), at(4.7, 3.3, -5.4))
	glass(Vector3.new(4.8, 1.3, 0.15), at(0, 5.65, -5.4))
	for _, x in { -7, -2.4, 2.4, 7 } do
		for _, z in { -5.4, 5.4 } do
			part(model, "Armacao", Vector3.new(0.3, 6.3, 0.3), at(x, 3.3, z), frame, Enum.Material.Metal)
		end
	end
	for _, z in { -5.4, 0, 5.4 } do
		decor(model, "Viga", Vector3.new(14.3, 0.3, 0.3), at(0, 6.4, z), frame, Enum.Material.Metal)
	end
	-- telhado de vidro em duas aguas
	for _, side in { -1, 1 } do
		glass(Vector3.new(7.6, 0.15, 11.4), at(side * 3.5, 7.75, 0) * CFrame.Angles(0, 0, math.rad(side * -21)))
		decor(model, "Caibro", Vector3.new(7.6, 0.25, 0.25), at(side * 3.5, 7.75, -5.6) * CFrame.Angles(0, 0, math.rad(side * -21)), frame, Enum.Material.Metal)
		decor(model, "Caibro", Vector3.new(7.6, 0.25, 0.25), at(side * 3.5, 7.75, 5.6) * CFrame.Angles(0, 0, math.rad(side * -21)), frame, Enum.Material.Metal)
	end
	decor(model, "Cumeeira", Vector3.new(0.35, 0.35, 11.6), at(0, 9.1, 0), frame, Enum.Material.Metal)
	-- mesas com vasos de flores dentro
	for _, x in { -4, 4 } do
		decor(model, "Mesa", Vector3.new(3, 0.25, 8.5), at(x, 2.2, 0.5), WOOD_LIGHT, Enum.Material.WoodPlanks)
		for _, dz in { -3.6, 3.6 } do
			for _, dx in { -1.2, 1.2 } do
				decor(model, "PeMesa", Vector3.new(0.25, 2.1, 0.25), at(x + dx, 1.1, 0.5 + dz), WOOD_DARK, Enum.Material.Wood)
			end
		end
		for i = 0, 3 do
			local potCF = at(x, 2.33, -2.6 + i * 2.1)
			cylinderPart(model, "Vaso", 0.9, 1.1, potCF * CFrame.new(0, 0.45, 0), Color3.fromRGB(200, 110, 70), Enum.Material.Slate)
			ball(model, "Folhas", Vector3.new(1.3, 1, 1.3), potCF * CFrame.new(0, 1.2, 0), Color3.fromRGB(70, 160, 60))
			for j = 1, 3 do
				local angle = j * math.pi * 2 / 3 + i
				ball(model, "Flor", Vector3.new(0.42, 0.3, 0.42), potCF * CFrame.new(math.cos(angle) * 0.4, 1.6, math.sin(angle) * 0.4), FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)])
			end
		end
	end
	-- vasos grandes no fundo e floreiras do lado de fora
	for _, x in { -5.5, 0, 5.5 } do
		cylinderPart(model, "VasoGrande", 1.6, 2, at(x, 1.1, 4.3), Color3.fromRGB(190, 100, 65), Enum.Material.Slate)
		ball(model, "Planta", Vector3.new(2.6, 3.2, 2.6), at(x, 3.4, 4.3), Color3.fromRGB(60, 150 + rng:NextInteger(0, 30), 60))
	end
	for _, x in { -9.6, 9.6 } do
		flowerBox(model, at(x, 0, -3), 4, rng)
	end
	local sign = part(model, "Placa", Vector3.new(7, 1.6, 0.3), at(0, 7.4, -5.75), WHITE)
	sign.CanCollide = false
	surfaceText(sign, "🌸 Estufa", Color3.fromRGB(90, 160, 70))
	model.Parent = parent
end

---------------------------------------------------------------------
-- Praca central com chafariz
---------------------------------------------------------------------

local function buildPlaza(parent: Instance, rng: Random)
	local plaza = Instance.new("Model")
	plaza.Name = "Praca"
	local floor = cylinderPart(plaza, "Piso", 0.3, 34, CFrame.new(0, 0.12, 0), STONE, Enum.Material.Slate)
	floor.CanCollide = true
	cylinderPart(plaza, "Borda", 0.32, 35.4, CFrame.new(0, 0.1, 0), STONE_DARK, Enum.Material.Slate)
	cylinderPart(plaza, "Anel", 0.34, 22, CFrame.new(0, 0.13, 0), Color3.fromRGB(225, 215, 195), Enum.Material.Slate)
	cylinderPart(plaza, "Anel", 0.36, 20.6, CFrame.new(0, 0.14, 0), STONE, Enum.Material.Slate)

	-- chafariz
	local wall = cylinderPart(plaza, "Chafariz", 1.6, 13, CFrame.new(0, 0.9, 0), STONE_DARK, Enum.Material.Slate)
	wall.CanCollide = true
	-- borda em anel (feita de pedacos, para a agua aparecer no meio)
	for i = 0, 15 do
		local angle = i * math.pi / 8
		decor(plaza, "BordaChafariz", Vector3.new(0.9, 0.35, 2.75), CFrame.new(math.cos(angle) * 6.55, 1.85, math.sin(angle) * 6.55) * CFrame.Angles(0, -angle, 0), STONE, Enum.Material.Slate)
	end
	local water = cylinderPart(plaza, "Agua", 0.12, 11.9, CFrame.new(0, 1.74, 0), WATER, Enum.Material.Glass)
	water.Transparency = 0.25
	cylinderPart(plaza, "Coluna", 4.4, 1.6, CFrame.new(0, 3.6, 0), STONE, Enum.Material.Slate)
	cylinderPart(plaza, "Bacia", 0.7, 5.2, CFrame.new(0, 5.6, 0), STONE_DARK, Enum.Material.Slate)
	local topWater = cylinderPart(plaza, "AguaTopo", 0.12, 4.6, CFrame.new(0, 5.98, 0), WATER, Enum.Material.Glass)
	topWater.Transparency = 0.2
	local spout = ball(plaza, "Bica", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 6.5, 0), STONE, Enum.Material.Slate)
	local jets = Instance.new("ParticleEmitter")
	jets.Name = "Jatos"
	jets.Color = ColorSequence.new(Color3.fromRGB(170, 215, 255))
	jets.LightEmission = 0.3
	jets.Transparency = NumberSequence.new(0.25, 0.8)
	jets.Size = NumberSequence.new(0.35, 0.15)
	jets.Lifetime = NumberRange.new(1.1, 1.5)
	jets.Speed = NumberRange.new(7, 9)
	jets.SpreadAngle = Vector2.new(25, 25)
	jets.Acceleration = Vector3.new(0, -18, 0)
	jets.Rate = 45
	jets.Parent = spout
	-- peixinhos na agua
	for i = 1, 4 do
		local angle = i * math.pi / 2 + 0.4
		ball(plaza, "Peixe", Vector3.new(0.7, 0.25, 0.35), CFrame.new(math.cos(angle) * 4, 1.55, math.sin(angle) * 4) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(255, 140, 40))
	end

	-- bancos e canteiros de flores em volta
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local benchCF = CFrame.new(math.cos(angle) * 13.5, 0, math.sin(angle) * 13.5) * CFrame.Angles(0, -angle - math.pi / 2, 0)
		decor(plaza, "Banco", Vector3.new(5, 0.35, 1.6), benchCF * CFrame.new(0, 1.4, 0), WOOD, Enum.Material.WoodPlanks)
		decor(plaza, "Encosto", Vector3.new(5, 1.2, 0.3), benchCF * CFrame.new(0, 2.2, 0.75), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -2.1, 2.1 } do
			decor(plaza, "PeBanco", Vector3.new(0.35, 1.3, 1.4), benchCF * CFrame.new(x, 0.65, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		end
		local bedAngle = angle + math.pi / 4
		local bedCF = CFrame.new(math.cos(bedAngle) * 14.5, 0, math.sin(bedAngle) * 14.5)
		cylinderPart(plaza, "Canteiro", 0.8, 4.6, bedCF * CFrame.new(0, 0.5, 0), STONE_DARK, Enum.Material.Slate)
		cylinderPart(plaza, "Terra", 0.1, 4, bedCF * CFrame.new(0, 0.92, 0), Color3.fromRGB(100, 66, 40), Enum.Material.Ground)
		for j = 1, 7 do
			local a = j * math.pi * 2 / 7
			flower(plaza, (bedCF * CFrame.new(math.cos(a) * 1.3, 0.92, math.sin(a) * 1.3)).Position, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], 1.2)
		end
		ball(plaza, "Arbusto", Vector3.new(1.6, 1.4, 1.6), bedCF * CFrame.new(0, 1.5, 0), Color3.fromRGB(70, 160, 60))
	end

	-- placa de boas-vindas em um portal de madeira
	for _, x in { -14, 14 } do
		local post = part(plaza, "PostePortal", Vector3.new(1.2, 16, 1.2), CFrame.new(x, 8, 0), WOOD_DARK, Enum.Material.Wood)
		post.CanCollide = true
		decor(plaza, "Tampa", Vector3.new(1.6, 0.5, 1.6), CFrame.new(x, 16.2, 0), WOOD_LIGHT, Enum.Material.Wood)
		ball(plaza, "Arbusto", Vector3.new(2.6, 2, 2.6), CFrame.new(x, 1, 0), Color3.fromRGB(70, 160, 60))
	end
	local welcome = part(plaza, "Boas-vindas", Vector3.new(26, 5, 0.6), CFrame.new(0, 14, 0), Color3.fromRGB(255, 250, 235))
	welcome.CanCollide = false
	for _, y in { 11.35, 16.65 } do
		decor(plaza, "Moldura", Vector3.new(27, 0.4, 0.9), CFrame.new(0, y, 0), WOOD_DARK, Enum.Material.Wood)
	end
	surfaceText(welcome, "🌱 Cultive um Jardim 🌱", Color3.fromRGB(70, 150, 50), Enum.NormalId.Front)
	surfaceText(welcome, "🌱 Cultive um Jardim 🌱", Color3.fromRGB(70, 150, 50), Enum.NormalId.Back)
	for i = 1, 9 do -- florzinhas em cima da placa
		local x = -12 + (i - 1) * 3
		ball(plaza, "Folha", Vector3.new(1.4, 0.7, 0.9), CFrame.new(x, 17.1, 0), Color3.fromRGB(70, 160, 60))
		ball(plaza, "Flor", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + 0.3, 17.5, 0), FLOWER_COLORS[i % #FLOWER_COLORS + 1])
	end
	plaza.Parent = parent
end

---------------------------------------------------------------------
-- Decoracao
---------------------------------------------------------------------

local function buildTree(parent: Instance, position: Vector3, scale: number, rng: Random)
	local kind = rng:NextInteger(1, 10)
	if kind <= 2 then -- pinheiro em camadas
		local trunk = part(parent, "Tronco", Vector3.new(1.1, 5, 1.1) * scale, CFrame.new(position + Vector3.new(0, 2.5 * scale, 0)), Color3.fromRGB(100, 68, 42), Enum.Material.Wood)
		trunk.CastShadow = true
		trunk.CanCollide = false
		for i = 0, 3 do
			cylinderPart(parent, "Copa", 1.6 * scale, (7.5 - i * 1.7) * scale, CFrame.new(position + Vector3.new(0, (3.4 + i * 1.9) * scale, 0)), Color3.fromRGB(40, 120 + i * 8, 60))
		end
		ball(parent, "Topo", Vector3.new(1.4, 1.6, 1.4) * scale, CFrame.new(position + Vector3.new(0, 10.6 * scale, 0)), Color3.fromRGB(50, 150, 70))
		return
	end
	local trunk = part(parent, "Tronco", Vector3.new(1.2, 6, 1.2) * scale, CFrame.new(position + Vector3.new(0, 3 * scale, 0)), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	trunk.CastShadow = true
	for i = 1, 3 do -- raizes
		local angle = i * math.pi * 2 / 3 + rng:NextNumber(0, 1)
		ball(parent, "Raiz", Vector3.new(1.4, 0.6, 0.7) * scale, CFrame.new(position + Vector3.new(math.cos(angle) * 0.7, 0.2, math.sin(angle) * 0.7) * scale) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(100, 68, 42))
	end
	local blossom = kind == 3
	local base = if blossom then Color3.fromRGB(255, 175, 205) else Color3.fromRGB(60, 150, 55)
	local shades = { base, base:Lerp(WHITE, 0.12), base:Lerp(BLACK, 0.12) }
	local blobs = {
		{ Vector3.new(0, 7.5, 0), Vector3.new(7, 6, 7) },
		{ Vector3.new(1.9, 9.4, 0.5), Vector3.new(4.6, 4, 4.6) },
		{ Vector3.new(-1.8, 8.9, -0.9), Vector3.new(4.2, 3.8, 4.2) },
		{ Vector3.new(0.3, 8.6, 2), Vector3.new(4, 3.6, 4) },
		{ Vector3.new(-0.4, 10.4, -0.2), Vector3.new(3.6, 3, 3.6) },
	}
	for i, blob in blobs do
		ball(parent, "Copa", blob[2] * scale, CFrame.new(position + blob[1] * scale), shades[(i - 1) % #shades + 1])
	end
	if kind == 4 then -- macieira
		for i = 1, 7 do
			local angle = i * 0.9
			ball(parent, "Maca", Vector3.new(0.7, 0.7, 0.7) * scale, CFrame.new(position + Vector3.new(math.cos(angle) * 3.2, 6.6 + (i % 3) * 0.8, math.sin(angle) * 3.2) * scale), Color3.fromRGB(220, 40, 45))
		end
	end
end

local function buildBush(parent: Instance, position: Vector3, rng: Random)
	local size = rng:NextNumber(1.6, 3)
	local color = Color3.fromRGB(65, 150 + rng:NextInteger(0, 25), 55)
	ball(parent, "Arbusto", Vector3.new(size * 1.3, size, size * 1.2), CFrame.new(position + Vector3.new(0, size * 0.4, 0)), color)
	ball(parent, "Arbusto", Vector3.new(size, size * 0.8, size), CFrame.new(position + Vector3.new(size * 0.55, size * 0.3, size * 0.2)), color:Lerp(WHITE, 0.08))
	if rng:NextNumber() < 0.5 then -- frutinhas ou flores no arbusto
		local berry = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
		for i = 1, 4 do
			local angle = i * 1.6
			ball(parent, "Frutinha", Vector3.new(0.35, 0.35, 0.35), CFrame.new(position + Vector3.new(math.cos(angle) * size * 0.55, size * (0.55 + (i % 2) * 0.2), math.sin(angle) * size * 0.5)), berry)
		end
	end
end

local function buildRock(parent: Instance, position: Vector3, rng: Random)
	local size = rng:NextNumber(1, 3)
	local gray = Color3.fromRGB(140, 140, 135):Lerp(Color3.fromRGB(180, 175, 165), rng:NextNumber())
	ball(parent, "Pedra", Vector3.new(size * 1.4, size * 0.8, size), CFrame.new(position + Vector3.new(0, size * 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), gray, Enum.Material.Slate)
	if size > 2 then
		ball(parent, "Pedra", Vector3.new(size * 0.6, size * 0.45, size * 0.5), CFrame.new(position + Vector3.new(size * 0.7, 0.1, size * 0.3)), gray:Lerp(BLACK, 0.1), Enum.Material.Slate)
	end
end

local function buildLamp(parent: Instance, position: Vector3)
	local metal = Color3.fromRGB(55, 58, 68)
	cylinderPart(parent, "BaseLuz", 0.6, 1.4, CFrame.new(position + Vector3.new(0, 0.3, 0)), metal, Enum.Material.Metal)
	part(parent, "PosteLuz", Vector3.new(0.45, 8.4, 0.45), CFrame.new(position + Vector3.new(0, 4.6, 0)), metal, Enum.Material.Metal)
	decor(parent, "TopoLuz", Vector3.new(1.5, 0.25, 1.5), CFrame.new(position + Vector3.new(0, 8.9, 0)), metal, Enum.Material.Metal)
	local lamp = decor(parent, "Lampada", Vector3.new(1.1, 1.3, 1.1), CFrame.new(position + Vector3.new(0, 9.7, 0)), Color3.fromRGB(255, 235, 170), Enum.Material.Neon)
	lamp.CastShadow = false
	for _, offset in { Vector3.new(0.58, 0, 0.58), Vector3.new(-0.58, 0, 0.58), Vector3.new(0.58, 0, -0.58), Vector3.new(-0.58, 0, -0.58) } do
		decor(parent, "Grade", Vector3.new(0.12, 1.4, 0.12), CFrame.new(position + Vector3.new(0, 9.7, 0) + offset), metal, Enum.Material.Metal)
	end
	decor(parent, "Chapeu", Vector3.new(1.6, 0.3, 1.6), CFrame.new(position + Vector3.new(0, 10.5, 0)), metal, Enum.Material.Metal)
	ball(parent, "Ponta", Vector3.new(0.4, 0.4, 0.4), CFrame.new(position + Vector3.new(0, 10.8, 0)), metal, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 215, 150)
	light.Parent = lamp
	return light
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(95, 95, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 148, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.1
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.15
		atmosphere.Haze = 1
		atmosphere.Glare = 0.4
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Decay = Color3.fromRGB(120, 150, 200)
		atmosphere.Parent = Lighting
	end
	-- cores mais vivas, brilho suave nas luzes e raios de sol
	if not Lighting:FindFirstChild("CoresJardim") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "CoresJardim"
		color.Saturation = 0.15
		color.Contrast = 0.06
		color.Brightness = 0.02
		color.TintColor = Color3.fromRGB(255, 251, 242)
		color.Parent = Lighting
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "BrilhoJardim"
		bloom.Intensity = 0.5
		bloom.Size = 26
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
		local sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "RaiosJardim"
		sunRays.Intensity = 0.05
		sunRays.Spread = 0.6
		sunRays.Parent = Lighting
	end
	-- nuvens de verdade no ceu
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.7
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

-- lagos atras dos jardins do meio
local PONDS = { Vector3.new(0, 0, 124), Vector3.new(0, 0, -124) }
local POND_RADIUS = 15

local function nearPond(x: number, z: number, margin: number): boolean
	for _, pond in PONDS do
		local dx, dz = x - pond.X, z - pond.Z
		if dx * dx + dz * dz < (POND_RADIUS + 8 + margin) ^ 2 then
			return true
		end
	end
	return false
end

-- area livre para enfeites (fora da rua, dos jardins, das lojas, da praca e dos lagos)
local function isFree(x: number, z: number, margin: number): boolean
	local L = MapBuilder.Layout
	if math.abs(x) > 200 or math.abs(z) > 150 then
		return false
	end
	if nearPond(x, z, margin) then
		return false
	end
	if math.abs(z) < 23 + margin and math.abs(x) < 190 then
		return false
	end
	for _, cx in L.columns do
		for _, cz in { L.rowZ, -L.rowZ } do
			if math.abs(x - cx) < L.plotHalfX + 4 + margin and math.abs(z - cz) < L.plotHalfZ + 5 + margin then
				return false
			end
		end
	end
	for _, sx in { -40, 40 } do
		for _, sz in { -30, 30 } do
			if math.abs(x - sx) < 12 + margin and math.abs(z - sz) < 10 + margin then
				return false
			end
		end
	end
	return true
end

local function randomFreeSpot(rng: Random, margin: number): Vector3?
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-198, 198), rng:NextNumber(-148, 148)
		if isFree(x, z, margin) then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Terreno (grama de verdade, morros e lagos)
---------------------------------------------------------------------

-- Usa o terreno do Roblox: grama com folhinhas (Terrain > Decoration, ja ligado no arquivo
-- do lugar), morros suaves e lagos com agua. Sem terreno, usa uma peca de grama.
local function buildTerrain(map: Instance, rng: Random): Terrain?
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		part(map, "Chao", Vector3.new(900, 2, 800), CFrame.new(0, -1, 0), Color3.fromRGB(95, 170, 70), Enum.Material.Grass)
		return nil
	end
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 178, 72))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(88, 158, 62))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(226, 206, 156))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 88, 58))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 146, 140))
	terrain.WaterColor = Color3.fromRGB(55, 165, 205)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 8
	-- chao: o topo fica exatamente em y = 0
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(900, 16, 800), Enum.Material.Grass)
	-- morros no horizonte (fora da area de jogo)
	for i = 1, 26 do
		local angle = i * math.pi * 2 / 26 + rng:NextNumber(-0.08, 0.08)
		local distance = rng:NextNumber(280, 350)
		local radius = rng:NextNumber(45, 80)
		local center = Vector3.new(math.cos(angle) * distance * 1.2, -radius * 0.45, math.sin(angle) * distance)
		terrain:FillBall(center, radius, if i % 3 == 0 then Enum.Material.LeafyGrass else Enum.Material.Grass)
		if i % 4 == 0 then -- pedras aparecendo no morro
			terrain:FillBall(center + Vector3.new(radius * 0.3, radius * 0.4, 0), radius * 0.25, Enum.Material.Rock)
		end
	end
	-- lagos cheios (agua no nivel do chao) com margem de areia
	for _, pond in PONDS do
		terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -1, 0)), 2, POND_RADIUS + 5, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -3, 0)), 6, POND_RADIUS, Enum.Material.Water)
	end
	return terrain
end

-- enfeites do lago: vitorias-regias, taboas, pedras e um deque de madeira
local function buildPondDecor(parent: Instance, center: Vector3, rng: Random)
	local pond = Instance.new("Model")
	pond.Name = "Lago"
	for i = 1, 9 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(3, POND_RADIUS - 3)
		local position = center + Vector3.new(math.cos(angle) * radius, 0.06, math.sin(angle) * radius)
		local size = rng:NextNumber(1.6, 2.6)
		cylinderPart(pond, "VitoriaRegia", 0.08, size, CFrame.new(position), Color3.fromRGB(70, 160, 70))
		if i % 3 == 0 then
			ball(pond, "Flor", Vector3.new(0.6, 0.45, 0.6), CFrame.new(position + Vector3.new(0.2, 0.25, 0.1)), Color3.fromRGB(255, 160, 200))
		end
	end
	for i = 1, 16 do
		local angle = i * math.pi * 2 / 16 + rng:NextNumber(-0.15, 0.15)
		local radius = POND_RADIUS + rng:NextNumber(-0.5, 1.5)
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if i % 2 == 0 then -- taboas
			for j = 1, 3 do
				local offset = Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
				local height = rng:NextNumber(2.2, 3.4)
				decor(pond, "Taboa", Vector3.new(0.12, height, 0.12), CFrame.new(position + offset + Vector3.new(0, height / 2, 0)), Color3.fromRGB(80, 150, 60))
				decor(pond, "Espiga", Vector3.new(0.3, 0.7, 0.3), CFrame.new(position + offset + Vector3.new(0, height - 0.2, 0)), Color3.fromRGB(120, 80, 45))
			end
		else
			local size = rng:NextNumber(1, 2.2)
			ball(pond, "Pedra", Vector3.new(size * 1.4, size * 0.7, size), CFrame.new(position + Vector3.new(0, 0.15, 0)), Color3.fromRGB(150, 148, 140), Enum.Material.Slate)
		end
	end
	-- deque de madeira entrando no lago (virado para o jardim)
	local towardGarden = if center.Z > 0 then -1 else 1
	for i = 0, 4 do
		local z = center.Z + towardGarden * (POND_RADIUS + 3 - i * 2)
		decor(pond, "Tabua", Vector3.new(4, 0.3, 1.8), CFrame.new(center.X + 4, 0.35, z), WOOD_LIGHT, Enum.Material.WoodPlanks).CanCollide = true
		for _, x in { -1.8, 1.8 } do
			decor(pond, "Estaca", Vector3.new(0.35, 2.4, 0.35), CFrame.new(center.X + 4 + x, -0.8, z), WOOD_DARK, Enum.Material.Wood)
		end
	end
	pond.Parent = parent
end

---------------------------------------------------------------------
-- Construcao completa
---------------------------------------------------------------------

function MapBuilder.build()
	local old = workspace:FindFirstChild("Mapa")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Mapa"
	local rng = Random.new(2025) -- sempre o mesmo mapa

	setupLighting()

	local terrain = buildTerrain(map, rng)
	part(map, "Rua", Vector3.new(360, 0.2, 40), CFrame.new(0, 0, 0), Color3.fromRGB(220, 200, 150), Enum.Material.Sand)
	-- meio-fio de pedra (com aberturas nas entradas dos jardins)
	for _, z in { -20.3, 20.3 } do
		local edges = { -180, -86, -74, -6, 6, 74, 86, 180 }
		for i = 1, #edges - 1, 2 do
			local x1, x2 = edges[i], edges[i + 1]
			decor(map, "MeioFio", Vector3.new(x2 - x1, 0.4, 0.8), CFrame.new((x1 + x2) / 2, 0.2, z), STONE, Enum.Material.Slate)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 6)
	spawn.CFrame = CFrame.new(0, 0.2, -12)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = SMOOTH
	spawn.Parent = map

	buildPlaza(map, rng)

	-- jardins: 3 de cada lado da rua
	local L = MapBuilder.Layout
	local plots = {}
	for row = 1, 2 do
		local z = if row == 1 then L.rowZ else -L.rowZ
		local rotation = if row == 1 then 0 else math.pi
		for _, x in L.columns do
			table.insert(plots, buildPlot(#plots + 1, Vector3.new(x, 0, z), rotation, map, rng))
		end
	end

	if terrain then
		for _, plot in plots do
			local base = plot.model:FindFirstChild("Base")
			if base and base:IsA("BasePart") then
				base.Transparency = 1
			end
		end
	end

	-- lojas entre os jardins
	local stalls = {
		{
			id = "Seeds", title = "Sementes", icon = "🌱", npc = "Sam", action = "Comprar sementes",
			position = Vector3.new(-40, 0, 30), rotation = 0,
			roofA = Color3.fromRGB(70, 160, 60), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(225, 30, 55), Color3.fromRGB(60, 80, 210), Color3.fromRGB(240, 70, 110) },
			look = {
				tagColor = Color3.fromRGB(120, 220, 90),
				skin = Color3.fromRGB(255, 205, 160), hair = Color3.fromRGB(110, 70, 40), hairStyle = "short",
				hat = "straw", hatColor = Color3.fromRGB(235, 205, 120),
				shirt = Color3.fromRGB(90, 170, 70), pants = Color3.fromRGB(60, 90, 150), shoes = Color3.fromRGB(90, 60, 40),
				outfit = "overalls", outfitColor = Color3.fromRGB(60, 90, 150),
			},
		},
		{
			id = "Sell", title = "Venda", icon = "💰", npc = "Steven", action = "Vender frutos",
			position = Vector3.new(40, 0, 30), rotation = 0,
			roofA = Color3.fromRGB(230, 170, 30), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(255, 205, 40), Color3.fromRGB(255, 230, 120), Color3.fromRGB(225, 40, 50), Color3.fromRGB(120, 200, 70) },
			look = {
				tagColor = Color3.fromRGB(255, 205, 60),
				skin = Color3.fromRGB(240, 190, 150), hair = Color3.fromRGB(240, 210, 110), hairStyle = "short",
				hat = "cap", hatColor = Color3.fromRGB(230, 170, 30), glasses = true,
				shirt = Color3.fromRGB(70, 130, 210), pants = Color3.fromRGB(90, 90, 100), shoes = Color3.fromRGB(40, 40, 45),
				outfit = "apron", outfitColor = Color3.fromRGB(245, 205, 70),
			},
		},
		{
			id = "Gear", title = "Equipamentos", icon = "🔧", npc = "George", action = "Comprar equipamentos",
			position = Vector3.new(-40, 0, -30), rotation = math.pi,
			roofA = Color3.fromRGB(60, 120, 210), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(80, 140, 230), Color3.fromRGB(170, 170, 180), Color3.fromRGB(90, 200, 90), Color3.fromRGB(250, 200, 50) },
			look = {
				tagColor = Color3.fromRGB(110, 170, 255),
				skin = Color3.fromRGB(230, 180, 140), hair = Color3.fromRGB(150, 150, 150), hairStyle = "short",
				hat = "hardhat", hatColor = Color3.fromRGB(250, 200, 40), beard = Color3.fromRGB(170, 170, 170),
				shirt = Color3.fromRGB(110, 110, 120), pants = Color3.fromRGB(50, 50, 60), shoes = Color3.fromRGB(70, 50, 35),
				outfit = "vest", outfitColor = Color3.fromRGB(250, 130, 40),
			},
		},
	}
	local locations = {}
	local shopPositions = {}
	for _, info in stalls do
		locations[info.id] = buildStall(map, info, rng)
		shopPositions[info.id] = info.position
	end
	locations.Spawn = CFrame.new(0, 3, -12)
	buildGreenhouse(map, Vector3.new(40, 0, -30), math.pi, rng)

	-- decoracao
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decoracao"
	decorFolder.Parent = map
	-- postes entre as entradas dos jardins (x = -140, -100, ..., 140)
	local lights = {}
	for x = -140, 140, 40 do
		for _, z in { -19, 19 } do
			table.insert(lights, buildLamp(decorFolder, Vector3.new(x, 0, z + (if z > 0 then 2.2 else -2.2))))
		end
	end
	-- floreiras ao longo da rua, entre os postes
	for x = -160, 160, 40 do
		if math.abs(x) > 20 then
			for _, z in { -22, 22 } do
				if isFree(x, z + (if z > 0 then 3 else -3), -4) then
					flowerBox(decorFolder, CFrame.new(x, 0, z + (if z > 0 then 1.6 else -1.6)), 6, rng)
				end
			end
		end
	end
	-- arvores na borda do mapa e entre os jardins
	for x = -180, 180, 30 do
		local north = Vector3.new(x + (x % 20), 0, 115 + (x % 3) * 4)
		local south = Vector3.new(x - (x % 20), 0, -115 - (x % 3) * 4)
		if not (terrain and nearPond(north.X, north.Z, 2)) then
			buildTree(decorFolder, north, 1 + (x % 7) / 10, rng)
		end
		if not (terrain and nearPond(south.X, south.Z, 2)) then
			buildTree(decorFolder, south, 1 + (x % 5) / 10, rng)
		end
	end
	if terrain then
		for _, pond in PONDS do
			buildPondDecor(decorFolder, pond, rng)
		end
	end
	for _, x in { -150, -130, 130, 150 } do
		for _, z in { -60, -30, 30, 60 } do
			buildTree(decorFolder, Vector3.new(x, 0, z), 1.1, rng)
		end
	end
	for _ = 1, 18 do
		local spot = randomFreeSpot(rng, 6)
		if spot then
			buildTree(decorFolder, spot, rng:NextNumber(0.8, 1.3), rng)
		end
	end
	-- manchas de grama, flores, arbustos e pedras espalhados
	for _ = 1, 45 do
		local spot = randomFreeSpot(rng, 0)
		if spot then
			local tone = Color3.fromRGB(95, 170, 70):Lerp(if rng:NextNumber() < 0.5 then Color3.fromRGB(70, 140, 55) else Color3.fromRGB(140, 200, 90), rng:NextNumber(0.3, 0.7))
			local patch = cylinderPart(decorFolder, "Mancha", 0.06, rng:NextNumber(8, 20), CFrame.new(spot + Vector3.new(0, 0.02, 0)), tone, Enum.Material.Grass)
			patch.CastShadow = false
		end
	end
	for _ = 1, 60 do
		local spot = randomFreeSpot(rng, 0)
		if spot then
			local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
			for i = 1, rng:NextInteger(3, 6) do
				flower(decorFolder, spot + Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)), if i % 3 == 0 then FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)] else color, rng:NextNumber(0.9, 1.4))
			end
		end
	end
	for _ = 1, 34 do
		local spot = randomFreeSpot(rng, 2)
		if spot then
			buildBush(decorFolder, spot, rng)
		end
	end
	for _ = 1, 24 do
		local spot = randomFreeSpot(rng, 2)
		if spot then
			buildRock(decorFolder, spot, rng)
		end
	end
	-- morros no horizonte (fora da area de jogo); com terreno eles sao feitos de terreno
	for i = 1, if terrain then 0 else 26 do
		local angle = i * math.pi * 2 / 26 + rng:NextNumber(-0.08, 0.08)
		local distance = rng:NextNumber(270, 340)
		local width = rng:NextNumber(90, 150)
		local height = rng:NextNumber(35, 70)
		local tone = Color3.fromRGB(80, 150, 70):Lerp(Color3.fromRGB(60, 120, 80), rng:NextNumber())
		ball(decorFolder, "Morro", Vector3.new(width, height, width * 0.8), CFrame.new(math.cos(angle) * distance * 1.2, -height * 0.18, math.sin(angle) * distance) * CFrame.Angles(0, -angle, 0), tone, Enum.Material.Grass)
	end

	-- paredes invisiveis nas bordas
	local walls = {
		{ Vector3.new(420, 60, 2), Vector3.new(0, 30, 160) },
		{ Vector3.new(420, 60, 2), Vector3.new(0, 30, -160) },
		{ Vector3.new(2, 60, 320), Vector3.new(210, 30, 0) },
		{ Vector3.new(2, 60, 320), Vector3.new(-210, 30, 0) },
	}
	for _, wall in walls do
		local p = part(map, "Parede", wall[1], CFrame.new(wall[2]), WHITE)
		p.Transparency = 1
		p.CastShadow = false
	end

	map.Parent = workspace

	return {
		folder = map,
		plots = plots,
		locations = locations,
		shopPositions = shopPositions,
		lights = lights,
	}
end

return MapBuilder
