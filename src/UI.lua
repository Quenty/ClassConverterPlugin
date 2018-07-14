local MakeMaid = require(script.Parent:WaitForChild("Maid")).MakeMaid
local Signal = require(script.Parent:WaitForChild("Signal"))
local ScrollingFrame = require(script.Parent:WaitForChild("ScrollingFrame"))
local ValueObject = require(script.Parent:WaitForChild("ValueObject"))
local IconHandler = require(script.Parent:WaitForChild("IconHandler"))
local HttpService = game:GetService("HttpService")

local function TrimString(str, pattern)
	pattern = pattern or "%s";
	-- %S is whitespaces
	-- When we find the first non space character defined by ^%s
	-- we yank out anything in between that and the end of the string
	-- Everything else is replaced with %1 which is essentially nothing

	-- Credit Sorcus, Modified by Quenty
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*$", "%1"))
end

local UIBase = {}
UIBase.ClassName = "UIBase"
UIBase.__index = UIBase

function UIBase.new(Gui)
	local self = setmetatable({}, UIBase)

	self.Maid = MakeMaid()

	self.Gui = Gui or error("No GUI")
	self.Gui.Visible = true
	self.Maid.Gui = Gui

	self.VisibleChanged = Signal.new()

	self.Visible = true
	self:Hide(true)

	return self
end

function UIBase:IsVisible()
	return self.Visible
end

function UIBase:Show(DoNotAnimate)
	if not self:IsVisible() then
		self.Visible = true
		self.VisibleChanged:fire(self:IsVisible(), DoNotAnimate)
	end
end

function UIBase:Hide(DoNotAnimate)
	if self:IsVisible() then
		self.Visible = false
		self.VisibleChanged:fire(self:IsVisible(), DoNotAnimate)
	end
end

function UIBase:Toggle(DoNotAnimate)
	self:SetVisible(not self:IsVisible(), DoNotAnimate)
end

function UIBase:SetVisible(IsVisible, DoNotAnimate)
	if IsVisible then
		self:Show(DoNotAnimate)
	else
		self:Hide(DoNotAnimate)
	end
end

function UIBase:Destroy()
	self.Maid:DoCleaning()
end




local Checkbox = setmetatable({}, UIBase)
Checkbox.__index = Checkbox
Checkbox.ClassName = "Checkbox"

function Checkbox.new(Gui)
	local self = setmetatable(UIBase.new(Gui), Checkbox)

	self.Checked = Instance.new("BoolValue")
	self.Checked.Value = false

	self.CheckButton = self.Gui.CheckButton
	self.TextLabel = self.Gui.TextLabel
	self.TextLabel.Text = "???"

	self.Maid.Click = self.Gui.MouseButton1Click:connect(function()
		self.Checked.Value = not self.Checked.Value
	end)

	self.Maid.ButtonClick = self.CheckButton.MouseButton1Click:connect(function()
		self.Checked.Value = not self.Checked.Value
	end)

	self.Maid.Changed = self.Checked.Changed:connect(function()
		self:UpdateRender()
	end)
	self:UpdateRender()

	self.Maid:GiveTask(self.Gui.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self.Gui.BackgroundTransparency = 0
		end
	end))

	self.Maid:GiveTask(self.Gui.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self.Gui.BackgroundTransparency = 1
		end
	end))

	return self
end

function Checkbox:GetBoolValue()
	return self.Checked
end

function Checkbox:WithData(Data)
	self.Data = Data or error("No data")

	return self
end

function Checkbox:WithRenderData(RenderData)
	self.RenderData = RenderData or error("No RenderData")
	self.TextLabel.Text = tostring(self.RenderData.Name)

	return self
end

function Checkbox:UpdateRender()
	if self.Checked.Value then
		self.CheckButton.Text = "X"
	else
		self.CheckButton.Text = ""
	end
end



