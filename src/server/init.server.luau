-- Server entry (Script). Syncs via Rojo into ServerScriptService.Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hello = require(ReplicatedStorage.Shared.Hello)

print(Hello.greet("dragon-hears-you (server)"))
