local function update_window(player, status)
  local screen = player.gui.screen
  local frame = screen["localised-search-progress"]
  if not frame then
    frame = screen.add{
      type = "frame",
      name="localised-search-progress",
      caption = "localised-search-progress",
      direction = "vertical",
    }
    frame.style.horizontal_align = "right"
    frame.style.width = 120
  end

  frame.clear()
  for _, entry in pairs(status) do
    frame.add{type="label", caption=entry}
  end
end

local function update()
  local status = {}
  for _, locale in pairs(global.locales) do
    local current = locale.suffix_tree.i
    local total = locale.suffix_tree.rope:get_length()
    if current < total then
      status[#status+1] = current.." / "..total
    end
  end
  for _, player in pairs(game.connected_players) do
    local gui_enabled =
      settings.get_player_settings(player)["localised-search-show-progress"].value and
      next(status) ~= nil
    if gui_enabled then
      update_window(player, status)
    else
      local frame = player.gui.screen["localised-search-progress"]
      if frame then
        frame.destroy()
      end
    end
  end
end

return {
  update = update
}