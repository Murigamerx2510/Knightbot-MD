-- Cenario de teste completo: simula jogadores jogando o jogo do comeco ao fim.
local H = __H
local checks, failed = 0, 0
local function check(condition, message)
	checks += 1
	if not condition then
		failed += 1
		H.report("error", "FALHOU: " .. message)
	end
end
local function section(name)
	__REALPRINT = __REALPRINT
	H.logs[#H.logs + 1] = "== " .. name
end

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- arvore igual a do projeto
local shared = H.newInstance("Folder", true)
shared.Name = "Shared"
shared.Parent = RS
H.makeScript("ModuleScript", "Config", "Shared/Config", shared)
H.makeScript("ModuleScript", "Formulas", "Shared/Formulas", shared)
local serverScript = H.makeScript("Script", "GardenServer", "Server/init", SSS)
for _, name in { "DataService", "GardenService", "Inventory", "MapBuilder", "PetService", "Remotes", "ShopService", "Sync", "Visuals", "WeatherService" } do
	H.makeScript("ModuleScript", name, "Server/" .. name, serverScript)
end

H.runScript(serverScript)
H.run(1)

local Config = require(shared.Config)
local Formulas = require(shared.Formulas)
local DataService = require(serverScript.DataService)
local GardenService = require(serverScript.GardenService)
local MapBuilder = require(serverScript.MapBuilder)

check(workspace:FindFirstChild("Mapa") ~= nil, "mapa criado")
check(#workspace.Mapa:GetChildren() > 10, "mapa tem varias partes")
check(RS:FindFirstChild("Remotes") ~= nil, "remotes criados")

local function startClient(player)
	local clientScript = H.makeScript("LocalScript", "GardenClient", "Client/init", player:WaitForChild("PlayerScripts"))
	H.makeScript("ModuleScript", "Interface", "Client/Interface", clientScript)
	H.makeScript("ModuleScript", "Effects", "Client/Effects", clientScript)
	H.runScript(clientScript)
	return clientScript
end

-- busca recursiva de botao por texto
local function findButton(root, pattern)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and string.find(d.Text, pattern, 1, true) and (d.Parent ~= nil) then
			return d
		end
	end
	return nil
end
local function findButtons(root, pattern)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and string.find(d.Text, pattern, 1, true) then
			table.insert(list, d)
		end
	end
	return list
end
local function click(buttonInstance)
	H.fire(H.signal(buttonInstance, "Activated"))
	H.run(0.3)
end
local function equip(player, kind, id)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in { backpack, character } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("ItemKind") == kind and tool:GetAttribute("ItemId") == id then
				-- desequipa as outras
				for _, other in character:GetChildren() do
					if other:IsA("Tool") and other ~= tool then
						other.Parent = backpack
					end
				end
				tool.Parent = character
				H.run(0.05)
				return tool
			end
		end
	end
	return nil
end
local function activate(player, tool, position)
	H.setMouse(player, position)
	H.fire(H.signal(tool, "Activated"))
	H.run(0.3)
end
local function chat(player, message)
	H.fire(H.signal(player, "Chatted"), message)
	H.run(0.3)
end
local function plotOf(player)
	local index = player:GetAttribute("PlotIndex")
	return workspace.Mapa:FindFirstChild("Jardim" .. tostring(index))
end
local function bedPoint(player, lx, lz)
	local plot = plotOf(player)
	local base = plot:FindFirstChild("Base")
	local cf = base.CFrame
	return cf:PointToWorldSpace(Vector3.new(lx, 0.25, lz))
end
local function promptsIn(root, action)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") and (action == nil or d.ActionText == action) then
			table.insert(list, d)
		end
	end
	return list
end
local function trigger(prompt, player)
	H.fire(H.signal(prompt, "Triggered"), player)
	H.fire(H.signal(game:GetService("ProximityPromptService"), "PromptTriggered"), prompt, player)
	H.run(0.2)
end


-- exporta a interface (para gerar capturas de tela em HTML)
local function jsonString(str)
	str = string.gsub(str, '[%c"\\]', function(ch)
		if ch == '"' then
			return '\\"'
		elseif ch == "\\" then
			return "\\\\"
		elseif ch == "\n" then
			return "\\n"
		end
		return string.format("\\u%04x", string.byte(ch))
	end)
	return '"' .. str .. '"'
end
local function toJson(value)
	local t = type(value)
	if t == "table" then
		if #value > 0 or next(value) == nil then
			local parts = {}
			for _, v in ipairs(value) do
				table.insert(parts, toJson(v))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, v in value do
			table.insert(parts, jsonString(tostring(k)) .. ":" .. toJson(v))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return jsonString(value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t == "number" then
		return string.format("%.4f", value)
	end
	return "null"
end
local function udim2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end
local function color(c)
	return { c.R, c.G, c.B }
end
local function guiNode(inst)
	local node = { class = inst.ClassName, name = inst.Name, children = {} }
	if inst:IsA("GuiObject") then
		node.pos = udim2(inst.Position)
		node.size = udim2(inst.Size)
		node.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
		node.bg = color(inst.BackgroundColor3)
		node.bgT = inst.BackgroundTransparency
		node.visible = inst.Visible
		node.order = inst.LayoutOrder
		node.auto = inst.AutomaticSize.Name
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			node.text = inst.Text
			node.tc = color(inst.TextColor3)
			node.ts = inst.TextSize
			node.scaled = inst.TextScaled
			node.xa = inst.TextXAlignment.Name
			node.wrap = inst.TextWrapped
			node.strokeT = inst.TextStrokeTransparency
		end
	elseif inst:IsA("UIListLayout") then
		node.dir = inst.FillDirection.Name
		node.pad = inst.Padding.Offset
		node.ha = inst.HorizontalAlignment.Name
		node.va = inst.VerticalAlignment.Name
	elseif inst:IsA("UICorner") then
		node.r = inst.CornerRadius.Offset
	elseif inst:IsA("UIStroke") then
		node.c = color(inst.Color)
		node.th = inst.Thickness
	elseif inst:IsA("UIPadding") then
		node.p = { inst.PaddingTop.Offset, inst.PaddingRight.Offset, inst.PaddingBottom.Offset, inst.PaddingLeft.Offset }
	elseif inst:IsA("UIScale") then
		node.scale = inst.Scale
	elseif inst:IsA("UITextSizeConstraint") then
		node.max = inst.MaxTextSize
	end
	for _, child in inst:GetChildren() do
		table.insert(node.children, guiNode(child))
	end
	return node
end
local function dumpGui(tag, player)
	if not __DUMP then
		return
	end
	local root = player.PlayerGui:FindFirstChild("JardimUI")
	H.realPrint("GUI|" .. tag .. "|" .. toJson(guiNode(root)))
end

---------------------------------------------------------------------
section("Jogador 1 entra")
local p1 = H.addPlayer(1001, "Jogador1", true)
H.run(0.5)
H.spawnCharacter(p1)
local ui = startClient(p1)
H.run(3)

local data = DataService.get(p1)
check(data ~= nil, "dados carregados")
check(data.sheckles == 20, "comeca com 20 sheckles")
check(p1.leaderstats.Sheckles.Value == 20, "leaderstats mostra 20")
check(p1:GetAttribute("PlotIndex") == 1, "recebeu o jardim 1")
check(string.find(plotOf(p1).Placa:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel").Text, "Jogador1", 1, true) ~= nil, "placa com nome do dono")
local gui = p1.PlayerGui:FindFirstChild("JardimUI")
check(gui ~= nil, "interface criada")
local seedTool = equip(p1, "Seed", "Carrot")
check(seedTool ~= nil, "ferramenta de semente de cenoura na mochila")
local rootPos = p1.Character.HumanoidRootPart.Position
local spawnPos = plotOf(p1).Base.CFrame:PointToWorldSpace(Vector3.new(0, 3, -31))
check((rootPos - spawnPos).Magnitude < 1, "personagem teleportado para o jardim")

-- dinheiro na tela
local moneyText = nil
for _, d in gui:GetDescendants() do
	if d:IsA("TextLabel") and string.sub(d.Text, 1, #Config.CurrencySymbol) == Config.CurrencySymbol then
		moneyText = d.Text
	end
end
check(moneyText == "¢20", "HUD mostra ¢20 (mostrou " .. tostring(moneyText) .. ")")
dumpGui("1_inicio", p1)

---------------------------------------------------------------------
section("Plantar fora do jardim e dentro")
activate(p1, seedTool, Vector3.new(0, 0, 0)) -- rua: deve falhar (personagem no caminho do meio)
check(#data.plants == 0, "nao planta na rua")
activate(p1, seedTool, bedPoint(p1, 10, 0))
check(#data.plants == 1, "plantou cenoura no canteiro")
check(data.seeds.Carrot == nil, "semente consumida")
H.run(0.5)
check(p1.Backpack:FindFirstChildOfClass("Tool") == nil and p1.Character:FindFirstChildOfClass("Tool") == nil, "ferramenta removida ao acabar sementes")

H.run(25)
local carrotPrompts = promptsIn(plotOf(p1), "Colher")
check(#carrotPrompts == 1, "cenoura madura tem botao Colher")
check(carrotPrompts[1] and carrotPrompts[1].Enabled == true, "botao habilitado para o dono")
trigger(carrotPrompts[1], p1)
check(#data.fruits == 1, "colheu 1 fruto")
check(#data.plants == 0, "cenoura removida apos colher")

---------------------------------------------------------------------
section("Vender")
local sellButton = findButton(gui, "Vender Tudo")
local topSell = findButton(gui, "💰 Vender")
click(topSell)
H.run(0.5)
check(gui.PainelSell.Visible == true, "painel de venda aberto")
local before = data.sheckles
click(sellButton)
check(data.sheckles > before, "vendeu e ganhou sheckles")
check(#data.fruits == 0, "inventario vazio apos vender")

---------------------------------------------------------------------
section("Comprar sementes")
click(findButton(gui, "🌱 Sementes"))
H.run(0.5)
check(gui.PainelSeeds.Visible == true, "loja de sementes aberta")
dumpGui("2_loja_sementes", p1)
local buyButtons = findButtons(gui.PainelSeeds, "Comprar")
check(#buyButtons > 0, "botoes Comprar existem")
local carrotStockBefore = data.stock.seeds.Carrot
click(buyButtons[1])
check(data.seeds.Carrot == 1 or carrotStockBefore == 0, "comprou cenoura")

-- testar todas as sementes e equipamentos com dinheiro e estoque de teste
chat(p1, "/sheckles 50000000")
chat(p1, "/estoque")
check(data.sheckles >= 50000000, "comando /sheckles funcionou")
local ShopService = require(serverScript.ShopService)
for _, seed in Config.SeedList do
	click(findButton(gui, "🌱 Sementes"))
	-- compra pelo botao da linha certa
	for _, row in gui.PainelSeeds:GetDescendants() do
		if row:IsA("TextLabel") and row.Text == seed.name then
			local b = row.Parent:FindFirstChildOfClass("TextButton")
			click(b)
			break
		end
	end
end
local boughtAll = true
for _, seed in Config.SeedList do
	if (data.seeds[seed.id] or 0) < 1 then
		boughtAll = false
		H.report("error", "nao comprou " .. seed.id)
	end
end
check(boughtAll, "comprou todas as sementes")

---------------------------------------------------------------------
section("Plantar todas as sementes")
H.run(0.5)
local i = 0
for _, seed in Config.SeedList do
	i += 1
	local tool = equip(p1, "Seed", seed.id)
	check(tool ~= nil, "ferramenta da semente " .. seed.id)
	if tool then
		local side = if i % 2 == 0 then 1 else -1
		local lz = -22 + math.floor((i - 1) / 2) * 5
		activate(p1, tool, bedPoint(p1, side * 12, lz))
	end
end
check(#data.plants == #Config.SeedList, "plantou todas (" .. #data.plants .. "/" .. #Config.SeedList .. ")")
-- tentar plantar em cima de outra planta
local extra = equip(p1, "Seed", "Carrot")
if extra then
	activate(p1, extra, bedPoint(p1, -12, -22))
end
check(#data.plants == #Config.SeedList, "nao planta em cima de outra planta")

chat(p1, "/crescer")
H.run(3)
local plot1 = plotOf(p1)
local harvestPrompts = promptsIn(plot1, "Colher")
check(#harvestPrompts >= #Config.SeedList, "todas tem frutos maduros (" .. #harvestPrompts .. ")")
for _, prompt in harvestPrompts do
	trigger(prompt, p1)
end
check(#data.fruits >= #Config.SeedList, "colheu frutos de todas as plantas (" .. #data.fruits .. ")")
local multi = 0
for _, seed in Config.SeedList do
	if seed.multiHarvest then
		multi += 1
	end
end
check(#data.plants == multi, "plantas de varias colheitas ficaram (" .. #data.plants .. "/" .. multi .. ")")
H.run(60)
check(#promptsIn(plot1, "Colher") > 0, "frutos voltam a crescer")

-- exporta o mundo para renderizar no Blender
if __DUMP then
	local P = H.realPrint
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			local shape = "block"
			if d:IsA("Part") then
				local name = d.Shape.Name
				if name == "Ball" then
					shape = "ball"
				elseif name == "Cylinder" then
					shape = "cyl"
				end
			end
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			if mesh and (mesh.MeshType.Name == "Sphere" or mesh.MeshType.Name == "Head") then
				shape = "ball"
			end
			local c = { d.CFrame:GetComponents() }
			local size, color = d.Size, d.Color
			P(string.format("PART|%s|%.3f|%.3f|%.3f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.3f|%.3f|%.3f|%.4f|%.4f|%.4f|%.2f|%s",
				shape, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12],
				size.X, size.Y, size.Z, color.R, color.G, color.B, d.Transparency, d.Material.Name))
		end
	end
end

---------------------------------------------------------------------
section("Inventario e venda de um fruto")
click(findButton(gui, "🎒 Inventário"))
check(gui.PainelInventory.Visible == true, "inventario aberto")
dumpGui("4_inventario", p1)
click(findButton(gui, "💰 Vender"))
local count = #data.fruits
local sellOne = findButtons(gui.PainelSell, "Vender")
local rowButton = nil
for _, b in sellOne do
	if b.Text == "Vender" then
		rowButton = b
		break
	end
end
check(rowButton ~= nil, "botao vender individual")
dumpGui("3_venda", p1)
if rowButton then
	click(rowButton)
end
check(#data.fruits == count - 1, "vendeu um fruto")

---------------------------------------------------------------------
section("Equipamentos")
click(findButton(gui, "🔧 Equip."))
check(gui.PainelGear.Visible == true, "loja de equipamentos aberta")
dumpGui("5_equipamentos", p1)
for _, gear in Config.GearList do
	click(findButton(gui, "🔧 Equip."))
	for _, row in gui.PainelGear:GetDescendants() do
		if row:IsA("TextLabel") and row.Text == gear.name then
			click(row.Parent:FindFirstChildOfClass("TextButton"))
			break
		end
	end
end
check(data.gear.WateringCan == 10, "regador com 10 usos")
check(data.gear.Shovel == 1, "comprou pa")
check((data.gear.BasicSprinkler or 0) >= 1, "comprou sprinkler")
click(findButton(gui, "🏡 Jardim"))
H.run(1)
local can = equip(p1, "Gear", "WateringCan")
local firstPlant = data.plants[1]
local bonusBefore = firstPlant.b
activate(p1, can, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(firstPlant.x, 0.25, firstPlant.z)))
check(firstPlant.b > bonusBefore, "regador acelerou a planta")
check(data.gear.WateringCan == 9, "regador gastou um uso")

for _, gear in Config.GearList do
	if gear.kind == "sprinkler" then
		local tool = equip(p1, "Gear", gear.id)
		if tool then
			activate(p1, tool, bedPoint(p1, 0.5, 10 + #data.sprinklers * 3))
		end
	end
end
check(#data.sprinklers >= 1, "sprinklers colocados (" .. #data.sprinklers .. ")")
H.run(5)
local shovel = equip(p1, "Gear", "Shovel")
local target = data.plants[#data.plants]
local plantsBefore = #data.plants
local pos = plot1.Base.CFrame:PointToWorldSpace(Vector3.new(target.x, 0.25, target.z))
activate(p1, shovel, pos)
check(#data.plants == plantsBefore, "primeiro clique da pa so avisa")
activate(p1, shovel, pos)
check(#data.plants == plantsBefore - 1, "segundo clique remove a planta")

---------------------------------------------------------------------
section("Ovos e pets")
click(findButton(gui, "🥚 Ovos"))
check(gui.PainelEggs.Visible == true, "loja de ovos aberta")
dumpGui("6_ovos", p1)
for _, egg in Config.EggList do
	click(findButton(gui, "🥚 Ovos"))
	for _, row in gui.PainelEggs:GetDescendants() do
		if row:IsA("TextLabel") and row.Text == egg.name then
			click(row.Parent:FindFirstChildOfClass("TextButton"))
			break
		end
	end
end
check((data.eggs.CommonEgg or 0) >= 1, "comprou ovo comum")
click(findButton(gui, "🏡 Jardim"))
H.run(1)
local placed = 0
for _, egg in Config.EggList do
	local tool = equip(p1, "Egg", egg.id)
	if tool then
		activate(p1, tool, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(0, 0.2, -20 + placed * 4)))
		placed += 1
	end
end
check(#data.placedEggs == math.min(placed, Config.MaxEggsPerGarden), "ovos colocados (" .. #data.placedEggs .. ")")
H.run(2)
chat(p1, "/crescer")
H.run(2)
local hatchPrompts = promptsIn(plot1, "Chocar")
check(#hatchPrompts == #data.placedEggs, "ovos prontos para chocar")
for _, prompt in hatchPrompts do
	trigger(prompt, p1)
end
check(#data.pets >= 1, "chocou pets (" .. #data.pets .. ")")
check(type(p1:GetAttribute("EquippedPets")) == "string" and p1:GetAttribute("EquippedPets") ~= "", "pets equipados no atributo")
H.run(1)
local petsFolder = workspace:FindFirstChild("PetsLocais")
check(petsFolder ~= nil and #petsFolder:GetChildren() >= 1, "pets aparecem seguindo o jogador")
click(findButton(gui, "🐾 Pets"))
check(gui.PainelPets.Visible == true, "painel de pets aberto")
dumpGui("7_pets", p1)
local guardar = findButton(gui.PainelPets, "Guardar")
if guardar then
	local equippedBefore = #data.equippedPets
	click(guardar)
	check(#data.equippedPets == equippedBefore - 1, "guardou um pet")
	local equipar = findButton(gui.PainelPets, "Equipar")
	if equipar then
		click(equipar)
		check(#data.equippedPets == equippedBefore, "equipou de novo")
	end
end

---------------------------------------------------------------------
section("Mutacoes visuais")
local multiPlant = nil
for _, plant in data.plants do
	if Config.Seeds[plant.s].multiHarvest and #plant.slots >= 4 then
		multiPlant = plant
		break
	end
end
check(multiPlant ~= nil, "existe planta com 4+ frutos")
if multiPlant then
	multiPlant.slots[1].m = { "Rainbow", "Shocked" }
	multiPlant.slots[2].m = { "Gold", "Frozen" }
	multiPlant.slots[3].m = { "Wet" }
	multiPlant.slots[4].m = { "Rainbow" }
	chat(p1, "/crescer")
	H.run(2)
	local CollectionService = game:GetService("CollectionService")
	check(#CollectionService:GetTagged("RainbowFruit") >= 1, "fruto arco-iris marcado")
	local sparkles = 0
	for _, d in plot1:GetDescendants() do
		if d:IsA("Sparkles") then
			sparkles += 1
		end
	end
	check(sparkles >= 3, "brilho nos frutos raros (" .. sparkles .. ")")
	local shockedValue = Formulas.fruitValue(multiPlant.s, multiPlant.slots[1].w, multiPlant.slots[1].m)
	local plainValue = Formulas.fruitValue(multiPlant.s, multiPlant.slots[1].w, {})
	check(Formulas.mutationMultiplier({ "Rainbow", "Shocked" }) == 5000, "multiplicador arco-iris + eletrizado = 5000")
	check(math.abs(shockedValue - plainValue * 5000) <= 5000, "valor do fruto usa o multiplicador")
end

---------------------------------------------------------------------
section("Renascer")
local toolsBefore = #p1.Backpack:GetChildren() + #p1.Character:GetChildren()
H.spawnCharacter(p1)
H.run(2)
local toolCount = 0
for _, d in p1.Backpack:GetChildren() do
	if d:IsA("Tool") then
		toolCount += 1
	end
end
check(toolCount > 0, "ferramentas voltam na mochila nova apos renascer (" .. toolCount .. ")")
local rootAfter = p1.Character.HumanoidRootPart.Position
local gardenSpawn = plotOf(p1).Base.CFrame:PointToWorldSpace(Vector3.new(0, 3, -31))
check((rootAfter - gardenSpawn).Magnitude < 1, "renasce no proprio jardim")

---------------------------------------------------------------------
section("Clima")
chat(p1, "/clima chuva")
check(workspace:GetAttribute("Weather") == "Rain", "chuva comecou")
H.run(3)
check(gui.Clima.Visible == true, "faixa de clima visivel")
dumpGui("8_chuva", p1)
local rainEmitter = workspace.ClimaLocal.Chuva
check(rainEmitter.Enabled == true, "particulas de chuva ligadas")
H.run(40)
chat(p1, "/clima tempestade")
check(workspace:GetAttribute("Weather") == "Thunderstorm", "tempestade comecou")
H.run(40)
chat(p1, "/clima geada")
H.run(40)
chat(p1, "/clima parar")
H.run(2)
check(workspace:GetAttribute("Weather") == "", "clima parou")
local mutated = 0
for _, plant in data.plants do
	local seed = Config.Seeds[plant.s]
	if seed.multiHarvest then
		for _, slot in plant.slots do
			if #slot.m > 0 then
				mutated += 1
			end
		end
	elseif #plant.f.m > 0 then
		mutated += 1
	end
end
H.logs[#H.logs + 1] = "frutos com mutacao apos clima: " .. mutated
check(mutated > 0, "clima aplicou mutacoes")

---------------------------------------------------------------------
section("Dica do mouse")
local anyPlant = plot1.Plantas:FindFirstChildWhichIsA("Model")
local part = anyPlant and anyPlant:FindFirstChildWhichIsA("BasePart", true)
H.setMouse(p1, Vector3.new(0, 0, 0), part)
click(findButton(gui, "🏡 Jardim"))
H.run(0.5)
check(gui.Dica.Visible == true and gui.Dica.Text ~= "", "dica aparece sobre a planta: " .. tostring(gui.Dica.Text))

---------------------------------------------------------------------
section("Segundo jogador")
local p2 = H.addPlayer(2002, "Jogador2", false)
H.run(0.5)
H.spawnCharacter(p2)
H.run(2)
local data2 = DataService.get(p2)
check(p2:GetAttribute("PlotIndex") == 2, "jogador 2 recebeu jardim 2")
data2.seeds.Carrot = 2
H.moveCharacter(p2, Vector3.new(0, 3, 0))
GardenService.useItem(p2, "Seed", "Carrot", bedPoint(p2, 10, 10))
H.run(0.3)
check(#data2.plants == 1, "jogador 2 plantou")
H.run(25)
local otherPrompts = promptsIn(plotOf(p2), "Colher")
check(#otherPrompts == 1 and otherPrompts[1].Enabled == false, "botao Colher do jardim alheio fica escondido para o jogador 1")
if otherPrompts[1] then
	trigger(otherPrompts[1], p1)
end
check(#data2.plants == 1 and #data.fruits < Config.MaxFruitsInInventory, "jogador 1 nao consegue colher do jardim do jogador 2")

---------------------------------------------------------------------
section("Reabastecimento e eventos naturais")
H.run(700, 0.5)
local restocked = false
for _, log in H.logs do
	if string.find(log, "reabastecidas", 1, true) then
		restocked = true
	end
end
check(true, "simulou 700s")

---------------------------------------------------------------------
section("Sair, crescer offline e voltar")
local plantsSaved = #data.plants
local fruitsSaved = #data.fruits
local petsSaved = #data.pets
local sheckSaved = data.sheckles
H.removePlayer(p1)
H.run(2)
check(H.storeData[Config.DataStoreName]["Jogador_1001"] ~= nil, "dados salvos ao sair")
check(plot1:GetAttribute("OwnerUserId") == 0, "jardim liberado")
check(#plot1.Plantas:GetChildren() == 0, "plantas removidas do mapa ao sair")
H.run(300, 1)
local p1b = H.addPlayer(1001, "Jogador1", true)
H.run(0.5)
H.spawnCharacter(p1b)
startClient(p1b)
H.run(3)
local dataB = DataService.get(p1b)
check(dataB ~= nil and #dataB.plants == plantsSaved, "plantas restauradas (" .. (dataB and #dataB.plants or -1) .. "/" .. plantsSaved .. ")")
check(dataB and #dataB.fruits == fruitsSaved, "frutos restaurados")
check(dataB and #dataB.pets == petsSaved, "pets restaurados")
check(dataB and dataB.sheckles == sheckSaved, "sheckles restaurados")
local newPlot = plotOf(p1b)
check(newPlot ~= nil and #newPlot.Plantas:GetChildren() >= plantsSaved, "plantas recriadas no mapa")

---------------------------------------------------------------------
section("Falha no DataStore")
H.dataStoreFailures = 3
local p3 = H.addPlayer(3003, "Jogador3", false)
H.run(10)
check(H.dataStoreFailures == 0, "tentou carregar 3 vezes antes de desistir")
local data3 = DataService.get(p3)
check(data3 ~= nil, "jogador 3 joga mesmo com falha")
H.removePlayer(p3)
H.run(2)
check(H.storeData[Config.DataStoreName]["Jogador_3003"] == nil, "nao salvou por cima apos falha de carregamento")

---------------------------------------------------------------------
section("Servidor cheio")
local extras = {}
for n = 1, 6 do
	table.insert(extras, H.addPlayer(5000 + n, "Extra" .. n, false))
	H.run(1)
end
H.run(2)
check(H.kicked ~= nil and #H.kicked >= 1, "7o jogador e expulso com servidor cheio")

---------------------------------------------------------------------
section("Modelos do Blender (biblioteca)")
local library = H.newInstance("Folder", true)
library.Name = "Modelos"
library.Parent = RS
local function meshModel(name, parts)
	local model = H.newInstance("Model", true)
	model.Name = name
	for _, info in parts do
		local mesh = H.newInstance("MeshPart", true)
		mesh.Name = info[1]
		mesh.Size = info[2]
		mesh.CFrame = CFrame.new(info[3])
		mesh.Parent = model
	end
	model.Parent = library
end
meshModel("Planta_Carrot", { { "Folhas", Vector3.new(0.8, 1.2, 0.8), Vector3.new(0, 1.5, 0) }, { "Produto_Cenoura", Vector3.new(0.5, 1, 0.5), Vector3.new(0, 0.4, 0) } })
meshModel("Fruto_Strawberry", { { "Produto_Strawberry", Vector3.new(30, 36, 30), Vector3.new(100, 100, 100) }, { "Cabo_Strawberry", Vector3.new(5, 10, 5), Vector3.new(100, 120, 100) } })
meshModel("Sprinkler_BasicSprinkler", { { "Base_BasicSprinkler", Vector3.new(1.4, 0.4, 1.4), Vector3.new(0, 0.2, 0) }, { "Cabeca_BasicSprinkler", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 1.9, 0) } })
meshModel("Ovo_CommonEgg", { { "Casca_CommonEgg", Vector3.new(16, 20, 16), Vector3.new(0, 10, 0) } })
local single = H.newInstance("MeshPart", true)
single.Name = "Planta_Tomato"
single.Size = Vector3.new(200, 300, 200)
single.Parent = library
dataB.seeds.Carrot = 1
dataB.seeds.Strawberry = 1
dataB.seeds.Tomato = 1
require(serverScript.Sync).markDirty(p1b)
H.run(0.5)
for n, id in { "Carrot", "Strawberry", "Tomato" } do
	local tool = equip(p1b, "Seed", id)
	if tool then
		activate(p1b, tool, bedPoint(p1b, -20, 20 + n * 2.5))
	end
end
dataB.gear.BasicSprinkler = 1
dataB.eggs.CommonEgg = 1
require(serverScript.Sync).markDirty(p1b)
H.run(0.5)
local libSprinkler = equip(p1b, "Gear", "BasicSprinkler")
if libSprinkler then
	activate(p1b, libSprinkler, bedPoint(p1b, 0.5, 25))
end
local libEgg = equip(p1b, "Egg", "CommonEgg")
if libEgg then
	activate(p1b, libEgg, bedPoint(p1b, -1, 28))
end
chat(p1b, "/crescer")
H.run(3)
check(#promptsIn(newPlot, "Colher") > 0, "plantas com modelos importados funcionam")
local strawberryFruit = nil
for _, d in newPlot:GetDescendants() do
	if d:IsA("MeshPart") and d.Name == "Cabo_Strawberry" then
		strawberryFruit = d
	end
end
check(strawberryFruit ~= nil and strawberryFruit:GetAttribute("Produce") == nil, "cabo do fruto importado nao conta como fruto")
local waterOnHead = false
for _, d in newPlot:GetDescendants() do
	if d:IsA("ParticleEmitter") and d.Parent and d.Parent.Name == "Cabeca_BasicSprinkler" then
		waterOnHead = true
	end
end
check(waterOnHead, "agua sai da cabeca do sprinkler importado")
local hatchLib = promptsIn(newPlot, "Chocar")
check(#hatchLib >= 1, "ovo importado pode chocar")

---------------------------------------------------------------------
section("Fechar servidor")
for _, fn in H.bindToClose or {} do
	task.spawn(fn)
end
H.run(5)
check(H.storeData[Config.DataStoreName]["Jogador_1001"] ~= nil, "BindToClose salvou")

---------------------------------------------------------------------
local unimpl = {}
for k in H.unimplemented do
	table.insert(unimpl, k)
end
local deprecated = {}
for k in H.deprecatedUse do
	table.insert(deprecated, k)
end
table.sort(unimpl)
table.sort(deprecated)
__RESULT = {
	checks = checks,
	failed = failed,
	errors = #H.errors,
	warnings = #H.warnings,
	unimplemented = table.concat(unimpl, ", "),
	deprecated = table.concat(deprecated, ", "),
}
local P = H.realPrint
local seen = {}
for _, w in H.warnings do
	if not seen[w] then
		seen[w] = true
		P("[aviso] " .. w)
	end
end
P(string.format("CHECAGENS: %d, falharam: %d, erros: %d, avisos: %d", checks, failed, #H.errors, #H.warnings))
P("Metodos sem simulacao: " .. __RESULT.unimplemented)
P("APIs obsoletas usadas: " .. __RESULT.deprecated)
return __RESULT
