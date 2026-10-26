-- Interface: toda a interface do jogador (HUD, lojas, venda, inventario, pets, avisos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))

local Interface = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local COLORS = {
	panel = Color3.fromRGB(255, 246, 226),
	row = Color3.fromRGB(242, 226, 194),
	border = Color3.fromRGB(110, 72, 38),
	text = Color3.fromRGB(70, 45, 20),
	green = Color3.fromRGB(85, 190, 70),
	darkGreen = Color3.fromRGB(50, 140, 40),
	yellow = Color3.fromRGB(245, 185, 40),
	red = Color3.fromRGB(225, 75, 60),
	blue = Color3.fromRGB(70, 150, 230),
	purple = Color3.fromRGB(170, 90, 220),
	gray = Color3.fromRGB(150, 150, 150),
	white = Color3.fromRGB(255, 255, 255),
	money = Color3.fromRGB(130, 235, 95),
}

local NOTIFY_COLORS = {
	success = COLORS.green,
	error = COLORS.red,
	rare = COLORS.purple,
	info = COLORS.blue,
}

local WEATHER_COLORS = {
	Rain = Color3.fromRGB(70, 120, 200),
	Frost = Color3.fromRGB(120, 190, 230),
	Thunderstorm = Color3.fromRGB(80, 70, 140),
}

---------------------------------------------------------------------
-- Ajudantes para criar instancias
---------------------------------------------------------------------

local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent: Instance, radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function darker(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.3)
end

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, align: Enum.TextXAlignment?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Font = FONT,
		Text = value,
		TextSize = textSize,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Parent = parent,
	})
end

local function button(parent: Instance, value: string, color: Color3, position: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = color,
		Position = position,
		Size = size,
		Font = FONT,
		Text = value,
		TextSize = 18,
		TextColor3 = COLORS.white,
		TextStrokeTransparency = 0.5,
		TextWrapped = true,
		AutoButtonColor = true,
		Parent = parent,
	})
	corner(b, 8)
	stroke(b, darker(color), 2)
	b.Activated:Connect(onClick)
	return b
end

local function pill(parent: Instance, value: string, color: Color3, position: UDim2, width: number): Frame
	local frame = new("Frame", {
		BackgroundColor3 = color,
		Position = position,
		Size = UDim2.fromOffset(width, 20),
		Parent = parent,
	})
	corner(frame, 10)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = value,
		TextSize = 14,
		TextColor3 = COLORS.white,
		TextStrokeTransparency = 0.4,
		Parent = frame,
	})
	return frame
end

local function swatch(parent: Instance, color: Color3)
	local frame = new("Frame", {
		BackgroundColor3 = color,
		Position = UDim2.new(0, 10, 0.5, -23),
		Size = UDim2.fromOffset(46, 46),
		Parent = parent,
	})
	corner(frame, 23)
	stroke(frame, darker(color), 3)
	return frame
end

local function clearList(list: Instance)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function makeRow(list: Instance, order: number, height: number): Frame
	local row = new("Frame", {
		BackgroundColor3 = COLORS.row,
		Size = UDim2.new(1, -12, 0, height),
		LayoutOrder = order,
		Parent = list,
	})
	corner(row, 10)
	return row
end

local function fruitTitle(fruit): string
	local seed = Config.Seeds[fruit.s]
	local name = if seed then seed.name else fruit.s
	return string.format("%s  •  %s", name, Formulas.formatWeight(fruit.w))
end

---------------------------------------------------------------------
-- Criacao da interface
---------------------------------------------------------------------

