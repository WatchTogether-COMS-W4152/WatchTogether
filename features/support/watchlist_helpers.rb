module WatchlistHelpers
  def watchlist_path(group_name)
    "#{group_path(group_name)}/watchlist_items"
  end

  def watchlist_ids
    @watchlist_ids ||= {}
  end

  def remember_watchlist_item(title, group_name)
    item = WatchlistItem.find_by(group_id: group_id(group_name), title: title)
    watchlist_ids[[ group_name, title ]] = item.id if item
  end

  def watchlist_item_id(title, group_name)
    watchlist_ids.fetch([ group_name, title ])
  end

  def expect_watchlist_page(group_name)
    expect(@response.status).to eq(200)
    expect(@page.fetch("component")).to eq("watchlist_items/index")
    expect(props.fetch("group").fetch("id")).to eq(group_id(group_name))
  end
end

World(WatchlistHelpers)
