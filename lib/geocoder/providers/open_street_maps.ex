defmodule Geocoder.Providers.OpenStreetMaps do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://nominatim.openstreetmap.org/")

  plug(Tesla.Middleware.Headers, [
    {"user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3)"}
  ])

  plug(Tesla.Middleware.JSON)

  @default_params [format: "json", "accept-language": "en", addressdetails: 1]
  @field_mapping %{
    "house_number" => :street_number,
    "county" => :county,
    "city" => :city,
    "road" => :street,
    "state" => :state,
    "postcode" => :postal_code,
    "country" => :country
  }

  @path_search "/search"
  @path_reverse "/reverse"

  def geocode(opts) do
    with {:ok, %Tesla.Env{status: 200, body: body}} <-
           get(@path_search, query: build_request_params(opts)) do
      body |> transform_response()
    else
      _ -> :error
    end
  end

  def reverse_geocode(opts) do
    with {:ok, %Tesla.Env{status: 200, body: body}} <-
           get(@path_reverse, query: build_request_params(opts)) do
      body |> transform_response()
    else
      _ -> :error
    end
  end

  defp build_request_params(opts, params \\ @default_params)
  defp build_request_params([], params), do: params

  defp build_request_params([{:address, address} | opts], params) when is_list(params) do
    opts |> build_request_params([{:q, address} | params])
  end

  defp build_request_params([{:latlng, {lat, lon}} | opts], params) when is_list(params) do
    opts |> build_request_params([{:q, "#{lat},#{lon}"}, {:lat, lat}, {:lon, lon} | params])
  end

  defp build_request_params([_ | opts], params), do: opts |> build_request_params(params)

  defp transform_response([]), do: :error

  defp transform_response([first_match | _]), do: transform_response(first_match)

  defp transform_response(%{} = response) do
    coords = retrieve_coords(response)
    location = retrieve_location(response)
    bounds = retrieve_bounds(response)

    {:ok, %{coords | location: location, bounds: bounds}}
  end

  defp retrieve_coords(%{"lat" => lat, "lon" => lon}) do
    [lat, lon] = [lat, lon] |> Enum.map(&String.to_float(&1))
    %Geocoder.Coords{lat: lat, lon: lon}
  end

  defp retrieve_coords(_), do: %Geocoder.Coords{}

  defp retrieve_bounds(%{"boundingbox" => bbox}) do
    [north, south, west, east] = bbox |> Enum.map(&String.to_float(&1))
    %Geocoder.Bounds{top: north, right: east, bottom: south, left: west}
  end

  defp retrieve_bounds(_), do: %Geocoder.Bounds{}

  defp retrieve_location(
         %{
           "address" => address
         } = response
       ) do
    address
    |> Enum.reduce(
      %Geocoder.Location{
        country_code: address["country_code"],
        formatted_address: response["display_name"]
      },
      fn {field, value}, location ->
        if Map.has_key?(@field_mapping, field),
          do: location |> struct([{@field_mapping[field], value}]),
          else: location
      end
    )
  end

  # %{"address" =>
  #      %{"city" => "Ghent", "city_district" => "Wondelgem", "country" => "Belgium",
  #        "country_code" => "be", "county" => "Gent", "postcode" => "9032",
  #        "road" => "Dikkelindestraat", "state" => "Flanders"},
  #   "boundingbox" => ["51.075731", "51.0786674", "3.7063849", "3.7083991"],
  #   "display_name" => "Dikkelindestraat, Wondelgem, Ghent, Gent, East Flanders, Flanders, 9032, Belgium",
  #   "lat" => "51.0772661",
  #   "licence" => "Data © OpenStreetMap contributors, ODbL 1.0. http://www.openstreetmap.org/copyright",
  #   "lon" => "3.7074267",
  #   "osm_id" => "45352282", "osm_type" => "way", "place_id" => "70350383"}
end
