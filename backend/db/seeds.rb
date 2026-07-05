# Idempotent store seeds. Safe to run repeatedly (find_or_create_by! on slug).

Store.find_or_create_by!(slug: "walmart") do |store|
  store.name = "Walmart"
  store.domain = "walmart.com"
  store.adapter = "walmart"
  store.config = {}
end

Store.find_or_create_by!(slug: "target") do |store|
  store.name = "Target"
  store.domain = "target.com"
  store.adapter = "target"
  # redsky_key and store_id are filled in per issue #7 (grab from target.com in
  # browser devtools: the `key` query param on any redsky.target.com request, and
  # your chosen store's id). Left nil here so the adapter raises a clear config error.
  store.config = { "redsky_key" => nil, "store_id" => nil }
end

Store.find_or_create_by!(slug: "generic") do |store|
  store.name = "Other (by URL)"
  store.domain = ""
  store.adapter = "generic"
  store.config = {}
end
