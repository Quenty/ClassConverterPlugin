local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local Signal = require(script.Parent:WaitForChild("Signal"))
local StringMatcher = require(script.Parent:WaitForChild("StringMatcher"))

local Converter = {}
Converter.ClassName = "Converter"
Converter.__index = Converter
Converter.ApiSettingCacheName = "AnaminusAPICache"
Converter.MaxCacheSettingsTime = 60*60*24 -- 1 day
Converter.SearchCache = false -- TODO: Try enabling cache
Converter.ServiceNameMap = setmetatable({}, {
	__index = function(self, className)
		local isService = className:find("Service$")
		               or className:find("Provider$")
		               or className:find("Settings$")

		if not isService then
			-- Try to find the service
			pcall(function()
				isService = game:FindService(className)
			end)
		end

		self[className] = isService
		return isService
	end
})


Converter.BaseGroups = {
	Container = {
		'Folder',
		'Model',
		'Configuration',
		'Backpack',
	},
	Part = {
		'Part',
		'WedgePart',
		'MeshPart',
		'TrussPart',
		'Seat',
		'VehicleSeat',
		'SpawnLocation',
		'CornerWedgePart',
	},
	Event = {
		'RemoteEvent',
		'RemoteFunction',
		'BindableEvent',
		'BindableFunction'
	},
	Particle = {
		'Smoke',
		'Fire',
		'Sparkles',
		'Trail',
		'ParticleEmitter',
		'Explosion',
	},
	Value = '^.*Value$',
	Mesh = '^.*Mesh$'
}


for _, Item in pairs({"Workspace", "Debris", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "StarterGui", "StarterPack", "Teams", "Chat"}) do
	Converter.ServiceNameMap[Item] = true
end

function Converter.new(IS_DEBUG_MODE)
	local self = setmetatable({}, Converter)

	self.IS_DEBUG_MODE = IS_DEBUG_MODE
	self.HttpNotEnabled = false
	self.HttpNotEnabledChanged = Signal.new()

	return self
end

--[[
function Converter:GetPriority(ClassName)
	if IconHandler:HasIcon(ClassName) then
		return 5
	end

	return 0
end--]]

function Converter:CanConvert(Selection)
	local Classes = self:GetClassesMap()
	if not Classes then
		return false
	end

	local CommonAncestorsAndGroupsMap
	for _, Item in pairs(Selection) do
		local Class = Classes[Item.ClassName]
		if not Class then
			return false
		end

		if not CommonAncestorsAndGroupsMap then
			CommonAncestorsAndGroupsMap = {}
			-- Make a copy because original table is cached
			for Item, _ in pairs(Class:GetAncestorsAndGroups()) do
				CommonAncestorsAndGroupsMap[Item] = true
			end
		else
			-- Make sure we've got something in common with (set intersection)
			local NewCommon = {}
			for Item, _ in pairs(Class:GetAncestorsAndGroups()) do
				if CommonAncestorsAndGroupsMap[Item] then
					NewCommon[Item] = true
				end
			end
			CommonAncestorsAndGroupsMap = NewCommon
		end
	end

	return next(CommonAncestorsAndGroupsMap) ~= nil
end

-- We use the plugin
function Converter:WithPluginForCache(PluginForCache)
	self.PluginForCache = PluginForCache or error("No PluginForCache")
	return self
end

function Converter:IsNoHttp()
	return self.HttpNotEnabled
end

