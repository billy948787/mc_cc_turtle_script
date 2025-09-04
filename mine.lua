-- a program that receive a size of tunnel and dig it
-- example mine(5) means dig a tunnel with 5x5
-- it will automatically dig the tunnel in a square shape
-- and refuel when needed
local function refuel()
    local prev = turtle.getSelectedSlot()
    if turtle.getFuelLevel() < TargetFuelLevel then
        -- found fuel slots
        local slots = {}
        for i = 1, 16 do
            turtle.select(i)
            -- first check if the item is a fuel
            if turtle.refuel(0) then
                table.insert(slots, i)
            end
        end

        while turtle.getFuelLevel() < TargetFuelLevel do
            if #slots == 0 then
                print("No more fuel to refuel")
                turtle.select(prev)
                return false -- No fuel left, return false
            end
            turtle.select(slots[1])
            if turtle.getItemCount(slots[1]) > 0  and turtle.refuel(0) then
                turtle.refuel(1)
            else
                -- This stack is empty, remove it and try the next one
                table.remove(slots, 1)
            end
        end
    end

    turtle.select(prev)
    return true -- Fuel is sufficient
end

local blockKnowledge = {}

local function findEmptySlot()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return i
        end
    end
    return nil
end

local function isValuableOrLearnBlock(blockData)
    if not blockData or not blockData.name then
        return false -- Can't process without a name.
    end

    local blockName = blockData.name

    -- 1. Check the knowledge base first for a quick answer.
    if blockKnowledge[blockName] ~= nil then
        return blockKnowledge[blockName]
    end

    -- 2. If unknown, perform the expensive tag check ONCE.
    local isOre = false
    if blockData.tags then
        for tagName, _ in pairs(blockData.tags) do
            if string.find(tagName, "c:ores") then
                isOre = true
                break -- Found an ore tag, no need to check further.
            end
        end
    end

    -- 3. Save the knowledge for next time.
    if isOre then
        print("Learned: " .. blockName .. " is valuable.")
        blockKnowledge[blockName] = true
    else
        -- Also cache that it's NOT valuable to avoid re-checking common blocks like stone.
        blockKnowledge[blockName] = false
    end

    return isOre
end

local function whileDigging(detectFunc, digFunc, inspectFunc)
    while detectFunc() do
        local success, data = inspectFunc()
        local digResult = false
        -- Use the new learning function for the check
        if success and not isValuableOrLearnBlock(data) then
            -- It's a worthless block, dig and drop it
            local emptySlot = findEmptySlot()
            if not emptySlot then
                -- Inventory is full, can't dig-and-drop.
                digResult =  digFunc()
            else
                local prevSlot = turtle.getSelectedSlot()
                turtle.select(emptySlot)
                digResult = digFunc()     -- Digs the block into the empty slot
                turtle.drop() -- Drops the newly acquired item
                turtle.select(prevSlot)
            end
        else
            -- It's a valuable block (or inspection failed), dig it normally
            digResult = digFunc()
        end
        
        if not digResult then
            print("Failed to dig block, retrying...")
            break
        end
    end
end

local function mine(size)
    local prevFuelLevel = turtle.getFuelLevel()
    -- first dig front block
    whileDigging(turtle.detect, turtle.dig, turtle.inspect)
    -- then forward
    turtle.forward()
    for i = 1, size do
        local turn = (i % 2 == 1) and turtle.turnRight or turtle.turnLeft
        local reverseTurn = (i % 2 == 1) and turtle.turnLeft or turtle.turnRight
        turn()
        for j = 2, size do
            whileDigging(turtle.detect, turtle.dig, turtle.inspect)
            if j <= size then
                turtle.forward()
            end
        end
        if i < size then
            whileDigging(turtle.detectUp, turtle.digUp, turtle.inspectUp)
            turtle.up()
            reverseTurn()
        end
    end

    local finalTurn = (size % 2 == 1) and turtle.turnLeft or turtle.turnRight
    local finalReverseTurn = (size % 2 == 1) and turtle.turnRight or turtle.turnLeft

    finalTurn()
    finalTurn()

    for i = 1, size - 1 do
        if size % 2 == 1 then
            turtle.forward()
        end
        turtle.down()
    end

    finalReverseTurn()

    return prevFuelLevel - turtle.getFuelLevel()
end
local function compactInventory()
    local prev = turtle.getSelectedSlot()
    for i = 1, 16 do
        local di = turtle.getItemDetail(i, true)
        if di then
            for j = i + 1, 16 do
                local dj = turtle.getItemDetail(j, true)
                if dj and dj.name == di.name and (not di.nbt and not dj.nbt) then
                    turtle.select(j)
                    turtle.transferTo(i)
                end
            end
        end
    end
    turtle.select(prev)
end

local function checkIfAllSlotFull()
    -- compactInventory()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end


local function dropItem()
    local prev = turtle.getSelectedSlot()
    local fuelCount = 0
    local lastFuelSlot = 0
    for i = 1, 16 do
        turtle.select(i)
        if turtle.refuel(0) and fuelCount < 2 then
            fuelCount = fuelCount + 1
            lastFuelSlot = i
        else
            turtle.drop()
        end
    end
    
    
    turtle.select(prev)
end

local function backToStart()
    if peripheral.isPresent("front") and peripheral.hasType("front", "inventory") then
        print("Found inventory in front, dropping items")
        dropItem()
        -- rotate back
        turtle.turnLeft()
        turtle.turnLeft()
        IsReturning = false
    else
        turtle.forward()
    end
end

-- get user input for tunnel size
print("Enter tunnel size:")
local size = tonumber(read())


IsReturning = false
-- give a start level but it will change overtime
TargetFuelLevel = (size * size * 2) + (size * 4) + 50
-- main loop
while true do 
    if not refuel(size) and not IsReturning  then 
        print("Out of fuel, returning to start")
        -- let turtle rotate
        turtle.turnLeft()
        turtle.turnLeft()
        IsReturning = true
    end


    if  not IsReturning and checkIfAllSlotFull()  then
        print("All slots are full")
        -- let turtle rotate
        turtle.turnLeft()
        turtle.turnLeft()
        IsReturning = true
    end
    
    if IsReturning then
        backToStart()
    else
        if turtle.detect() then 
            local usedFuelInMine = mine(size)
            if(usedFuelInMine > TargetFuelLevel) then
                TargetFuelLevel = usedFuelInMine * 2
                print("New target fuel level: " .. TargetFuelLevel)
            end
        else
            turtle.forward()
        end
    end
end
