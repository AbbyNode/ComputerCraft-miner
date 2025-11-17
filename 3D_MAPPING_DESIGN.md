# 3D Mapping System Design Document

## Overview
This document outlines the design for a 3D mapping system that records blocks encountered during mining operations and provides visualization capabilities.

## Purpose
- Track all blocks encountered during mining
- Record ore discoveries with precise locations
- Enable post-mining analysis and visualization
- Provide data export for external tools

## Core Components

### 1. Data Structure

#### Block Record
```lua
block_record = {
  position = {x = 100, y = 60, z = -50},
  block_name = "minecraft:diamond_ore",
  metadata = 0,
  timestamp = 1234567890,
  mined = true,  -- whether turtle mined this block
  inspected = true  -- whether turtle inspected (vs assumed air)
}
```

#### Map Storage Format
```lua
-- In-memory structure (hash map for fast lookup)
map_data = {
  ["100,60,-50"] = block_record,
  ["100,61,-50"] = block_record,
  -- ... more entries
}

-- Metadata
map_metadata = {
  operation_id = "strip_mine_20251117_001",
  start_time = 1234567890,
  end_time = 1234567999,
  turtle_id = 42,
  base_position = {x = 0, y = 65, z = 0},
  total_blocks_recorded = 5000
}
```

### 2. Recording Strategy

#### When to Record
- **Always record**: Blocks that are inspected (ore detection enabled)
- **Selective record**: Blocks that are mined (configurable)
- **Never record**: Air blocks in paths (to save memory)

#### Recording Modes
1. **Minimal Mode** (Low memory usage)
   - Only record valuable ores and unexpected blocks
   - Approximate tunnel structure

2. **Standard Mode** (Balanced)
   - Record all inspected blocks
   - Record tunnel boundaries
   - Track ore discoveries

3. **Complete Mode** (High memory usage)
   - Record every block interacted with
   - Include assumed air blocks
   - Full 3D reconstruction possible

### 3. Memory Management

#### Storage Limits
```lua
map_config = {
  max_records = 10000,  -- Maximum blocks to track
  compression_enabled = true,
  auto_flush = true,  -- Write to disk periodically
  flush_interval = 1000,  -- Flush every N blocks
}
```

#### Compression Strategy
- Group contiguous blocks of same type
- Store ranges instead of individual positions for tunnels
- Example: `{type="minecraft:stone", from={x=0,y=60,z=0}, to={x=20,y=60,z=0}}`

#### Disk Storage
- Periodic flush to disk to prevent memory overflow
- Split into chunks if operation is large
- Use textutils.serialize() for Lua compatibility

### 4. Export Formats

#### CSV Export
```csv
x,y,z,block_type,block_name,mined,timestamp
100,60,-50,ore,minecraft:diamond_ore,true,1234567890
101,60,-50,stone,minecraft:stone,true,1234567891
```

#### JSON Export
```json
{
  "metadata": {
    "operation_id": "strip_mine_20251117_001",
    "turtle_id": 42,
    "start_time": 1234567890,
    "base_position": {"x": 0, "y": 65, "z": 0}
  },
  "blocks": [
    {
      "pos": {"x": 100, "y": 60, "z": -50},
      "name": "minecraft:diamond_ore",
      "mined": true,
      "time": 1234567890
    }
  ],
  "ores": [
    {
      "type": "minecraft:diamond_ore",
      "locations": [{"x": 100, "y": 60, "z": -50}],
      "count": 1
    }
  ]
}
```

#### Schematic Export (Future)
- Export to Minecraft schematic format for visualization in external tools
- Would allow viewing the mined area in Minecraft world editors

### 5. Visualization Options

#### In-Game Monitor Display
```lua
-- Simple 2D slice view on a CC monitor
function render_2d_slice(y_level)
  local monitor = peripheral.find("monitor")
  if not monitor then return end
  
  monitor.clear()
  monitor.setTextScale(0.5)
  
  -- Render top-down view at specified Y level
  for z = min_z, max_z do
    for x = min_x, max_x do
      local key = x .. "," .. y_level .. "," .. z
      local block = map_data[key]
      
      if block then
        -- Different colors for different block types
        if is_ore(block.name) then
          monitor.setTextColor(colors.yellow)
        elseif block.name == "minecraft:air" then
          monitor.setTextColor(colors.black)
        else
          monitor.setTextColor(colors.gray)
        end
        
        monitor.write("#")
      end
    end
    monitor.setCursorPos(1, monitor.getCursorPos())
  end
end
```

#### Console Display
```
=== Mining Map Summary ===
Area: X[0 to 100], Y[50 to 60], Z[-20 to 20]
Total blocks recorded: 4,523
Ores found: 42
  - Diamond: 8
  - Iron: 24
  - Gold: 10

Ore Distribution by Y-Level:
Y-50: ############
Y-51: ########
Y-52: ######
Y-53: ###
```

#### External Visualization
- Export CSV/JSON for visualization in external tools
- Could use tools like:
  - Spreadsheet software for simple charts
  - Python scripts with matplotlib for 3D plots
  - Web-based viewers using Three.js
  - Minecraft structure viewers

### 6. API Design

