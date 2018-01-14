--- Conversion plugin
-- @author Quenty
-- With help from: Badcc, Stravant, TreyReynolds

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local IS_DEBUG_MODE = script:IsDescendantOf(game)
if IS_DEBUG_MODE then
	warn("Starting plugin in debug mode")
end

local MakeMaid = require(script:WaitForChild("Maid")).MakeMaid
local Converter = require(script:WaitForChild("Converter"))
local UI = require(script:WaitForChild("UI"))
local Signal = require(script:WaitForChild("Signal"))

local ScreenGui = script.Parent:WaitForChild("ScreenGui")
ScreenGui.Enabled = false
local MainMaid = MakeMaid()

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

local IsActive = false
local Converter = Converter.new(IS_DEBUG_MODE)
	:WithPluginForCache(plugin)

local function Deactivate(Button)
	-- Deactivates the plugin	
	MainMaid.ActiveMaid = nil
	IsActive = false
end

local function Activate(Button)
	-- Activates the plugin

	local Maid = MakeMaid()
	IsActive = true

	local NewScreenGui = ScreenGui:Clone()
	NewScreenGui.Enabled = true
	NewScreenGui.Parent = IS_DEBUG_MODE and game.Players.LocalPlayer.PlayerGui or game.CoreGui

	local MainUI = UI.new(NewScreenGui.Main, Selection)
		:WithConverter(Converter)
	Maid.MainUI = MainUI

	Maid.Done = MainUI.Done:connect(function()
		Deactivate(Button)
	end)

	if Button then
		Button:SetActive(true)
	end

	Maid.Cleanup = function()
		if Button then
			Button:SetActive(false)
		end

		IsActive = false
	end

	MainUI:Show()

	if not IS_DEBUG_MODE then
		local ChangeHistoryService = game:GetService("ChangeHistoryService")
		MainUI.ConversionStarting:connect(function()
			ChangeHistoryService:SetWaypoint("Conversion_" .. HttpService:GenerateGUID(true))
		end)
	end

	MainMaid.ActiveMaid = Maid
end



if not IS_DEBUG_MODE then
	local Toolbar = plugin:CreateToolbar("Object")

	local Button = Toolbar:CreateButton(
		"Class Converter",
		"Converts classes from one item to another",
		"rbxassetid://906772526"
	)

	Button.Click:connect(function()
		if not IsActive then
			Activate(Button)
		else
			Deactivate(Button)
		end
	end)
else
	Activate()
end