
---@class Queue<T>
---@field private items table<number, T>
---@field private head number
---@field private tail number
local Queue = {}
Queue.__index = Queue

---@generic T
---@return Queue<T>
function Queue.new()
    return setmetatable({
        items = {},
        head = 1,
        tail = 0
    }, Queue)
end

---@param item T
function Queue:Push(item)
    self.tail = self.tail + 1
    self.items[self.tail] = item
end

---@return T?
function Queue:Pop()
    if self.head > self.tail then
        return nil
    end

    local item = self.items[self.head]
    self.items[self.head] = nil
    self.head = self.head + 1

    return item
end

---Removes the first occurrence of an item from the queue.
---@param item any
---@return boolean removed
function Queue:Remove(item)
    for i = self.head, self.tail do
        if self.items[i] == item then
            for j = i, self.tail - 1 do
                self.items[j] = self.items[j + 1]
            end

            self.items[self.tail] = nil
            self.tail = self.tail - 1

            if self.head > self.tail then
                self.head = 1
                self.tail = 0
                self.items = {}
            end

            return true
        end
    end

    return false
end

---@return boolean
function Queue:IsEmpty()
    return self.head > self.tail
end

---@return number
function Queue:Size()
    return self.tail - self.head + 1
end

---Removes all items from the queue.
function Queue:Clear()
    self.items = {}
    self.head = 1
    self.tail = 0
end

return Queue