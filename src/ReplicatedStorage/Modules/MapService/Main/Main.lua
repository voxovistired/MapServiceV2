--!strict
--!optimize 2

local MapService: MapService = {
	-- This is where we store all of the meta for our maps.
	__maid = nil;
	CurrentMap = nil;
	Maps = {};

	-- Current Stage meta.
	Stage = nil;
	ExtraCameras = {};
	Cameras = {
		BF = nil;
		Dad = nil;
		Camera = nil;
	};

	-- Track any assets that aren't being used or are being cached.
	Lighting = {
		Objects = {} :: { Instance };
		Properties = {} :: { [string]: any };
	};
	Instances = {};
	StageData = {
		-- Tracking all positions
		BFCam = nil;
		DadCam = nil;
		MainCam = nil;

		Speaker = nil;
		GF = nil;
	};
	Connections = {};
	Signals = {};
};

--[[
	AARON'S TO-DO LIST:
	
	TODO: Begin the process on creating and adding on maps into MapService so it can be accessible for other stuff
]]

-- Services
local RunService = game:GetService("RunService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Lighting = game:GetService("Lighting");
local ServerStorage = RunService:IsServer() and game:GetService("ServerStorage") or nil;
local Players = game:GetService("Players");

-- Variables
local Assets: Folder? = ServerStorage and ServerStorage.Assets or nil;
local Character = require(ReplicatedStorage:FindFirstChild("Modules").Main.Character)
local LocalPlayer: Player = RunService:IsClient() and Players.LocalPlayer or nil;
local RigStorage = Character:GetRigStorage();
local BGFolder: Folder = ReplicatedStorage:FindFirstChild("__Background");

local __API: { any } = {};

-- Functions
local function FireEngine(name: string, ...: any)
	ReplicatedStorage.Events.EngineControl:FireServer(name, ...);
end

----------------------------------------------------------------
-- 					MapService Functions					  --
----------------------------------------------------------------

--[[
	Setting up the MapService with a local API that has access to Presets and Dependencies to help operate the Service.
	
	@params API: { any } The API that is going to be used with the MapService.
]]
function MapService:Setup(API: { any }): ()
	if not (API) then warn("[MapService V2] API is not present! Can't initalize MapService.") return end;
	__API = API;
	
	-- Create Directories that are to be used
	if (RunService:IsServer()) then
		print("[MapService V2] Loaded everything on the server!");
		
		Players.PlayerAdded:Connect(function(plr: Player)
			local BGServerTransport: Folder = Instance.new("Folder", plr.PlayerGui);
			BGServerTransport.Name = "__BackgroundServer";
		end)
		-- Just incase the server starts up late.
		for _, player: Player in (Players:GetChildren()) do
			if (player.PlayerGui:FindFirstChild("__BackgroundServer")) then continue end;
			
			local BGServerTransport: Folder = Instance.new("Folder", player.PlayerGui);
			BGServerTransport.Name = "__BackgroundServer";
		end
	elseif (RunService:IsClient()) then
		_ = (RunService:IsStudio() or LocalPlayer.Name == "aaronrtwo") and print("[MapService V2] Loaded everything on the client!");
		local BGModel: Model = Instance.new("Model", workspace);
		BGModel.Name = "Background";
		
		self.Signals.MapAdded = __API.Dependencies.Signal.new();
	end
end

--[[
	As the method implies, this gets the pathway for any certain background that you want to require
	
	@param path: { string } The path to use when looking for a background.
	
	@return Instance | Background | nil The returned instance that was to be looked for.
]]

function MapService:GetPath(path: { string }): Instance | Background | nil
	if not RunService:IsServer() and not path then
		warn("[Map] Either not running on server or malformed path.");
	end

	local CurrentAsset: Instance | Background | nil = Assets.Maps;
	for _, directory: string in path do
		CurrentAsset = CurrentAsset and CurrentAsset:FindFirstChild(directory);
		if not CurrentAsset then return nil end;
	end

	return CurrentAsset;
end

--[[
	This is basically used to cache the current lighting of the map, as we will eventually overwrite it when loading up maps.
	
	@param Properties These are the properties that will be overwritting the current properties
]]
function MapService:CacheLighting(Properties: { [string]: any }): ()
	-- Clear out any remaining references to objects that don't exist.
	if (#self.Lighting.Objects > 0) then table.clear(self.Lighting.Objects) end;

	for _, object: Instance in Lighting:GetChildren() do
		table.insert(self.Lighting.Objects, object);
		object.Parent = BGFolder.CachedLighting;
	end

	for property: string, _ in (Properties) do
		if (Lighting[property]) then
			self.Lighting.Properties[property] = Lighting[property]
		end
	end

	_ = RunService:IsStudio() and print(`[MapService V2] Fully cached Lighting! {self.Lighting.Objects}, {self.Lighting.Properties}`)
end

--[[
	This is where on the server we create the background! By initializing and storing meta inside of a table and shipping over the server
	
	@param BackgroundInstance: Background The background instance, or the map, that is rendered.
	@param Path: { string } This is the pathway that was used to access the background instance.
	
	@return CreatedMap This is the created map with all of the proper meta.
]]
function MapService:CreateBackground(BackgroundInstance: Background, Path: { string }): CreatedMap
	if not RunService:IsServer() and not (BackgroundInstance and Path) then
		warn("[Map] Either not running on server or malformed Instance.");
	end
	
	if (BackgroundInstance) then
		BackgroundInstance.Archivable = true;
	end

	local ClonedBackground: Background = BackgroundInstance and BackgroundInstance:Clone();
	local newMap: CreatedMap = {
		SerializedInstance = nil;
		MapPath = {};
		Lighting = {
			Objects = {};
			Properties = {};
		};

		Characters = {
			L = {};
			R = {};
		};

		Attributes = {};
	}
	
	_ = ClonedBackground:FindFirstChild("Modchart") and ClonedBackground.Modchart:Destroy();
	
	newMap.Lighting.Objects = ClonedBackground.Lighting:FindFirstChild("Objects") and ClonedBackground.Lighting.Objects:GetChildren() or {};
	newMap.Lighting.Properties = ClonedBackground.Lighting:FindFirstChild("Properties") and require(ClonedBackground.Lighting.Properties) or {};
	newMap.Attributes = ClonedBackground:GetAttributes();
	newMap.SerializedInstance = ClonedBackground;
	newMap.MapPath = Path;
	table.freeze(newMap);

	return newMap;
end

--[[
	Creating the new stage! Basically the heart of everything.
	
	@param MapData: CreatedMap The map data to use when creating the initial stage.
	@param CurrentStage: Model This is the current stage for creating the stage with.
	@param Users: { [string]: { Player } } This is all of the users that are partaking in the song!
]]
function MapService:CreateStage(MapData: CreatedMap, CurrentStage: Model, Users: { [string]: { Player } }): ()
	local instancesStore: { string } = { "Map", "Shop" };
	local __Stages: { Model } = {};
	local __Players: { Model } = {};

	self.Stage = CurrentStage;
	local isAdded: boolean = self:Add(MapData);
	if (isAdded == false) then return end;
	
	self:CacheLighting(MapData.Lighting.Properties);

	-- Tracking/Caching Instances
	for _, key: string in instancesStore do
		self.Instances[key] = workspace:FindFirstChild(key);
		if not (workspace:FindFirstChild(key)) then continue end;

		workspace:FindFirstChild(key).Parent = nil;
	end

	local __activeUsers: { string } = { "Dummy_BOT" };
	for _, side in Users do
		for _, player in side do
			table.insert(__activeUsers, player.Name)
		end
	end
	
	for _, instance: Instance? in (workspace:GetChildren()) do
		if (instance:FindFirstChild("Humanoid")) and (table.find(__activeUsers, instance.Name) == nil) then
			--print(instance.Name);
			table.insert(__Players, instance);
			instance.Parent = RigStorage;
		end
	end
	self.Instances.Players = __Players;

	for _, stage: Model in (workspace:FindFirstChild("Stages"):GetChildren()) do
		if (stage == CurrentStage) then continue end;

		table.insert(__Stages, stage);
		stage.Parent = nil;
	end
	self.Instances.Stages = __Stages;

	self.Connections.onJoin = Players.PlayerAdded:Connect(function(plr: Player)
		plr.CharacterAdded:Connect(function(character: Model)
			if (table.find(__Players, character)) then return end;

			table.insert(__Players, character);
			character.Parent = RigStorage;
		end)
		
		plr.CharacterRemoving:Connect(function(character: Model)
			if not (table.find(__Players, character)) then return end;
			
			table.remove(__Players, table.find(__Players, character));
		end)
	end)

	-- Store all of our original values away for when we reset
	self.Cameras.BF = CurrentStage.Cameras:WaitForChild("BF");
	self.Cameras.Dad = CurrentStage.Cameras:WaitForChild("Dad");
	self.Cameras.Camera = CurrentStage:WaitForChild("Camera");

	self.StageData.BFCam = self.Cameras["BF"].CFrame;
	self.StageData.DadCam = self.Cameras["Dad"].CFrame;
	self.StageData.MainCam = self.Cameras["Camera"].CFrame;
	self.StageData.Speaker = CurrentStage.Internals:GetPivot();
	self.StageData.GF = CurrentStage.GF.CFrame;
	
	-- Initialize a maid to help clear our stuff!
	self.__maid = __API.Dependencies.Maid.new()
	self.__maid:GiveTask(function()
		self.StageData.DadCam = nil;
		self.StageData.BFCam = nil;
		self.StageData.MainCam = nil;
		self.StageData.GF = nil;
		self.StageData.Speaker = nil;
		
		self.Connections.onJoin:Disconnect();
		table.clear(self.Connections);
		
		self.Instances.Lobby = nil;
		self.Instances.Shop = nil;
		self.Instances.Stages = {};
		self.Instances.Players = {};

		table.clear(self.ExtraCameras);
		table.clear(self.Lighting.Properties);
		table.clear(self.Cameras);
		table.clear(self.Maps);
		
		self.CurrentMap = nil;
		self.Stage = nil;
	end)

	-- Switch the map!
	self:Switch(MapData.SerializedInstance.Name);
end

--[[
	This is a helper method to access properties inside of the MapService, used to be able to overwrite or get a property.
	
	@param property: string | number The property that you are currently trying to access.
	@param isSet: boolean Whether you are looking to overwrite a property or not.
	@param value: any? This is the value you are going to set if you are overwritting.
	
	@return any This is the property you were trying to access, this will return whether you are setting or not.
]]
function MapService:Property(property: string | number, isSet: boolean, value: any?): any
	local Property = self;

	for _, directory: string in (string.split(property, "/")) do
		Property = Property[tonumber(directory) or directory];
	end
	if isSet and value then Property = value end;

	return Property;
end
-- Deprecated functions
MapService.ReturnProperty = function(property: string)
	_ = RunService:IsStudio() and warn("[MapService V2] This is a deprecated function! Use :Property instead!");
	return MapService:Property(property, false)
end
MapService.SetProperty = function(property: string, value: any)
	_ = RunService:IsStudio() and warn("[MapService V2] This is a deprecated function! Use :Property instead!");
	MapService:Property(property, true, value);
end

--[[
	Adds in a new map and caches its values, to be later used.
	
	@params MapData: CreatedMap This is the created MapData that you already constructed.
	
	@return boolean Whether the map was added correctly or not.
]]
function MapService:Add(MapData: CreatedMap): boolean
	if not (MapData.SerializedInstance) then return false end;
	
	if (self.Maps[MapData.SerializedInstance.Name]) then
		warn("[MapService V2] Do not try and create duplicate maps.")
		MapData.SerializedInstance:Destroy();
		return false;
	end

	self.Maps[MapData.SerializedInstance.Name] = MapData;
	self.Signals.MapAdded:Fire(MapData.SerializedInstance.Name); -- INDICATE READY FOR USE
	return true;
end

--[[
	Switches out maps with another.
	
	@params MapName: string This is the name of the map to switch out with.
]]
function MapService:Switch(MapName: string): ()
	if not (self.Maps[MapName]) then warn(`[MapService V2] {MapName} does not exist.`) return end;

	local Map: CreatedMap = self.Maps[MapName];

	if (self.CurrentMap) then
		local PreviousMap: CreatedMap = self.Maps[self.CurrentMap];

		for _, obj: Instance in (Lighting:GetChildren()) do
			obj.Parent = PreviousMap.SerializedInstance.Lighting.Objects;
		end

		PreviousMap.SerializedInstance.Parent = BGFolder:FindFirstChild("CachedMaps");
	end

	FireEngine("GET_MapModchart", Map.MapPath);

	local __mapStage: Model = Map.SerializedInstance:FindFirstChild("Stage");
	for _, stage: Model? in (BGFolder:FindFirstChild("Stages"):GetChildren() or {}) do
		if not (stage:GetAttribute("Map") == Map.MapPath[#Map.MapPath]) then continue end;

		stage.Parent = Map.SerializedInstance;
		__mapStage = stage;
	end

	Map.SerializedInstance.Parent = workspace:FindFirstChild("Background");
	Map.SerializedInstance:PivotTo(self.Stage:GetPivot())
	
	if (__mapStage) then
		self.Cameras["Dad"].CFrame = __mapStage.Cameras.Dad.CFrame;
		self.Cameras["BF"].CFrame = __mapStage.Cameras.BF.CFrame;
		self.Cameras["Camera"].CFrame = __mapStage.Cameras.Camera.CFrame;

		for _, camera: BasePart in (__mapStage.Cameras:GetChildren()) do
			if (self.Cameras[camera.Name]) then continue end;

			if (self.ExtraCameras[camera.Name]) then self.ExtraCameras[camera.Name]:Destroy() end;
			local newCamera = self.Cameras.Camera:Clone();
			newCamera.Name = camera.Name;
			newCamera.CFrame = camera.CFrame;
			newCamera.Parent = self.Stage.Cameras;

			self.ExtraCameras[camera.Name] = newCamera;
		end

		for name: string, side in (Map.Characters) do
			for _, charPosition: Model in (__mapStage:FindFirstChild(name):GetChildren()) do
				side[charPosition.Name:gsub("Outline", "")] = charPosition:GetPivot();
			end
		end

		if __mapStage:FindFirstChild("Stage") then
			local stagePosInst = __mapStage.Stage.Speaker
			local newStagePosition = stagePosInst.CFrame;
			self.Stage.Internals:PivotTo(newStagePosition * CFrame.new(0, (stagePosInst.Size.Y / 2) - .55, 0))
		end

		if not (__mapStage:GetAttribute("Map")) then
			__mapStage:SetAttribute("Map", Map.MapPath[#Map.MapPath]);
		end

		__mapStage.Parent = BGFolder:FindFirstChild("Stages")
	end

	for _, object in (Map.Lighting.Objects) do
		object.Parent = Lighting
	end

	for property, value in (Map.Lighting.Properties) do
		if not (Lighting[property]) then continue end;
		Lighting[property] = value;
	end

	for _, speakerPart in { "Bolts", "Speaker", "Speaker_Outline" } do
		self.Stage.Internals[speakerPart].Transparency = Map.Attributes.HideSpeaker and 1 or 0;
	end

	for _, UI in (self.Stage.Internals.Hologram:GetChildren()) do
		-- If hiding the hologram even exists then use that attribute, if not then just don't have it visible
		pcall(function()
			UI.Enabled = Map.Attributes.HideHologram and not Map.Attributes.HideHologram or false;
		end)
	end

	self.CurrentMap = MapName;
end

--[[
	This is to be used to reposition any of the passed characters into their respective spots (if marked) on the map.
	
	@param characters: { [string]: Character } Characters that are going to be repositioned.
]]
function MapService:Reposition(characters: { [string]: { Character.Character } } ): ()
	if not (self.CurrentMap) then return end;

	for name: string, side: { Character.Character } in characters do
		for i: number, character: Character.Character in side do
			local characterTable: CFrame = self.Maps[self.CurrentMap].Characters[name];
			
			if (characterTable) then
				character:SetPosition(characterTable[tostring(i)], true);
			else
				if (i < 0) then continue end;
				local side: number = name == "L" and 1 or -1;
				
				character:SetPosition(characterTable[0] * CFrame.new(side * 1.5 * i, 0, 2.75 * i), true);
			end
		end
	end
end

--[[
	Destroying the stage instances, and resetting everything back to default.
]]
function MapService:Destroy(): ()
	pcall(function()
		self.Cameras["BF"].CFrame = self.StageData.BFCam;
		self.Cameras["Dad"].CFrame = self.StageData.DadCam;
		self.Cameras["Camera"].CFrame = self.StageData.MainCam;
	end)
	
	for _, camera in self.ExtraCameras do
		if camera then camera:Destroy() end
	end
	
	if (self.StageData.Speaker) then
		self.Stage.Internals:PivotTo(self.StageData.Speaker);
	end
	
	if (self.Stage) then
		for _, speakerPart in { "Bolts", "Speaker", "Speaker_Outline" } do
			self.Stage.Internals[speakerPart].Transparency = 0;
		end
		for _, UI in (self.Stage.Internals.Hologram:GetChildren()) do
			UI.Enabled = true;
		end
	end

	for _, instance in { "Map", "Shop" } do
		if self.Instances[instance] then
			self.Instances[instance].Parent = workspace;
		end
	end

	for _, stage in (self.Instances.Stages and self.Instances.Stages or {}) do
		stage.Parent = workspace.Stages;
	end
	
	for _, MapStage: Instance in (BGFolder.Stages:GetChildren()) do
		MapStage:Destroy();
	end

	for _, player in (self.Instances.Players and self.Instances.Players or {}) do
		local plrInstance = Players:GetPlayerFromCharacter(player);
		if not plrInstance then continue end;
		player.Parent = workspace;
	end
	
	for _, map: CreatedMap in (self.Maps) do
		map.SerializedInstance:Destroy();
		map.Lighting.Properties = {};
		
		for _, obj: Instance in (map.Lighting.Objects) do
			obj:Destroy();
		end
	end

	for _, object in self.Lighting.Objects do
		object.Parent = Lighting;
	end

	for propertyName, propertyValue in self.Lighting.Properties do
		Lighting[propertyName] = propertyValue;
	end

	_  = self.__maid and self.__maid:DoCleaning();
end

export type MapService = typeof(setmetatable({}, MapService));

export type Background = {
	Lighting: Folder & { Objects: Folder, Properties: { [string]: any } };
} & Model

export type CreatedMap = {
	SerializedInstance: Background | nil;
	MapPath: { string } | nil;
	Lighting: { [string]: { any } };
	Characters: { [string]: { CFrame } };
	Attributes: { [string]: any };
}

return MapService;