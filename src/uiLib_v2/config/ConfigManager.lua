local ConfigManager = {}
local HttpService = game:GetService("HttpService")
local State = require(script.Parent.Parent.state)

local cachedConfig = nil

function ConfigManager.getPath()
	local folder = State.saveFolder ~= "" and (State.saveFolder .. "/") or ""
	return folder .. State.saveFileName .. ".json"
end

function ConfigManager.getDefault()
	return { 
		Startup = {}, 
		Keybinds = {}, 
		Settings = {
			GridSnap = true,
			GridSize = 15
		}, 
		TabPositions = {},
		TabStates = {},
		MenuToggle = "RightShift",
		QuickCommandsToggle = "F2"
	}
end

function ConfigManager.load()
	if cachedConfig then return cachedConfig end

	if type(isfile) ~= "function" or not isfile(ConfigManager.getPath()) then 
		cachedConfig = ConfigManager.getDefault()
		return cachedConfig
	end
	
	local success, content = pcall(readfile, ConfigManager.getPath())
	if not success then return ConfigManager.getDefault() end
	
	local decSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, content)
	cachedConfig = decSuccess and decoded or ConfigManager.getDefault()
	return cachedConfig
end

function ConfigManager.save(config)
	cachedConfig = config
	if type(writefile) ~= "function" then return false end
	
	if State.saveFolder ~= "" and type(isfolder) == "function" and not isfolder(State.saveFolder) then
		pcall(makefolder, State.saveFolder)
	end
	
	local success, encoded = pcall(HttpService.JSONEncode, HttpService, config)
	if not success then return false end
	return pcall(writefile, ConfigManager.getPath(), encoded)
end

function ConfigManager.set(key, value, dict)
	local config = ConfigManager.load()
	if dict then
		config[dict] = config[dict] or {}
		config[dict][key] = value
	else
		config[key] = value
	end
	ConfigManager.save(config)
end

function ConfigManager.get(dict)
	local config = ConfigManager.load()
	return dict and (config[dict] or {}) or config
end

return ConfigManager