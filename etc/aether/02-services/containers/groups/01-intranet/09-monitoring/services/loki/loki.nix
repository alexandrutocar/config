_: {
  services.loki = {
    enable = true;

    configuration = {
      auth_enabled = false;

      server = {
        http_listen_port = 3100;
        grpc_listen_port = 9096;
        log_level = "warn";
        http_server_read_timeout = "60s"; # Default 30s
        http_server_write_timeout = "60s"; # Default 30s
        http_server_idle_timeout = "3m"; # Default 2m
        grpc_server_max_recv_msg_size = 20971520; # 20MiB - Default 4MiB
        grpc_server_max_send_msg_size = 20971520; # 20MiB - Default 4MiB
      };

      common = {
        instance_addr = "0.0.0.0";
        path_prefix = "/tmp/loki";
        storage.filesystem = {
          chunks_directory = "/tmp/loki/chunks";
          rules_directory = "/tmp/loki/rules";
        };

        replication_factor = 1;
        ring.kvstore.store = "inmemory";
      };

      query_range.results_cache.cache.embedded_cache = {
        enabled = true;
        max_size_mb = 100;
      };

      schema_config.configs = [
        {
          from = "2020-10-24";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      ruler.alertmanager_url = "http://localhost:9093";

      analytics.reporting_enabled = false;

      frontend = {
        encoding = "protobuf";
        address = "127.0.0.1";
        max_outstanding_per_tenant = 2048;
      };

      limits_config = {
        discover_service_name = [];
        discover_log_levels = false;
        max_query_series = 100000;
        max_entries_limit_per_query = 100000;
        query_timeout = "3m";
        split_queries_by_interval = 0;
      };

      chunk_store_config.chunk_cache_config.embedded_cache.enabled = false;
    };
  };
}
