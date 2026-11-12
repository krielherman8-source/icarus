--!strict

local ClientData = require(script.ClientData)
local HUD = require(script.HUD)
local ShopUI = require(script.ShopUI)
local RunSummary = require(script.RunSummary)
local CatapultController = require(script.CatapultController)
local FlightController = require(script.FlightController)

ClientData.start()
HUD.start()
ShopUI.start()
RunSummary.start()
CatapultController.start()
FlightController.start()
