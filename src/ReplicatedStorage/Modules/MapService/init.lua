if not (script:FindFirstChild("Main")) then
	warn("[MapService] Cannot initialize MapService again.")
	return nil;
else
	local Service = {
		Dependencies = {};
	}
	
	local MapService = require(script.Main.Main);

	for _, mod: ModuleScript in (script.Main.Dependencies:GetChildren()) do
		if (mod:IsA("ModuleScript")) then
			local success, response = pcall(function() 
				return require(mod);	
			end)

			if success then Service.Dependencies[mod.Name] = response end;
		end
	end

	MapService:Setup(Service);
	-- If we are running on the server then we don't want to destroy the MapService Source.
	_ = game["Run Service"]:IsClient() and script.Main:Destroy();
	return MapService :: MapService.MapService;
end