local DropDownButton = setmetatable({}, UIBase)
DropDownButton.__index = DropDownButton
DropDownButton.ClassName = "DropDownButton"

function DropDownButton.new(Gui)
	local self = setmetatable(UIBase.new(Gui), DropDownButton)

	self.TextLabel = self.Gui.TextLabel
	self.IconLabel = self.Gui.IconLabel

	self.Selected = Signal.new()
	self.IsSelected = Instance.new("BoolValue")
	self.IsSelected.Value = false

	self.Maid.IsSelectedChanged = self.IsSelected.Changed:connect(function()
		self:UpdateRender()
	end)
	self.Maid.VisibleChanged = self.VisibleChanged:connect(function(IsVisible, DoNotAnimate)
		self.Gui.Visible = IsVisible
		if not IsVisible then
			self.MouseOver = false
		end
		self:UpdateRender()
	end)

	self.MouseOver = false
	self.Maid.InputBeganEnter = self.Gui.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self.MouseOver = true
			self:UpdateRender()
		end
	end)

	self.Maid.InputEnded = self.Gui.InputEnded:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self.MouseOver = false
			self:UpdateRender()
		end
	end)

	return self
end

function DropDownButton:GetData()
	return self.Data
end

function DropDownButton:UpdateRender()
	local Desired = Color3.new(1, 1, 1)
	if self.IsSelected.Value then
		Desired = Color3.new(90/255, 142/255, 243/255)
	end

	if self.MouseOver then
		Desired = Desired:lerp(Color3.new(0, 0, 0), 0.05)
	end

	self.Gui.BackgroundColor3 = Desired
end

function DropDownButton:WithScroller(Scroller)
	self.Scroller = Scroller or error("No scroller")

	self.Maid.InputBeganScroller = self.Scroller:BindInput(self.Gui, {
		OnClick = function(InputObject)
			self.Selected:fire()
		end;
	})

	return self
end

function DropDownButton:WithData(Data)
	self.Data = Data or error("No data")

	return self
end

function DropDownButton:WithRenderData(RenderData)
	self.RenderData = RenderData or error("No RenderData")

	self.TextLabel.Text = tostring(RenderData.Name)

	if RenderData.Image and RenderData.Image.Image then
		self.IconLabel.Image = RenderData.Image.Image
	else
		self.IconLabel.Image = "rbxassetid://133293265"
	end

	if RenderData.Image and RenderData.Image.ImageRectSize then
		self.IconLabel.ImageRectSize = RenderData.Image.ImageRectSize
	else
		self.IconLabel.ImageRectSize = Vector2.new()
	end

	if RenderData.Image and RenderData.Image.ImageRectOffset then
		self.IconLabel.ImageRectOffset = RenderData.Image.ImageRectOffset
	else
		self.IconLabel.ImageRectOffset = Vector2.new()
	end

	return self
end

function DropDownButton:GetRenderData()
	return self.RenderData
end





local DropDownFilter = setmetatable({}, UIBase)
DropDownFilter.__index = DropDownFilter
DropDownFilter.ClassName = "DropDownFilter"
DropDownFilter.DefaultFilterText = "Filter..."

