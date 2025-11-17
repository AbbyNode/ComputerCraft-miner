--[[
ComputerCraft Miner - Main Entrypoint
Modular mining system with Awareness, Profiles, and advanced features

Features:
- Plan-based execution with automatic checkpointing
- Profile system (Speed Demon, Balanced, Paranoid, Resource Hunter)
- GPS integration and position tracking
- Wireless monitoring and remote control
- Comprehensive error handling and logging
- Smart liquid handling and fuel management

Usage: Run this file to start the miner
]]

-- Load all modules
os.loadAPI("awareness.lua")
os.loadAPI("profiles.lua")
os.loadAPI("error_handler.lua")
os.loadAPI("wireless.lua")
os.loadAPI("ui.lua")
os.loadAPI("logger.lua")
os.loadAPI("fuel_safety.lua")
os.loadAPI("liquid_handler.lua")

--
-- Helper function to mine a simple strip
--

local function create_strip_mining_plan(length, profile_settings)
    local plan = awareness.create_plan("strip_mine", "Simple strip mining")
    
    -- Mine forward
    for i = 1, length do
        -- Dig forward
        awareness.add_step(plan, function()
            local success = turtle.dig()
            if success then
                logger.increment_blocks_mined(1)
            end
            return success
        end, "Dig forward #" .. i)
        
        -- Move forward
        awareness.add_step(plan, function()
            local success = turtle.forward()
            if not success then
                error_handler.handle_movement_blocked("forward", awareness.get_position())
            end
            return success
        end, "Move forward #" .. i)
        
        -- Handle liquids if safe mode
        if profile_settings.safe then
            awareness.add_step(plan, function()
                liquid_handler.handle_all_liquids()
                return true
            end, "Check liquids #" .. i)
        end
        
        -- Dig up
        awareness.add_step(plan, function()
            local success = turtle.digUp()
            if success then
                logger.increment_blocks_mined(1)
            end
            return success
        end, "Dig up #" .. i)
    end
    
    -- Return journey
    awareness.add_step(plan, turtle.turnLeft, "Turn around (1/2)")
    awareness.add_step(plan, turtle.turnLeft, "Turn around (2/2)")
    awareness.add_movements(plan, "forward", length, "Return")
    
    return plan
end

--
-- Main function using parallel operations
--

