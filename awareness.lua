--[[
Awareness System
A plan-based execution wrapper for Turtle API

Provides:
- Plan-based execution with progress tracking
- Automatic state persistence and checkpointing
- Resume capability after interruptions
- Integration with all mining operations
]]

-- State file for persistence
local awareness_state_file = "blue-miner/awareness_state"

-- Current plan being executed
local current_plan = nil

-- Position tracking
local position = {x = 0, y = 0, z = 0, facing = 0} -- 0=north, 1=east, 2=south, 3=west

-- Statistics
local stats = {
	total_steps = 0,
	failed_steps = 0,
	checkpoints = 0,
	last_checkpoint = 0
}

-- Configuration
local config = {
	checkpoint_interval = 50, -- Checkpoint every N steps
	auto_save = true,
	enable_gps = false -- Set by profile
}

--
-- Helper Functions
--

local function direction_to_string(dir)
	local dirs = {"north", "east", "south", "west"}
	return dirs[(dir % 4) + 1]
end

local function log_awareness(msg)
	if _G.debug then
		print("[Awareness] " .. msg)
	end
end

--
-- Position Tracking
--

local function update_position_forward()
	if position.facing == 0 then -- north
		position.z = position.z - 1
	elseif position.facing == 1 then -- east
		position.x = position.x + 1
	elseif position.facing == 2 then -- south
		position.z = position.z + 1
	elseif position.facing == 3 then -- west
		position.x = position.x - 1
	end
end

local function update_position_back()
	if position.facing == 0 then -- north
		position.z = position.z + 1
	elseif position.facing == 1 then -- east
		position.x = position.x - 1
	elseif position.facing == 2 then -- south
		position.z = position.z - 1
	elseif position.facing == 3 then -- west
		position.x = position.x + 1
	end
end

local function update_position_up()
	position.y = position.y + 1
end

local function update_position_down()
	position.y = position.y - 1
end

local function update_position_turn_right()
	position.facing = (position.facing + 1) % 4
end

local function update_position_turn_left()
	position.facing = (position.facing - 1) % 4
end

--
-- State Persistence
--

local function save_state()
	if not config.auto_save then return end
	
	local state = {
		version = "1.0",
		position = position,
		plan = current_plan,
		stats = stats,
		timestamp = os.epoch("utc")
	}
	
	local file = fs.open(awareness_state_file, "w")
	file.write(textutils.serialize(state))
	file.close()
	
	stats.checkpoints = stats.checkpoints + 1
	stats.last_checkpoint = os.epoch("utc")
	log_awareness("State saved (checkpoint #" .. stats.checkpoints .. ")")
end

local function load_state()
	if not fs.exists(awareness_state_file) then
		return nil
	end
	
	local file = fs.open(awareness_state_file, "r")
	local content = file.readAll()
	file.close()
	
	local state = textutils.unserialize(content)
	if state and state.version == "1.0" then
		return state
	end
	
	return nil
end

local function clear_state()
	if fs.exists(awareness_state_file) then
		fs.delete(awareness_state_file)
	end
	current_plan = nil
end

--
-- GPS Integration
--

local function verify_position_gps()
	if not config.enable_gps then
		return true, "GPS disabled"
	end
	
	-- Check if modem available
	local modem_side = nil
	for _, side in ipairs({"left", "right", "top", "bottom", "front", "back"}) do
		if peripheral.getType(side) == "modem" then
			modem_side = side
			break
		end
	end
	
	if not modem_side then
		return false, "No modem found for GPS"
	end
	
	-- Try to get GPS position
	local gps_x, gps_y, gps_z = gps.locate(5)
	
	if not gps_x then
		return false, "GPS signal not available"
	end
	
	-- Check if position matches
	local dx = math.abs(gps_x - position.x)
	local dy = math.abs(gps_y - position.y)
	local dz = math.abs(gps_z - position.z)
	
	if dx > 0 or dy > 0 or dz > 0 then
		log_awareness(string.format("Position drift detected: (%d,%d,%d)", dx, dy, dz))
		
		-- Update position from GPS
		position.x = gps_x
		position.y = gps_y
		position.z = gps_z
		
		return true, "Position corrected from GPS"
	end
	
	return true, "Position verified by GPS"
end

--
-- Plan Creation
--

-- Create a new plan
function awareness_create_plan(id, description)
	local plan = {
		id = id or ("plan_" .. os.epoch("utc")),
		description = description or "Mining operation",
		steps = {},
		current_step = 1,
		metadata = {
			created = os.epoch("utc"),
			started = nil,
			completed = nil
		},
		stats = {
			total_steps = 0,
			completed_steps = 0,
			failed_steps = 0
		}
	}
	
	return plan
end

-- Add a step to a plan
function awareness_add_step(plan, action, description, metadata)
	table.insert(plan.steps, {
		action = action,
		description = description or "unknown action",
		metadata = metadata or {},
		executed = false,
		success = false,
		result = nil,
		timestamp = nil
	})
	
	plan.stats.total_steps = #plan.steps
end

