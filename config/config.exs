use Mix.Config

config :geocoder, :worker_pool_config,
  size: 5,
  max_overflow: 2

config :geocoder, :worker, provider: Geocoder.Providers.OpenStreetMaps
