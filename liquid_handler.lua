--[[
Liquid Handler
Smart detection and handling of liquids (lava, water)
]]

-- Liquid types
local LIQUIDS = {
	LAVA = {"minecraft:lava", "minecraft:flowing_lava"},
	WATER = {"minecraft:water", "minecraft:flowing_water"}
}

--
-- Detection
--

local function is_liquid(block_name, liquid_type)
	if not liquid_type then
		-- Check if it's any liquid
		for _, liquid_list in pairs(LIQUIDS) do
			for _, liquid_name in ipairs(liquid_list) do
				if block_name == liquid_name then
					return true
				end
			end
		end
		return false
	else
		-- Check specific liquid type
		local liquid_list = LIQUIDS[liquid_type]
		if liquid_list then
			for _, liquid_name in ipairs(liquid_list) do
				if block_name == liquid_name then
					return true
				end
			end
		end
		return false
	end
end

local function is_source_block(metadata)
	-- Source blocks have metadata 0
	return metadata == 0
end

--
-- Liquid Handling
--

local function handle_liquid_forward()
	local success, data = turtle.inspect()
	
	if not success then
		return false, "no_block"
	end
	
	-- Check if it's lava
	if is_liquid(data.name, "LAVA") then
		if is_source_block(data.metadata) then
			-- Try to collect lava source
			for slot = 1, 16 do
				turtle.select(slot)
				local detail = turtle.getItemDetail()
				if detail and detail.name == "minecraft:bucket" then
					if turtle.place() then
						return true, "lava_collected"
					end
				end
			end
			return false, "no_bucket"
		else
			-- Flowing lava, can't collect
			return false, "flowing_lava"
		end
	end
	
	-- Check if it's water
	if is_liquid(data.name, "WATER") then
		if is_source_block(data.metadata) then
			-- Try to collect water source
			for slot = 1, 16 do
				turtle.select(slot)
				local detail = turtle.getItemDetail()
				if detail and detail.name == "minecraft:bucket" then
					if turtle.place() then
						return true, "water_collected"
					end
				end
			end
			return false, "no_bucket"
		else
			-- Flowing water
			return false, "flowing_water"
		end
	end
	
	return false, "not_liquid"
end

local function handle_liquid_up()
	local success, data = turtle.inspectUp()
	
	if not success then
		return false, "no_block"
	end
	
	-- Check if it's lava
	if is_liquid(data.name, "LAVA") then
		if is_source_block(data.metadata) then
			for slot = 1, 16 do
				turtle.select(slot)
				local detail = turtle.getItemDetail()
				if detail and detail.name == "minecraft:bucket" then
					if turtle.placeUp() then
						return true, "lava_collected"
					end
				end
			end
			return false, "no_bucket"
		end
	end
	
	-- Check if it's water
	if is_liquid(data.name, "WATER") then
		if is_source_block(data.metadata) then
			for slot = 1, 16 do
				turtle.select(slot)
				local detail = turtle.getItemDetail()
				if detail and detail.name == "minecraft:bucket" then
					if turtle.placeUp() then
						return true, "water_collected"
					end
				end
			end
			return false, "no_bucket"
		end
	end
	
	return false, "not_liquid"
end

local function handle_liquid_down()
	local success, data = turtle.inspectDown()
	
	if not success then
		return false, "no_block"
	end
	
	-- Check if it's lava
	if is_liquid(data.name, "LAVA") then
		if is_source_block(data.metadata) then
			for slot = 1, 16 do
				turtle.select(slot)
				local detail = turtle.getItemDetail()
				if detail and detail.name == "minecraft:bucket" then
					if turtle.placeDown() then
						return true, "lava_collected"
					end
				end
			end
			return false, "no_bucket"
		end
	end
	
	-- Check if it's water
	if is_liquid(data.name, "WATER") then
		if is_source_block(data.metadata) then
			for slot = 1, 16 do
				turtle.select(slot)
				local detail = turtle.getItemDetail()
				if detail and detail.name == "minecraft:bucket" then
					if turtle.placeDown() then
						return true, "water_collected"
					end
				end
			end
			return false, "no_bucket"
		end
	end
	
	return false, "not_liquid"
end

-- Handle all directions
local function handle_all_liquids()
	local results = {}
	
	results.forward = handle_liquid_forward()
	results.up = handle_liquid_up()
	results.down = handle_liquid_down()
	
	return results
end

-- Use lava for fuel
local function use_lava_for_fuel()
	for slot = 1, 16 do
		turtle.select(slot)
		local detail = turtle.getItemDetail()
		if detail and detail.name == "minecraft:lava_bucket" then
			if turtle.refuel(1) then
				return true
			end
		end
	end
	return false
end

-- Export API
return {
	-- Detection
	is_liquid = is_liquid,
	is_source_block = is_source_block,
	
	-- Handling
	handle_liquid_forward = handle_liquid_forward,
	handle_liquid_up = handle_liquid_up,
	handle_liquid_down = handle_liquid_down,
	handle_all_liquids = handle_all_liquids,
	
	-- Fuel
	use_lava_for_fuel = use_lava_for_fuel,
	
	-- Constants
	LIQUIDS = LIQUIDS
}
