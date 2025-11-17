--[[
Mining Profiles System
Preset configurations for different mining styles

Easy to add new profiles - just add entries to the profiles table
]]

-- Profile definitions
local profiles = {
    speed_demon = {
        name = "Speed Demon",
        description = "Maximum speed, minimal checking, no frills",
        
        -- Core settings
        aggressive = true,
        neat = false,
        safe = false,
        ave_speed = 9,
        strip_spacing = 4,
        strip_len = 20,
        
        -- Awareness settings
        checkpoint_interval = 100, -- Less frequent checkpoints
        enable_gps = false,
        
        -- Fuel settings
        fuel_safety_margin = 0.05,
        fuel_emergency_reserve = 200,
        
        -- Features
        ore_logging = false,
        wireless_monitoring = false,
        parallel_operations = true,
        
        -- Display
        progress_display = true,
        display_update_interval = 10
    },
    
    balanced = {
        name = "Balanced",
        description = "Good mix of speed and safety (Recommended)",
        
        -- Core settings
        aggressive = true,
        neat = true,
        safe = true,
        ave_speed = 5,
        strip_spacing = 3,
        strip_len = 20,
        
        -- Awareness settings
        checkpoint_interval = 50, -- Balanced checkpointing
        enable_gps = "auto", -- Use if available
        
        -- Fuel settings
        fuel_safety_margin = 0.15,
        fuel_emergency_reserve = 500,
        
        -- Features
        ore_logging = true,
        wireless_monitoring = "auto",
        parallel_operations = true,
        
        -- Display
        progress_display = true,
        display_update_interval = 5
    },
    
    paranoid = {
        name = "Paranoid",
        description = "Maximum safety, GPS verification, full error checking",
        
        -- Core settings
        aggressive = false,
        neat = true,
        safe = true,
        ave_speed = 2,
        strip_spacing = 2,
        strip_len = 15,
        
        -- Awareness settings
        checkpoint_interval = 25, -- Frequent checkpoints
        enable_gps = true, -- Always use GPS
        
        -- Fuel settings
        fuel_safety_margin = 0.30,
        fuel_emergency_reserve = 1000,
        
        -- Features
        ore_logging = true,
        wireless_monitoring = true,
        parallel_operations = false, -- Avoid complexity
        
        -- Display
        progress_display = true,
        display_update_interval = 3
    },
    
    resource_hunter = {
        name = "Resource Hunter",
        description = "Focus on finding and collecting ores efficiently",
        
        -- Core settings
        aggressive = true,
        neat = false,
        safe = true,
        ave_speed = 4,
        strip_spacing = 2, -- Closer strips to find more ore
        strip_len = 25,
        
        -- Awareness settings
        checkpoint_interval = 40,
        enable_gps = "auto",
        
        -- Fuel settings
        fuel_safety_margin = 0.20,
        fuel_emergency_reserve = 600,
        
        -- Features
        ore_logging = true,
        wireless_monitoring = "auto",
        parallel_operations = true,
        vein_excavation = true, -- Special feature for this profile
        
        -- Display
        progress_display = true,
        display_update_interval = 5,
        show_ore_count = true
    }
}

-- Active profile
local active_profile = nil
local custom_profile = nil

--
-- Profile Management
--

-- Get a profile by name
local function get_profile(name)
    return profiles[name]
end

-- List all available profiles
local function list_profiles()
    local profile_list = {}
    for name, profile in pairs(profiles) do
        table.insert(profile_list, {
            id = name,
            name = profile.name,
            description = profile.description
        })
    end
    return profile_list
end

-- Add a custom profile (makes it easy to extend)
local function add_profile(id, profile)
    if profiles[id] then
        return false, "Profile '" .. id .. "' already exists"
    end
    
    profiles[id] = profile
    return true
end

-- Set active profile
local function set_active_profile(name)
    local profile = profiles[name]
    if not profile then
        return false, "Profile '" .. name .. "' not found"
    end
    
    active_profile = name
    return true, profile
end

-- Get active profile
local function get_active_profile()
    if not active_profile then
        return nil, "No active profile"
    end
    return profiles[active_profile]
end

-- Create a custom profile from current settings
local function create_custom_from_current(current_settings)
    custom_profile = {
        name = "Custom",
        description = "User-defined settings",
        
        -- Copy current settings
        aggressive = current_settings.aggressive,
        neat = current_settings.neat,
        safe = current_settings.safe,
        ave_speed = current_settings.ave_speed,
        strip_spacing = current_settings.strip_spacing,
        strip_len = current_settings.strip_len,
        
        -- Default awareness settings
        checkpoint_interval = 50,
        enable_gps = false,
        
        -- Default fuel settings
        fuel_safety_margin = 0.15,
        fuel_emergency_reserve = 500,
        
        -- Default features
        ore_logging = true,
        wireless_monitoring = false,
        parallel_operations = false,
        
        -- Default display
        progress_display = true,
        display_update_interval = 5
    }
    
    profiles.custom = custom_profile
    return custom_profile
