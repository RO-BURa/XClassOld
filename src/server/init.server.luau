local ReplicatedStorage = game:GetService("ReplicatedStorage")
local bob = require(ReplicatedStorage.Shared.Classes.bob)

local myBob = bob.new()

myBob.Name = "good"

myBob:AHH()
