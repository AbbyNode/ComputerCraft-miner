--[[
Wireless Monitoring System
Remote status monitoring and control for mining turtles

Integrates with Awareness system and Profiles
Race condition safe through message queuing
]]

-- Configuration
local config = {
    enabled = false,
    modem_side = nil,
    status_interval = 30, -- Broadcast every 30 seconds
    command_check_interval = 1, -- Check for commands every second
    turtle_id = os.getComputerID(),
    channel = 65500 -- Default channel for miner communication
}

-- State
local state = {
    last_status_broadcast = 0,
    last_command_check = 0,
    is_paused = false,
    status_broadcast_count = 0,
    commands_received = 0
}

-- Message queue (prevents race conditions)
local message_queue = {}
local queue_lock = false

-- Command handlers
local command_handlers = {}

--
-- Modem Detection and Initialization
--

local function detect_modem()
    for _, side in ipairs({"left", "right", "top", "bottom", "front", "back"}) do
        if peripheral.getType(side) == "modem" then
            local modem = peripheral.wrap(side)
            if modem.isWireless() then
                return side, modem
            end
        end
    end
    return nil, nil
end

local function init_wireless(auto_detect)
    if auto_detect or auto_detect == nil then
        local side, modem = detect_modem()
        if side then
            config.modem_side = side
            config.enabled = true
            
            -- Open rednet
            rednet.open(config.modem_side)
            
            print("[Wireless] Initialized on " .. config.modem_side)
            return true
        else
            print("[Wireless] No wireless modem found")
            return false
        end
    end
    
    return false
end

local function close_wireless()
    if config.enabled and config.modem_side then
        rednet.close(config.modem_side)
        config.enabled = false
        print("[Wireless] Closed")
    end
end

--
-- Message Queue (Race Condition Safe)
--

local function queue_message(message)
    -- Wait for lock to be available
    while queue_lock do
        os.sleep(0.05)
    end
    
    queue_lock = true
    table.insert(message_queue, message)
    queue_lock = false
end

local function dequeue_message()
    -- Wait for lock to be available
    while queue_lock do
        os.sleep(0.05)
    end
    
    queue_lock = true
    local message = table.remove(message_queue, 1)
    queue_lock = false
    
    return message
end

local function queue_size()
    return #message_queue
end

--
-- Status Broadcasting
--

