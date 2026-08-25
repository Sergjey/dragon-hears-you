-- Client entry (LocalScript). Syncs via Rojo into StarterPlayerScripts.Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hello = require(ReplicatedStorage.Shared.Hello)

print(Hello.greet("dragon-hears-you (client)"))