function Converter:GetAPIAsync(IsHttpEnabledRetry)
	if not self.API then
		if self.SearchCache and self.PluginForCache and self:IsNoHttp() then
			warn("[Converter] - No HTTP, searching for cache!")

			local CacheResult = self.PluginForCache:GetSetting(self.ApiSettingCacheName)
			if CacheResult then
				local Age = os.time() - CacheResult.CacheTime
				if Age <= self.MaxCacheSettingsTime then
					local Hours = math.floor((Age / 60 / 60))
					local Minutes = math.floor((Age/60) % 60)
					warn(("[Converter] - Restoring from cache! Results may be out of date. Age: %d:%d"):format(Hours, Minutes))
					self.API = CacheResult.Data
					return
				else
					-- Wipe cache!
					self.PluginForCache:SetSetting(self.ApiSettingCacheName, nil)
				end
			end
		end


		if self.APIPending then
			return self.APIPending:wait()
		end

		self.APIPending = Signal.new()
		delay(5, function()
			if self.APIPending then
				self.APIPending:fire(nil, "Timed out")
			end
		end)

		spawn(function()
			if IsHttpEnabledRetry then
				print("[Converter] - API request sent")
			end
			local Success, Error = pcall(function()
				self.API = HttpService:JSONDecode(HttpService:GetAsync('http://anaminus.github.io/rbx/json/api/latest.json'))
			end)
			if IsHttpEnabledRetry then
				print(("[Converter] - Done retrieving API (%s)"):format(Success and "Success" or ("Failed, '%s'"):format(tostring(Error))))
			end

			if self.API then
				-- Cache result for no-http points!
				self.PluginForCache:SetSetting(self.ApiSettingCacheName, {
					CacheTime = os.time();
					Data = self.API;
				})
			end

			if Success then
				self.HttpNotEnabled = false
				self.HttpNotEnabledChanged:fire()
			else
				self.HttpNotEnabled = (Error or ""):find("not enabled")
				self.HttpNotEnabledChanged:fire()
				Error = Error or "Error, no extra data"

				if self.IS_DEBUG_MODE then
					warn(("[Converter] - Failed to retrieve API due to '%s'"):format(tostring(Error)))
				end
			end

			self.APIPending:fire(self.API, Error)
			self.APIPending = nil
		end)

		self.APIPending:wait()
	end

	return self.API
end


function Converter:GetSuggested(Selection, Settings)
	local Classes = self:GetClassesMap()
	if not Classes then
		return nil
	end



	local RankMap = {}
	if Settings.Filter then
		local Matches = self.StringMatcher:match(Settings.Filter)
		for Index, Match in pairs(Matches) do
			RankMap[Classes[Match]] = #Matches - Index
		end
	else
		local function Explore(BaseClass)
			local Queue = {{BaseClass, 0}}

			-- Breadth first search
			while #Queue > 0 do
				local Class, Rank = unpack(table.remove(Queue, 1))
				if not RankMap[Class] then
					local ExtraRank = 0
					for _, Group in pairs(Class.Groups) do
						if BaseClass.Groups[Group.Name] then
							ExtraRank = ExtraRank + 10000
						end
					end
					RankMap[Class] = Rank + ExtraRank

					for _, Item in pairs(Class.Children) do
						table.insert(Queue, {Item, Rank + 10})
					end

					if Class.Superclass then
						table.insert(Queue, {Class.Superclass, Rank - 100})
					end
				end
			end

			RankMap[BaseClass] = nil
		end

		-- Exploration
		local Explored = false
		for _, Selected in pairs(Selection) do
			local Class = Classes[Selected.ClassName]
			if not Class then
				warn(("[Converter] - Bad class name '%s'"):format(Selected.ClassName))
				return nil
			end
			Explored = true
			Explore(Class)
			break;
		end

		if not Explored then
			Explore(Classes["Instance"])
		end
	end



	local Services = self.ServiceNameMap

	local function DoInclude(Class)
		return  (not Class.Tags.notbrowsable or Settings.IncludeNotBrowsable)
			and (not Class.Tags.notCreatable or Settings.IncludeNotCreatable)
			and (not Services[Class.ClassName] or Settings.IncludeServices)
		--[[
		if not Settings.IncludeNotBrowsable then

		end--]]
	end

	-- Remove current class from thing
	-- RankMap[Class] = nil

	local Options = {}
	for _, Class in pairs(Classes) do
		if RankMap[Class] and DoInclude(Class) then
			table.insert(Options, Class)
		end
	end
	table.sort(Options, function(A, B)
		if RankMap[A] == RankMap[B] then
			return A.ClassName < B.ClassName
		end
		return RankMap[A] > RankMap[B]
	end)
	return Options
end

local ClassMetatable = {}
ClassMetatable.__index = ClassMetatable