function Interface.create(remotes)
	local api = {}
	local state = nil
	local openName: string? = nil
	local busy = false
	local scalers: { UIScale } = {}
	local toastCounter = 0

	local gui = new("ScreenGui", {
		Name = "JardimUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local function addScale(target: Instance)
		table.insert(scalers, new("UIScale", { Parent = target }))
	end

	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1100, viewport.Y / 720), 0.55, 1)
		for _, scaler in scalers do
			scaler.Scale = scale
		end
	end

	local function notify(message: string, kind: string?)
		local toasts = gui:FindFirstChild("Avisos")
		if not toasts then
			return
		end
		toastCounter += 1
		local toast = new("TextLabel", {
			Name = "Aviso",
			BackgroundColor3 = NOTIFY_COLORS[kind or "info"] or COLORS.blue,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = FONT,
			Text = message,
			TextSize = 20,
			TextColor3 = COLORS.white,
			TextStrokeTransparency = 0.5,
			TextWrapped = true,
			LayoutOrder = toastCounter,
			Parent = toasts,
		})
		corner(toast, 10)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = toast,
		})
		local list = {}
		for _, child in toasts:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(list, child)
			end
		end
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #list - 5 do
			list[i]:Destroy()
		end
		task.delay(4, function()
			if toast.Parent then
				local tween = TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1 })
				tween:Play()
				tween.Completed:Wait()
				toast:Destroy()
			end
		end)
	end
	api.notify = notify

	---------------------------------------------------------------
	-- HUD
	---------------------------------------------------------------

	local toasts = new("Frame", {
		Name = "Avisos",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(470, 320),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toasts,
	})
	addScale(toasts)

	-- dinheiro e botoes laterais
	local side = new("Frame", {
		Name = "Lateral",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(220, 210),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	addScale(side)
	local moneyFrame = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromOffset(220, 56),
		Parent = side,
	})
	corner(moneyFrame, 12)
	local moneyLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Font = FONT,
		Text = Config.CurrencySymbol .. "...",
		TextScaled = true,
		TextColor3 = COLORS.money,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = moneyFrame,
	})
	new("UITextSizeConstraint", { MaxTextSize = 38, Parent = moneyLabel })
	local plantsLabel = text(side, "🌱 0/" .. Config.MaxPlantsPerGarden .. " plantas", UDim2.fromOffset(4, 58), UDim2.fromOffset(216, 24), 18, COLORS.white)
	plantsLabel.TextStrokeTransparency = 0.3

	---------------------------------------------------------------
	-- Paineis
	---------------------------------------------------------------

	local panels = {}

	local function closePanels()
		for _, panel in panels do
			panel.frame.Visible = false
		end
		openName = nil
	end

	local function makePanel(name: string, title: string, accent: Color3)
		local frame = new("Frame", {
			Name = "Painel" .. name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromOffset(580, 440),
			BackgroundColor3 = COLORS.panel,
			Visible = false,
			Parent = gui,
		})
		corner(frame, 14)
		stroke(frame, COLORS.border, 3)
		addScale(frame)
		local titleBar = new("Frame", {
			BackgroundColor3 = accent,
			Size = UDim2.new(1, 0, 0, 50),
			Parent = frame,
		})
		corner(titleBar, 14)
		new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -14),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = titleBar,
		})
		local titleLabel = text(titleBar, title, UDim2.fromOffset(16, 0), UDim2.new(1, -80, 1, 0), 30, COLORS.white)
		titleLabel.TextStrokeTransparency = 0.4
		titleLabel.ZIndex = 2
		local closeButton = button(titleBar, "X", COLORS.red, UDim2.new(1, -46, 0, 6), UDim2.fromOffset(38, 38), closePanels)
		closeButton.ZIndex = 2
		local info = text(frame, "", UDim2.fromOffset(14, 56), UDim2.new(1, -240, 0, 32), 18, COLORS.text)
		local header = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 56),
			Size = UDim2.fromOffset(220, 34),
			Parent = frame,
		})
		local list = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 96),
			Size = UDim2.new(1, -20, 1, -106),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = COLORS.border,
			Parent = frame,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = list,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = list })
		local panel = { frame = frame, info = info, header = header, list = list }
		panels[name] = panel
		return panel
	end

	local seedsPanel = makePanel("Seeds", "🌱 Sementes do Sam", COLORS.green)
	local gearPanel = makePanel("Gear", "🔧 Equipamentos da Eloise", COLORS.blue)
	local eggsPanel = makePanel("Eggs", "🥚 Ovos do Ray", COLORS.purple)
	local sellPanel = makePanel("Sell", "💰 Venda do Steven", COLORS.yellow)
	local inventoryPanel = makePanel("Inventory", "🎒 Inventário", Color3.fromRGB(160, 110, 60))
	local petsPanel = makePanel("Pets", "🐾 Meus Pets", Color3.fromRGB(230, 120, 160))

	local function invoke(remote: RemoteFunction, ...): (boolean, string)
		if busy then
			return false, ""
		end
		busy = true
		local args = table.pack(...)
		local ok, success, message = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		busy = false
		if not ok then
			return false, "Falha de conexão. Tente novamente."
		end
		return success == true, if type(message) == "string" then message else ""
	end

	local function report(success: boolean, message: string)
		if message ~= "" then
			notify(message, if success then "success" else "error")
		end
	end

	local function buy(category: string, id: string)
		report(invoke(remotes.Buy, category, id))
	end

	local function restockText(): string
		if not state then
			return ""
		end
		return "🔄 Reabastece em " .. Formulas.formatTime(state.restockAt - workspace:GetServerTimeNow())
	end

	local function shopRow(list: Instance, item, category: string, stock: number, owned: number, subtitle: string, color: Color3)
		local row = makeRow(list, item.order, 76)
		swatch(row, color)
		text(row, item.name, UDim2.fromOffset(66, 4), UDim2.new(1, -220, 0, 26), 22, COLORS.text)
		local rarity = Config.Rarities[item.rarity]
		pill(row, rarity.name, rarity.color, UDim2.fromOffset(66, 31), 90)
		text(row, "Você tem: " .. owned, UDim2.fromOffset(162, 31), UDim2.fromOffset(150, 20), 15, COLORS.text)
		text(row, subtitle, UDim2.fromOffset(66, 52), UDim2.new(1, -220, 0, 20), 14, darker(COLORS.text, -0.4))
		text(row, Formulas.formatMoney(item.price), UDim2.new(1, -146, 0, 4), UDim2.fromOffset(136, 26), 20, COLORS.darkGreen, Enum.TextXAlignment.Right)
		local affordable = state and state.sheckles >= item.price
		local label = if stock > 0 then "Comprar (x" .. stock .. ")" else "Sem estoque"
		local color2 = if stock > 0 and affordable then COLORS.green elseif stock > 0 then COLORS.yellow else COLORS.gray
		button(row, label, color2, UDim2.new(1, -146, 0, 34), UDim2.fromOffset(136, 34), function()
			buy(category, item.id)
		end)
	end

	local function renderSeeds()
		local panel = seedsPanel
		panel.info.Text = restockText()
		clearList(panel.list)
		for _, seed in Config.SeedList do
			local stock = state.stock.seeds[seed.id] or 0
			local subtitle = string.format(
				"%s • cresce em %s • vale ~%s",
				if seed.multiHarvest then "Várias colheitas" else "Colheita única",
				Formulas.formatTime(seed.growTime),
				Formulas.formatMoney(seed.baseValue)
			)
			shopRow(panel.list, seed, "Seeds", stock, state.seeds[seed.id] or 0, subtitle, seed.fruitColor)
		end
	end

	local function renderGear()
		local panel = gearPanel
		panel.info.Text = restockText()
		clearList(panel.list)
		for _, gear in Config.GearList do
			local stock = state.stock.gear[gear.id] or 0
			shopRow(panel.list, gear, "Gear", stock, state.gear[gear.id] or 0, gear.description, gear.color)
		end
	end

	local function renderEggs()
		local panel = eggsPanel
		panel.info.Text = restockText()
		clearList(panel.list)
		for _, egg in Config.EggList do
			local stock = state.stock.eggs[egg.id] or 0
			local total = 0
			for _, entry in egg.pets do
				total += entry.weight
			end
			local chances = {}
			for _, entry in egg.pets do
				local pet = Config.Pets[entry.pet]
				table.insert(chances, string.format("%s %d%%", pet.name, math.floor(entry.weight / total * 100 + 0.5)))
			end
			local subtitle = "Choca em " .. Formulas.formatTime(egg.hatchTime) .. " • " .. table.concat(chances, ", ")
			shopRow(panel.list, egg, "Eggs", stock, state.eggs[egg.id] or 0, subtitle, egg.color)
		end
	end

	local function sortedFruits()
		local list = table.clone(state.fruits)
		table.sort(list, function(a, b)
			if a.v == b.v then
				return a.i < b.i
			end
			return a.v > b.v
		end)
		return list
	end

	local function totalValue(): number
		local total = 0
		for _, fruit in state.fruits do
			total += fruit.v
		end
		return total
	end

	local function fruitRow(list: Instance, fruit, order: number, withSell: boolean)
		local seed = Config.Seeds[fruit.s]
		local row = makeRow(list, order, 62)
		swatch(row, if seed then seed.fruitColor else COLORS.gray)
		text(row, fruitTitle(fruit), UDim2.fromOffset(66, 4), UDim2.new(1, -230, 0, 26), 20, COLORS.text)
		local mutations = Formulas.mutationNames(fruit.m)
		local mutationText = if mutations ~= "" then "✨ " .. mutations .. " (x" .. Formulas.formatNumber(Formulas.mutationMultiplier(fruit.m)) .. ")" else "Sem mutações"
		text(row, mutationText, UDim2.fromOffset(66, 32), UDim2.new(1, -230, 0, 22), 15, if mutations ~= "" then COLORS.purple else darker(COLORS.text, -0.4))
		text(row, Formulas.formatMoney(fruit.v), UDim2.new(1, -156, 0, if withSell then 2 else 18), UDim2.fromOffset(146, 26), 20, COLORS.darkGreen, Enum.TextXAlignment.Right)
		if withSell then
			button(row, "Vender", COLORS.yellow, UDim2.new(1, -116, 0, 28), UDim2.fromOffset(106, 30), function()
				report(invoke(remotes.Sell, "one", fruit.i, fruit.s, fruit.w))
			end)
		end
	end

	local sellAllButton = button(sellPanel.header, "Vender Tudo", COLORS.green, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), function()
		report(invoke(remotes.Sell, "all"))
	end)
	sellAllButton.TextSize = 20

	local function emptyRow(list: Instance, message: string)
		local row = makeRow(list, 1, 60)
		text(row, message, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 18, COLORS.text, Enum.TextXAlignment.Center)
	end

	local function renderSell()
		local panel = sellPanel
		panel.info.Text = string.format("%d fruto(s) • Total: %s", #state.fruits, Formulas.formatMoney(totalValue()))
		clearList(panel.list)
		if #state.fruits == 0 then
			emptyRow(panel.list, "Você não tem frutos. Colha frutos maduros no seu jardim!")
			return
		end
		for order, fruit in sortedFruits() do
			fruitRow(panel.list, fruit, order, true)
		end
	end

	local function renderInventory()
		local panel = inventoryPanel
		panel.info.Text = string.format(
			"Frutos: %d/%d • Valor: %s",
			#state.fruits,
			Config.MaxFruitsInInventory,
			Formulas.formatMoney(totalValue())
		)
		clearList(panel.list)
		local stats = state.stats or {}
		local statsRow = makeRow(panel.list, 0, 40)
		text(
			statsRow,
			string.format("Plantados: %d • Colhidos: %d • Ganhos: %s", stats.planted or 0, stats.harvested or 0, Formulas.formatMoney(stats.earned or 0)),
			UDim2.fromOffset(12, 0),
			UDim2.new(1, -24, 1, 0),
			16,
			COLORS.text,
			Enum.TextXAlignment.Center
		)
		if #state.fruits == 0 then
			emptyRow(panel.list, "Nenhum fruto ainda. Plante, espere crescer e aperte E para colher!")
			return
		end
		for order, fruit in sortedFruits() do
			fruitRow(panel.list, fruit, order, false)
		end
	end

	local function renderPets()
		local panel = petsPanel
		local bonuses = state.bonuses or { Growth = 0, Sell = 0, Luck = 0 }
		local equipped = 0
		for _, pet in state.pets do
			if pet.eq then
				equipped += 1
			end
		end
		panel.info.Text = string.format(
			"Equipados %d/%d • Cresc. +%s • Venda +%s • Sorte +%s",
			equipped,
			Config.MaxPetsEquipped,
			Formulas.formatPercent(bonuses.Growth),
			Formulas.formatPercent(bonuses.Sell),
			Formulas.formatPercent(bonuses.Luck)
		)
		panel.info.Size = UDim2.new(1, -28, 0, 32)
		clearList(panel.list)
		if #state.pets == 0 then
			emptyRow(panel.list, "Você ainda não tem pets. Compre um ovo com o Ray e choque no seu jardim!")
			return
		end
		local list = table.clone(state.pets)
		table.sort(list, function(a, b)
			if a.eq ~= b.eq then
				return a.eq
			end
			local ra = Config.Rarities[Config.Pets[a.p].rarity].order
			local rb = Config.Rarities[Config.Pets[b.p].rarity].order
			if ra ~= rb then
				return ra > rb
			end
			return a.id < b.id
		end)
		for order, pet in list do
			local info = Config.Pets[pet.p]
			local rarity = Config.Rarities[info.rarity]
			local row = makeRow(panel.list, order, 62)
			swatch(row, info.color)
			text(row, info.name .. (if pet.eq then "  ✅" else ""), UDim2.fromOffset(66, 4), UDim2.new(1, -220, 0, 26), 20, COLORS.text)
			pill(row, rarity.name, rarity.color, UDim2.fromOffset(66, 34), 90)
			text(row, Config.PetBonusNames[info.bonusType] .. " +" .. Formulas.formatPercent(info.bonus), UDim2.fromOffset(164, 34), UDim2.fromOffset(200, 20), 16, COLORS.text)
			local action = if pet.eq then "unequip" else "equip"
			button(row, if pet.eq then "Guardar" else "Equipar", if pet.eq then COLORS.gray else COLORS.green, UDim2.new(1, -126, 0.5, -17), UDim2.fromOffset(116, 34), function()
				report(invoke(remotes.PetAction, action, pet.id))
			end)
		end
	end

	local renderers = {
		Seeds = renderSeeds,
		Gear = renderGear,
		Eggs = renderEggs,
		Sell = renderSell,
		Inventory = renderInventory,
		Pets = renderPets,
	}

	local function refresh()
		if openName and state then
			local renderer = renderers[openName]
			if renderer then
				renderer()
			end
		end
	end

	local function openPanel(name: string)
		local panel = panels[name]
		if not panel then
			return
		end
		closePanels()
		openName = name
		panel.frame.Visible = true
		if state then
			refresh()
		else
			panel.info.Text = "Carregando..."
		end
	end
	api.openShop = openPanel

	local function togglePanel(name: string)
		if openName == name then
			closePanels()
		else
			openPanel(name)
		end
	end

	button(side, "🎒 Inventário", Color3.fromRGB(160, 110, 60), UDim2.fromOffset(0, 88), UDim2.fromOffset(220, 46), function()
		togglePanel("Inventory")
	end).TextSize = 22
	button(side, "🐾 Pets", Color3.fromRGB(230, 120, 160), UDim2.fromOffset(0, 142), UDim2.fromOffset(220, 46), function()
		togglePanel("Pets")
	end).TextSize = 22

	-- botoes de teleporte no topo
	local top = new("Frame", {
		Name = "Topo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(660, 46),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	addScale(top)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})
	local teleports = {
		{ label = "🌱 Sementes", place = "Seeds", panel = "Seeds", color = COLORS.green },
		{ label = "💰 Vender", place = "Sell", panel = "Sell", color = COLORS.yellow },
		{ label = "🏡 Jardim", place = "Garden", panel = nil, color = Color3.fromRGB(160, 110, 60) },
		{ label = "🔧 Equip.", place = "Gear", panel = "Gear", color = COLORS.blue },
		{ label = "🥚 Ovos", place = "Eggs", panel = "Eggs", color = COLORS.purple },
	}
	for order, info in teleports do
		local b = button(top, info.label, info.color, UDim2.new(), UDim2.fromOffset(124, 44), function()
			remotes.Teleport:FireServer(info.place)
			if info.panel then
				openPanel(info.panel)
			else
				closePanels()
			end
		end)
		b.LayoutOrder = order
		b.TextSize = 18
	end

	-- faixa do clima
	local weatherBanner = new("Frame", {
		Name = "Clima",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(580, 52),
		BackgroundColor3 = COLORS.blue,
		Visible = false,
		Parent = gui,
	})
	corner(weatherBanner, 10)
	addScale(weatherBanner)
	local weatherLabel = text(weatherBanner, "", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 17, COLORS.white, Enum.TextXAlignment.Center)
	weatherLabel.TextStrokeTransparency = 0.4

	-- dica ao passar o mouse nas plantas
	local tooltip = new("TextLabel", {
		Name = "Dica",
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.25,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Font = FONT,
		Text = "",
		TextSize = 17,
		TextColor3 = COLORS.white,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	corner(tooltip, 8)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = tooltip,
	})

	function api.setTooltip(message: string?, x: number?, y: number?)
		if message and x and y then
			tooltip.Text = message
			tooltip.Position = UDim2.fromOffset(x + 16, y + 10)
			tooltip.Visible = true
		else
			tooltip.Visible = false
		end
	end

	function api.setState(newState)
		state = newState
		moneyLabel.Text = Formulas.formatMoney(state.sheckles)
		plantsLabel.Text = string.format("🌱 %d/%d plantas", state.plantCount or 0, Config.MaxPlantsPerGarden)
		refresh()
	end

	function api.isPanelOpen(): boolean
		return openName ~= nil
	end

	-- atualiza contadores a cada segundo
	task.spawn(function()
		while gui.Parent do
			local weatherId = workspace:GetAttribute("Weather")
			local weather = if type(weatherId) == "string" then Config.Weather[weatherId] else nil
			if weather then
				local ends = workspace:GetAttribute("WeatherEnds")
				local remaining = if type(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
				weatherBanner.BackgroundColor3 = WEATHER_COLORS[weather.id] or COLORS.blue
				weatherLabel.Text = string.format("%s %s (%s) — %s", weather.emoji, weather.name, Formulas.formatTime(remaining), weather.description)
				weatherBanner.Visible = true
			else
				weatherBanner.Visible = false
			end
			if state and (openName == "Seeds" or openName == "Gear" or openName == "Eggs") then
				panels[openName].info.Text = restockText()
			end
			task.wait(1)
		end
	end)

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()

	return api
end

return Interface