function DropDownFilter.new(Gui)
	local self = setmetatable(UIBase.new(Gui), DropDownFilter)

	self.CurrentText = ValueObject.new()
	self.ClearButton = self.Gui.ClearButton
	self.Background = self.Gui.Background

	self.AutoselectTop = Signal.new()

	self.Maid.VisibleChanged = self.VisibleChanged:connect(function(IsVisible, DoNotAnimate)
		if not IsVisible then
			self.Gui:ReleaseFocus(false)
		end
	end)

	self.Maid.Focused = self.Gui.Focused:connect(function()
		self.Gui.Text = ""
	end)

	self.Maid.FocusLost = self.Gui.FocusLost:connect(function(EnterPressed, InputObject)
		local Trimmed = TrimString(self.Gui.Text)
		if #Trimmed == 0 then
			self.Gui.Text = self.DefaultFilterText
		end

		if EnterPressed then
			self.AutoselectTop:fire()
		end
	end)

	self.Maid.FilterTextBoxChanged = self.Gui.Changed:connect(function(Property)
		if Property == "Text" then
			self:UpdateRender()
		end
	end)

	self.MouseOver = false
	self.Maid.InputBeganEnter = self.Background.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self.MouseOver = true
			self:UpdateRender()
		end
	end)

	self.Maid.InputEnded = self.Background.InputEnded:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self.MouseOver = false
			self:UpdateRender()
		end
	end)


	self.Maid.ClearButtonClick = self.ClearButton.MouseButton1Click:connect(function()
		self.Gui.Text = self.DefaultFilterText
		self.Gui:ReleaseFocus(false)
	end)

	return self
end

function DropDownFilter:GetText()
	local Trimmed = TrimString(self.Gui.Text)
	if #Trimmed == 0 then
		return self.DefaultFilterText
	end
	return Trimmed
end

function DropDownFilter:UpdateRender()
	if self.MouseOver then
		self.Background.BackgroundColor3 = Color3.new(0.95, 0.95, 0.95)
	else
		self.Background.BackgroundColor3 = Color3.new(1, 1, 1)
	end

	if not self.Gui:IsFocused() then
		local Text = self:GetText()
		if self.Gui.Text ~= Text then
			self.Gui.Text = self:GetText()
		end
	end

	if self:IsFiltered() or self.Gui:IsFocused() then
		self.ClearButton.Visible = true
	else
		self.ClearButton.Visible = false
	end

	if self:IsFiltered() then
		self.CurrentText.Value = self:GetText()
	else
		self.CurrentText.Value = nil
	end
end

function DropDownFilter:IsFiltered()
	return self.Gui.Text ~= self.DefaultFilterText and #TrimString(self.Gui.Text) > 0
end


local DropDownPane = setmetatable({}, UIBase)
DropDownPane.__index = DropDownPane
DropDownPane.ClassName = "DropDownPane"
DropDownPane.MaxHeight = 400

function DropDownPane.new(Gui)
	local self = setmetatable(UIBase.new(Gui), DropDownPane)

	self.Selected = ValueObject.new()

	self.ButtonCache = {}
	self.Buttons = {}
	self.ScrollingFrame = self.Gui.ScrollingFrame
	self.Container = self.ScrollingFrame.Container
	self.Template = self.Container.Template
	self.Template.Visible = false


	self.Scroller = ScrollingFrame.new(self.Container)
	self.Maid.Scroller = self.Scroller

	self.ScrollbarContainer = self.Gui.ScrollbarContainer
	self.Scroller:AddScrollbar(self.ScrollbarContainer.Scrollbar)

	do
		local ButtonGui = self.Template:Clone()
		ButtonGui.Visible = true
		ButtonGui.Parent = self.Gui

		self.SelectedRenderButton = DropDownButton.new(ButtonGui)
		self.Maid.SelectedRenderButton = self.SelectedRenderButton

		self.SelectedRenderButton:Show()

		self.Maid.SelectedRenderButtonClick = self.SelectedRenderButton.Selected:connect(function()
			self:Toggle()
		end)
	end

	self.FilterBox = DropDownFilter.new(self.Gui.FilterTextBox)

	self.Maid.VisibleChanged = self.VisibleChanged:connect(function(IsVisible, DoNotAnimate)
		self:UpdateRender()

		self.FilterBox:SetVisible(IsVisible, DoNotAnimate)
		--[[
		if self.Selected.Value then
			local ScrollPosition = self.Selected.Value.Gui.AbsolutePosition.Y - self.ScrollingFrame.AbsolutePosition.Y
			self.Scroller:ScrollTo(ScrollPosition, true)
		end--]]
	end)
	self:UpdateRender()

	self.Maid.SelectedChanged = self.Selected.Changed:connect(function(NewValue, OldValue)
		if OldValue then
			OldValue.IsSelected.Value = false
		end
		if NewValue then
			NewValue.IsSelected.Value = true
		end

		self:UpdateRender()
	end)


	self.Maid.AutoselectTop = self.FilterBox.AutoselectTop:connect(function()
		if self.Buttons[1] then
			self.Selected.Value = self.Buttons[1]
			self:Hide()
		end
	end)

	return self
