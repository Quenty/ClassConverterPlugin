--- Class conversion plugin
-- @author Quenty
-- With help from: Badcc, Stravant, TreyReynolds

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local IS_DEBUG_MODE = script:IsDescendantOf(game)
if IS_DEBUG_MODE then
	warn("[Converter] - Starting plugin in debug mode")
	while not Players.LocalPlayer do
		wait(0.05)
	end
end

local Converter = require(script:WaitForChild("Converter"))
local UI = require(script:WaitForChild("UI"))
local Signal = require(script:WaitForChild("Signal"))

local Selection do
	if not IS_DEBUG_MODE then
		Selection = game.Selection
	else
		-- The things I do for testing...
		Selection = {}
		Selection.Items = {}
		Selection.SelectionChanged = Signal.new()

		function Selection:Get()
			return Selection.Items
		end
		function Selection:Set(Items)
			self.Items = Items
			self.SelectionChanged:fire()
		end

		local Mouse = Players.LocalPlayer:GetMouse()
		Mouse.Button1Down:connect(function()
			local New = {}
			if Mouse.Target and Mouse.Target:IsA("BasePart") then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
					for _, Item in pairs(Selection:Get()) do
						table.insert(New, Item)
					end
				end
				if not Mouse.Target.Locked then
					table.insert(New, Mouse.Target)
				end
			end
			Selection:Set(New)
		end)
	end
end

local plugin = plugin
if IS_DEBUG_MODE then
	local FakeMetatable = {}
	function FakeMetatable.new(OldPlugin)
		local self = setmetatable({}, FakeMetatable)

		self.Settings = {}
		self.OldPlugin = OldPlugin
		return self
	end

	function FakeMetatable:__index(Index)
		local Result = rawget(FakeMetatable, Index)
		if Result then
			return Result
		end

		return self.OldPlugin[Index]
	end

	function FakeMetatable:GetSetting(Key)
		return self.Settings[Key]
	end

	function FakeMetatable:SetSetting(Key, Value)
		self.Settings[Key] = Value
	end

	-- Override plugin settings (get/set)
	plugin = FakeMetatable.new(plugin)
end

local converter = Converter.new(IS_DEBUG_MODE)
	:WithPluginForCache(plugin)

local screenGui
do
	-- Activates the plugin
	if IS_DEBUG_MODE then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "Converter"
		screenGui.Parent = Players.LocalPlayer.PlayerGui
		screenGui.Enabled = false
	else
		local info = DockWidgetPluginGuiInfo.new(
			Enum.InitialDockState.Float,
			false,
			true,
			250,
			320,
			200,
			240
		)
		screenGui = plugin:CreateDockWidgetPluginGui("Quenty_Class_Converter", info)
		screenGui.Title = "Quenty's Class Converter Plugin"
	end
	screenGui:BindToClose(function()
		screenGui.Enabled = false
	end)
	local function initializeGui()
		local main = script.Parent.ScreenGui.Main:Clone()
		main.Parent = screenGui

		local ui = UI.new(main, Selection)
			:WithConverter(converter)

		screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
			ui:SetVisible(screenGui.Enabled)
			if not screenGui.Enabled then
				ui.DropDown:SetVisible(false)
			end
		end)
		ui:SetVisible(screenGui.Enabled)

		if not IS_DEBUG_MODE then
			local ChangeHistoryService = game:GetService("ChangeHistoryService")
			ui.ConversionStarting:connect(function()
				ChangeHistoryService:SetWaypoint("Conversion_" .. HttpService:GenerateGUID(true))
			end)
			ui.ConversionEnding:connect(function()
				ChangeHistoryService:SetWaypoint("Conversion_" .. HttpService:GenerateGUID(true))
			end)


			screenGui.WindowFocusReleased:Connect(function()
				ui.DropDown:SetVisible(false)
			end)
		end
	end

	if screenGui.Enabled then
		spawn(function()
			initializeGui()
		end)
	else
		-- Wait to load GUI
		local connection
		connection = screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
			connection:disconnect()
			initializeGui()
		end)
	end
end

if not IS_DEBUG_MODE then
	local toolbar = plugin:CreateToolbar("Object")

	local button = toolbar:CreateButton(
		"Class converter",
		"Converts classes from one item to another",
		"rbxassetid://906772526"
	)

	screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		button:SetActive(screenGui.Enabled)
	end)
	--button:SetActive(screenGui.Enabled)

	button.Click:connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)
else
	screenGui.Enabled = true
end