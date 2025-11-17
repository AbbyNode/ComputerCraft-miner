--[[
Fuel Safety Module
Simple fuel management with safety margins
]]

-- Configuration
local config = {
    safety_margin = 0.15, -- 15% extra fuel
    emergency_reserve = 500,
    warning_threshold = 0.25 -- Warn at 25% fuel
}

-- State
local initial_fuel = 0
local fuel_consumed = 0

--
-- Fuel Calculation
--

local function calculate_safe_fuel(base_fuel_needed)
    local safety_fuel = math.ceil(base_fuel_needed * config.safety_margin)
    return base_fuel_needed + safety_fuel + config.emergency_reserve
end

local function get_fuel_level()
    local level = turtle.getFuelLevel()
    if type(level) == "number" then
        return level
    end
    return 999999 -- Unlimited fuel
end

local function get_fuel_limit()
    local limit = turtle.getFuelLimit()
    if type(limit) == "number" then
        return limit
    end
    return 999999 -- Unlimited fuel
end

--
-- Fuel Checking
--

local function has_sufficient_fuel(needed)
    local current = get_fuel_level()
    local safe_needed = calculate_safe_fuel(needed)
    return current >= safe_needed, current, safe_needed
end

local function get_fuel_status()
    local current = get_fuel_level()
    local limit = get_fuel_limit()
    
    local percent = 0
    if limit > 0 then
        percent = (current / limit) * 100
    end
    
    local status = "OK"
    if percent < config.warning_threshold * 100 then
        status = "LOW"
    end
    if current < config.emergency_reserve then
        status = "CRITICAL"
    end
    
    return {
        level = current,
        limit = limit,
        percent = percent,
        status = status,
        consumed = fuel_consumed
    }
end

local function check_fuel_warning()
    local status = get_fuel_status()
    
    if status.status == "CRITICAL" then
        print("!! CRITICAL FUEL !!")
        print("Fuel: " .. status.level)
        return false
    elseif status.status == "LOW" then
        print("Warning: Low fuel (" .. math.floor(status.percent) .. "%)")
        return true
    end
    
    return true
end

--
-- Fuel Consumption Tracking
--

local function init_fuel_tracking()
    initial_fuel = get_fuel_level()
    fuel_consumed = 0
end

local function update_fuel_consumed()
    local current = get_fuel_level()
    fuel_consumed = initial_fuel - current
end

local function get_fuel_consumed()
    update_fuel_consumed()
    return fuel_consumed
end

--
-- Configuration
--

local function set_safety_margin(margin)
    config.safety_margin = margin
end

local function set_emergency_reserve(reserve)
    config.emergency_reserve = reserve
end

local function set_warning_threshold(threshold)
    config.warning_threshold = threshold
end

local function get_config()
    return {
        safety_margin = config.safety_margin,
        emergency_reserve = config.emergency_reserve,
        warning_threshold = config.warning_threshold
    }
end

-- Export API
return {
    -- Fuel calculation
    calculate_safe_fuel = calculate_safe_fuel,
    has_sufficient_fuel = has_sufficient_fuel,
    
    -- Fuel status
    get_fuel_level = get_fuel_level,
    get_fuel_limit = get_fuel_limit,
    get_fuel_status = get_fuel_status,
    check_fuel_warning = check_fuel_warning,
    
    -- Consumption tracking
    init_fuel_tracking = init_fuel_tracking,
    update_fuel_consumed = update_fuel_consumed,
    get_fuel_consumed = get_fuel_consumed,
    
    -- Configuration
    set_safety_margin = set_safety_margin,
    set_emergency_reserve = set_emergency_reserve,
    set_warning_threshold = set_warning_threshold,
    get_config = get_config
}
