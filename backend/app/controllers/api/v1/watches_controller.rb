module Api
  module V1
    class WatchesController < ApplicationController
      # GET /api/v1/watches
      def index
        watches = Watch.includes(listing: [ :product, :store ]).order(created_at: :desc)
        render json: watches.map { |watch| WatchSerializer.new(watch).as_json }
      end

      # GET /api/v1/watches/:id
      def show
        watch = Watch.find(params[:id])
        render json: WatchSerializer.new(watch, detailed: true).as_json
      end

      # POST /api/v1/watches — from a resolution (barcode) or from a URL.
      # With dry_run: true (URL mode) the adapter resolves the price and returns
      # it WITHOUT persisting — lets the app show the found price before rules
      # are chosen.
      def create
        return dry_run_url if params[:url].present? && dry_run?

        rules = rules_param
        return render_error("invalid_rules", message: "at least one rule is required", status: :unprocessable_entity) if rules.empty?

        watch =
          if params[:resolution].present?
            create_from_resolution(rules)
          elsif params[:url].present?
            create_from_url(rules)
          else
            return render_error("invalid", message: "provide either a resolution or a url", status: :unprocessable_entity)
          end

        return if performed? # a create_* helper already rendered an error

        render json: WatchSerializer.new(watch, detailed: true).as_json, status: :created
      end

      # PATCH /api/v1/watches/:id {baseline_price_cents?, active?, rules?}
      def update
        watch = Watch.find(params[:id])
        ActiveRecord::Base.transaction do
          watch.update!(watch_update_params)
          if params.key?(:rules)
            watch.alert_rules.destroy_all
            create_rules!(watch, rules_param)
          end
        end
        render json: WatchSerializer.new(watch, detailed: true).as_json
      end

      # DELETE /api/v1/watches/:id
      def destroy
        watch = Watch.find(params[:id])
        listing = watch.listing
        watch.destroy!
        listing.destroy! if listing.watches.empty?
        head :no_content
      end

      private

      def dry_run?
        ActiveModel::Type::Boolean.new.cast(params[:dry_run])
      end

      # Resolve the URL's current price without persisting anything.
      def dry_run_url
        store = Store.find(params[:store_id])
        listing = Listing.new(store: store, url: params[:url], display_name: params[:name].presence, status: "active")
        result = StoreAdapters.for(store).check(listing)
        render json: {
          dry_run: true,
          price_cents: result.price_cents,
          currency: result.currency,
          in_stock: result.in_stock
        }
      rescue StoreAdapters::CheckFailed
        render_error("parse_failed", message: "could not read a price from that URL", status: :unprocessable_entity)
      rescue Http::BlockedError => e
        render_error("blocked", message: e.message, status: :unprocessable_entity)
      end

      def create_from_resolution(rules)
        gtin13 = Gtin.normalize(params[:barcode])
        return render_error("invalid_barcode", message: "unrecognized barcode", status: :unprocessable_entity) if gtin13.nil?

        store = Store.find(params[:store_id])
        resolution = resolution_param

        Watch.transaction do
          product = Product.find_or_create_by!(gtin13: gtin13) do |p|
            p.name = resolution[:title]
            p.image_url = resolution[:image_url]
          end
          listing = upsert_listing(product: product, store: store, url: resolution[:url],
                                   store_ref: (resolution[:store_ref] || {}).to_h, currency: resolution[:currency] || "USD")
          record_initial_price(listing, resolution[:price_cents], resolution[:currency] || "USD", "resolution")
          watch = Watch.create!(listing: listing, baseline_price_cents: baseline_for(resolution[:price_cents]))
          create_rules!(watch, rules)
          watch
        end
      end

      def create_from_url(rules)
        store = Store.find(params[:store_id])
        listing = Listing.new(store: store, url: params[:url], display_name: params[:name].presence, status: "active")

        result = StoreAdapters.for(store).check(listing)
        Watch.transaction do
          listing.currency = result.currency
          listing.save!
          record_initial_price(listing, result.price_cents, result.currency, result.source, in_stock: result.in_stock)
          watch = Watch.create!(listing: listing, baseline_price_cents: baseline_for(result.price_cents))
          create_rules!(watch, rules)
          watch
        end
      rescue StoreAdapters::CheckFailed
        render_error("parse_failed", message: "could not read a price from that URL", status: :unprocessable_entity)
      rescue Http::BlockedError => e
        render_error("blocked", message: e.message, status: :unprocessable_entity)
      end

      def upsert_listing(product:, store:, url:, store_ref:, currency:)
        listing = Listing.find_or_initialize_by(product: product, store: store)
        listing.url = url
        listing.store_ref = store_ref
        listing.currency = currency
        listing.status = "active" if listing.new_record?
        listing.save!
        listing
      end

      def record_initial_price(listing, price_cents, currency, source, in_stock: true)
        return if price_cents.blank?

        listing.price_points.create!(
          price_cents: price_cents, currency: currency, in_stock: in_stock,
          checked_at: Time.current, source: source
        )
      end

      def baseline_for(price_cents)
        params[:baseline_price_cents].presence || price_cents
      end

      def create_rules!(watch, rules)
        rules.each do |rule|
          watch.alert_rules.create!(kind: rule[:kind], value_cents: rule[:value_cents], value_pct: rule[:value_pct])
        end
      end

      def rules_param
        params.permit(rules: [ :kind, :value_cents, :value_pct ]).fetch(:rules, [])
      end

      def resolution_param
        params.require(:resolution).permit(:url, :title, :image_url, :price_cents, :currency, :verified, store_ref: {})
      end

      def watch_update_params
        params.permit(:baseline_price_cents, :active)
      end
    end
  end
end
