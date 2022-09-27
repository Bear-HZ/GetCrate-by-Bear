-----------------------------------------------------
-- INFO
-----------------------------------------------------


script_name("GetCrate")
script_description("This bot eliminates the need to enter text or key input for picking up drug crates (both crack and pot) by using a robust tracking system.")
script_author("Bear")
script_version("1.1.0")
local version = "1.1.0"


-----------------------------------------------------
-- HEADERS & CONFIG
-----------------------------------------------------


require "moonloader"
require "sampfuncs"

local sampev = require "lib.samp.events"
local inicfg = require "inicfg"

local config_dir_path = getWorkingDirectory() .. "\\config\\"
if not doesDirectoryExist(config_dir_path) then createDirectory(config_dir_path) end

local config_file_path = config_dir_path .. "GetCrate by Bear.ini"

config_dir_path = nil

local config_table

if doesFileExist(config_file_path) then
	config_table = inicfg.load(nil, config_file_path)
else
	local new_config = io.open(config_file_path, "w")
	new_config:close()
	new_config = nil
	
	config_table = {
		General = {
			isGCOff = false,
			isDrugChoicePot = false
		}
	}

	if not inicfg.save(config_table, config_file_path) then
		sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}Config file creation failed - contact the developer for help.", -1)
	end
end


-----------------------------------------------------
-- GLOBAL VARIABLES
-----------------------------------------------------


-- Indicates if a checkpoint doesn't exist
local isACheckpointActive = true

-- Flag turned on by /gcreset, helping the player end the drug selection loop if they so desire
local isGCResetRequired = false

-- Tells if a drug choice prompt from the server is active
local isDrugChoicePrompted = false

-- Flag turned on by a pickup failure message from the server
local isPickupFailureDetected = false

-- Player-controlled getcrate bot toggle (/gc), connected to the .ini
local isGCOff = config_table.General.isGCOff

-- Player's choice of drug crate, connected to the .ini: true for pot and false for crack
local isDrugChoicePot = config_table.General.isDrugChoicePot

-- Pickup sphere centre coordinates & the radius
local pickupX, pickupY, pickupZ, pickup_rad = 2206.129882, 1581.989990, 999.979980, 3

-- Player character position coordinates
local posX, posY, posZ = 0, 0, 0


-----------------------------------------------------
-- LOCALLY DECLARED FUNCTIONS
-----------------------------------------------------


local function isPlayerInPickupZone()
	posX, posY, posZ = getCharCoordinates(PLAYER_PED)
	if getDistanceBetweenCoords3d(pickupX, pickupY, pickupZ, posX, posY, posZ) < pickup_rad then
		return true
	else return false
	end
end


-----------------------------------------------------
-- MAIN
-----------------------------------------------------


function main()	
	-- Waiting to meet startup conditions
	repeat wait(50) until isSampAvailable()
	repeat wait(50) until string.find(sampGetCurrentServerName(), "Horizon Roleplay")
	
	-- Startup message and command registry
	sampAddChatMessage("--- {66FF66}GetCrate {FFFFFF}by Bear | Use {66FF66}/gchelp", -1)
	sampRegisterChatCommand("gc", cmd_gc)
	sampRegisterChatCommand("gcp", cmd_gcp)
	sampRegisterChatCommand("gcc", cmd_gcc)
	sampRegisterChatCommand("gchelp", cmd_gchelp)
	sampRegisterChatCommand("gcreset", cmd_gcreset)
	
	-- Making sure that "/drop crates" is entered when killing a checkpoint
	sampRegisterChatCommand("kcp", cmd_kcp)
	sampRegisterChatCommand("killcheckpoint", cmd_kcp)
	
	-- Inactivity loop
	::start::
	while isGCOff or isACheckpointActive do wait(0) end
	
	-- Tracking loop
	repeat
		::track::
		if isPlayerInPickupZone() then
			wait (60)
			posX, posY, posZ = getCharCoordinates(PLAYER_PED)
			if not isPlayerInPickupZone() then goto track end
			
			isDrugChoicePrompted = false
			isPickupFailureDetected = false
			sampSendChat("/getcrate")
			
			repeat wait(0) until isDrugChoicePrompted or isPickupFailureDetected
			
			if isPickupFailureDetected then wait(1500) goto track
			else
				isGCResetRequired = false
				
				repeat
					::choosedrug::
					if isPlayerInPickupZone() then
						wait(60)
						if not isPlayerInPickupZone() then goto choosedrug end
						
						if isDrugChoicePot then sampSendChat("pot") else sampSendChat("crack") end
						wait(1000)
					else
						wait(0)
						if isGCResetRequired or isGCOff then goto start end
					end
				until isACheckpointActive
				
				goto start
			end
		end
		
		wait(50)
		if isGCOff then goto start end
	until false
