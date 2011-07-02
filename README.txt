Rack::GridThumb

  Rack::GridThumb is used to dynamically create thumbnails when in front of rack_grid.
  You should run Rack::GridThumb behind a cache such as Varnish or Rack::Cache

Installation

  # gem install rack_grid_thumb

Usage Example with Sinatra.

  # app.rb
  require 'rack_grid'
  require 'rack_grid_thumb'

  configure do
    use Rack::GridThumb, :prefix => 'grid'
    use Rack::Grid, :prefix => 'grid'
  end

  # view.erb
  <img src="/grid/4ba69fde8c8f369a6e000003_50x50.jpg" alt="My Image" />

Usage

  /#{prefix}/#{uid}_50x50.jpg     # => Crop and resize to 50x50
  /#{prefix}/#{uid}_50x50-nw.jpg  # => Crop and resize with northwest gravity
  /#{prefix}/#{uid}_50x.jpg       # => Resize to a width of 50, preserving AR
  /#{prefix}/#{uid}_x50.jpg       # => Resize to a height of 50, preserving AR


  To prevent pesky end-users and bots from flooding your application with
  render requests you can set up Rack::Thumb to check for an SHA-1 signature
  that is unique to every url. Using this option, only thumbnails requested
  by your templates will be valid. Example:

  use Rack::Thumb, {
  :secret => "My secret",
  :keylength => "16"        # => Only use 16 digits of the SHA-1 key
  }

  You can then use your +secret+ to generate secure links in your templates:

  /#{prefix}/#{uid}_50x100-sw-a267c193a7eff046.jpg  # => Successful
  /#{prefix}/#{uid}_120x250-a267c193a7eff046.jpg    # => Returns a bad request error


Inspired by:
  https://github.com/akdubya/rack-thumb
