-- WeatherService: eventos de clima (Chuva, Geada, Tempestade).
-- Cada evento muda a iluminacao, acelera plantas e aplica mutacoes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local GardenService = require(script.Parent.GardenService)
local Sync = require(script.Parent.Sync)
local Visuals = require(script.Parent.Visuals)

local WeatherService = {}

local rng = Random.new()
local current = nil
local nextEventAt = 0

local CLEAR = { clockTime = 14, brightness = 2, density = 0.3 }

local function setSky(clockTime: number, brightness: number, density: number)
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, { ClockTime = clockTime, Brightness = brightness }):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Density = density }):Play()
	end
end

local function scheduleNext()
	nextEventAt = os.time() + rng:NextInteger(Config.WeatherMinInterval, Config.WeatherMaxInterval)
end

function WeatherService.getCurrent(): string?
	return if current then current.weather.id else nil
end

function WeatherService.startEvent(weatherId: string): boolean
	local weather = Config.Weather[weatherId]
	if not weather then
		return false
	end
	current = {
		weather = weather,
		endsAt = os.time() + weather.duration,
		nextStrike = os.clock() + (weather.strikeInterval or 0),
	}
	workspace:SetAttribute("Weather", weather.id)
	workspace:SetAttribute("WeatherEnds", current.endsAt)
	GardenService.setWeatherGrowth(weather.growthBonus)
	setSky(weather.clockTime, weather.brightness, weather.density)
	Sync.notifyAll(string.format("%s %s! %s", weather.emoji, weather.name, weather.description), "rare")
	return true
end

function WeatherService.stopEvent()
	if not current then
		return
	end
	current = nil
	workspace:SetAttribute("Weather", "")
	workspace:SetAttribute("WeatherEnds", 0)
	GardenService.setWeatherGrowth(0)
	setSky(CLEAR.clockTime, CLEAR.brightness, CLEAR.density)
	Sync.notifyAll("☀️ O tempo abriu!", "info")
	scheduleNext()
end

local function step()
	local now = os.time()
	if current then
		local weather = current.weather
		if now >= current.endsAt then
			WeatherService.stopEvent()
			return
		end
		if weather.mutation then
			GardenService.applyWeatherMutation(weather.mutation, weather.mutationChance)
		end
		if weather.strikeInterval and os.clock() >= current.nextStrike then
			current.nextStrike = os.clock() + weather.strikeInterval
			local position = GardenService.strikeRandomFruit(weather.strikeMutation)
			if position then
				Visuals.lightning(position)
			end
		end
	elseif now >= nextEventAt then
		local pick = Formulas.weightedPick(Config.WeatherList, rng)
		WeatherService.startEvent(pick.id)
	end
end

function WeatherService.start()
	workspace:SetAttribute("Weather", "")
	workspace:SetAttribute("WeatherEnds", 0)
	scheduleNext()
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
