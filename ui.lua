--[[
UI Module
User interface components: Setup Wizard, Progress Display, Help System
]]

--
-- Help System
--

local help_topics = {
    getting_started = {
        title = "Getting Started",
        content = [[
Getting Started with Miner
===========================

1. Load your turtle with:
   - Fuel (coal, lava buckets, or blaze rods)
   - Torches (for lighting)
   - Cobblestone (for filling gaps)
   - At least 1 chest (for storage)
   - Buckets (for lava removal)

2. Run the Miner program

3. Choose a profile or use custom settings

4. Follow the setup wizard

5. The turtle will mine strips automatically!

For more help, see other topics.
]]
    },
    
    profiles = {
        title = "Mining Profiles",
        content = [[
Mining Profiles
===============

Speed Demon:
  Fast mining, minimal safety checks
  Best for: Quick resource gathering
  
Balanced (Recommended):
  Good mix of speed and safety
  Best for: Most situations
  
Paranoid:
  Maximum safety, GPS verification
  Best for: Valuable locations
  
Resource Hunter:
  Optimized for finding ores
  Mines closer strips to find more
  Best for: Ore-rich areas

Choose a profile during setup.
]]
    },
    
    awareness = {
        title = "Awareness System",
        content = [[
Awareness System
================

The Awareness system tracks all turtle
actions and can resume if interrupted.

Features:
- Automatic progress saving
- Resume after chunk unload
- GPS position verification
- Error recovery

If turtle stops, just restart the
program and it will resume!

Checkpoint frequency varies by profile.
]]
    },
    
    wireless = {
        title = "Wireless Monitoring",
        content = [[
Wireless Monitoring
===================

Requires: Wireless Modem upgrade

Features:
- Remote status monitoring
- Position tracking
- Fuel level alerts
- Remote pause/resume

Commands you can send:
- pause: Pause the turtle
- resume: Resume operation
- status: Request status update
- get_position: Get current location
- get_fuel: Get fuel level

Enabled automatically if modem detected.
]]
    },
    
    troubleshooting = {
        title = "Troubleshooting",
        content = [[
Troubleshooting
===============

Turtle stopped moving:
- Check fuel level
- Check for obstacles
- Try resuming operation

Out of inventory space:
- Turtle will return to chest
- Ensure chest is not full
- May need multiple chests

Lost position:
- If GPS enabled, position auto-corrects
- Without GPS, turtle may be off course
- Can manually reset if needed

Errors persisting:
- Check error log (error_log.txt)
- Review error summary in UI
- May need to reset and restart
]]
    },
    
    commands = {
        title = "Command Reference",
        content = [[
Command Reference
=================

During Mining:
- Turtle automatically handles operations
- Use wireless commands if modem equipped
- Check progress in real-time

After Completion:
- View operation report
- Check error log if issues
- Export ore discovery data

Profile Management:
- Easy to add custom profiles
- Modify existing profiles
- Switch profiles between operations

State Management:
- Auto-save at checkpoints
- Manual save available
- Resume from any checkpoint
]]
    }
}

local function show_help(topic)
    if not topic then
        -- Show help menu
        print("==== Help Topics ====")
        print("")
        for topic_name, topic_data in pairs(help_topics) do
            print("  " .. topic_name .. " - " .. topic_data.title)
        end
        print("")
        print("Usage: help(\"topic_name\")")
        return
    end
    
    local topic_data = help_topics[topic]
    if topic_data then
        term.clear()
        term.setCursorPos(1, 1)
        print(topic_data.content)
        print("")
        print("Press Enter to continue...")
        io.read()
    else
        print("Unknown help topic: " .. topic)
        print("Available topics:")
        for topic_name, _ in pairs(help_topics) do
            print("  " .. topic_name)
        end
    end
end

--
-- Progress Display
--

local function draw_progress_bar(current, total, width)
    local filled = math.floor((current / total) * width)
    local empty = width - filled
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "]"
    local percent = math.floor((current / total) * 100)
    return bar .. " " .. percent .. "%"
end

local function format_time(milliseconds)
    local seconds = math.floor(milliseconds / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    
    seconds = seconds % 60
    minutes = minutes % 60
    
    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, seconds)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds)
    else
        return string.format("%ds", seconds)
    end
end

local function display_progress(data)
    term.clear()
    term.setCursorPos(1, 1)
    
    print("==== Mining Progress ====")
    print("")
    
    -- Overall progress
    if data.total_strips and data.current_strip then
        print("Overall: Strip " .. data.current_strip .. " of " .. data.total_strips)
        print(draw_progress_bar(data.current_strip, data.total_strips, 30))
        print("")
    end
    
    -- Current strip progress
    if data.strip_progress and data.strip_total then
        print("Current Strip:")
        print(draw_progress_bar(data.strip_progress, data.strip_total, 30))
        print("")
    end
    
    -- Statistics
    print("=== Statistics ===")
    if data.blocks_mined then
        print("Blocks mined: " .. data.blocks_mined)
    end
    if data.fuel_level and data.fuel_max then
        print("Fuel: " .. data.fuel_level .. "/" .. data.fuel_max)
    end
    if data.inventory_used then
        print("Inventory: " .. data.inventory_used .. "/16 slots")
    end
    print("")
    
    -- Ores found
    if data.ores_found and data.ores_found > 0 then
        print("=== Ores Found: " .. data.ores_found .. " ===")
        if data.ores_by_type then
            for ore_name, count in pairs(data.ores_by_type) do
                local short_name = ore_name:match(":(.+)") or ore_name
                print("  " .. short_name .. ": " .. count)
            end
        end
        print("")
    end
    
    -- Time
    if data.elapsed_time then
        print("Time elapsed: " .. format_time(data.elapsed_time))
    end
    if data.estimated_remaining then
        print("Est. remaining: " .. format_time(data.estimated_remaining))
    end
