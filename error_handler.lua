--[[
Error Handler System
Comprehensive error handling and reporting
]]

-- Error log file
local error_log_file = "blue-miner/error_log.txt"

-- Error categories
local ERROR_CATEGORIES = {
	FUEL = "FUEL",
	INVENTORY = "INVENTORY",
	MOVEMENT = "MOVEMENT",
	BLOCK_INTERACTION = "BLOCK_INTERACTION",
	PERIPHERAL = "PERIPHERAL",
	GPS = "GPS",
	SYSTEM = "SYSTEM"
}

-- Error severity
local ERROR_SEVERITY = {
	INFO = "INFO",
	WARNING = "WARNING",
	ERROR = "ERROR",
	CRITICAL = "CRITICAL"
}

-- Error statistics
local error_stats = {
	total_errors = 0,
	by_category = {},
	by_severity = {},
	last_error = nil
}

--
-- Error Logging
--

local function format_timestamp()
	local day = os.day()
	local time = textutils.formatTime(os.time(), false)
	return string.format("Day %d %s", day, time)
end

local function log_error(category, severity, message, context)
	-- Update statistics
	error_stats.total_errors = error_stats.total_errors + 1
	error_stats.by_category[category] = (error_stats.by_category[category] or 0) + 1
	error_stats.by_severity[severity] = (error_stats.by_severity[severity] or 0) + 1
	
	-- Create error entry
	local error_entry = {
		timestamp = os.epoch("utc"),
		category = category,
		severity = severity,
		message = message,
		context = context or {}
	}
	
	error_stats.last_error = error_entry
	
	-- Format for log file
	local log_line = string.format(
		"[%s] [%s] [%s] %s",
		format_timestamp(),
		severity,
		category,
		message
	)
	
	if context and next(context) then
		log_line = log_line .. " | Context: " .. textutils.serialize(context)
	end
	
	-- Write to log file
	local mode = fs.exists(error_log_file) and "a" or "w"
	local file = fs.open(error_log_file, mode)
	if file then
		file.writeLine(log_line)
		file.close()
	end
	
	-- Also print if ERROR or CRITICAL
	if severity == ERROR_SEVERITY.ERROR or severity == ERROR_SEVERITY.CRITICAL then
		print("[" .. severity .. "] " .. message)
	end
	
	return error_entry
end

--
-- Error Recovery Strategies
--

local function recover_fuel_error()
	print("Attempting to refuel...")
	
	-- Try to find and use fuel items
	for slot = 1, 16 do
		turtle.select(slot)
		if turtle.refuel(0) then -- Test if this slot has fuel
			turtle.refuel(1) -- Consume 1 item
			local level = turtle.getFuelLevel()
			if type(level) == "number" and level > 0 then
				print("Refueled successfully")
				return true
			end
		end
	end
	
	return false
end

local function recover_inventory_full()
	print("Inventory full. Attempting to dump non-essential items...")
	
	-- This would integrate with the save_items system
	-- For now, just indicate that manual intervention is needed
	return false
end

local function recover_movement_blocked(direction)
	print("Movement blocked. Attempting to clear path...")
	
	-- Try to dig
	if direction == "forward" then
		if turtle.dig() then
			print("Path cleared")
			return true
		end
	elseif direction == "up" then
		if turtle.digUp() then
			print("Path cleared above")
			return true
		end
	elseif direction == "down" then
		if turtle.digDown() then
			print("Path cleared below")
			return true
		end
	end
	
	-- Try to attack (might be a mob)
	if direction == "forward" then
		turtle.attack()
	elseif direction == "up" then
		turtle.attackUp()
	elseif direction == "down" then
		turtle.attackDown()
	end
	
	os.sleep(0.5)
	return false
end

--
-- Error Handling Functions
--

