--CHARACTER HANDLER!!!! v2!!!!!!
--LAST ONE SUCKED! THIS IS REWORK!

-- character module but v2, made fornof

--[[
	NOTES:
	
	-> Idles must be uploaded with looped enabled
		#Roblox WONT replicate looped state when changed through AnimationTrack (.Looped)
		#THIS IS NOT THE CASE FOR PRIORITIES!! THIS WAS CHANGED FOR THE ANIM BLENDING UPDATE!!

]]

-- TODOS:
--	Changing sides
-- 	Modules support

local Character = {};
Character.__index = Character;

function Character:GetRigStorage()
	return Instance.new("WorldModel", game.ReplicatedStorage);
end

export type Character = typeof(setmetatable({},{__index=Character})) & {
	locked:boolean;
	characterSide:string?;

	zoom:number?;
	camOffset:CFrame;
	startPos:CFrame;
	currentPos:CFrame;
	serverOff:CFrame;
	offsetPos:CFrame;
	rotation:number;
	charModel:Model;
	char:Model;
	parent:Instance?;
	destroyChar:boolean;
	humanoid:Humanoid|AnimationController;
	animator:Humanoid;

	preloadedRigs:{[string]:RigData};
	preloadedAnims:{[string]:AnimationData};

	animations:{[string]:AnimationTrack};
}

export type RigData = {
	hideCharacter:boolean,
	rig:Model,
	rotation:number;
	humanoid:Humanoid|AnimationController,
	animator:Animator
}

export type AnimationData = {
	isLoading:boolean?,
	animations:{[string]:AnimationTrack},
	name:string,
	rig:RigData?,
	isBeatDance:boolean,
	folder:Folder|{},
}

type WeirdWatermark = boolean

return Character;