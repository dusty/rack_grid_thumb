require 'rack'
require 'mapel'
require 'digest/sha1'
require 'tempfile'

module Rack

  class GridThumb
    RE_TH_BASE = /_([0-9]+x|x[0-9]+|[0-9]+x[0-9]+)(-(?:nw|n|ne|w|c|e|sw|s|se))?/
    RE_TH_EXT = /(\.(?:jpg|jpeg|png|gif))/i
    TH_GRAV = {
      '-nw' => :northwest,
      '-n' => :north,
      '-ne' => :northeast,
      '-w' => :west,
      '-c' => :center,
      '-e' => :east,
      '-sw' => :southwest,
      '-s' => :south,
      '-se' => :southeast
    }

    def initialize(app, options={})
      @app = app
      @keylen = options[:keylength]
      @secret = options[:secret]
      @route  = generate_route(options[:prefix])
    end

    # Generates route given a prefixes.
    def generate_route(prefix = nil)
      if @keylen
        /^(\/#{prefix}\/\w+).*#{RE_TH_BASE}-([0-9a-f]{#{@keylen}})#{RE_TH_EXT}$/
      else
        /^(\/#{prefix}\/\w+).*#{RE_TH_BASE}#{RE_TH_EXT}$/
      end
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      response = catch(:halt) do
        throw :halt unless %w{GET HEAD}.include? env["REQUEST_METHOD"]
        @env = env
        @path = env["PATH_INFO"]
        if match = @path.match(@route)
          @source, dim, grav = extract_meta(match)
          @image = get_source_image
          @thumb = render_thumbnail(dim, grav) unless head?
          serve
        end
        nil
      end

      response || @app.call(env)
    end

    # Extracts filename and options from the path.
    def extract_meta(match)
      result = if @keylen
        extract_signed_meta(match)
      else
        extract_unsigned_meta(match)
      end

      throw :halt unless result
      result
    end

    # Extracts filename and options from a signed path.
    def extract_signed_meta(match)
      base, dim, grav, sig, ext = match.captures
      digest = Digest::SHA1.hexdigest("#{base}_#{dim}#{grav}#{ext}#{@secret}")[0..@keylen-1]
      throw(:halt, bad_request) unless sig && (sig == digest)
      [base + ext, dim, grav]
    end

    # Extracts filename and options from an unsigned path.
    def extract_unsigned_meta(match)
      base, dim, grav, ext = match.captures
      [base + ext, dim, grav]
    end

    # Fetch the source image from the downstream app, returning the downstream
    # app's response if it is not a success.
    def get_source_image
      status, headers, body = @app.call(@env.merge(
        "PATH_INFO" => @source
      ))
      unless (status >= 200 && status < 300) &&
          (headers["Content-Type"].split("/").first == "image")
        throw :halt, [status, headers, body]
      end

      @source_headers = headers

      if !head?
        if body.respond_to?(:path)
          ::File.open(body.path, 'rb')
        elsif body.respond_to?(:each)
          data = ''
          body.each { |part| data << part.to_s }
          Tempfile.new(::File.basename(@path)).tap do |f|
            f.binmode
            f.write(data)
            f.close
          end
        end
      else
        nil
      end
    end

    # Renders a thumbnail from the source image. Returns a Tempfile.
    def render_thumbnail(dim, grav)
      gravity = grav ? TH_GRAV[grav] : :center
      width, height = parse_dimensions(dim)
      origin_width, origin_height = Mapel.info(@image.path)[:dimensions]
      width = [width, origin_width].min if width
      height = [height, origin_height].min if height
      output = create_tempfile
      cmd = Mapel(@image.path).gravity(gravity)
      if width && height
        cmd.resize!(width, height)
      else
        cmd.resize(width, height, 0, 0, '>')
      end
      cmd.to(output.path).run
      output
    end

    # Serves the thumbnail. If this is a HEAD request we strip the body as well
    # as the content length because the render was never run.
    def serve
      response = if head?
        @source_headers.delete("Content-Length")
        [200, @source_headers, []]
      else
        [200, @source_headers.merge("Content-Length" => ::File.size(@thumb.path).to_s), self]
      end

      throw :halt, response
    end

    # Parses the rendering options; returns false if rendering options are invalid
    def parse_dimensions(meta)
      dimensions = meta.split('x').map do |dim|
        if dim.empty?
          nil
        elsif dim[0].to_i == 0
          throw :halt, bad_request
        else
          dim.to_i
        end
      end
      dimensions.any? ? dimensions : throw(:halt, bad_request)
    end

    # Creates a new tempfile
    def create_tempfile
      Tempfile.new(::File.basename(@path)).tap { |f| f.close }
    end

    def bad_request
      body = "Bad thumbnail parameters in #{@path}\n"
      [400, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s},
       [body]]
    end

    def head?
      @env["REQUEST_METHOD"] == "HEAD"
    end

    def each
      ::File.open(@thumb.path, "rb") { |file|
        while part = file.read(8192)
          yield part
        end
      }
    end

    def to_path
      @thumb.path
    end
  end
end