end

--
-- Profile Application
--

-- Apply a profile to settings
local function apply_profile(profile)
    -- This function should be called to apply profile settings
    -- to the miner's configuration
    
    -- Return a settings object that can be used with init()
    local settings = {
        -- Core mining settings
        aggressive = profile.aggressive,
        neat = profile.neat,
        safe = profile.safe,
        ave_speed = profile.ave_speed,
        strip_spacing = profile.strip_spacing,
        strip_len = profile.strip_len,
        
        -- Additional settings
        checkpoint_interval = profile.checkpoint_interval,
        enable_gps = profile.enable_gps,
        fuel_safety_margin = profile.fuel_safety_margin,
        fuel_emergency_reserve = profile.fuel_emergency_reserve,
        ore_logging = profile.ore_logging,
        wireless_monitoring = profile.wireless_monitoring,
        parallel_operations = profile.parallel_operations,
        progress_display = profile.progress_display,
        display_update_interval = profile.display_update_interval,
        
        -- Special features
        vein_excavation = profile.vein_excavation or false,
        show_ore_count = profile.show_ore_count or false
    }
    
    return settings
end

--
-- Profile Selection UI
--

-- Display profile selection menu
local function display_profile_menu()
    print("==== Choose Mining Profile ====")
    print("")
    
    local profile_list = {
        {id = "speed_demon", num = 1},
        {id = "balanced", num = 2},
        {id = "paranoid", num = 3},
        {id = "resource_hunter", num = 4},
        {id = "custom", num = 5}
    }
    
    for _, item in ipairs(profile_list) do
        local profile = profiles[item.id]
        if profile then
            print(item.num .. " - " .. profile.name)
            print("    " .. profile.description)
            print("")
        end
    end
    
    return profile_list
end

-- Interactive profile selection
local function select_profile_interactive()
    local profile_list = display_profile_menu()
    
    print("Select profile (1-5):")
    local choice = tonumber(io.read())
    
    if not choice or choice < 1 or choice > #profile_list then
        return nil, "Invalid selection"
    end
    
    local selected_id = profile_list[choice].id
    
    if selected_id == "custom" then
        -- Custom profile needs to be configured
        return "custom", profiles.custom or create_custom_from_current({
            aggressive = true,
            neat = true,
            safe = true,
            ave_speed = 5,
            strip_spacing = 3,
            strip_len = 20
        })
    end
    
    return selected_id, profiles[selected_id]
end

--
-- Profile Comparison
--

-- Show comparison between profiles
local function display_profile_comparison()
    print("==== Profile Comparison ====")
    print("")
    print("Feature          | Speed | Balanced | Paranoid | Hunter")
    print("-" .. string.rep("-", 60))
    
    local features = {
        {key = "ave_speed", name = "Speed"},
        {key = "strip_spacing", name = "Strip Spacing"},
        {key = "neat", name = "Place Walls"},
        {key = "safe", name = "Handle Lava"},
        {key = "checkpoint_interval", name = "Checkpoint Freq"},
        {key = "enable_gps", name = "GPS"},
        {key = "fuel_safety_margin", name = "Fuel Safety%"}
    }
    
    for _, feature in ipairs(features) do
        local line = string.format("%-16s", feature.name)
        
        for _, profile_id in ipairs({"speed_demon", "balanced", "paranoid", "resource_hunter"}) do
            local profile = profiles[profile_id]
            local value = profile[feature.key]
            
            if type(value) == "boolean" then
                value = value and "Yes" or "No"
            elseif type(value) == "number" and feature.key == "fuel_safety_margin" then
                value = string.format("%.0f%%", value * 100)
            end
            
            line = line .. " | " .. string.format("%-8s", tostring(value))
        end
        
        print(line)
    end
    
    print("")
end

-- Export API
return {
    -- Profile management
    get = get_profile,
    list = list_profiles,
    add = add_profile,
    
    -- Active profile
    set_active = set_active_profile,
    get_active = get_active_profile,
    
    -- Profile application
    apply = apply_profile,
    
    -- UI functions
    select_interactive = select_profile_interactive,
    display_menu = display_profile_menu,
    display_comparison = display_profile_comparison,
    
    -- Custom profile
    create_custom = create_custom_from_current,
    
    -- Direct access to profiles (for adding new ones programmatically)
    profiles = profiles
}
