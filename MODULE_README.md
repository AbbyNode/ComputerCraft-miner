# New Modular Architecture

This document explains the new modular architecture for the ComputerCraft Miner.

## Overview

The miner has been refactored into a modular system with the following components:

### Core Modules

1. **awareness.lua** - Plan-based execution framework
2. **profiles.lua** - Mining profile system
3. **error_handler.lua** - Error handling and recovery
4. **wireless.lua** - Remote monitoring and control
5. **ui.lua** - User interface components
6. **logger.lua** - Operation logging and reporting
7. **fuel_safety.lua** - Fuel management
8. **liquid_handler.lua** - Liquid detection and handling

## Quick Start

### Loading Modules

```lua
-- Load modules using os.loadAPI
os.loadAPI("awareness.lua")
os.loadAPI("profiles.lua")
os.loadAPI("error_handler.lua")
os.loadAPI("wireless.lua")
os.loadAPI("ui.lua")
os.loadAPI("logger.lua")
os.loadAPI("fuel_safety.lua")
os.loadAPI("liquid_handler.lua")

-- Or use require if available (CC: Tweaked 1.89+)
local awareness = require("awareness")
local profiles = require("profiles")
-- ... etc
```

## Module Usage Guide

### 1. Awareness System

The Awareness system is the core framework that wraps all turtle actions in a plan.

```lua
-- Initialize
awareness.init({x=0, y=64, z=0, facing=0})

-- Create a plan
local plan = awareness.create_plan("test_plan", "Test mining")

-- Add steps to plan
awareness.add_step(plan, function()
  return turtle.forward()
end, "Move forward")

awareness.add_step(plan, function()
  return turtle.dig()
end, "Dig")

-- Execute plan
awareness.execute_plan(plan)

-- Check if there's a saved plan to resume
if awareness.has_saved_plan() then
  print("Resuming saved plan...")
  awareness.resume_plan()
end
```

### 2. Profiles System

Preset configurations for different mining styles.

```lua
-- List available profiles
local profile_list = profiles.list()
for _, p in ipairs(profile_list) do
  print(p.id .. ": " .. p.name)
end

-- Select a profile interactively
local profile_id, profile = profiles.select_interactive()

-- Or get a specific profile
local balanced = profiles.get("balanced")

-- Apply profile settings
local settings = profiles.apply(balanced)

-- Configure Awareness system based on profile
awareness.set_checkpoint_interval(settings.checkpoint_interval)
awareness.enable_gps(settings.enable_gps)
```

#### Adding Custom Profiles

It's easy to add new profiles - just add an entry to the profiles table:

```lua
-- In profiles.lua, add to the profiles table:
profiles.profiles.my_custom = {
  name = "My Custom Profile",
  description = "A custom mining configuration",
  aggressive = true,
  neat = true,
  safe = true,
  ave_speed = 7,
  strip_spacing = 3,
  checkpoint_interval = 30,
  enable_gps = true
  -- ... more settings
}
```

### 3. Error Handler

Comprehensive error handling and recovery.

```lua
-- Handle specific errors
error_handler.handle_fuel(current_fuel, needed_fuel)
error_handler.handle_movement_blocked("forward", position)

-- Get error statistics
local stats = error_handler.get_stats()
print("Total errors: " .. stats.total)

-- Print error summary
error_handler.print_summary()

-- Safe execution wrapper
local success, result = error_handler.safe_execute(function()
  -- Your code here
  return turtle.forward()
end, error_handler.CATEGORY.MOVEMENT, "Forward movement failed")
```

### 4. Wireless Monitoring

Remote status monitoring and control (requires wireless modem).

```lua
-- Initialize (auto-detects modem)
wireless.init(true)

-- Broadcast status
wireless.broadcast_status(awareness)

-- Check for commands
wireless.check_for_commands()
wireless.process_command_queue()

-- Run monitoring in parallel
parallel.waitForAll(
  main_mining_function,
  function()
    wireless.monitoring_task(awareness)
  end
)

-- Register custom commands
wireless.register_command("custom_cmd", function(params)
  -- Handle command
  return {success = true, message = "Command executed"}
end)
```

### 5. UI Module

User interface components.

```lua
-- Show help
ui.show_help("getting_started")

-- Run setup wizard
local setup_result = ui.run_setup_wizard(profiles)
if setup_result then
  print("Starting mining with profile: " .. setup_result.profile.name)
end

-- Display progress
ui.display_progress({
  total_strips = 10,
  current_strip = 3,
  strip_progress = 15,
  strip_total = 20,
  blocks_mined = 523,
  fuel_level = 5000,
  fuel_max = 10000,
  ores_found = 12,
  ores_by_type = {
    ["minecraft:diamond_ore"] = 3,
    ["minecraft:iron_ore"] = 9
  }
})

-- Input functions
local answer = ui.input_bool("Continue mining?")
local num = ui.input_num("Enter strip count:", 10)
```

