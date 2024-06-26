--[[

DOCUMENTS

return: nil - opens the script in Windows using websocket

- exploiting
loadstring(game:HttpGet("https://github.com/v1zoy/Roblox/edit/main/SaveInstance/InstancesToLua.lua"))( game.Workspace )

- roblox studio
loadstring(game:GetService("HttpService"):GetAsync("https://github.com/v1zoy/Roblox/edit/main/SaveInstance/InstancesToLua.lua"))( game.Workspace )

]] --

local RS = game:GetService("RunService")
local HS = game:GetService("HttpService")

function getRequest(url)
	local success, error = pcall(function()
		return game:HttpGet(url);
	end)
	if not success then
		return HS:GetAsync(url);
	end
end
function httpPostRequest(jsonData)
	if RS:IsServer() then
		HS:PostAsync('http://172.16.0.31:80', jsonData)
	else
		syn.request({
			Url = 'http://172.16.0.31:80',
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = jsonData
		})
	end	
end
local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local PropertyToString = loadstring(getRequest("https://raw.githubusercontent.com/v1zoy/Roblox/main/SaveInstance/PropertyToString.lua"))()
local API = loadstring(getRequest("https://raw.githubusercontent.com/v1zoy/Roblox/main/SaveInstance/API.lua"))()

local apiFetched = false
local classConverter = {
	'TouchTransmitter', 
	'Workspace',
	'Terrain',
	'StarterGui',
	'Players',
	'ServerScriptService',
	'ServerStorage',
	'Lighting',
}
local function InstanceToLua(part)
	local selectedItem = part
	local awaitReference = {}
	local defaultObjects = {}
	setmetatable(defaultObjects, {
		__index = function(self, index)
			local obj = Instance.new(index)
			rawset(defaultObjects, index, obj)
			return obj
		end;
	})
	if (not apiFetched) then
		apiFetched = true
		local success, returnVal = pcall(function()
			return API:Fetch()
		end)
		if ((not success) or (not returnVal)) then
			apiFetched = false
			return
		end
	end
	local codeBuilder = {}
	codeBuilder[#codeBuilder + 1] = "local partsWithId = {}\nlocal awaitRef = {}\n\nlocal root = "
	local ref = {}
	local idCount = 0
	local objectIds = {}
	local function GetProperties(obj, newClassName)
		local properties,default,class = {},defaultObjects[newClassName],API.ClassesByName[newClassName]
		for propName,propInfo in pairs(class:GetAllProperties(true)) do
			if ((not propInfo.ReadOnly) and (not propInfo.Hidden) and propName ~= "Parent") then
				local val = obj[propName]
				if (default[propName] == val) then continue end
				local valStr, isRef = PropertyToString(propInfo.ValueType, val, propName)
				if (isRef) then properties[propName] = ("\"_R:%s_\""):format(objectIds[val] or "E") else properties[propName] = valStr end
			end
		end
		return properties
	end
	local function Scan(obj, indentLvl)
		local newClassName = obj.ClassName
		if table.find(classConverter, obj.ClassName) then 
			newClassName = "Folder"
		end

		local indent = ("\t"):rep(indentLvl)
		if (indentLvl ~= 0) then
			codeBuilder[#codeBuilder + 1] = "\n" .. indent
		end
		codeBuilder[#codeBuilder + 1] = "{\n" .. indent .. "\tID = " .. objectIds[obj] .. ";\n" .. indent .. "\tType = \"" .. newClassName .. "\";\n" .. indent .. "\tProperties = {"
		local props = GetProperties(obj, newClassName)
		if (next(props)) then
			for propName,propVal in pairs(props) do
				codeBuilder[#codeBuilder + 1] = "\n" .. indent .. "\t\t" .. propName .. " = " .. propVal .. ";"
			end
			codeBuilder[#codeBuilder + 1] = "\n" .. indent .. "\t};"
		else
			codeBuilder[#codeBuilder + 1] = "};"
		end
		local children = obj:GetChildren()
		if (#children > 0) then
			codeBuilder[#codeBuilder + 1] = "\n" .. indent .. "\tChildren = {"
			for _,child in pairs(children) do
				Scan(child, indentLvl + 2)
			end
			codeBuilder[#codeBuilder + 1] = "\n" .. indent .. "\t};\n" .. indent .. "};"
		else
			codeBuilder[#codeBuilder + 1] = "\n" .. indent .. "\tChildren = {};\n" .. indent .. "};"
		end
	end
	objectIds[selectedItem] = idCount
	for _,v in pairs(selectedItem:GetDescendants()) do
		idCount = (idCount + 1)
		objectIds[v] = idCount
	end
	Scan(selectedItem, 0)
	local variables = table.concat(codeBuilder, "") 
	codeBuilder[#codeBuilder + 1] = "local function Scan(item, parent) local obj = Instance.new(item.Type) if (item.ID) then local awaiting = awaitRef[item.ID] if (awaiting) then awaiting[1][awaiting[2]] = obj awaitRef[item.ID] = nil else partsWithId[item.ID] = obj end end for p,v in pairs(item.Properties) do if (type(v) == \"string\") then local id = tonumber(v:match(\"^_R:(%w+)_$\")) if (id) then if (partsWithId[id]) then v = partsWithId[id] else awaitRef[id] = {obj, p} v = nil end end end obj[p] = v end for _,c in pairs(item.Children) do Scan(c, obj) end obj.Parent = parent return obj end\nScan(root, workspace)"
	local source = table.concat(codeBuilder, "")

	local parent = 'game.'
	local jsonData = HS:JSONEncode({script = source, name = game.placeId..'-'..parent..selectedItem:GetFullName()})
	print("Saving Instance(s)...")
	httpPostRequest(jsonData)
	return {
		source = source,
		getRoot = function()
			return loadstring(`{variables} return root;`)()
		end,
	}
end

local args = ...
local success, output = pcall(function()
	return InstanceToLua(args)
end)
return output;