local function create_status_message(awareness_api, custom_data)
    local position = awareness_api and awareness_api.get_position() or {x=0, y=0, z=0, facing=0}
    local stats = awareness_api and awareness_api.get_stats() or {}
    local current_plan = awareness_api and awareness_api.get_current_plan() or nil
    
    local fuel_level = turtle.getFuelLevel()
    local fuel_max = turtle.getFuelLimit()
    
    -- Count used inventory slots
    local slots_used = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            slots_used = slots_used + 1
        end
    end
    
    local status = {
        type = "miner_status",
        turtle_id = config.turtle_id,
        timestamp = os.epoch("utc"),
        
        -- Position
        position = position,
        
        -- Fuel
        fuel = {
            level = fuel_level,
            max = fuel_max,
            percent = type(fuel_level) == "number" and type(fuel_max) == "number" 
                and (fuel_level / fuel_max * 100) or 0
        },
        
        -- Inventory
        inventory = {
            slots_used = slots_used,
            slots_total = 16,
            percent = (slots_used / 16 * 100)
        },
        
        -- Operation status
        operation = {
            paused = state.is_paused,
            plan_id = current_plan and current_plan.id or "none",
            step = current_plan and current_plan.current_step or 0,
            total_steps = current_plan and #current_plan.steps or 0,
            progress_percent = current_plan and #current_plan.steps > 0
                and (current_plan.current_step / #current_plan.steps * 100) or 0
        },
        
        -- Statistics
        stats = stats,
        
        -- Custom data
        custom = custom_data or {}
    }
    
    return status
end

local function broadcast_status(awareness_api, custom_data)
    if not config.enabled then
        return false
    end
    
    local now = os.epoch("utc") / 1000
    
    -- Check if it's time to broadcast
    if now - state.last_status_broadcast < config.status_interval then
        return false
    end
    
    local status = create_status_message(awareness_api, custom_data)
    
    -- Broadcast using rednet
    rednet.broadcast(status, "miner_status")
    
    state.last_status_broadcast = now
    state.status_broadcast_count = state.status_broadcast_count + 1
    
    return true
end

--
-- Command Handling
--

-- Register a command handler
local function register_command(command_name, handler_fn)
    command_handlers[command_name] = handler_fn
end

-- Default command handlers
register_command("pause", function()
    state.is_paused = true
    return {success = true, message = "Turtle paused"}
end)

register_command("resume", function()
    state.is_paused = false
    return {success = true, message = "Turtle resumed"}
end)

register_command("status", function()
    -- Force status broadcast
    state.last_status_broadcast = 0
    return {success = true, message = "Status sent"}
end)

register_command("get_position", function()
    local awareness_api = _G.awareness
    if awareness_api then
        local pos = awareness_api.get_position()
        return {
            success = true,
            position = pos
        }
    end
    return {success = false, message = "Awareness system not available"}
end)

register_command("get_fuel", function()
    return {
        success = true,
        fuel_level = turtle.getFuelLevel(),
        fuel_max = turtle.getFuelLimit()
    }
end)

-- Process a command
local function process_command(command)
    if not command or not command.command then
        return {success = false, message = "Invalid command format"}
    end
    
    local handler = command_handlers[command.command]
    if not handler then
        return {success = false, message = "Unknown command: " .. command.command}
    end
    
    -- Execute handler
    local success, result = pcall(handler, command.params)
    
    if not success then
        return {success = false, message = "Command failed: " .. tostring(result)}
    end
    
    state.commands_received = state.commands_received + 1
    
    return result
end

-- Check for incoming commands
local function check_for_commands()
    if not config.enabled then
        return nil
    end
    
    local now = os.epoch("utc") / 1000
    
    -- Throttle command checks
    if now - state.last_command_check < config.command_check_interval then
        return nil
    end
    
    state.last_command_check = now
    
    -- Check for messages (non-blocking)
    local sender_id, message, protocol = rednet.receive("miner_command", 0.1)
    
    if message then
        -- Add to queue to prevent race conditions
        queue_message({
            sender = sender_id,
            message = message,
            protocol = protocol,
            timestamp = os.epoch("utc")
        })
        
        return true
    end
    
    return false
end

-- Process queued commands
local function process_command_queue()
    local processed = 0
    
    while queue_size() > 0 do
        local queued = dequeue_message()
        
        if queued then
            local result = process_command(queued.message)
            
            -- Send response back to sender
            if queued.sender then
                rednet.send(queued.sender, {
                    type = "command_response",
                    turtle_id = config.turtle_id,
                    command = queued.message.command,
                    result = result,
                    timestamp = os.epoch("utc")
                }, "miner_response")
            end
            
            processed = processed + 1
        end
    end
    
    return processed
end

--
-- Integration with Parallel Operations
--

-- Wireless monitoring task for parallel execution
local function monitoring_task(awareness_api, custom_data_fn)
    while not state.is_paused do
        -- Broadcast status
        broadcast_status(awareness_api, custom_data_fn and custom_data_fn() or nil)
        
        -- Check for commands
        check_for_commands()
        
        -- Process command queue
        process_command_queue()
        
        -- Small sleep to prevent tight loop
        os.sleep(0.5)
    end
end

--
-- Configuration
--

local function set_status_interval(seconds)
    config.status_interval = seconds
end

local function set_command_check_interval(seconds)
    config.command_check_interval = seconds
end

local function set_channel(channel)
    config.channel = channel
end

local function is_enabled()
    return config.enabled
end

local function is_paused()
    return state.is_paused
end

local function set_paused(paused)
    state.is_paused = paused
end

--
-- Statistics
--

local function get_stats()
    return {
        enabled = config.enabled,
        modem_side = config.modem_side,
        broadcasts_sent = state.status_broadcast_count,
        commands_received = state.commands_received,
        queue_size = queue_size(),
        is_paused = state.is_paused
    }
end

local function print_stats()
    print("==== Wireless Monitoring Stats ====")
    print("Enabled: " .. tostring(config.enabled))
    if config.enabled then
        print("Modem: " .. (config.modem_side or "none"))
        print("Status broadcasts sent: " .. state.status_broadcast_count)
        print("Commands received: " .. state.commands_received)
        print("Queue size: " .. queue_size())
        print("Is paused: " .. tostring(state.is_paused))
    end
end

-- Export API
return {
    -- Initialization
    init = init_wireless,
    close = close_wireless,
    
    -- Status broadcasting
    broadcast_status = broadcast_status,
    create_status_message = create_status_message,
    
    -- Command handling
    check_for_commands = check_for_commands,
    process_command_queue = process_command_queue,
    register_command = register_command,
    
    -- Parallel task
    monitoring_task = monitoring_task,
    
    -- Configuration
    set_status_interval = set_status_interval,
    set_command_check_interval = set_command_check_interval,
    set_channel = set_channel,
    is_enabled = is_enabled,
    
    -- Pause control
    is_paused = is_paused,
    set_paused = set_paused,
    
    -- Statistics
    get_stats = get_stats,
    print_stats = print_stats
}
