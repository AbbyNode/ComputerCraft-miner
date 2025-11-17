--[[
Operation Logger
Comprehensive logging and reporting system for mining operations
]]

-- Log file
local log_file = "blue-miner/operation_log.txt"
local report_dir = "blue-miner/reports"

-- Current operation data
local operation = {
    id = nil,
    start_time = 0,
    end_time = 0,
    profile = nil,
    
    -- Statistics
    blocks_mined = 0,
    fuel_consumed = 0,
    strips_completed = 0,
    
    -- Ores found
    ores_found = 0,
    ores_by_type = {},
    ore_locations = {},
    
    -- Events
    events = {}
}

--
-- Event Logging
--

local function log_event(category, message, data)
    local event = {
        timestamp = os.epoch("utc"),
        category = category,
        message = message,
        data = data or {}
    }
    
    table.insert(operation.events, event)
    
    -- Also write to log file
    local mode = fs.exists(log_file) and "a" or "w"
    local file = fs.open(log_file, mode)
    if file then
        local time_str = textutils.formatTime(os.time(), false)
        file.writeLine(string.format("[%s] [%s] %s", time_str, category, message))
        file.close()
    end
end

--
-- Operation Management
--

local function start_operation(profile_id, profile_name)
    operation.id = "mine_" .. os.epoch("utc")
    operation.start_time = os.epoch("utc")
    operation.profile = profile_name or profile_id
    
    -- Reset statistics
    operation.blocks_mined = 0
    operation.fuel_consumed = 0
    operation.strips_completed = 0
    operation.ores_found = 0
    operation.ores_by_type = {}
    operation.ore_locations = {}
    operation.events = {}
    
    log_event("OPERATION", "Mining operation started", {
        id = operation.id,
        profile = operation.profile
    })
end

local function end_operation()
    operation.end_time = os.epoch("utc")
    
    log_event("OPERATION", "Mining operation completed", {
        duration = operation.end_time - operation.start_time,
        blocks_mined = operation.blocks_mined,
        ores_found = operation.ores_found
    })
end

--
-- Statistics Tracking
--

local function increment_blocks_mined(count)
    operation.blocks_mined = operation.blocks_mined + (count or 1)
end

local function add_fuel_consumed(amount)
    operation.fuel_consumed = operation.fuel_consumed + amount
end

local function increment_strips_completed()
    operation.strips_completed = operation.strips_completed + 1
    log_event("PROGRESS", "Strip completed", {
        strip_number = operation.strips_completed
    })
end

local function log_ore_found(ore_name, position)
    operation.ores_found = operation.ores_found + 1
    operation.ores_by_type[ore_name] = (operation.ores_by_type[ore_name] or 0) + 1
    
    -- Store location
    if position then
        if not operation.ore_locations[ore_name] then
            operation.ore_locations[ore_name] = {}
        end
        table.insert(operation.ore_locations[ore_name], position)
    end
    
    log_event("ORE", "Ore discovered: " .. ore_name, {
        position = position,
        total_count = operation.ores_by_type[ore_name]
    })
end

--
-- Reporting
--