end

--
-- Setup Wizard
--

local function input_bool(prompt)
    if prompt then
        print(prompt)
    end
    print("(y/n)")
    local answer = io.read():sub(1,1):lower()
    return answer == "y"
end

local function input_num(prompt, default)
    if prompt then
        print(prompt)
    end
    if default then
        print("(default: " .. default .. ")")
    end
    local input = io.read()
    local num = tonumber(input)
    if not num and default then
        return default
    end
    return num or 0
end

local function wait_enter(prompt)
    print("")
    print("Press Enter to " .. (prompt or "continue") .. "...")
    io.read()
end

local function check_fuel(min_fuel)
    local level = turtle.getFuelLevel()
    if type(level) == "number" then
        return level >= min_fuel, level
    end
    return true, "unlimited"
end

local function check_torches(min_torches)
    local count = 0
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name == "minecraft:torch" then
            count = count + detail.count
        end
    end
    return count >= min_torches, count
end

local function check_cobblestone()
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and (detail.name == "minecraft:cobblestone" or detail.name == "minecraft:stone") then
            return true
        end
    end
    return false
end

local function check_chest()
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name == "minecraft:chest" then
            return true
        end
    end
    return false
end

local function check_bucket()
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name == "minecraft:bucket" then
            return true
        end
    end
    return false
end

local function run_setup_wizard(profiles_api)
    term.clear()
    term.setCursorPos(1, 1)
    
    print("==== Miner Setup Wizard ====")
    print("")
    print("This wizard will help you configure mining.")
    wait_enter("begin")
    
    -- Step 1: Profile selection
    term.clear()
    term.setCursorPos(1, 1)
    
    local profile_id, profile = profiles_api.select_interactive()
    if not profile_id then
        print("Invalid profile selection")
        return nil
    end
    
    -- Step 2: Mining parameters
    term.clear()
    term.setCursorPos(1, 1)
    
    print("==== Mining Parameters ====")
    print("")
    
    local current_y = input_num("Enter current Y coordinate:", 64)
    local dest_y = input_num("Enter destination Y coordinate:", 11)
    local depth = current_y - dest_y
    
    local num_strips = input_num("Number of mining strips:", 10)
    
    -- Step 3: Pre-flight checklist
    term.clear()
    term.setCursorPos(1, 1)
    
    print("==== Pre-flight Checklist ====")
    print("")
    
    local checklist = {
        {name = "Fuel", check = function() return check_fuel(1000) end, required = true},
        {name = "Torches", check = function() return check_torches(64) end, required = profile.neat},
        {name = "Cobblestone", check = check_cobblestone, required = profile.neat},
        {name = "Chest", check = check_chest, required = true},
        {name = "Bucket", check = check_bucket, required = profile.safe}
    }
    
    local all_ok = true
    for _, item in ipairs(checklist) do
        local ok, value = item.check()
        local status = ok and "[OK]" or (item.required and "[MISSING!]" or "[OPTIONAL]")
        local display = item.name
        if value and type(value) ~= "boolean" then
            display = display .. " (" .. tostring(value) .. ")"
        end
        print(status .. " " .. display)
        
        if not ok and item.required then
            all_ok = false
        end
    end
    
    print("")
    
    if not all_ok then
        print("Please add missing required items!")
        wait_enter("retry")
        return run_setup_wizard(profiles_api)
    end
    
    -- Step 4: Confirmation
    print("Ready to start mining!")
    print("")
    print("Profile: " .. profile.name)
    print("Depth: " .. depth .. " blocks")
    print("Strips: " .. num_strips)
    print("")
    
    if not input_bool("Start mining?") then
        return nil
    end
    
    return {
        profile = profile,
        profile_id = profile_id,
        current_y = current_y,
        dest_y = dest_y,
        depth = depth,
        num_strips = num_strips
    }
end

--
-- Simple Input Functions
--

local function clear_screen()
    term.clear()
    term.setCursorPos(1, 1)
end

local function print_header(title)
    print("==== " .. title .. " ====")
    print("")
end

-- Export API
return {
    -- Help system
    show_help = show_help,
    help_topics = help_topics,
    
    -- Progress display
    display_progress = display_progress,
    draw_progress_bar = draw_progress_bar,
    format_time = format_time,
    
    -- Setup wizard
    run_setup_wizard = run_setup_wizard,
    
    -- Input functions
    input_bool = input_bool,
    input_num = input_num,
    wait_enter = wait_enter,
    
    -- Checks
    check_fuel = check_fuel,
    check_torches = check_torches,
    check_cobblestone = check_cobblestone,
    check_chest = check_chest,
    check_bucket = check_bucket,
    
    -- Utilities
    clear_screen = clear_screen,
    print_header = print_header
}