local function handle_error(category, message, context, recovery_fn)
	-- Determine severity based on category
	local severity = ERROR_SEVERITY.ERROR
	if category == ERROR_CATEGORIES.FUEL and context and context.fuel_level == 0 then
		severity = ERROR_SEVERITY.CRITICAL
	elseif category == ERROR_CATEGORIES.INVENTORY then
		severity = ERROR_SEVERITY.WARNING
	end
	
	-- Log the error
	log_error(category, severity, message, context)
	
	-- Attempt recovery if function provided
	if recovery_fn then
		local success = recovery_fn()
		if success then
			log_error(
				category,
				ERROR_SEVERITY.INFO,
				"Recovered from error: " .. message,
				{recovery = "success"}
			)
			return true
		else
			log_error(
				category,
				ERROR_SEVERITY.ERROR,
				"Failed to recover from error: " .. message,
				{recovery = "failed"}
			)
		end
	end
	
	return false
end

--
-- Specific Error Handlers
--

local function handle_fuel_error(fuel_level, fuel_needed)
	return handle_error(
		ERROR_CATEGORIES.FUEL,
		string.format("Low fuel: %d/%d needed", fuel_level or 0, fuel_needed or 0),
		{fuel_level = fuel_level, fuel_needed = fuel_needed},
		recover_fuel_error
	)
end

local function handle_inventory_full()
	return handle_error(
		ERROR_CATEGORIES.INVENTORY,
		"Inventory full",
		{slots_used = 16},
		recover_inventory_full
	)
end

local function handle_movement_blocked(direction, position)
	return handle_error(
		ERROR_CATEGORIES.MOVEMENT,
		"Movement blocked: " .. direction,
		{direction = direction, position = position},
		function() return recover_movement_blocked(direction) end
	)
end

local function handle_gps_error(error_msg)
	return handle_error(
		ERROR_CATEGORIES.GPS,
		"GPS error: " .. error_msg,
		{},
		nil -- No automatic recovery for GPS
	)
end

local function handle_peripheral_error(peripheral_type, error_msg)
	return handle_error(
		ERROR_CATEGORIES.PERIPHERAL,
		string.format("Peripheral error (%s): %s", peripheral_type, error_msg),
		{peripheral_type = peripheral_type},
		nil
	)
end

--
-- Error Reporting
--

local function get_error_stats()
	return {
		total = error_stats.total_errors,
		by_category = error_stats.by_category,
		by_severity = error_stats.by_severity,
		last_error = error_stats.last_error
	}
end

local function print_error_summary()
	print("==== Error Summary ====")
	print("Total errors: " .. error_stats.total_errors)
	print("")
	
	if error_stats.total_errors > 0 then
		print("By Category:")
		for category, count in pairs(error_stats.by_category) do
			print("  " .. category .. ": " .. count)
		end
		print("")
		
		print("By Severity:")
		for severity, count in pairs(error_stats.by_severity) do
			print("  " .. severity .. ": " .. count)
		end
		print("")
		
		if error_stats.last_error then
			print("Last Error:")
			print("  " .. error_stats.last_error.message)
			print("  Category: " .. error_stats.last_error.category)
			print("  Severity: " .. error_stats.last_error.severity)
		end
	end
	
	print("")
	print("Full log: " .. error_log_file)
end

local function clear_error_log()
	if fs.exists(error_log_file) then
		fs.delete(error_log_file)
	end
	
	error_stats = {
		total_errors = 0,
		by_category = {},
		by_severity = {},
		last_error = nil
	}
end

--
-- Safe Execution Wrapper
--

local function safe_execute(fn, error_category, error_message)
	local success, result = pcall(fn)
	
	if not success then
		handle_error(
			error_category or ERROR_CATEGORIES.SYSTEM,
			error_message or "Execution failed",
			{error = tostring(result)},
			nil
		)
		return false, result
	end
	
	return true, result
end

-- Export API
return {
	-- Error categories and severity
	CATEGORY = ERROR_CATEGORIES,
	SEVERITY = ERROR_SEVERITY,
	
	-- Error handling
	handle = handle_error,
	handle_fuel = handle_fuel_error,
	handle_inventory_full = handle_inventory_full,
	handle_movement_blocked = handle_movement_blocked,
	handle_gps = handle_gps_error,
	handle_peripheral = handle_peripheral_error,
	
	-- Error reporting
	get_stats = get_error_stats,
	print_summary = print_error_summary,
	clear_log = clear_error_log,
	
	-- Safe execution
	safe_execute = safe_execute,
	
	-- Direct logging (for custom cases)
	log = log_error
}
