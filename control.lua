local gui = require "gui"
local translation = require "__flib__.translation"
local SuffixTree = require "lualib.textindex.SuffixTree"

local unique_locale_key = "empty-stop-name"
local update_interval = 10

local function add_all_prototype_names()
  for _, prototype_type in pairs{"entity", "fluid", "item", "recipe", "technology"} do
    local requests = {}
    global.requested_translations[prototype_type] = requests
    local prototypes = game[prototype_type.."_prototypes"]
    for name, prototype in pairs(prototypes) do
      requests[prototype_type.."/"..name] = prototype.localised_name
    end
  end
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
      translating_player_index = player_index or nil,
      [unique_locale_value] = {
        suffix_tree = SuffixTree,
        translations = {
          [dictionary_name] = {
            [translated_string] = internal_name,
          }
        },
      }
    }
  --]]
  global.locales = {}
  --[[
    requested_translations = {
      [dictionary_name] = {
        [internal_name] = localised_string
      }
    }
  --]]
  global.requested_translations = {}
  add_all_prototype_names()
end

local on_tick
local function on_player_joined_game(ev)
  log("requesting current locale for player "..ev.player_index)
  global.player_data[ev.player_index] = {}
  translation.add_requests(
    ev.player_index,
    {
      {
        dictionary = "locale_id",
        internal = "locale_id",
        localised = {unique_locale_key},
      }
    }
  )
  script.on_nth_tick(update_interval, on_tick)
end

local function on_load()
  for _, dictionary in pairs(global.dictionaries) do
    SuffixTree.restore(dictionary.st)
  end
end

local function request_translations_from_player(player_index)
  local translation_requests = {}
  for dictionary_name, requests in pairs(global.requested_translations) do
    for internal, localised in pairs(requests) do
      translation_requests[#translation_requests+1] = {
        dictionary = dictionary_name,
        internal = internal,
        localised = localised,
      }
    end
  end
  translation.add_requests(player_index, translation_requests)
  global.locales[global.player_data[player_index].unique_locale_value].translating_player_index = player_index
end


local function setup_locale(player_index, locale_id)
  global.locales[locale_id] = {
    translating_player_index = player_index,
    suffix_tree = SuffixTree.new(),
    translations = {},
  }
  request_translations_from_player(player_index)
end

local function find_player_with_locale(locale_id)
  for _, player in pairs(game.connected_players) do
    local locale = global.player_data[player.index].unique_locale_value
    if locale == locale_id then
      return player.index
    end
  end
end

local function on_player_left_game(ev)
  local player_data = global.player_data[ev.player_index]
  local locale_id = player_data.unique_locale_value
  local player_locale = locale_id and global.locales[locale_id]
  if player_locale and player_locale.translating_player_index == ev.player_index then
    local new_player_index = find_player_with_locale(locale_id)
    request_translations_from_player(new_player_index)
  end
  global.player_data[ev.player_index] = nil
end

local iteration_limit = 250
local function update_dictionaries()
  local iterations = 0
  for _, locale_data in pairs(global.locales) do
    local locale_done = false
    while not locale_done and iterations < iteration_limit do
      locale_done = locale_data.suffix_tree:run_once()
      iterations = iterations + 1
    end
  end
  return iterations < iteration_limit
end

local function are_translations_complete()
  if global.__flib.translation.translating_players_count > 0 then return false end
  for _, locale in pairs(global.locales) do
    if locale.translating_player_index then
      return false
    end
    if locale.suffix_tree.rope:get_length() > locale.suffix_tree.i then
      return false
    end
  end
  return true
end

on_tick = function (ev)
  translation.iterate_batch(ev)
  update_dictionaries()
  gui.update()
  if are_translations_complete() then
    script.on_nth_tick(update_interval, nil)
  end
end

local function on_string_translated(ev)
  local sorting, translation_complete = translation.process_result(ev)
  if not sorting then return end
  if sorting.locale_id then
    global.player_data[ev.player_index].unique_locale_value = ev.result
    if not global.locales[sorting.locale_id] then
      setup_locale(ev.player_index, ev.result)
    end
  end

  local locale_id = global.player_data[ev.player_index].unique_locale_value
  local locale_data = global.locales[locale_id]
  local translated_str = ev.result:lower()

  for dictionary_name, names in pairs(sorting) do
    local dictionary = locale_data.translations[dictionary_name]
    if not dictionary then
      dictionary = {}
      locale_data.translations[dictionary_name] = dictionary
    end

    for _, name in pairs(names) do
      local dict_names = dictionary[translated_str]
      if not dict_names then
        locale_data.suffix_tree.rope:append_segment(translated_str)
        dict_names = {}
        dictionary[translated_str] = dict_names
      end
      dict_names[#dict_names+1] = name
    end
  end

  if translation_complete then
    locale_data.translating_player_index = nil
    locale_data.suffix_tree.rope:compact()
  end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_event(defines.events.on_player_joined_game, on_player_joined_game)
script.on_event(defines.events.on_player_left_game, on_player_left_game)
script.on_event(defines.events.on_string_translated, on_string_translated)

local function get_status(player_index)
  local locale_id = global.player_data[player_index].unique_locale_value
  if not locale_id then return false end
  local locale = global.locales[locale_id]
  local total = locale.suffix_tree.rope:get_length()
  local current = locale.suffix_tree.i
  return current >= total, current, total
end

local function request_translation(dictionary, internal_name, localised_string)
  local requested = global.requested_translations
  local requests = requested[dictionary]
  if not requests then
    requests = {}
    requested[dictionary] = requests
  end
  requests[internal_name] = localised_string
end

local function search_dictionary(player_index, dictionary_name, needle)
  local locale_id = global.player_data[player_index].unique_locale_value
  if not locale_id then return nil end
  local locale_data = global.locales[locale_id]
  local matches = locale_data.suffix_tree:segments_with_substring(needle:lower())
  local translations = locale_data.translations[dictionary_name]
  if not translations then return {} end

  local out = {}
  for match in pairs(matches) do
    out[#out+1] = translations[match]
  end
  return out
end

remote.add_interface("localised-search", {
  request_translation = request_translation,
  get_status = get_status,
  search_dictionary = search_dictionary,
})