local function main()
    -- Clear screen and show title
    ui.clear_screen()
    ui.print_header("ComputerCraft Miner - New System")
    
    -- Show help option
    print("Type 'help' for assistance")
    print("Press Enter to continue...")
    local input = io.read()
    if input == "help" then
        ui.show_help()
        return
    end
    
    -- Run setup wizard
    local setup = ui.run_setup_wizard(profiles)
    if not setup then
        print("Setup cancelled")
        return
    end
    
    -- Apply profile settings
    local profile_settings = profiles.apply(setup.profile)
    
    -- Configure modules based on profile
    awareness.set_checkpoint_interval(profile_settings.checkpoint_interval)
    awareness.enable_gps(profile_settings.enable_gps == true or profile_settings.enable_gps == "auto")
    
    fuel_safety.set_safety_margin(profile_settings.fuel_safety_margin)
    fuel_safety.set_emergency_reserve(profile_settings.fuel_emergency_reserve)
    
    -- Initialize awareness system
    awareness.init({x=0, y=setup.current_y, z=0, facing=0})
    
    -- Initialize fuel tracking
    fuel_safety.init_fuel_tracking()
    
    -- Start operation logging
    logger.start_operation(setup.profile_id, setup.profile.name)
    
    -- Initialize wireless if enabled
    local wireless_enabled = false
    if profile_settings.wireless_monitoring == true or 
       profile_settings.wireless_monitoring == "auto" then
        wireless_enabled = wireless.init(true)
        if wireless_enabled then
            print("Wireless monitoring enabled")
        end
    end
    
    -- Check if we should resume
    if awareness.has_saved_plan() then
        print("Found saved plan. Resume?")
        if ui.input_bool("") then
            print("Resuming...")
            
            if profile_settings.parallel_operations and wireless_enabled then
                -- Resume with parallel monitoring
                parallel.waitForAll(
                    function() awareness.resume_plan() end,
                    function() wireless.monitoring_task(awareness) end
                )
            else
                awareness.resume_plan()
            end
            
            logger.end_operation()
            logger.print_summary()
            return
        else
            awareness.reset()
        end
    end
    
    -- Check fuel
    local strip_length = profile_settings.strip_len or 20
    local estimated_fuel = strip_length * 4 -- Rough estimate
    local has_fuel, current, needed = fuel_safety.has_sufficient_fuel(estimated_fuel)
    
    if not has_fuel then
        print("Insufficient fuel!")
        print("Current: " .. current)
        print("Needed: " .. needed)
        print("Please add more fuel")
        return
    end
    
    -- Create mining plan
    print("Creating mining plan...")
    local plan = create_strip_mining_plan(strip_length, profile_settings)
    print("Plan created with " .. #plan.steps .. " steps")
    
    ui.wait_enter("start mining")
    
    -- Execute plan
    if profile_settings.parallel_operations and wireless_enabled then
        print("Starting parallel operation...")
        
        -- Main mining + wireless monitoring + progress display
        parallel.waitForAll(
            function()
                -- Main mining operation
                awareness.execute_plan(plan)
            end,
            function()
                -- Wireless monitoring (race condition safe)
                while awareness.get_current_plan() do
                    wireless.broadcast_status(awareness, logger.get_stats())
                    wireless.check_for_commands()
                    wireless.process_command_queue()
                    
                    -- Check for pause
                    if wireless.is_paused() then
                        print("Paused by remote command")
                        while wireless.is_paused() do
                            os.sleep(1)
                        end
                        print("Resumed")
                    end
                    
                    os.sleep(1)
                end
            end,
            function()
                -- Progress display
                while awareness.get_current_plan() do
                    local current_plan = awareness.get_current_plan()
                    if current_plan then
                        local stats = logger.get_stats()
                        ui.display_progress({
                            strip_progress = current_plan.current_step,
                            strip_total = #current_plan.steps,
                            blocks_mined = stats.blocks_mined,
                            fuel_level = fuel_safety.get_fuel_level(),
                            fuel_max = fuel_safety.get_fuel_limit(),
                            ores_found = stats.ores_found,
                            ores_by_type = stats.ores_by_type,
                            elapsed_time = stats.operation_time
                        })
                    end
                    os.sleep(profile_settings.display_update_interval or 5)
                end
            end
        )
    else
        -- Simple execution without parallel operations
        print("Starting mining...")
        awareness.execute_plan(plan)
    end
    
    -- Complete operation
    logger.end_operation()
    
    -- Close wireless
    if wireless_enabled then
        wireless.close()
    end
    
    -- Show results
    ui.clear_screen()
    ui.print_header("Mining Complete!")
    print("")
    logger.print_summary()
    print("")
    
    -- Show fuel efficiency
    local consumed = fuel_safety.get_fuel_consumed()
    local stats = logger.get_stats()
    if consumed > 0 then
        print("Fuel efficiency: " .. string.format("%.2f", stats.blocks_mined / consumed) .. " blocks/fuel")
    end
    print("")
    
    -- Generate report
    print("Generating report...")
    local success, report_file = logger.generate_report()
    if success then
        print("Report saved: " .. report_file)
    end
    
    -- Show errors if any
    local error_stats = error_handler.get_stats()
    if error_stats.total > 0 then
        print("")
        print("Errors occurred during operation:")
        error_handler.print_summary()
    end
    
    -- Show awareness stats
    local awareness_stats = awareness.get_stats()
    print("")
    print("Operation statistics:")
    print("  Total steps: " .. awareness_stats.total_steps)
    print("  Failed steps: " .. awareness_stats.failed_steps)
    print("  Success rate: " .. string.format("%.1f%%", awareness_stats.success_rate * 100))
    print("  Checkpoints: " .. awareness_stats.checkpoints)
    
    -- Export ore data if ores found
    if stats.ores_found > 0 then
        print("")
        if ui.input_bool("Export ore locations to CSV?") then
            logger.export_ore_data_csv()
        end
    end
    
    print("")
    print("Thank you for using ComputerCraft Miner!")
end

--
-- Error handling wrapper
--

local success, error_msg = error_handler.safe_execute(
    main,
    error_handler.CATEGORY.SYSTEM,
    "Main function failed"
)

if not success then
    print("")
    print("CRITICAL ERROR:")
    print(tostring(error_msg))
    print("")
    print("Check error log for details:")
    error_handler.print_summary()
end
