# Implementation Plan - Approved Features

This document outlines the features approved for implementation based on code review feedback.

## Core Framework: Awareness System (NEW - HIGH PRIORITY)

**Comment**: "Let's make a more comprehensive framework of robot awareness. Essentially, a robot should have a 'plan', keeping track of where in the plan it was completed executing up to."

### Design Overview
The Awareness system is a plan-based wrapper around the Turtle API that provides:
- **Plan-based execution**: All turtle actions are part of a structured plan
- **Progress tracking**: Know exactly where in the plan execution stopped
- **State persistence**: Automatic checkpointing integrated into the plan
- **Resume capability**: Pick up exactly where it left off after interruption

### Architecture

```lua
-- Plan structure
Plan = {
  id = "strip_mine_001",
  steps = {
    {action = turtle.forward, description = "move forward"},
    {action = turtle.dig, description = "dig forward"},
    {action = turtle.forward, description = "move forward"},
    -- ... more steps
  },
  current_step = 1,
  metadata = {
    created = timestamp,
    started = timestamp,
    last_checkpoint = timestamp
  }
}

-- Awareness wrapper
function awareness_execute_plan(plan)
  while plan.current_step <= #plan.steps do
    local step = plan.steps[plan.current_step]
    
    -- Execute step
    local success = step.action()
    
    -- Track result
    step.result = success
    step.executed_at = os.epoch("utc")
    
    -- Auto-checkpoint periodically
    if plan.current_step % checkpoint_interval == 0 then
      awareness_save_plan(plan)
    end
    
    -- Move to next step
    plan.current_step = plan.current_step + 1
  end
  
  awareness_save_plan(plan)  -- Final save
end
```

### Integration Points
- Replaces manual state persistence
- GPS tracking integrated at plan level
- Profile settings determine checkpoint frequency
- All mining operations build plans before execution

---

## Approved Features for Implementation

### 1. GPS Integration for Position Tracking ✓
**Status**: APPROVED  
**Priority**: High

- Detect wireless modem
- GPS location verification at checkpoints
- Integrate with Awareness system for position tracking
- Optional based on profile settings

### 2. Improved Error Handling and Reporting ✓
**Status**: APPROVED  
**Priority**: High

- Categorize errors (fuel, inventory, movement, block interaction)
- Error recovery strategies
- Log errors to disk with timestamp
- User-friendly error messages

### 3. Fuel Reserve and Safety Margins ✓
**Status**: APPROVED - Keep Simple  
**Priority**: High

- Configurable safety margins
- Reserve fuel for emergency return
- Warning system with thresholds
- Simple implementation, don't overcomplicate

### 4. Wireless Modem for Remote Monitoring ✓
**Status**: APPROVED - "Amazing"  
**Priority**: High

- Broadcast status updates (position, fuel, inventory)
- Receive commands from control computer
- Alert system for errors/completion
- Profile-based configuration

### 5. Parallel Mining Operations ✓
**Status**: APPROVED - Mind Race Conditions  
**Priority**: High

- Use `parallel` API for concurrent operations
- Fuel monitoring in parallel
- Wireless communication in parallel
- **CRITICAL**: Integrate well with remote monitoring
- **CRITICAL**: Be very mindful of race conditions

### 6. Advanced Liquid Handling ✓
**Status**: APPROVED  
**Priority**: Medium

- Detect all liquid types (water, lava)
- Smart liquid removal
- Collect lava for fuel
- Safety-focused implementation

### 7. Preset Mining Profiles ✓
**Status**: APPROVED - Make Extensible  
**Priority**: High

- Speed Demon, Balanced, Paranoid, Resource Hunter profiles
- **CRITICAL**: Make it easy to add more profiles in code
- **CRITICAL**: Integrate with Awareness system
- Ore Vein Excavation should be one of the profiles

### 8. Interactive Setup Wizard ✓
**Status**: APPROVED  
**Priority**: High

- Pre-flight checklist
- Inventory validation
- Requirement calculations
- User-friendly interface

### 9. Better Visual Feedback and Progress Display ✓
**Status**: APPROVED - Don't Overdo It  
**Priority**: Medium

- Progress bars
- Real-time statistics
- Keep it simple and clean