### 6. Operation Logger

Logging and reporting system.

```lua
-- Start operation
logger.start_operation("balanced", "Balanced Profile")

-- Track progress
logger.increment_blocks_mined(1)
logger.add_fuel_consumed(1)
logger.increment_strips_completed()

-- Log ore discovery
logger.log_ore_found("minecraft:diamond_ore", {x=100, y=12, z=-50})

-- End operation
logger.end_operation()

-- Generate report
logger.generate_report()

-- Print summary
logger.print_summary()

-- Export ore data
logger.export_ore_data_csv()
```

### 7. Fuel Safety

Simple fuel management with safety margins.

```lua
-- Configure
fuel_safety.set_safety_margin(0.20) -- 20% extra
fuel_safety.set_emergency_reserve(500)

-- Check fuel
local has_fuel, current, needed = fuel_safety.has_sufficient_fuel(1000)
if not has_fuel then
  print("Insufficient fuel!")
  print("Current: " .. current .. ", Needed: " .. needed)
end

-- Get status
local status = fuel_safety.get_fuel_status()
print("Fuel: " .. status.level .. " (" .. math.floor(status.percent) .. "%)")
print("Status: " .. status.status) -- OK, LOW, or CRITICAL

-- Track consumption
fuel_safety.init_fuel_tracking()
-- ... mining operations ...
local consumed = fuel_safety.get_fuel_consumed()
print("Fuel consumed: " .. consumed)
```

### 8. Liquid Handler

Smart liquid detection and handling.

```lua
-- Check for liquids
local success, result = liquid_handler.handle_liquid_forward()
if success then
  print("Liquid collected: " .. result)
end

-- Handle all directions
local results = liquid_handler.handle_all_liquids()
if results.forward then
  print("Handled liquid in front")
end

-- Use lava for fuel
if liquid_handler.use_lava_for_fuel() then
  print("Refueled with lava!")
end
```

## Main Entrypoint

Run `miner.lua` to start the miner with all modules integrated. This is the main entrypoint that combines all features into a complete mining system.

## Parallel Operations

When using parallel operations with wireless monitoring, race conditions are prevented through message queuing:

```lua
-- Safe parallel execution
parallel.waitForAll(
  function()
    -- Main mining operation
    local plan = awareness.create_plan("mining")
    -- ... add steps ...
    awareness.execute_plan(plan)
  end,
  function()
    -- Wireless monitoring (race condition safe)
    wireless.monitoring_task(awareness)
  end,
  function()
    -- Fuel monitoring
    while true do
      fuel_safety.check_fuel_warning()
      os.sleep(10)
    end
  end
)
```

## Profile-Based Configuration

Different profiles have different default settings:

- **Speed Demon**: Fast, minimal checking, checkpoints every 100 steps
- **Balanced**: Recommended, balanced safety, checkpoints every 50 steps
- **Paranoid**: Maximum safety, GPS always on, checkpoints every 25 steps
- **Resource Hunter**: Ore-focused, includes vein excavation feature

## File Structure

```
/blue-miner/
  awareness.lua          - Core execution framework
  profiles.lua           - Profile definitions
  error_handler.lua      - Error handling
  wireless.lua           - Wireless monitoring
  ui.lua                 - User interface
  logger.lua             - Operation logging
  fuel_safety.lua        - Fuel management
  liquid_handler.lua     - Liquid handling
  
  Miner.lua              - Original main file (to be updated)
  
  awareness_state        - Auto-saved state (resume point)
  error_log.txt          - Error log
  operation_log.txt      - Operation events log
  
  /reports/              - Generated reports
    report_*.txt         - Operation reports
    ores_*.csv           - Ore location data
```

## Migration from Old Code

The original `Miner.lua` can be gradually migrated to use these modules:

1. Replace manual state tracking with Awareness system
2. Replace settings system with Profiles
3. Replace error handling with error_handler module
4. Add wireless monitoring if modem available
5. Use UI components for user interaction
6. Add logging for better tracking

## Testing

Test individual modules before integration:

```lua
-- Test awareness system
local plan = awareness.create_plan("test")
awareness.add_movements(plan, "forward", 5)
awareness.execute_plan(plan)

-- Test profiles
local profile = profiles.get("balanced")
print(textutils.serialize(profile))

-- Test wireless
if wireless.init(true) then
  wireless.broadcast_status(awareness)
end
```

## Best Practices

1. **Always use Awareness system** for turtle actions to get state persistence
2. **Choose appropriate profile** for your mining scenario
3. **Enable wireless monitoring** if you have a modem for remote monitoring
4. **Check fuel safety** before starting operations
5. **Generate reports** after operations for analysis
6. **Review error logs** if issues occur

## Support

For issues or questions, see:
- `ui.show_help()` for in-program help
- `IMPLEMENTATION_PLAN.md` for feature details
- `3D_MAPPING_DESIGN.md` for future 3D mapping feature
