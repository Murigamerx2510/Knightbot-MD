-- WeatherService: eventos de clima.
--   De dia: Chuva, Tempestade, Geada, Nevasca, Areia, Calor, Tornado, Arco-iris, Explosao Solar, Chocolate.
--   De noite (luas): Sangue, Dourada, Arco-iris, Gigante, Meteoros, Aurora, Estrelas.
--   Especial: Eclipse (ao colher uma Flor do Eclipse).
-- Cada evento muda o ceu, acelera plantas e aplica mutacoes nos frutos.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DayNightService = require(script.Parent.DayNightService)
local GardenService = require(script.Parent.GardenService)
local Sync = require(script.Parent.Sync)
local Visuals = require(script.Parent.Visuals)

local WeatherService = {}

local rng = Random.new()
local current = nil
local nextDayEventAt: number? = nil
local lastSpecial: { [string]: number } = {}

local CLEAR = { brightness = 2, density = 0.3, color = Color3.fromRGB(200, 220, 255) }

local function setSky(sky)
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, { Brightness = sky.brightness }):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Density = sky.density, Color = sky.color }):Play()
	end
end

local function listFor(period: string)
	local list = {}
	for _, weather in Config.WeatherList do
		if weather.period == period and weather.weight > 0 then
			table.insert(list, weather)
		end
	end
	return list
end

function WeatherService.getCurrent(): string?
	return if current then current.weather.id else nil
end

function WeatherService.getCurrentInfo()
	return if current then current.weather else nil
end

local function applyEffects()
	local weather = if current then current.weather else nil
	GardenService.setWeatherEffects({
		growthBonus = if weather then weather.growthBonus or 0 else 0,
		goldBoost = if weather then weather.goldBoost or 1 else 1,
		rainbowBoost = if weather then weather.rainbowBoost or 1 else 1,
		sizeBoost = if weather then weather.sizeBoost or 0 else 0,
	})
end

function WeatherService.stopEvent(silent: boolean?)
	if not current then
		return
	end
	current = nil
	workspace:SetAttribute("Weather", "")
	workspace:SetAttribute("WeatherEnds", 0)
	applyEffects()
	setSky(CLEAR)
	if not silent then
		Sync.notifyAll("O clima voltou ao normal.", "info")
	end
end

function WeatherService.startEvent(weatherId: string, duration: number?): boolean
	local weather = Config.Weather[weatherId]
	if not weather then
		return false
	end
	if current then
		WeatherService.stopEvent(true)
	end
	local length = duration or weather.duration
	current = {
		weather = weather,
		endsAt = os.time() + length,
		nextStrike = os.clock() + (if weather.strike then weather.strike.interval else 0),
	}
	if weather.period == "special" then
		lastSpecial[weather.id] = os.time()
	end
	-- um clima por dia: cancela o clima natural que estava agendado
	nextDayEventAt = nil
	workspace:SetAttribute("Weather", weather.id)
	workspace:SetAttribute("WeatherEnds", current.endsAt)
	applyEffects()
	setSky(weather.sky or CLEAR)
	Sync.notifyAll(string.format("%s %s! %s", weather.emoji, weather.name, weather.description), "rare")
	return true
end

-- Eventos especiais (Eclipse) disparados por plantas
function WeatherService.trigger(weatherId: string): boolean
	local weather = Config.Weather[weatherId]
	if not weather then
		return false
	end
	local last = lastSpecial[weatherId]
	if last and os.time() - last < (weather.cooldown or 600) then
		return false
	end
	return WeatherService.startEvent(weatherId)
end

local function strikeVisual(kind: string, position: Vector3)
	if kind == "lightning" then
		Visuals.lightning(position)
	elseif kind == "meteor" then
		Visuals.meteor(position)
	elseif kind == "star" then
		Visuals.star(position)
	elseif kind == "tornado" then
		Visuals.tornado(position)
	end
end

local function onPhaseChanged(phase: string, _index: number)
	if phase == "Night" then
		-- a noite encerra os climas de dia; pode surgir uma lua especial
		if current and current.weather.period == "day" then
			WeatherService.stopEvent(true)
		end
		if not current and rng:NextNumber() < Config.DayNight.nightEventChance then
			local pick = Formulas.weightedPick(listFor("night"), rng)
			local _, remaining = DayNightService.getPhase()
			WeatherService.startEvent(pick.id, math.min(pick.duration, math.floor(remaining)))
		end
	elseif phase == "Day" then
		if current and current.weather.period == "night" then
			WeatherService.stopEvent(true)
		end
		nextDayEventAt = nil
		if rng:NextNumber() < Config.DayNight.dayEventChance then
			nextDayEventAt = os.time() + rng:NextInteger(Config.DayNight.dayEventDelayMin, Config.DayNight.dayEventDelayMax)
		end
	end
end

local function step()
	local now = os.time()
	if current then
		local weather = current.weather
		if now >= current.endsAt then
			WeatherService.stopEvent()
			return
		end
		for mutationId, chance in weather.mutations do
			GardenService.applyWeatherMutation(mutationId, chance)
		end
		local strike = weather.strike
		if strike and os.clock() >= current.nextStrike then
			current.nextStrike = os.clock() + strike.interval
			for _ = 1, strike.count or 1 do
				local position = GardenService.strikeRandomFruit(strike.mutation)
				if position then
					strikeVisual(strike.visual, position)
				end
			end
		end
	elseif nextDayEventAt and now >= nextDayEventAt and DayNightService.getPhase() == "Day" then
		nextDayEventAt = nil
		local pick = Formulas.weightedPick(listFor("day"), rng)
		WeatherService.startEvent(pick.id)
	end
end

function WeatherService.start()
	workspace:SetAttribute("Weather", "")
	workspace:SetAttribute("WeatherEnds", 0)
	applyEffects()
	DayNightService.onPhaseChanged(onPhaseChanged)
	onPhaseChanged((DayNightService.getPhase()), 0)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(step)
			if not ok then
				warn("[Jardim] Erro no clima: " .. tostring(err))
			end
		end
	end)
end

return WeatherService