function ClassMetatable:IsA(self, Type)
	if not self then
		return false
	elseif self.ClassName == Type then
		return true
	elseif self.Superclass then
		return self.Superclass:IsA(Type)
	else
		return false
	end
end

function ClassMetatable:GetAllProperties()
	if self.AllProperties then
		return self.AllProperties
	end

	local Properties = {}
	local Current = self

	while Current do
		for _, Property in pairs(Current.Properties) do
			Properties[Property.Name] = Property
		end
		Current = Current.Superclass
	end
	self.AllProperties = Properties
	return Properties
end

function ClassMetatable:GetAncestorsAndGroups()
	if self.AncestorsAndGroups then
		return self.AncestorsAndGroups
	end
	local Map = {}
	for _, Group in pairs(self.Groups) do
		Map[Group] = true
	end

	local Current = self
	while Current and Current.ClassName ~= "Instance" do
		for _, Group in pairs(Current.Groups) do
			Map[Group] = true
		end
		Map[Current] = true
		Current = Current.Superclass
	end
	self.AncestorsAndGroups = Map
	return Map
end

function Converter:GetLoadedText()
	return self.LoadedText or "Not loaded"
end

function Converter:GetClassesMap()
	if self.Classes then
		return self.Classes
	end

	local API = self:GetAPIAsync()
	if not API then
		return nil
	end

	local Classes = {}
	local Properties = {}
	local ClassCount = 0
	local PropertyCount = 0
	for _, Data in pairs(self.API) do
		if Data.type == "Class" then
			ClassCount = ClassCount + 1
			local Class = setmetatable({
				ClassName = Data.Name;
				Children = {};
				OriginalData = Data;
				Tags = {};
				Properties = {};
				-- Parent = nil;
				Groups = {};
			}, ClassMetatable)

			if Data.tags then
				for _, Tag in pairs(Data.tags) do
					Class.Tags[Tag] = true
				end
			end
			Classes[Data.Name] = Class
		elseif Data.type == "Property" then
			PropertyCount = PropertyCount + 1
			Properties[Data] = {
				Name = Data.Name;
				OriginalData = Data;
				Classes = {};
				-- Class = nil;
			}
		end
	end
	self.LoadedText = ("Loaded " .. ClassCount .. " classes and " .. PropertyCount .. " properties")

	for _, Property in pairs(Properties) do
		local Class = Classes[Property.OriginalData.Class]
		if Class then
			Class.Properties[Property.Name] = Property;
			table.insert(Property.Classes, Class)
		else
			warn("No class found for property '%s'"):format(tostring(Property.Name))
		end
	end

	-- Calculate Superclass and Children
	for _, Class in pairs(Classes) do
		local SuperclassName = Class.OriginalData.Superclass
		if SuperclassName and Classes[SuperclassName] then
			local Superclass = Classes[SuperclassName]
			table.insert(Superclass.Children, Class)
			Class.Superclass = Superclass;
		end
	end
	self.Classes = Classes

	-- Calculate groups
	local Groups = {}

	local function AddToGroup(Group, GroupData)
		if type(GroupData) == "string" then
			if self.Classes[GroupData] then
				AddToGroup(Group, self.Classes[GroupData])
			else
				assert(GroupData:sub(#GroupData,#GroupData) == "$")

				for _, Class in pairs(self.Classes) do
					if Class.ClassName:find(GroupData) then
						AddToGroup(Group, Class)
					end
				end
			end
		elseif type(GroupData) == "table" then
			if not getmetatable(GroupData) then
				for _, Data in pairs(GroupData) do
					AddToGroup(Group, Data)
				end
			else
				-- Class
				if not GroupData.Groups[Group.Name] then
					table.insert(Group.Classes, GroupData)
					GroupData.Groups[Group.Name] = Group
				end
			end
		else
			error("Bad group type")
		end
	end

	for GroupName, GroupData in pairs(self.BaseGroups) do
		local Group = {
			Name = GroupName;
			Classes = {};
		}
		AddToGroup(Group, GroupData)
		table.insert(Groups, Group)
	end
	self.Groups = Groups


	local Options = {}
	for _, Class in pairs(Classes) do
		table.insert(Options, Class.ClassName)
	end
	self.StringMatcher = StringMatcher.new(Options, true, true)

	return self.Classes
end

function Converter:ChangeClass(Object, ClassName)
	local Classes = self:GetClassesMap()
	if not Classes then
		warn("[Converter] - No API loaded")
		return nil
	end

	local NewObject
	local Success, Error = pcall(function()
		NewObject = Instance.new(ClassName)
	end)
	if not NewObject then
		warn(("[Converter] - Failed to instantiate '%s'"):format(tostring(ClassName)))
		return nil
	end

	--[[
	local function Recurse(ClassName, Object, NewObject)
		for _,v in next, Classes do
			if (v['type'] == 'Class' and v['Name'] == ClassName and v['Superclass']) then
				Recurse(v['Superclass'], Object, NewObject)
			elseif (v['type'] == 'Property' and v['Class'] == ClassName) then
				if Changed[NewObject] then
					pcall(function() -- If property is not allowed to be changed, do not error.
						NewObject[v.Name] = Object[v.Name]
					end)
				end
			end
		end
	end

	Recurse(Object.ClassName, Object, NewObject)--]]


	local CurrentClass = Classes[Object.ClassName]
	local NewClass = Classes[ClassName]

	if not CurrentClass then
		warn(("[Converter] - Failed to find class for '%s'"):format(tostring(Object.ClassName)))
		return nil
	end
	if not NewClass then
		warn(("[Converter] - Failed to find class for '%s'"):format(tostring(ClassName)))
		return nil
	end

	local CurrentProperties = CurrentClass:GetAllProperties()
	local NewProperties = NewClass:GetAllProperties()
	for PropertyName, Data in pairs(CurrentProperties) do
		if PropertyName ~= "Parent" and NewProperties[PropertyName] then
			pcall(function() -- If property is not allowed to be changed, do not error.
				NewObject[PropertyName] = Object[PropertyName]
			end)
		end
	end

	-- Tag instance
	for _, Tag in pairs(CollectionService:GetTags(Object)) do
		CollectionService:AddTag(NewObject, Tag)
	end

	-- Go through each child and identify properties that point towards the parent that's getting replaced
	local OldParent = Object.Parent
	local DescendantList = Object:GetChildren()
	local DescendantPropertyMap = self:GetDescendantPropertyMap(DescendantList, Object, NewObject)

	for _, Descendant in pairs(DescendantList) do
		if DescendantPropertyMap[Descendant] then
			for Property, NewValue in pairs(DescendantPropertyMap[Descendant]) do
				pcall(function()
					Descendant[Property] = NewValue
				end)
			end
		end
	end

	-- Reparent children
	for _, Child in pairs(Object:GetChildren()) do
		Child.Parent = NewObject
	end

	Object:remove()
	NewObject.Parent = OldParent

	return NewObject
end

--- Map OldParent to NewParent to handle welds in children
function Converter:GetDescendantPropertyMap(ChildrenList, Object, NewObject)
	assert(NewObject)
	assert(Object)

	local Classes = self:GetClassesMap()
	if not Classes then
		warn("[Converter][GetDescendantPropertyMap] - No API loaded")
		return nil
	end

	local PropertyMap = {} -- [Child] = { [Property] = NewValue }
	for _, Child in pairs(ChildrenList) do
		local Class = Classes[Child.ClassName]
		for PropertyName, Data in pairs(Class:GetAllProperties()) do
			--print(PropertyName, Data.OriginalData.ValueType, "--")

			if PropertyName ~= "Parent" and Data.OriginalData.ValueType == "Object" then
				local PropertyValue

				-- Reading certain properties can error
				local Success = pcall(function()
					PropertyValue = Child[PropertyName]
				end)

				--print("PropertyValue", PropertyValue, PropertyValue == Object, Object)

				if Success and PropertyValue == Object then
					PropertyMap[Child] = PropertyMap[Child] or {}
					PropertyMap[Child][PropertyName] = NewObject
				end
			end
		end
	end
	return PropertyMap
end

return Converter