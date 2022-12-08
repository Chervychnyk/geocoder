defmodule Geocoder.Cache do
  use Nebulex.Cache,
    otp_app: :geocoder,
    adapter: Nebulex.Adapters.Local

  @precision Application.get_env(:geocoder, :latlng_precision, 11)

  def geocode(opts) when is_list(opts), do: opts |> Keyword.get(:address) |> geocode()

  def geocode(location) when is_binary(location) do
    location_key = encode(location)

    with latlng_key when is_binary(latlng_key) <- get(location_key),
         %Geocoder.Coords{} = coords <- get(latlng) do
      {:just, coords}
    else
      _ -> :nothing
    end
  end

  def geocode(_), do: :nothing

  def reverse_geocode(opts) when is_list(opts),
    do: opts |> Keyword.get(:latlng) |> reverse_geocode()

  def reverse_geocode({lat, lng} = latlng) do
    key = encode(latlng, @precision)

    case get(key) do
      %Geocoder.Coords{} = coords -> {:just, coords}
      _ -> :nothing
    end
  end

  def reverse_geocode(_), do: :nothing

  def store(from, %Geocoder.Coords{lat: lat, lon: lon} = coords) do
    latlng_key = encode({lat, lon}, @precision)
    
    set(latlng_key, coords)

    unless is_nil(from[:address]) do
      from[:address] |> encode() |> set(latlng_key)
    end
  end

  defp encode(location, option \\ nil)

  defp encode({lat, lon}, precision) do
    Geohash.encode(:erlang.float(lat), :erlang.float(lon), precision)
  end

  defp encode(location, _) when is_binary(location) do
    location
    |> String.downcase()
    |> String.replace(~r/[^\w]/, "")
    |> String.trim()
    |> Base.encode64()
  end
end
