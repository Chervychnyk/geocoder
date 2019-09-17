defmodule Geocoder.Cache do
  use Nebulex.Cache,
    otp_app: :geocoder,
    adapter: Nebulex.Adapters.Local

  @precision Application.get_env(:geocoder, :latlng_precision, 11)

  def geocode(opts) when is_list(opts) do
    opts |> Keyword.get(:address) |> geocode()
  end

  def geocode(location) when is_binary(location) do
    link = encode(location)

    with key when is_binary(key) <- get(link),
         %Geocoder.Coords{} = coords <- get(key) do
      {:just, coords}
    else
      _ -> :nothing
    end
  end

  def link(from, %Geocoder.Coords{lat: lat, lon: lon} = coords) do
    key = encode({lat, lon}, @precision)
    link = encode(from[:address] || from[:latlng], @precision)

    link |> set(key) |> set(coords)
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
