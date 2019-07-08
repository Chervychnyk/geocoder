defmodule Geocoder.Providers.GoogleMaps do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://maps.googleapis.com")

  plug(Tesla.Middleware.Query,
    key: Application.fetch_env!(:geocoder, Geocoder.Providers.GoogleMaps)[:key]
  )

  plug(Tesla.Middleware.JSON)

  @path_geocode "/maps/api/geocode/json"
  @components [
    "locality",
    "administrative_area_level_1",
    "administrative_area_level_2",
    "country",
    "postal_code",
    "street",
    "street_number",
    "route"
  ]
  @field_mapping %{
    "country" => :country,
    "administrative_area_level_1" => :state,
    "administrative_area_level_2" => :county,
    "locality" => :city,
    "postal_code" => :postal_code,
    "route" => :street,
    "street_address" => :street,
    "street_number" => :street_number
  }

  def geocode(opts) do
    with {:ok, %Tesla.Env{status: 200, body: body}} <-
           get(@path_geocode, query: build_request_params(opts)) |> IO.inspect() do
      body |> transform_response()
    else
      _ -> :error
    end
  end

  defdelegate reverse_geocode(opts), to: __MODULE__, as: :geocode

  defp build_request_params(opts) do
    opts
    |> Keyword.take([
      :key,
      :address,
      :latlng,
      :components,
      :bounds,
      :language,
      :region,
      :place_id,
      :result_type,
      :location_type
    ])
    |> Keyword.update(:latlng, nil, fn
      {lat, lng} -> "#{lat},#{lng}"
      q -> q
    end)
    |> Keyword.delete(:latlng, nil)
  end

  def transform_response(%{"results" => [result | _], "status" => "OK"}) do
    coords = retrieve_coords(result)
    bounds = retrieve_bounds(result)
    location = retrieve_location(result)

    {:ok, %{coords | bounds: bounds, location: location}}
  end

  def transform_response(%{"results" => [], "error_message" => message})
      when is_binary(message) do
    {:error, message}
  end

  defp retrieve_location(%{
         "address_components" => components,
         "formatted_address" => formatted_address
       }) do
    components
    |> Enum.filter(fn %{"types" => [type | _]} -> type in @components end)
    |> Enum.reduce(
      %Geocoder.Location{formatted_address: formatted_address},
      fn
        %{"long_name" => long_name, "short_name" => short_name, "types" => ["country" | _]},
        acc ->
          struct(acc, country: long_name, country_code: short_name)

        %{"long_name" => long_name, "types" => [type | _]}, acc ->
          struct(acc, [{@field_mapping[type], long_name}])
      end
    )
  end

  defp retrieve_coords(%{"geometry" => %{"location" => coords}}) do
    %{"lat" => lat, "lng" => lon} = coords
    %Geocoder.Coords{lat: lat, lon: lon}
  end

  defp retrieve_bounds(%{"geometry" => %{"bounds" => bounds}}) do
    %{
      "northeast" => %{"lat" => north, "lng" => east},
      "southwest" => %{"lat" => south, "lng" => west}
    } = bounds

    %Geocoder.Bounds{top: north, right: east, bottom: south, left: west}
  end

  defp retrieve_bounds(_), do: %Geocoder.Bounds{}

  # %{
  #    "results" => [
  #      %{
  #        "address_components" => [
  #          %{
  #            "long_name" => "Toronto",
  #            "short_name" => "Toronto",
  #            "types" => ["locality", "political"]
  #          },
  #          %{
  #            "long_name" => "Toronto Division",
  #            "short_name" => "Toronto Division",
  #            "types" => ["administrative_area_level_2", "political"]
  #          },
  #          %{
  #            "long_name" => "Ontario",
  #            "short_name" => "ON",
  #            "types" => ["administrative_area_level_1", "political"]
  #          },
  #          %{
  #            "long_name" => "Canada",
  #            "short_name" => "CA",
  #            "types" => ["country", "political"]
  #          }
  #        ],
  #        "formatted_address" => "Toronto, ON, Canada",
  #        "geometry" => %{
  #          "bounds" => %{
  #            "northeast" => %{"lat" => 43.8554579, "lng" => -79.1168971},
  #            "southwest" => %{"lat" => 43.5810245, "lng" => -79.639219}
  #          },
  #          "location" => %{"lat" => 43.653226, "lng" => -79.3831843},
  #          "location_type" => "APPROXIMATE",
  #          "viewport" => %{
  #            "northeast" => %{"lat" => 43.8554579, "lng" => -79.1168971},
  #            "southwest" => %{"lat" => 43.5810245, "lng" => -79.639219}
  #          }
  #        },
  #        "place_id" => "ChIJpTvG15DL1IkRd8S0KlBVNTI",
  #        "types" => ["locality", "political"]
  #      }
  #    ],
  #    "status" => "OK"
  #  }
end