end


-----------------------------------------------------
-- API-SPECIFIC FUNCTIONS
-----------------------------------------------------


function sampev.onDisableCheckpoint()
	isACheckpointActive = false
end

function sampev.onServerMessage(_, msg_text)
	-- (Drug choice prompt) "What type of drugs would you like to smuggle? (Type crack or pot)"
	if msg_text == "What type of drugs would you like to smuggle? (Type crack or pot)" then
		isDrugChoicePrompted = true
	
	-- (Crates purchased) "* You bought some Drug Crates for $100." / "* You bought some drug crates for $100."
	elseif string.sub(msg_text, 1, 18) == "* You bought some " and string.sub(msg_text, 25, 39) == "rates for $100." then
		isACheckpointActive = true
	
	-- (Proximity failure) "You are not at the Drug Factory!"
	elseif msg_text == "You are not at the Drug Factory!" then
		isPickupFailureDetected = true
	
	-- (Lacking required job) "   You are not a Drug Smuggler!"
	elseif msg_text == "   You are not a Drug Smuggler!" then
		isPickupFailureDetected = true
	
	-- (Lacking funds) " You can't afford the $100!"
	elseif msg_text == " You can't afford the $100!" then
		isPickupFailureDetected = true
	
	-- (Crates already possessed) "   You can't hold any more Drug Crates!"
	elseif msg_text == "   You can't hold any more Drug Crates!" then
		isPickupFailureDetected = true
	
	-- (Server reconnection) "Welcome to Horizon Roleplay, ..."
	elseif string.sub(msg_text, 1, 29) == "Welcome to Horizon Roleplay, " then
		isGCResetRequired = true
	
	end
end


-----------------------------------------------------
-- COMMAND-SPECIFIC FUNCTIONS
-----------------------------------------------------


function cmd_gc()
	isGCOff = config_table.General.isGCOff
	
	if not isGCOff then
		isGCOff, config_table.General.isGCOff = true, true
		
		if inicfg.save(config_table, config_file_path) then
			sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}Off", -1)
		else
			sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}Pickup toggle in config failed - contact the developer for help.", -1)
		end
	else
		isGCOff, config_table.General.isGCOff = false, false
		
		if inicfg.save(config_table, config_file_path) then
			if isDrugChoicePot then
				sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}On | {66FF66}Drug Choice {FFFFFF}- Pot", -1)
			else
				sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}On | {66FF66}Drug Choice {FFFFFF}- Crack", -1)
			end
		else
			sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}Pickup toggle in config failed - contact the developer for help.", -1)
		end
	end
end

function cmd_gcp()
	isDrugChoicePot, config_table.General.isDrugChoicePot = true, true
	
	if inicfg.save(config_table, config_file_path) then
		sampAddChatMessage("--- {66FF66}GetCrate - Drug Choice: {FFFFFF}Pot", -1)
	else
		sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}Drug selection in config failed - contact the developer for help.", -1)
	end
end

function cmd_gcc()
	isDrugChoicePot, config_table.General.isDrugChoicePot = false, false
	
	if inicfg.save(config_table, config_file_path) then
		sampAddChatMessage("--- {66FF66}GetCrate - Drug Choice: {FFFFFF}Crack", -1)
	else
		sampAddChatMessage("--- {66FF66}GetCrate: {FFFFFF}Drug selection in config failed - contact the developer for help.", -1)
	end
end

function cmd_gchelp()
	sampAddChatMessage(" ", -1)
	sampAddChatMessage("------ {66FF66}GetCrate v" .. version .. " {FFFFFF}------", -1)
	sampAddChatMessage(" ", -1)
	sampAddChatMessage("{66FF66}/gc {FFFFFF}- Toggle Crate Pickup", -1)
	sampAddChatMessage("{66FF66}/gcp {FFFFFF}- Set Drug Choice to Pot", -1)
	sampAddChatMessage("{66FF66}/gcc {FFFFFF}- Set Drug Choice to Crack", -1)
	sampAddChatMessage(" ", -1)
	sampAddChatMessage("{66FF66}Developer: {FFFFFF}Bear (Swapnil#9308)", -1)
	sampAddChatMessage("------------", -1)
	sampAddChatMessage(" ", -1)
end

function cmd_gcreset()
	isGCResetRequired = true
end

function cmd_kcp()
	if string.find(sampGetCurrentServerName(), "Horizon Roleplay") and isACheckpointActive then
		sampSendChat("/drop crates")
	end
	
	sampSendChat("/kcp")
end