end


function DropDownPane:UpdateRender()
	if self.Selected.Value then
		self.SelectedRenderButton:WithRenderData(self.Selected.Value:GetRenderData())
	else
		self.SelectedRenderButton:WithRenderData({
			Name = "Select a class";
		})
	end

	local YHeight = 0
	for _, Button in pairs(self.Buttons) do
		Button.Gui.Position = UDim2.new(0, 0, 0, YHeight)
		YHeight = YHeight + Button.Gui.Size.Y.Offset
	end

	if self:IsVisible() then
		self.Gui.Size = UDim2.new(self.Gui.Size.X, UDim.new(0, math.min(self.MaxHeight, YHeight + 80)))
	else
		self.Gui.Size = UDim2.new(self.Gui.Size.X, UDim.new(1, 0))
	end
	self.Container.Size = UDim2.new(self.Gui.Size.X, UDim.new(0, YHeight))
end

function DropDownPane:GetButtonFromData(Data)
	if self.ButtonCache[Data] then
		return self.ButtonCache[Data]
	end

	local ButtonMaid = MakeMaid()

	local Gui = self.Template:Clone()
	Gui.Visible = false
	Gui.Name = tostring(Data.ClassName) .. "Button"
	Gui.Parent = self.Template.Parent

	local Button = DropDownButton.new(Gui)
		:WithData(Data)
		:WithRenderData({
			Name = Data.ClassName;
			Image = IconHandler:GetIcon(Data.ClassName);
		})
		:WithScroller(self.Scroller)

	ButtonMaid.Button = Button
	ButtonMaid.Selected = Button.Selected:connect(function()
		self.Selected.Value = Button
		self:Hide()
	end)


	self.ButtonCache[Data] = Button
	self.Maid[Button] = ButtonMaid

	return Button
end


function DropDownPane:UpdateButtons(Suggested)
	for _, Item in pairs(self.Buttons) do
		Item:Hide(true)
	end

	self.Buttons = {}
	if Suggested then
		for _, Data in pairs(Suggested) do
			local Button = self:GetButtonFromData(Data)
			Button:Show(true)
			table.insert(self.Buttons, Button)
		end
	end

	self:UpdateRender()
end



local DropDown = setmetatable({}, UIBase)
DropDown.__index = DropDown
DropDown.ClassName = "DropDown"

function DropDown.new(Gui)
	local self = setmetatable(UIBase.new(Gui), DropDown)

	self.Pane = DropDownPane.new(self.Gui.Pane)
	self.Maid.Pane = self.Pane

	self.Maid.Click = self.Gui.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self.Pane:Toggle()
		end
	end)

	return self
end


local CheckboxPane = setmetatable({}, UIBase)
CheckboxPane.ClassName = "CheckboxPane"
CheckboxPane.__index = CheckboxPane

function CheckboxPane.new(Gui)
	local self = setmetatable(UIBase.new(Gui), CheckboxPane)

	self.Checkboxes = {}
	self.SettingsChanged = Signal.new()

	self.CheckboxTemplate = self.Gui.CheckboxTemplate
	self.CheckboxTemplate.Visible = false

	return self
end

