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


for _, item in pairs({
	"Workspace",
	"Debris",
	"Players",
	"Lighting",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"StarterGui",
	"StarterPack",
	"Teams",
	"Chat"}) do
	Converter.ServiceNameMap[item] = true
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

function Converter:CanConvert(selection)
	local classes = self:GetClassesMap()
	if not classes then
		return false
	end

	local commonAncestorsAndGroupsMap
	for _, item in pairs(selection) do
		local Class = classes[item.ClassName]
		if not Class then
			return false
		end

		if not commonAncestorsAndGroupsMap then
			commonAncestorsAndGroupsMap = {}
			-- Make a copy because original table is cached
			for child, _ in pairs(Class:GetAncestorsAndGroups()) do
				commonAncestorsAndGroupsMap[child] = true
			end
		else
			-- Make sure we've got something in common with (set intersection)
			local newCommon = {}
			for child, _ in pairs(Class:GetAncestorsAndGroups()) do
				if commonAncestorsAndGroupsMap[child] then
					newCommon[child] = true
				end
			end
			commonAncestorsAndGroupsMap = newCommon
		end
	end

	return next(commonAncestorsAndGroupsMap) ~= nil
end

-- We use the plugin to cache content
function Converter:WithPluginForCache(pluginForCache)
	self._pluginForCache = pluginForCache or error("No pluginForCache")

	return self
end

function Converter:IsNoHttp()
	return self.HttpNotEnabled
end

function Converter:GetAPIAsync(isHttpEnabledRetry)
	if not self.API then
		if self.SearchCache and self._pluginForCache and self:IsNoHttp() then
			warn("[Converter] - No HTTP, searching for cache!")

			local cacheResult = self._pluginForCache:GetSetting(self.ApiSettingCacheName)
			if cacheResult then
				local Age = os.time() - cacheResult.CacheTime
				if Age <= self.MaxCacheSettingsTime then
					local Hours = math.floor((Age / 60 / 60))
					local Minutes = math.floor((Age/60) % 60)
					warn(("[Converter] - Restoring from cache! Results may be out of date. Age: %d:%d"):format(Hours, Minutes))
					self.API = cacheResult.Data
					return
				else
					-- Wipe cache!
					self._pluginForCache:SetSetting(self.ApiSettingCacheName, nil)
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
			if isHttpEnabledRetry then
				print("[Converter] - API request sent")
			end
			local ok, err = pcall(function()
				self.API = HttpService:JSONDecode(HttpService:GetAsync('http://anaminus.github.io/rbx/json/api/latest.json'))
			end)
			if isHttpEnabledRetry then
				print(("[Converter] - Done retrieving API (%s)"):format(ok and "Success" or ("Failed, '%s'"):format(tostring(err))))
			end

			if self.API then
				-- Cache result for no-http points!
				self._pluginForCache:SetSetting(self.ApiSettingCacheName, {
					CacheTime = os.time();
					Data = self.API;
				})
			end

			if ok then
				self.HttpNotEnabled = false
				self.HttpNotEnabledChanged:fire()
			else
				self.HttpNotEnabled = (err or ""):find("not enabled")
				self.HttpNotEnabledChanged:fire()
				err = err or "Error, no extra data"

				if self.IS_DEBUG_MODE then
					warn(("[Converter] - Failed to retrieve API due to '%s'"):format(tostring(err)))
				end
			end

			self.APIPending:fire(self.API, err)
			self.APIPending = nil
		end)

		self.APIPending:wait()
	end

	return self.API
end


function Converter:GetSuggested(selection, settings)
	local classes = self:GetClassesMap()
	if not classes then
		return nil
	end

	local rankMap = {}
	if settings.Filter then
		local matches = self.StringMatcher:match(settings.Filter)
		for index, Match in pairs(matches) do
			rankMap[classes[Match]] = #matches - index
		end
	else
		local function Explore(baseClass)
			local queue = {{baseClass, 0}}

			-- Breadth first search
			while #queue > 0 do
				local Class, Rank = unpack(table.remove(queue, 1))
				if not rankMap[Class] then
					local ExtraRank = 0
					for _, Group in pairs(Class.Groups) do
						if baseClass.Groups[Group.Name] then
							ExtraRank = ExtraRank + 10000
						end
					end
					rankMap[Class] = Rank + ExtraRank

					for _, Item in pairs(Class.Children) do
						table.insert(queue, {Item, Rank + 10})
					end

					if Class.Superclass then
						table.insert(queue, {Class.Superclass, Rank - 100})
					end
				end
			end

			rankMap[baseClass] = nil
		end

		-- Exploration
		local _, selected = next(selection)
		if selection then
			local class = classes[selected.ClassName]
			if not class then
				warn(("[Converter] - Bad class name '%s'"):format(selected.ClassName))
				return nil
			end
			Explore(class)
		else
			Explore(classes["Instance"])
		end
	end

	local services = self.ServiceNameMap

	local function doInclude(class)
		return  (not class.Tags.notbrowsable or settings.IncludeNotBrowsable)
			and (not class.Tags.notCreatable or settings.IncludeNotCreatable)
			and (not services[class.ClassName] or settings.IncludeServices)
		--[[
		if not Settings.IncludeNotBrowsable then

		end--]]
	end

	-- Remove current class from thing
	-- rankMap[Class] = nil

	local options = {}
	for _, Class in pairs(classes) do
		if rankMap[Class] and doInclude(Class) then
			table.insert(options, Class)
		end
	end
	table.sort(options, function(A, B)
		if rankMap[A] == rankMap[B] then
			return A.ClassName < B.ClassName
		end
		return rankMap[A] > rankMap[B]
	end)
	return options