-- Add multiple movement steps efficiently
function awareness_add_movements(plan, direction, count, description_prefix)
	for i = 1, count do
		local desc = (description_prefix or direction) .. " #" .. i
		
		if direction == "forward" then
			awareness_add_step(plan, function()
				local success = turtle.forward()
				if success then update_position_forward() end
				return success
			end, desc)
		elseif direction == "back" then
			awareness_add_step(plan, function()
				local success = turtle.back()
				if success then update_position_back() end
				return success
			end, desc)
		elseif direction == "up" then
			awareness_add_step(plan, function()
				local success = turtle.up()
				if success then update_position_up() end
				return success
			end, desc)
		elseif direction == "down" then
			awareness_add_step(plan, function()
				local success = turtle.down()
				if success then update_position_down() end
				return success
			end, desc)
		end
	end
end

--
-- Plan Execution
--

-- Execute a plan
function awareness_execute_plan(plan, start_from)
	current_plan = plan
	plan.metadata.started = plan.metadata.started or os.epoch("utc")
	
	-- Start from specific step if resuming
	if start_from then
		plan.current_step = start_from
	end
	
	log_awareness("Executing plan: " .. plan.id)
	log_awareness("Starting from step " .. plan.current_step .. " of " .. #plan.steps)
	
	while plan.current_step <= #plan.steps do
		local step = plan.steps[plan.current_step]
		
		-- Execute step
		log_awareness("Step " .. plan.current_step .. ": " .. step.description)
		step.executed = true
		step.timestamp = os.epoch("utc")
		
		local success, result = pcall(step.action)
		step.success = success
		step.result = result
		
		if success then
			plan.stats.completed_steps = plan.stats.completed_steps + 1
		else
			plan.stats.failed_steps = plan.stats.failed_steps + 1
			log_awareness("Step failed: " .. tostring(result))
		end
		
		stats.total_steps = stats.total_steps + 1
		if not success then
			stats.failed_steps = stats.failed_steps + 1
		end
		
		-- Auto-checkpoint
		if plan.current_step % config.checkpoint_interval == 0 then
			save_state()
			
			-- GPS verification at checkpoints
			if config.enable_gps then
				verify_position_gps()
			end
		end
		
		-- Move to next step
		plan.current_step = plan.current_step + 1
	end
	
	plan.metadata.completed = os.epoch("utc")
	log_awareness("Plan completed: " .. plan.id)
	
	-- Final save and clear
	save_state()
	
	return plan
end

-- Check if there's a plan to resume
function awareness_has_saved_plan()
	local state = load_state()
	return state ~= nil and state.plan ~= nil
end

-- Resume a saved plan
function awareness_resume_plan()
	local state = load_state()
	
	if not state or not state.plan then
		return nil, "No saved plan found"
	end
	
	-- Restore position
	position = state.position
	stats = state.stats
	
	log_awareness("Resuming plan: " .. state.plan.id)
	log_awareness("Position restored: " .. position.x .. "," .. position.y .. "," .. position.z)
	log_awareness("Facing: " .. direction_to_string(position.facing))
	
	-- Resume execution
	return awareness_execute_plan(state.plan, state.plan.current_step)
end

--
-- Getters
--

function awareness_get_position()
	return {x = position.x, y = position.y, z = position.z, facing = position.facing}
end

function awareness_get_stats()
	return {
		total_steps = stats.total_steps,
		failed_steps = stats.failed_steps,
		checkpoints = stats.checkpoints,
		success_rate = stats.total_steps > 0 and ((stats.total_steps - stats.failed_steps) / stats.total_steps) or 0
	}
end

function awareness_get_current_plan()
	return current_plan
end

--
-- Configuration
--

function awareness_set_checkpoint_interval(interval)
	config.checkpoint_interval = interval
end

function awareness_enable_gps(enable)
	config.enable_gps = enable
end

function awareness_set_auto_save(enable)
	config.auto_save = enable
end

--
-- Initialization
--

function awareness_init(start_position)
	if start_position then
		position = {
			x = start_position.x or 0,
			y = start_position.y or 0,
			z = start_position.z or 0,
			facing = start_position.facing or 0
		}
	end
	
	log_awareness("Awareness system initialized")
	log_awareness("Starting position: " .. position.x .. "," .. position.y .. "," .. position.z)
end

-- Reset everything
function awareness_reset()
	clear_state()
	position = {x = 0, y = 0, z = 0, facing = 0}
	stats = {
		total_steps = 0,
		failed_steps = 0,
		checkpoints = 0,
		last_checkpoint = 0
	}
	current_plan = nil
	log_awareness("Awareness system reset")
end

-- Export API
return {
	-- Plan management
	create_plan = awareness_create_plan,
	add_step = awareness_add_step,
	add_movements = awareness_add_movements,
	execute_plan = awareness_execute_plan,
	
	-- Resume functionality
	has_saved_plan = awareness_has_saved_plan,
	resume_plan = awareness_resume_plan,
	
	-- State management
	save_state = save_state,
	clear_state = clear_state,
	
	-- Getters
	get_position = awareness_get_position,
	get_stats = awareness_get_stats,
	get_current_plan = awareness_get_current_plan,
	
	-- Configuration
	set_checkpoint_interval = awareness_set_checkpoint_interval,
	enable_gps = awareness_enable_gps,
	set_auto_save = awareness_set_auto_save,
	
	-- Initialization
	init = awareness_init,
	reset = awareness_reset
}