function CheckboxPane:AddCheckbox(Data)
	assert(Data.SerializeName)

	local Gui = self.CheckboxTemplate:Clone()
	Gui.Visible = true
	Gui.Parent = self.CheckboxTemplate.Parent

	local CheckboxMaid = MakeMaid()

	local checkbox = Checkbox.new(Gui)
		:WithData(Data)
		:WithRenderData({
			Name = Data.Name;
		})
	CheckboxMaid:GiveTask(checkbox)

	CheckboxMaid:GiveTask(checkbox.Checked.Changed:connect(function()
		self.SettingsChanged:fire()
	end))

	if Data.DefaultValue then
		checkbox.Checked.Value = Data.DefaultValue
	end

	checkbox:Show()

	self.Maid[checkbox] = CheckboxMaid
	table.insert(self.Checkboxes, checkbox)

	self:UpdateRender()

	return checkbox
end

function CheckboxPane:GetSettings()
	local Settings = {}
	for _, checkbox in pairs(self.Checkboxes) do
		Settings[checkbox.Data.SerializeName] = checkbox.Checked.Value
	end
	return Settings
end

function CheckboxPane:UpdateRender()
	local YHeight = 0
	for _, Button in pairs(self.Checkboxes) do
		Button.Gui.Position = UDim2.new(0, 0, 0, YHeight)
		YHeight = YHeight + Button.Gui.Size.Y.Offset
	end
end



local Pane = setmetatable({}, UIBase)
Pane.__index = Pane
Pane.ClassName = "Pane"

function Pane.new(Gui, Selection)
	local self = setmetatable(UIBase.new(Gui), Pane)

	-- self.Done = Signal.new()
	self.ConversionStarting = Signal.new()
	self.ConversionEnding = Signal.new()

	self.Selection = Selection or error("No selection")
	self.Content = self.Gui.Content
	self.WarningPane = self.Gui.WarningPane
	self.RetryButton = self.WarningPane.RetryButton

	self.Buttons = self.Content.Buttons
	self.ConvertButton = self.Buttons.ConvertButton
	self.StatusLabel = self.Buttons.StatusLabel
	self.LoadedStatusLabel = self.Buttons.LoadedStatusLabel

	self.DropDown = DropDown.new(self.Content.DropDown)
	self.Maid.DropDown = self.DropDown

	self.CheckboxPane = CheckboxPane.new(self.Content.Checkboxes)
	self.Maid.CheckboxPane = self.CheckboxPane

	self.CheckboxPane:AddCheckbox({
		Name = "Include not browsable";
		SerializeName = "IncludeNotBrowsable";
		DefaultValue = false;
	})
	self.CheckboxPane:AddCheckbox({
		Name = "Include not creatable";
		SerializeName = "IncludeNotCreatable";
		DefaultValue = false;
	})
	self.CheckboxPane:AddCheckbox({
		Name = "Include services";
		SerializeName = "IncludeServices";
		DefaultValue = false;
	})

	self.Maid.SettingsChanged = self.CheckboxPane.SettingsChanged:connect(function()
		self:UpdateRender()
	end)

	-- self.Maid.ScreenGui = self.Gui.Parent
	-- self.Maid.CloseButtonClick = self.Gui.Header.CloseButton.MouseButton1Click:connect(function()
	-- 	self.Done:fire()
	-- end)


	self.Maid.RetryButton = self.RetryButton.MouseButton1Click:connect(function()
		self:SelectHttpService()
		self.Converter:GetAPIAsync(true)
		self:UpdateRender()
	end)

	self.Maid:GiveTask(self.DropDown.Pane.Selected.Changed:connect(function()
		self:UpdateRender()
	end))

	self.Maid.ConvertButtonClick = self.ConvertButton.MouseButton1Click:connect(function()
		self:UpdateRender()
		if self.IsAvailable then
			self:DoConversion()
		end
	end)

	self.Maid.VisibleChanged = self.VisibleChanged:connect(function(IsVisible, DoNotAnimate)
		self.CheckboxPane:SetVisible(IsVisible)
		self.Gui.Visible = IsVisible

		self.CheckboxPane:SetVisible(IsVisible)
		self.DropDown:SetVisible(IsVisible)

		self:UpdateRender()

		if IsVisible then
			self.Maid.SelectionChangedEvent = self.Selection.SelectionChanged:connect(function()
				if self:IsVisible() then
					self:UpdateRender()
				end
			end)
		else
			self.Maid.SelectionChangedEvent = nil
		end
	end)

	self.Maid.FilterChanged = self.DropDown.Pane.FilterBox.CurrentText.Changed:connect(function(CurrentText)
		self:UpdateRender()
	end)



	return self