end

local ClassMetatable = {}
ClassMetatable.__index = ClassMetatable

function ClassMetatable:IsA(type)
	if not self then
		return false
	elseif self.ClassName == type then
		return true
	elseif self.Superclass then
		return self.Superclass:IsA(type)
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
	if self._classes then
		return self._classes
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
	self._classes = Classes

	-- Calculate groups
	local Groups = {}

	local function AddToGroup(Group, GroupData)
		if type(GroupData) == "string" then
			if self._classes[GroupData] then
				AddToGroup(Group, self._classes[GroupData])
			else
				assert(GroupData:sub(#GroupData,#GroupData) == "$")

				for _, Class in pairs(self._classes) do
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

	return self._classes
end

function Converter:ChangeClass(object, ClassName)
	local Classes = self:GetClassesMap()
	if not Classes then
		warn("[Converter] - No API loaded")
		return nil
	end

	local newObject
	local ok, err = pcall(function()
		newObject = Instance.new(ClassName)
	end)
	if not ok then
		warn(("[Converter] - Failed to make new instance '%s' due to '%s'"):format(tostring(ClassName), tostring(err)))
		return
	end
	if not newObject then
		warn(("[Converter] - Failed to instantiate '%s'"):format(tostring(ClassName)))
		return nil
	end

	--[[
	local function Recurse(ClassName, object, newObject)
		for _,v in next, Classes do
			if (v['type'] == 'Class' and v['Name'] == ClassName and v['Superclass']) then
				Recurse(v['Superclass'], object, newObject)
			elseif (v['type'] == 'Property' and v['Class'] == ClassName) then
				if Changed[newObject] then
					pcall(function() -- If property is not allowed to be changed, do not error.
						newObject[v.Name] = object[v.Name]
					end)
				end
			end
		end
	end

	Recurse(object.ClassName, object, newObject)--]]


	local currentClass = Classes[object.ClassName]
	local newClass = Classes[ClassName]

	if not currentClass then
		warn(("[Converter] - Failed to find class for '%s'"):format(tostring(object.ClassName)))
		return nil
	end
	if not newClass then
		warn(("[Converter] - Failed to find class for '%s'"):format(tostring(ClassName)))
		return nil
	end

	local currentProperties = currentClass:GetAllProperties()
	local newProperties = newClass:GetAllProperties()
	for propertyName, _ in pairs(currentProperties) do
		if propertyName ~= "Parent" and newProperties[propertyName] then
			pcall(function() -- If property is not allowed to be changed, do not error.
				newObject[propertyName] = object[propertyName]
			end)
		end
	end

	-- Tag instance
	for _, Tag in pairs(CollectionService:GetTags(object)) do
		CollectionService:AddTag(newObject, Tag)
	end

	-- Go through each child and identify properties that point towards the parent that's getting replaced
	local oldParent = object.Parent
	local descendantList = object:GetChildren()
	local descendantPropertyMap = self:GetDescendantPropertyMap(descendantList, object, newObject)

	for _, descendant in pairs(descendantList) do
		if descendantPropertyMap[descendant] then
			for Property, NewValue in pairs(descendantPropertyMap[descendant]) do
				pcall(function()
					descendant[Property] = NewValue
				end)
			end
		end
	end

	-- Reparent children
	for _, child in pairs(object:GetChildren()) do
		child.Parent = newObject
	end

	object:remove()
	newObject.Parent = oldParent

	return newObject
end

--- Map oldParent to NewParent to handle welds in children
function Converter:GetDescendantPropertyMap(childrenList, object, newObject)
	assert(newObject)
	assert(object)

	local classes = self:GetClassesMap()
	if not classes then
		warn("[Converter][GetDescendantPropertyMap] - No API loaded")
		return nil
	end

	local propertyMap = {} -- [Child] = { [Property] = NewValue }
	for _, child in pairs(childrenList) do
		local class = classes[child.ClassName]
		for propertyName, data in pairs(class:GetAllProperties()) do
			--print(propertyName, data.OriginalData.ValueType, "--")

			if propertyName ~= "Parent" and data.OriginalData.ValueType == "Object" then
				local propertyValue

				-- Reading certain properties can error
				local ok = pcall(function()
					propertyValue = child[propertyName]
				end)

				--print("propertyValue", propertyValue, propertyValue == object, object)

				if ok and propertyValue == object then
					propertyMap[child] = propertyMap[child] or {}
					propertyMap[child][propertyName] = newObject
				end
			end
		end
	end
	return propertyMap
end

return Converter