defmodule Geocoder.Providers.OpenCageData do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://maps.googleapis.com")

  plug(Tesla.Middleware.Query,
    key: Application.fetch_env!(:geocoder, Geocoder.Providers.OpenCageData)[:key],
    pretty: 1
  )

  plug(Tesla.Middleware.JSON)

  @path_geocode "/geocode/v1/json"
  @field_mapping %{
    "house_number" => :street_number,
    "road" => :street,
    "city" => :city,
    "state" => :state,
    "county" => :county,
    "postcode" => :postal_code,
    "country" => :country,
    "country_code" => :country_code
  }

  def geocode(opts) do
    with {:ok, %Tesla.Env{status: 200, body: body}} <-
           get(@path_geocode, query: build_request_params(opts)) do
      body |> transform_response()
    else
      _ -> :error
    end
  end

  defdelegate reverse_geocode(opts), to: __MODULE__, as: :geocode

  defp build_request_params(opts) do
    opts
    |> Keyword.take([
      :bounds,
      :language,
      :add_request,
      :countrycode,
      :jsonp,
      :limit,
      :min_confidence,
      :no_annotations,
      :no_dedupe
    ])
    |> Keyword.put(
      :q,
      case opts |> Keyword.take([:address, :latlng]) |> Keyword.values() do
        [{lat, lon}] -> "#{lat},#{lon}"
        [query] -> query
        _ -> nil
      end
    )
  end

  def transform_response(%{"results" => [result | _]}) do
    coords = retrieve_coords(result)
    bounds = retrieve_bounds(result)
    location = retrieve_location(result)

    {:ok, %{coords | bounds: bounds, location: location}}
  end

  defp retrieve_coords(%{
         "geometry" => %{
           "lat" => lat,
           "lng" => lon
         }
       }) do
    %Geocoder.Coords{lat: lat, lon: lon}
  end

  defp retrieve_location(%{"components" => components, "formatted" => formatted_address}) do
    components
    |> Enum.reduce(
      %Geocoder.Location{formatted_address: formatted_address},
      fn {type, value}, acc ->
        struct(acc, [{@field_mapping[type], value}])
      end
    )
  end

  defp retrieve_bounds(%{
         "bounds" => %{
           "northeast" => %{
             "lat" => north,
             "lng" => east
           },
           "southwest" => %{
             "lat" => south,
             "lng" => west
           }
         }
       }) do
    %Geocoder.Bounds{top: north, right: east, bottom: south, left: west}
  end

  defp retrieve_bounds(_), do: %Geocoder.Bounds{}
end