#### Recording Functions
```lua
-- Record a block at current position
function map_record_block(position, block_data, action)
  if not map_config.enabled then return end
  
  local key = position_to_key(position)
  
  map_data[key] = {
    position = position,
    block_name = block_data.name,
    metadata = block_data.metadata,
    timestamp = os.epoch("utc"),
    mined = (action == "mined"),
    inspected = (action == "inspected" or action == "mined")
  }
  
  -- Check if we need to flush
  if #map_data >= map_config.flush_interval then
    map_flush_to_disk()
  end
end

-- Record multiple blocks (for efficiency)
function map_record_range(from_pos, to_pos, block_name)
  -- Store as a range to save memory
  local range_key = "range_" .. map_range_counter
  map_range_counter = map_range_counter + 1
  
  map_ranges[range_key] = {
    type = "range",
    block_name = block_name,
    from = from_pos,
    to = to_pos
  }
end
```

#### Query Functions
```lua
-- Get block at position
function map_get_block(position)
  local key = position_to_key(position)
  return map_data[key]
end

-- Find all blocks of a type
function map_find_blocks(block_name)
  local results = {}
  for key, block in pairs(map_data) do
    if block.block_name == block_name then
      table.insert(results, block)
    end
  end
  return results
end

-- Get ore statistics
function map_get_ore_stats()
  local stats = {}
  for key, block in pairs(map_data) do
    if is_ore(block.block_name) then
      stats[block.block_name] = (stats[block.block_name] or 0) + 1
    end
  end
  return stats
end
```

#### Export Functions
```lua
-- Export to CSV
function map_export_csv(filename)
  local f = fs.open(filename, "w")
  f.writeLine("x,y,z,block_type,block_name,mined,timestamp")
  
  for key, block in pairs(map_data) do
    f.writeLine(string.format("%d,%d,%d,%s,%s,%s,%d",
      block.position.x, block.position.y, block.position.z,
      get_block_category(block.block_name),
      block.block_name,
      tostring(block.mined),
      block.timestamp
    ))
  end
  
  f.close()
  print("Exported to " .. filename)
end

-- Export to JSON
function map_export_json(filename)
  local export_data = {
    metadata = map_metadata,
    blocks = {},
    ores = {}
  }
  
  -- Convert map_data to array for JSON
  for key, block in pairs(map_data) do
    table.insert(export_data.blocks, block)
  end
  
  -- Aggregate ore data
  export_data.ores = map_get_ore_stats()
  
  local f = fs.open(filename, "w")
  f.write(textutils.serializeJSON(export_data))
  f.close()
  
  print("Exported to " .. filename)
end
```

### 7. Integration with Awareness System

The mapping system should integrate with the planned Awareness system:

```lua
-- Awareness system wrapper
function awareness_action(action_fn, description)
  local result = action_fn()
  
  -- If mapping enabled, record the action
  if map_config.enabled then
    local current_pos = awareness_get_position()
    
    -- If action involved block interaction, record it
    if description:match("dig") or description:match("inspect") then
      local block_data = get_block_data_from_action(description)
      if block_data then
        map_record_block(current_pos, block_data, description)
      end
    end
  end
  
  return result
end
```

### 8. Performance Considerations

#### Memory Usage
- Typical operation (1000 blocks): ~50KB
- Large operation (10000 blocks): ~500KB
- With compression: ~200KB for 10000 blocks

#### Processing Overhead
- Recording per block: <1ms
- Flushing to disk: ~100ms per 1000 blocks
- Export: ~1s per 10000 blocks

#### Best Practices
- Enable only when needed (profile-based)
- Use compression for large operations
- Flush to disk regularly
- Limit map size for very long operations

### 9. Configuration

```lua
map_config = {
  -- Enable/disable mapping
  enabled = false,
  
  -- Recording mode
  mode = "standard",  -- "minimal" | "standard" | "complete"
  
  -- Memory management
  max_records = 10000,
  auto_flush = true,
  flush_interval = 1000,
  
  -- Compression
  compression_enabled = true,
  
  -- What to record
  record_air = false,
  record_stone = false,
  record_ores = true,
  record_all_inspected = true,
  
  -- Export options
  export_format = "csv",  -- "csv" | "json" | "both"
  auto_export_on_complete = true
}
```

### 10. Profile Integration

Different profiles should have different mapping defaults:

- **Speed Demon**: Mapping disabled (overhead not worth it)
- **Balanced**: Minimal mode (ore discoveries only)
- **Paranoid**: Standard mode (all inspected blocks)
- **Resource Hunter**: Complete mode (full 3D map for analysis)

### 11. Future Enhancements

1. **Real-time Visualization**: Stream map data to external viewer via wireless modem
2. **Collaborative Mapping**: Multiple turtles contribute to shared map
3. **Pathfinding Integration**: Use map data to navigate back through previously mined tunnels
4. **Ore Prediction**: Analyze map data to predict likely ore locations
5. **Vein Tracking**: Automatically track and visualize complete ore veins

## Implementation Priority

This is a **low priority** feature that should be implemented after:
1. Awareness system (required for integration)
2. GPS integration (helpful for absolute positioning)
3. Wireless monitoring (could enable real-time map streaming)
4. Profiles (determines default mapping behavior)

## Conclusion

The 3D mapping system provides valuable post-mining analysis capabilities without significantly impacting runtime performance when properly configured. It integrates well with the Awareness system and can be selectively enabled based on user needs via profiles.
