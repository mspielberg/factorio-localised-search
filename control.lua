local translation = require "__flib__.translation"
local Rope = require "lualib.Rope"
local SuffixTree = require "lualib.SuffixTree"

local create_dictionary = function(name)
  global.dictionaries[name] = {
    st = SuffixTree.new(Rope.new()),
    direct = {},
  }
end

local add_to_dictionary = function(name, str)
  local rope = global.dictionaries[name].rope
  rope:add_segment(str)
  rope:add_segment("\0")
end

local search_dictionary = function(name, needle)
  return global.dictionaries[name]:segments_with_substring(needle)
end

local function on_init()
  translation.init()
  global.dictionaries = {}
  global.dictionary_iter = nil

  create_dictionary("items")
  local requests = {}
  for _, prototype in pairs(game.item_prototypes) do
    requests[#requests+1] = {
      dictionary = "items",
      internal = prototype.name,
      localised = prototype.localised_name,
    }
  end
  translation.add_requests(next(game.players), requests)
end

local function on_load()
  for _, dictionary in pairs(global.dictionaries) do
    SuffixTree.restore(dictionary.st)
  end
end

local function update_dictionaries()
  local iter = global.dictionary_iter
  if not global.dictionaries[iter] then
    iter = false
  end
  local new_iter, dictionary = next(global.dictionaries, iter)
  global.dictionary_iter = new_iter
  dictionary.st:run_once()
end

local function on_tick(ev)
  translation.iterate_batch(ev)
  update_dictionaries()
end

local function on_string_translated(ev)
  local result = translation.process_result(ev)
  for dictionary_name, names in pairs(result) do
    local dictionary = global.dictionaries[dictionary_name]
    for name in pairs(names) do
      local names = dictionary.direct[ev.translated] or {}
      if not names then
        dictionary.st.rope:add_segment(ev.translated)
        names = {}
        dictionary.direct[ev.translated] = names
      end
      names[#names+1] = name
    end
  end
end

remote.add_interface("localised-search-helper", {
  create_dictionary = create_dictionary,
  add_to_dictionary = add_to_dictionary,
  search_dictionary = search_dictionary,
})

script.on_init(on_init)
script.on_load(on_load)
script.on_tick(on_tick)
script.on_event(defines.events.on_string_translated, on_string_translated)