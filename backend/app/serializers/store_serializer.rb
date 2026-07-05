# Plain PORO serializer (no gem). See docs/API.md.
class StoreSerializer
  def initialize(store)
    @store = store
  end

  def as_json(*)
    {
      id: @store.id,
      slug: @store.slug,
      name: @store.name,
      supports_resolution: @store.adapter != "generic"
    }
  end
end
