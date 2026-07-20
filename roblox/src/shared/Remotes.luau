-- Single access point for RemoteEvents. The server creates them on demand;
-- clients wait for them to replicate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RivalsRemotes"

local Remotes = {}

function Remotes.get(name)
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	else
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		return folder:WaitForChild(name)
	end
end

return Remotes
