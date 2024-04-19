--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService")
local Players = game:GetService("Players");
local MapService = require(ReplicatedStorage.Modules.MapService);
local RemotePacketSize = require(ReplicatedStorage.Modules.RemotePacketSize);

local LocalPlayerUI = Players.LocalPlayer.PlayerGui;
local daUI = LocalPlayerUI:WaitForChild("ScreenGui"):WaitForChild("Request");
local remoteListen: { [string]: (any) -> nil } = {}

local function fireServer(name,...)
	ReplicatedStorage.Events.EngineControl:FireServer(name,...)
end

local function listenTo(eventName: string, func: (any) -> nil)
	remoteListen[eventName] = func;
end

ReplicatedStorage.Events.EngineControl.OnClientEvent:Connect(function(name,...)
	_ = RunService:IsStudio() and print(`[Server] Packet size for {name}: {RemotePacketSize.GetDataByteSize(...)} kbs`);
	
	xpcall(remoteListen[name], function(err)
		error("REMOTE CALL",err,debug.traceback())
	end,...)
end)

daUI.Request.MouseButton1Click:Connect(function()
	fireServer("GET_Map", {
		Path = {
			daUI.Root.Text;
			daUI.Mod.Text;
			daUI.Map.Text;
		};
		Settings = {
			false;
			false;
		}
	})
end)

daUI.Clear.MouseButton1Down:Connect(function()
	MapService:Destroy();
end)

listenTo("POST_Map", function(MapData: MapService.CreatedMap)
	local SerializedInstance: MapService.Background = MapData.SerializedInstance;

	MapService:CreateStage(MapData, workspace.Stages.Speaker1, { ["L"] = { Players.LocalPlayer.Name }; ["R"] = {} });
end)

listenTo("POST_MapModchart", function(ModchartData: ModuleScript)
	print(ModchartData)
	
	local swag = require(ModchartData);
	ModchartData:Destroy();
end)