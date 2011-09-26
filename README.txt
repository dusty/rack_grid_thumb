Rack::GridThumb

  Rack::GridThumb is used to dynamically create thumbnails when in front of rack_grid.
  You should run Rack::GridThumb behind a cache such as Varnish or Rack::Cache

Installation

  # gem install rack_grid_thumb

Usage Example with Sinatra.

  # app.rb
  require 'rack/cache'
  require 'rack_grid'
  require 'rack_grid_thumb'

  use Rack::Cache, {
    :verbose     => true,
    :metastore   => 'file:/var/cache/rack/meta',
    :entitystore => 'file:/var/cache/rack/body'
  }

  use Rack::GridThumb, :prefix => 'grid'

  use Rack::Grid, {
    :prefix => 'grid',
    :host => Settings['mongo_host'],
    :port => Settings['mongo_port'],
    :username => Settings['mongo_username'],
    :password => Settings['mongo_password'],
    :database => Settings['mongo_database'],
    :cache_control => {
      :public => true,
      :max_age => 1800
    }
  }

  get '/' do
    # ...
  end

  # view.erb
  <img src="/grid/4ba69fde8c8f369a6e000003/myimage_50x50.jpg" alt="My Image" />

Usage

  /#{prefix}/#{uid}/myimage_50x50.jpg     # => Crop and resize to 50x50
  /#{prefix}/#{uid}/myimage_50x50-nw.jpg  # => Crop and resize with northwest gravity
  /#{prefix}/#{uid}/myimage_50x.jpg       # => Resize to a width of 50, preserving AR
  /#{prefix}/#{uid}/myimage_x50.jpg       # => Resize to a height of 50, preserving AR

  To prevent pesky end-users and bots from flooding your application with
  render requests you can set up Rack::Thumb to check for an SHA-1 signature
  that is unique to every url. Using this option, only thumbnails requested
  by your templates will be valid. Example:

  use Rack::Thumb, {
  :secret => "My secret",
  :keylength => "16"        # => Only use 16 digits of the SHA-1 key
  }

  You can then use your +secret+ to generate secure links in your templates:

  /#{prefix}/#{uid}/myimage_50x100-sw-a267c193a7eff046.jpg  # => Successful
  /#{prefix}/#{uid}/myimage_120x250-a267c193a7eff046.jpg    # => Returns a bad request error


Inspired by:
  https://github.com/akdubya/rack-thumb

Notes:
  Rack-Cache is a good choice for caching thumbnails so they don't have to be regenerated
  ofted.  Simply include rack-cache on the top of your app:

  use Rack::Cache, {
    :verbose     => true,
    :metastore   => 'file:/var/cache/rack/meta',
    :entitystore => 'file:/var/cache/rack/body'
  }

  Nginx also provides caching, which is a good choice if you already have nginx in front
  of your backend servers.  Below are some examples.

  Main nginx.conf http section

  http {
    log_format cache '$upstream_cache_status: "$request" ($status)';
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=main:10m max_size=1g inactive=30m;
    proxy_set_header  X-Real-IP  $remote_addr;
    proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_max_temp_file_size 0;
    proxy_cache_key "$scheme://$host$request_uri";
    proxy_cache_valid 200 302 10m;
    proxy_cache_valid 404 1m;
    ....
  }

  Your virtual host configuration

  upstream myapp {
    server 10.10.10.10:5200 fail_timeout=0;
    server 10.10.10.11:5200 fail_timeout=0;
  }

  server {
    listen 80;
    server_name www.myapp.com myapp.com;
    root /var/www/myapp/public;
    access_log /var/log/nginx/myapp.access.log;
    access_log /var/log/nginx/myapp.cache.log cache;

    ## Cache anything sent to /grid
    location /grid {
      proxy_cache main;
      proxy_cache_valid 30m;
      proxy_pass http://myapp;
      break;
    }

    ## Cache other static files
    location ~* ^.+.(jpg|jpeg|gif|png|ico|css|js)$ {
      proxy_cache main;
      proxy_cache_valid 30m;
      proxy_pass http://myapp;
      break;
    }

    ## Pass the rest to your app
    location / {
      proxy_pass http://myapp;
      break;
    }

  }