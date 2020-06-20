---@class Rope
local Rope = {}

local function seek_relative(self, offset)
  self.char_pos = self.char_pos + offset
  assert(self.char_pos >= 1 and self.char_pos <= self.length)
  local current_segment = self.segments[self.current_segment_index]
  self.segment_pos = self.segment_pos + offset
  while self.segment_pos <= 0 do
    self.current_segment_index = self.current_segment_index - 1
    self.segment_pos = self.segment_pos + #self:get_current_segment()
  end
  while self.segment_pos > #self:get_current_segment() do
    self.segment_pos = self.segment_pos - #self:get_current_segment()
    self.current_segment_index = self.current_segment_index + 1
  end
end

function Rope:get_length()
  return self.length
end

function Rope:seek(pos)
  seek_relative(self, pos - self.char_pos)
end

local sub = string.sub
function Rope:get_char(pos)
  self:seek(pos)
  local segment_pos = self.segment_pos
  return sub(self:get_current_segment(), segment_pos, segment_pos)
end

function Rope:get_current_segment()
  return self.segments[self.current_segment_index]
end

function Rope:append_segment(str)
  self.segments[#self.segments+1] = str
  self.length = self.length + #str
end

local meta = { __index = Rope }

local function restore(self)
  return setmetatable(self, meta)
end

local function new()
  local self = {
    length = 0,
    segments = {},
    char_pos = 1,
    current_segment_index = 1,
    segment_pos = 1,
  }
  return restore(self)
end

return {
    new = new,
    restore = restor,
}