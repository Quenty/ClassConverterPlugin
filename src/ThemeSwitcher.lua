-- Theme Switcher for Quenty's Class Converter Plugin
-- provides support for Roblox Studio's Themes
-- defaults to light theme if Roblox Studio ever supports more themes
-- @author presssssure

local ThemeSwitcher = {}

local Studio = settings().Studio

local DockWidget = nil

local LightColors = {
	Background = Color3.fromRGB(255, 255, 255),
	BackgroundOnHover = Color3.fromRGB(242, 242, 242),

	Text = Color3.fromRGB(40, 40, 40),
	DropDownText = Color3.fromRGB(27, 42, 53),
	DropDownAccent = Color3.fromRGB(0, 0, 0),
	TextBoxText = Color3.fromRGB(49, 49, 49),

	Line = Color3.fromRGB(230, 230, 230),
	ScrollBar = Color3.fromRGB(230, 230, 230),
	ScrollBarOnHover = Color3.fromRGB(161, 161, 161),
	Selected = Color3.fromRGB(90, 142, 243),

	ButtonStyle = Enum.ButtonStyle.RobloxRoundDropdownButton,
}
local DarkColors = {
	Background = Color3.fromRGB(46, 46, 46),
	BackgroundOnHover = Color3.fromRGB(56, 56, 56),

	Text = Color3.fromRGB(204, 204, 204),
	DropDownText = Color3.fromRGB(191, 206, 217),
	DropDownAccent = Color3.fromRGB(255, 255, 255),
	TextBoxText = Color3.fromRGB(213, 213, 213),

	Line = Color3.fromRGB(21, 21, 21),
	ScrollBar = Color3.fromRGB(76, 76, 76),
	ScrollBarOnHover = Color3.fromRGB(96, 96, 96),
	Selected = Color3.fromRGB(90, 142, 243),

	ButtonStyle = Enum.ButtonStyle.RobloxButton,
}
local ConvertButtonTextColor = Color3.fromRGB(255, 255, 255)


-- find theme colors (defaults to light if other themes are available besides light and dark)
local function GetColorPalette(theme)
	if theme == Enum.UITheme.Dark then
		return DarkColors
	end
	return LightColors
end


-- determines if a button is a button in the dropdown menu
local function isInDropDown(obj)
	return (obj.Parent.Parent.Parent.Parent and obj.Parent.Parent.Parent.Parent.Name == "DropDown")
end


-- determines if something is a "Line" (really skinny Frame that stretches across the page)
local function isLine(obj)
	return obj.AbsoluteSize.Y == 1 or obj.AbsoluteSize.Y == 2
end


-- changes the theme of a given ui element
function ThemeSwitcher.SwitchObject(obj, theme)
	if not obj:IsA("GuiBase") then return end
	theme = theme or Studio["UI Theme"]

	local NewPalette = GetColorPalette(theme)

	-- handle special cases first
	if isLine(obj) then -- lines in the main view
		obj.BackgroundColor3 = NewPalette.Line
		return
	elseif obj.Name == "Scrollbar" then -- scroll bar in the drop down
		obj.BackgroundColor3 = NewPalette.ScrollBar
		return
	elseif obj.Name == "CheckButton" then -- check boxes in the main view
		obj.Style = NewPalette.ButtonStyle
		-- no return on purpose, text color still needs to be changed
	elseif obj.Name == "ConvertButton" then -- ConvertButton's text color is always the same
		obj.TextColor3 = ConvertButtonTextColor
		return
	end

	-- then change the text
	if obj.ClassName:find("Text") then
		local NewTextColor

		if obj:IsA("TextBox") then
			 NewTextColor = NewPalette.TextBoxText
		elseif isInDropDown(obj) then
			NewTextColor = NewPalette.DropDownText
		else
			NewTextColor = NewPalette.Text
		end

		obj.TextColor3 = NewTextColor
	end

	-- lastly change the background
	obj.BackgroundColor3 = NewPalette.Background
end


-- switches every ui element within
local function SwitchAllObjects(NewTheme)
	for _, obj in pairs(DockWidget:GetDescendants()) do
		ThemeSwitcher.SwitchObject(obj, NewTheme)
	end
end


-- for when the user changes theme while having the window open
Studio.ThemeChanged:Connect(function()
	SwitchAllObjects(Studio["UI Theme"])
end)


-- switches the plugin dock widget and all the objects within it
function ThemeSwitcher.SetDockWidget(NewDockWidget)
	DockWidget = NewDockWidget

	SwitchAllObjects(Studio["UI Theme"])
	DockWidget.DescendantAdded:Connect(function(obj)
		ThemeSwitcher.SwitchObject(obj, Studio["UI Theme"])
	end)
end


-- allow other scripts to access colors
function ThemeSwitcher.GetColorFor(ElementString)
	local Palette = GetColorPalette(Studio["UI Theme"])
	return Palette[ElementString]
end

return ThemeSwitcher