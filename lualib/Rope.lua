local floor = math.floor
local function binsearch(a, x)
  local left = 1
  local right = #a
  local mid = 1
  while left <= right do
    mid = floor((left + right) / 2)
    if x < a[mid] then
      right = mid - 1
    else
      left = mid + 1
    end
  end
  if mid > #a or a[mid] > x then
    mid = mid - 1
  end
  if mid < 1 then
    mid = 1
  end
  return mid
end

---@class Rope
local Rope = {}

local function seek_relative(self, offset)
  assert(self.char_pos >= 1 and self.char_pos <= self.length)
  local segment_index = self.current_segment_index
  local segment_pos = self.segment_pos + offset
  while segment_pos <= 0 do
    segment_index = segment_index - 1
    segment_pos = segment_pos + #self.segments[segment_index]
  end
  while segment_pos > #self.segments[segment_index] do
    segment_pos = segment_pos - #self.segments[segment_index]
    segment_index = segment_index + 1
  end
  self.current_segment_index = segment_index
  self.segment_pos = segment_pos
  self.char_pos = self.char_pos + offset
end

function Rope:get_length()
  return self.length
end

function Rope:seek(pos)
  seek_relative(self, pos - self.char_pos)
end

local sub = string.sub
local function word_from_index(self, word_index)
  local starts = self.starts
  local start_pos = starts[word_index]
  local end_pos = starts[word_index+1]
  return sub(self.segments[1], start_pos, end_pos and end_pos-1)
end

local function word_from_pos(self, pos)
  assert(pos >= 1 and pos <= #self.segments[1])
  local index = binsearch(self.starts, pos)
  return word_from_index(self, index)
end

local function get_current_segment(self)
  local segment_index = self.current_segment_index
  if segment_index > 1 then
    return self.segments[self.current_segment_index]
  end
  return word_from_pos(self, self.segment_pos)
end

function Rope:get_char(pos)
  if pos <= #self.segments[1] then
    return sub(self.segments[1], pos, pos)
  end
  self:seek(pos)
  local segment_pos = self.segment_pos
  return sub(get_current_segment(self), segment_pos, segment_pos)
end

function Rope:get_segment(pos)
  if pos <= #self.segments[1] then
    return word_from_pos(self, pos)
  end
  self:seek(pos)
  return get_current_segment(self)
end

function Rope:append_segment(str)
  self.segments[#self.segments+1] = str
  self.length = self.length + #str
end

function Rope:compact()
  local pos = #self.segments[1] + 1
  local starts = self.starts
  for i=2,#self.segments do
    starts[#starts+1] = pos
    pos = pos + #self.segments[i]
  end
  local merged = table.concat(self.segments)
  assert(#merged == self.length)
  self.segments = {merged}
  self.current_segment_index = 1
  self.segment_pos = self.char_pos
end

local meta = { __index = Rope }

local function restore(self)
  return setmetatable(self, meta)
end

local function new()
  local self = {
    length = 0,
    segments = {},
    starts = {1},
    char_pos = 1,
    current_segment_index = 1,
    segment_pos = 1,
  }
  return restore(self)
end

return {
    new = new,
    restore = restore,
}