end

function Pane:SelectHttpService()
	if not (#self.Selection:Get() == 1 and self.Selection:Get()[1] == HttpService) then
		self.Selection:Set({HttpService})
	end
end

function Pane:UpdateRender()
	local Selection = self.Selection:Get()
	local IsAvailable = true

	self.WarningPane.Visible = false
	self.Content.Visible = true
	self.LoadedStatusLabel.Text = self.Converter:GetLoadedText()

	if self.Converter:IsNoHttp() then
		self.StatusLabel.Text = "No HTTP"
		self.WarningPane.Visible = true
		self.Content.Visible = false

		-- if not self.WasNoHttp then
		-- 	self.WasNoHttp = true
		-- 	self:SelectHttpService()
		-- end

		IsAvailable = false
	else
		self.WasNoHttp = false
	end

	if IsAvailable then
		if #Selection == 0 then
			self.StatusLabel.Text = "Nothing selected"
			IsAvailable = false
		elseif not self:GetClassName() then
			self.StatusLabel.Text = ("No class picked to convert to")
			IsAvailable = false
		elseif not self.Converter:CanConvert(Selection) then
			self.StatusLabel.Text = ("%d item%s are not similar"):format(#Selection, #Selection == 1 and "" or "s")
		else
			self.StatusLabel.Text = ("%d item%s selected"):format(#Selection, #Selection == 1 and "" or "s")
		end
	end

	if IsAvailable then
		self.ConvertButton.AutoButtonColor = true
		self.ConvertButton.TextTransparency = 0
		self.ConvertButton.Active = true
		self.ConvertButton.Style = Enum.ButtonStyle.RobloxRoundDefaultButton
	else
		self.ConvertButton.AutoButtonColor = false
		self.ConvertButton.Active = false
		self.ConvertButton.TextTransparency = 0.7
		self.ConvertButton.Style = Enum.ButtonStyle.RobloxRoundButton
	end

	self.IsAvailable = IsAvailable

	if self:IsVisible() then
		local Settings = self.CheckboxPane:GetSettings()
		Settings.Filter = self.DropDown.Pane.FilterBox.CurrentText.Value

		local Suggested = self.Converter:GetSuggested(Selection, Settings)
		self.DropDown.Pane:UpdateButtons(Suggested)
	else
		self.DropDown.Pane:UpdateButtons(nil)
	end
end

function Pane:WithConverter(Converter)
	self.Converter = Converter or error("No converter")

	self.Maid.HttpNotEnabledChanged = self.Converter.HttpNotEnabledChanged:connect(function()
		self:UpdateRender()
	end)

	return self
end

function Pane:GetClassName()
	local Selected = self.DropDown.Pane.Selected.Value
	if Selected then
		return Selected:GetData().ClassName
	end

	return nil
end

function Pane:DoConversion()
	local ClassName = self:GetClassName()
	local Selection = self.Selection:Get()
	if Selection and ClassName then
		print(("[Converter] - Converting selection to '%s'"):format(tostring(ClassName)))
		self.ConversionStarting:fire()

		local NewSelection = {}
		for _, Object in pairs(Selection) do
			local Result = self.Converter:ChangeClass(Object, ClassName) or Object
			table.insert(NewSelection, Result)
		end

		self.Selection:Set(NewSelection)
		self.ConversionEnding:fire()
	else
		print("[Converter] - No selection or class name")
	end
end

return Pane