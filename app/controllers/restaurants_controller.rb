require 'geokit'

class RestaurantsController < ApplicationController
  include Geokit::Geocoders
  before_action :set_restaurant, only: [:show, :update, :destroy]

  # GET /restaurants
  def index
    @restaurants = Restaurant.includes({coupons: :tags}).all.reverse
    @restaurants = @restaurants.map { |r| AdminRestaurantSerializer.new(r) } 
    # @found = [];
    # @restaurants.each do |restaurant|
    #   couponsJSON = []
    #   couponsJSON = Coupon.where(restaurant_id: restaurant.id)
    #   findRestaurant = Restaurant.where(id: restaurant.id).first
    #   findRestaurant.couponsJSON = couponsJSON
    #   @found.push(findRestaurant)
    # end
    render json: @restaurants
    # , serializer: AdminRestaurantSerializer
  end

  # GET /restaurants/1
  def show
    @meetup_params = meetup_params(@restaurant)
    @meets = meetup_api(@meetup_params)
    @restaurant.meetups = @meets
    @couponsJSON = Coupon.where(restaurant_id: @restaurant.id)
    # @couponsJSON.sort_by {|a| a.created_at}
    @restaurant.couponsJSON = @couponsJSON
    # byebug
    render json: @restaurant
  end

  # POST /restaurants
  def create
    parsed = JSON.parse(request.raw_post)
    params = {
      email: parsed['email'],
      password: parsed['password'],
    }
    puts params

    if @restaurant = Restaurant.authenticate_with_credentials(params[:email], params[:password])

      render json: @restaurant, status: :created
    else
      render json: {error:'Change your email or check you password'}
    end

  end

  # PATCH/PUT /restaurants/id
  def update
    if @restaurant.update(restaurant_params)
      render json: @restaurant
    else
      render json: @restaurant.errors, status: :unprocessable_entity
    end
  end

  # DELETE /restaurants/1
  def destroy
    @restaurant.destroy
  end

  def charge
   puts "charge begin"
    charge = JSON.parse(request.body.read)
    amount = (charge["amount"].to_i) * 100
    token = charge["token"]["id"]
    restId = charge["restid"]

    puts "#{charge["restid"]} rest ID"
    begin
      charge = Stripe::Charge.create(
        :amount      => amount,
        :description => 'Lagni App reload',
        :currency    => 'cad',
        :source  => token
      )
      # Charge went through
      add_charge(restId, amount/100)
      render json: {status: "ok", message: "Charge when through", amount: amount}, status: :ok
    rescue Stripe::CardError => e
      flash[:error] = e.message
      redirect_to :root
      render json: {status: "error", message: "Charge Not Completed"}, status: :bad_request
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.

    def add_charge(id, amount)
      restaurant = Restaurant.find(id)
      restaurant.balance += amount

      if restaurant.update_attribute('balance', restaurant.balance)
        puts "#{amount} added to restaurant"
      else
        puts "error"
      end
    end

    def set_restaurant
      @restaurant = Restaurant.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def restaurant_params
      params.permit(
        :name,
        :username,
        :email,
        :password,
        :phone,
        :address,
        :balance,
        :longitude,
        :latitude
        )
    end

    def get_lat_lng(restaurant)
        coords = GoogleGeocoder.geocode(restaurant.address)
        @restaurant.longitude = coords.lng
        @restaurant.latitude = coords.lat
    end

    def meetup_params(restaurant)
      meetup_params = {
        lon: restaurant.longitude,
        lat: restaurant.latitude,
        radius: 2,
        status: 'upcoming',
        format: 'json',
        page: '500'
      }
    end

    def meetup_api(meetup_params)
      i = 0
      meetups_arr = []
      @events = MeetupApi.new.open_events(meetup_params)
      while (i < 50) do
        if @events["results"][i] == nil
          return meetups_arr
        end
        if
          @events["results"][i]["yes_rsvp_count"] > 30 &&
          @events["results"][i]["name"] != @events["results"][i-1]["name"]

          meetups_arr.push({
            name: @events["results"][i]["name"],
            ppl_yes: @events["results"][i]["yes_rsvp_count"],
            distance: @events["results"][i]["distance"] * 100,
            date: time_zone(@events["results"][i]["time"]),
            event_url: @events["results"][i]["event_url"]
          })
        end

        i = i + 1
      end
      return meetups_arr
    end

    def time_zone(date)
      Time.zone = 'Eastern Time (US & Canada)'
      Time.zone.at(date / 1000).strftime("%B %e, %Y at %I:%M %p")
    end
end
