local translation = require "__flib__.translation"
local Rope = require "lualib.Rope"
local SuffixTree = require "lualib.SuffixTree"

local unique_locale_key = "empty-stop-name"

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
  return global.dictionaries[name].st:segments_with_substring(needle:lower())
end

local function on_init()
  translation.init()
  --[[
    player_data = {
      [player_index] = {
        unique_locale_value = translated_string_of_unique_locale_key,
      }
    }
  --]]
  global.player_data = {}
  --[[
    locales = {
      [unique_locale_value] = {
        player_indexes = {
          [player_index] = true
        }
        suffix_tree = SuffixTree
        translations = {
          [translated_string] = localised_string (table) OR tick_requested (number),
        }
      }
    }
  --]]
  global.locales = {}
  global.dictionary_iter = nil
end

local function request_translation(player_index, localised_string)
  locale locale_id = global.player_data[player_index].unique_locale_value
end

local function on_player_created(ev)
  log("attempting to request current locale for player "..player_index)
  translation.add_requests(
    ev.player_index,
    {
      {
        dictionary = "locale_id",
        internal = "locale_id",
        localised = {unique_locale_key},
      }
    },
  )
end

local function on_load()
  for _, dictionary in pairs(global.dictionaries) do
    SuffixTree.restore(dictionary.st)
  end
end

local function update_dictionaries()
  local dictionaries = global.dictionaries
  local iter = global.dictionary_iter or next(dictionaries)
  local dictionary = dictionaries[iter]
  for i=1,50 do
    local done = dictionary.st:run_once()
    if done then
      iter, dictionary = next(dictionaries, iter)
      global.dictionary_iter = iter
      if not iter then
        return
      end
    end
  end
  global.dictionary_iter = iter
end

local function on_tick(ev)
  translation.iterate_batch(ev)
  update_dictionaries()
end

local function on_string_translated(ev)
  local translated_str = ev.result:lower()
  local sorting, translation_complete = translation.process_result(ev)
  for dictionary_name, names in pairs(sorting) do
    local dictionary = global.dictionaries[dictionary_name]
    for _, name in pairs(names) do
      local dict_names = dictionary.direct[translated_str]
      if not dict_names then
        dictionary.st.rope:append_segment(translated_str)
        dict_names = {}
        dictionary.direct[translated_str] = dict_names
      end
      dict_names[#dict_names+1] = name
    end
  end
  if translation_complete then
    for dictionary_name in pairs(sorting) do
      local dictionary = global.dictionaries[dictionary_name]
      dictionary.st.rope:compact()
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
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_string_translated, on_string_translated)
script.on_nth_tick(10, on_tick)