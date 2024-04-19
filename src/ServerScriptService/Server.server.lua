--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService");
local MapService = require(ReplicatedStorage.Modules.MapService);
local RemotePacketSize = require(ReplicatedStorage.Modules.RemotePacketSize);

local RemoteListeners: { [string]: (Player, any) -> nil} = {};

local EngineRemote: RemoteEvent = ReplicatedStorage.Events.EngineControl;
local function listenTo(name: string, func: (Player, any) -> nil)
    RemoteListeners[name] = func;
end

local function fireClient(plr,name,...)
	if plr == nil then return end
	EngineRemote:FireClient(plr,name,...)
end

EngineRemote.OnServerEvent:Connect(function(plr: Player, name: string, ...)
	_ = RunService:IsStudio() and print(`[Server] Packet size for {name}: {RemotePacketSize.GetDataByteSize(...)} kbs`);
	
    xpcall(RemoteListeners[name], function(err)
        print(`REMOTE CALL ERROR:\n{err}\n\n{debug.traceback()}`)
    end, plr, ...)
end)

local function GenerateHash(): string
	local LegalCharacters = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz123456789";
	local Hash = ""

	for HashStepsDone = 1, 16 do 
		local RandomNumber: number = math.random(1, #LegalCharacters);
		Hash ..= string.sub(LegalCharacters, RandomNumber, RandomNumber);
	end
	
	return Hash;
end

listenTo("GET_Map", function(plr: Player, Arguments: any)
    -- There should be always 3 arguments for a map (avoid people using it for bad)
    if not (#Arguments.Path == 3) or not (Arguments.Path) then return end;

    local Path: { string } = Arguments.Path;
    local Settings: { any } = Arguments.Settings;

    if (Settings[1]) and (#Path == 1 or Settings[2]) then
        Path[2] = "Global";
        Path[3] = "BlackVoid";
    end

    if not (MapService:GetPath(Path)) then
        _ = RunService:IsStudio() and warn("[MapService V2] Map was invalid, checking globals.")
        Path[2] = "Global";

        if not (MapService:GetPath(Path)) then
            warn(`[MapService V2] Cound not find the current path for the map: {Path[3]}`);
            return;
        end
    end

    local MapData: MapService.CreatedMap = MapService:CreateBackground(MapService:GetPath(Path), Path);
	
	if (MapData.SerializedInstance) then
		MapData.SerializedInstance.Parent = plr.PlayerGui:FindFirstChild("__BackgroundServer");
    end
    
    fireClient(plr, "POST_Map", MapData);
end)

listenTo("GET_MapModchart", function(plr: Player, Arguments: any)
	local CurrentMap = MapService:GetPath(Arguments);
	if not (CurrentMap:FindFirstChild("Modchart")) then return end;

	pcall(function()
		plr.PlayerGui:FindFirstChild("MapModchart"):Destroy();
	end)

	local ClonedModchart: ModuleScript = CurrentMap.Modchart:Clone();
	ClonedModchart.Name = GenerateHash();
	ClonedModchart.Parent = plr.PlayerGui:FindFirstChild("__BackgroundServer");

	fireClient(plr, "POST_MapModchart", ClonedModchart);
end)