### 10. Smart Inventory Suggestions ✓
**Status**: APPROVED - Keep Minimal  
**Priority**: Low

- Calculate requirements
- Simple recommendations
- Don't overcomplicate

### 11. In-Program Help System ✓
**Status**: APPROVED  
**Priority**: High

- Context-sensitive help
- Command reference
- Troubleshooting guide

### 12. Operation Log and Reporting ✓
**Status**: APPROVED  
**Priority**: High

- Operation log with timestamps
- Performance metrics
- Ore discovery report
- Export to readable format

---

## Features NOT to Implement

### Explicitly Rejected
1. **Enhanced Block Detection (inspect before dig)** - Too slow for workflow
2. **Inventory Management with Peripheral Integration** - Not required
3. **Redstone Integration** - Not required
4. **Multi-Session Support** - Conflicts with Awareness system
5. **Multi-Turtle Coordination** - Out of scope
6. **Adaptive Mining Algorithm** - Out of scope
7. **Movement Optimization** - Already optimized, don't change
8. **Batch Operations and Caching** - Out of scope
9. **Collision Detection** - Keep brute force approach
10. **Backup and Recovery System** - Conflicts with Awareness system
11. **Energy System Integration** - Keep to CC: Tweaked features only
12. **Storage System Integration** - Out of scope

### Deferred
1. **3D Mapping** - Design document created, implementation deferred

---

## Implementation Order

### Phase 1: Core Framework (CRITICAL)
1. **Awareness System** - Plan-based execution wrapper
   - Plan creation and execution
   - Progress tracking
   - Auto-checkpointing
   - Resume capability
   - Integration with profiles

### Phase 2: Essential Features
2. **GPS Integration** - Position tracking and verification
3. **Error Handling** - Comprehensive error system
4. **Fuel Safety** - Simple safety margins
5. **Preset Profiles** - Extensible profile system with Awareness integration

### Phase 3: Communication & Monitoring
6. **Wireless Monitoring** - Remote status and control
7. **Parallel Operations** - Concurrent tasks with race condition safety

### Phase 4: User Experience
8. **Setup Wizard** - Interactive setup with validation
9. **Progress Display** - Simple visual feedback
10. **Help System** - In-program documentation

### Phase 5: Additional Features
11. **Liquid Handling** - Smart liquid management
12. **Operation Logging** - Comprehensive logging and reports
13. **Inventory Suggestions** - Minimal requirement calculator

---

## Technical Considerations

### Race Conditions (Parallel Operations + Wireless)
When implementing parallel operations with wireless monitoring:
- Use mutexes/locks for shared state access
- Separate communication channel for each parallel task
- Careful event handling to avoid conflicts
- Test thoroughly with multiple concurrent operations

### Awareness System Integration
All features must integrate with the Awareness system:
- GPS checks happen at plan checkpoints
- Fuel checks integrated into plan execution
- Wireless status broadcasts plan progress
- Profile settings affect plan generation

### Profile Extensibility
Make it easy to add new profiles:
```lua
-- profiles.lua
local profiles = {
  speed_demon = {...},
  balanced = {...},
  paranoid = {...},
  resource_hunter = {...},
  -- Easy to add more here
}

function add_profile(name, config)
  profiles[name] = config
end
```

### Keep It Simple
As noted in several comments:
- Fuel safety: Keep simple
- Progress display: Don't overdo it
- Inventory suggestions: Keep minimal

Focus on functionality over complexity.

---

## File Structure

Suggested organization:
```
/blue-miner/
  Miner.lua              # Main entry point
  awareness.lua          # NEW - Awareness system
  profiles.lua           # NEW - Profile definitions
  gps_tracking.lua       # NEW - GPS integration
  wireless.lua           # NEW - Wireless monitoring
  error_handler.lua      # NEW - Error handling
  ui.lua                 # NEW - User interface (wizard, display, help)
  logger.lua             # NEW - Operation logging
  utils.lua              # Utility functions
  MinerSettings          # Settings file (existing)
```

---

## Next Steps

1. Implement Awareness system framework
2. Integrate existing code with Awareness system
3. Implement approved features in order
4. Test each phase thoroughly
5. Ensure all features work together without conflicts
