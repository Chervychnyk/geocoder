use Mix.Config

config :geocoder, :worker_pool_config,
  size: 5,
  max_overflow: 2

config :geocoder, :worker, provider: Geocoder.Providers.OpenStreetMaps

config :geocoder, Geocoder.Cache,
  n_shards: 3,
  gc_interval: 3600