local function generate_report()
    -- Ensure report directory exists
    if not fs.exists(report_dir) then
        fs.makeDir(report_dir)
    end
    
    local report_file = fs.combine(report_dir, "report_" .. operation.id .. ".txt")
    local file = fs.open(report_file, "w")
    
    if not file then
        return false, "Could not create report file"
    end
    
    -- Write report
    file.writeLine("==== Mining Operation Report ====")
    file.writeLine("Operation ID: " .. operation.id)
    file.writeLine("Profile: " .. (operation.profile or "Unknown"))
    file.writeLine("Generated: " .. textutils.formatTime(os.time(), false))
    file.writeLine("")
    
    -- Summary
    file.writeLine("=== Summary ===")
    file.writeLine("Total blocks mined: " .. operation.blocks_mined)
    file.writeLine("Total fuel consumed: " .. operation.fuel_consumed)
    file.writeLine("Strips completed: " .. operation.strips_completed)
    file.writeLine("")
    
    -- Duration
    local duration = (operation.end_time - operation.start_time) / 1000 -- seconds
    local minutes = math.floor(duration / 60)
    local seconds = math.floor(duration % 60)
    file.writeLine("Operation time: " .. minutes .. "m " .. seconds .. "s")
    file.writeLine("")
    
    -- Ores
    file.writeLine("=== Ores Found: " .. operation.ores_found .. " ===")
    if operation.ores_found > 0 then
        for ore_name, count in pairs(operation.ores_by_type) do
            local short_name = ore_name:match(":(.+)") or ore_name
            file.writeLine(short_name .. ": " .. count)
        end
    else
        file.writeLine("No ores found")
    end
    file.writeLine("")
    
    -- Efficiency
    file.writeLine("=== Efficiency ===")
    if operation.fuel_consumed > 0 then
        local blocks_per_fuel = operation.blocks_mined / operation.fuel_consumed
        file.writeLine("Blocks per fuel: " .. string.format("%.2f", blocks_per_fuel))
        
        if operation.ores_found > 0 then
            local ores_per_fuel = operation.ores_found / operation.fuel_consumed
            file.writeLine("Ores per fuel: " .. string.format("%.4f", ores_per_fuel))
        end
    end
    file.writeLine("")
    
    -- Ore locations (if tracked)
    if next(operation.ore_locations) then
        file.writeLine("=== Ore Locations ===")
        for ore_name, locations in pairs(operation.ore_locations) do
            local short_name = ore_name:match(":(.+)") or ore_name
            file.writeLine(short_name .. ":")
            for _, pos in ipairs(locations) do
                file.writeLine(string.format("  (%d, %d, %d)", pos.x, pos.y, pos.z))
            end
        end
        file.writeLine("")
    end
    
    -- Event log
    if #operation.events > 0 then
        file.writeLine("=== Event Log (last 50) ===")
        local start_idx = math.max(1, #operation.events - 49)
        for i = start_idx, #operation.events do
            local event = operation.events[i]
            local time_str = textutils.formatTime(os.time(), false)
            file.writeLine(string.format("[%s] %s", event.category, event.message))
        end
    end
    
    file.close()
    
    print("Report saved to: " .. report_file)
    return true, report_file
end

local function print_summary()
    print("==== Operation Summary ====")
    print("")
    print("Blocks mined: " .. operation.blocks_mined)
    print("Fuel consumed: " .. operation.fuel_consumed)
    print("Strips completed: " .. operation.strips_completed)
    print("")
    
    if operation.ores_found > 0 then
        print("Ores found: " .. operation.ores_found)
        for ore_name, count in pairs(operation.ores_by_type) do
            local short_name = ore_name:match(":(.+)") or ore_name
            print("  " .. short_name .. ": " .. count)
        end
    else
        print("No ores found")
    end
    
    print("")
    
    if operation.end_time > operation.start_time then
        local duration = (operation.end_time - operation.start_time) / 1000
        local minutes = math.floor(duration / 60)
        local seconds = math.floor(duration % 60)
        print("Time: " .. minutes .. "m " .. seconds .. "s")
    end
end

--
-- Getters
--

local function get_stats()
    return {
        blocks_mined = operation.blocks_mined,
        fuel_consumed = operation.fuel_consumed,
        strips_completed = operation.strips_completed,
        ores_found = operation.ores_found,
        ores_by_type = operation.ores_by_type,
        operation_time = os.epoch("utc") - operation.start_time
    }
end

local function get_operation_id()
    return operation.id
end

--
-- Data Export
--

local function export_ore_data_csv()
    if operation.ores_found == 0 then
        return false, "No ore data to export"
    end
    
    local csv_file = fs.combine(report_dir, "ores_" .. operation.id .. ".csv")
    local file = fs.open(csv_file, "w")
    
    if not file then
        return false, "Could not create CSV file"
    end
    
    file.writeLine("ore_type,x,y,z")
    
    for ore_name, locations in pairs(operation.ore_locations) do
        for _, pos in ipairs(locations) do
            file.writeLine(string.format("%s,%d,%d,%d", ore_name, pos.x, pos.y, pos.z))
        end
    end
    
    file.close()
    
    print("Ore data exported to: " .. csv_file)
    return true, csv_file
end

-- Export API
return {
    -- Operation management
    start_operation = start_operation,
    end_operation = end_operation,
    
    -- Event logging
    log_event = log_event,
    
    -- Statistics
    increment_blocks_mined = increment_blocks_mined,
    add_fuel_consumed = add_fuel_consumed,
    increment_strips_completed = increment_strips_completed,
    log_ore_found = log_ore_found,
    
    -- Reporting
    generate_report = generate_report,
    print_summary = print_summary,
    export_ore_data_csv = export_ore_data_csv,
    
    -- Getters
    get_stats = get_stats,
    get_operation_id = get_operation_id
}
