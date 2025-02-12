require "socket"
require "json"

module PostCss
  class Socket
    class PostCssRuntimeError; end
    START_SCRIPT = File.expand_path("../../bin/command", __dir__)
    POSTCSS_SCRIPT = File.expand_path("../../bin/postcss", __dir__)

    def initialize
      start_dev_server if development?
    end

    def write(data)
      if development?
        @postcss.puts encode(data)
      else
        @compiled_css = `#{POSTCSS_SCRIPT} '#{encode(data)}'`
      end

      nil
    end

    def read
      if development?
        decode(@postcss.gets.chomp)
      else
        raise "You must call PostCss#write before calling PostCss#read" if @compiled_css.nil?

        decode(@compiled_css)
      end
    end

    private

    def encode(data)
      if development?
        "POSTCSS-START#{JSON.dump(:raw_content => data)}POSTCSS-END"
      else
        JSON.dump(:raw_content => data)
      end
    end

    def decode(data)
      JSON.parse(data)["compiled_css"]
    end

    def development?
      @env ||= Jekyll.env

      @env == "development"
    end

    def start_dev_server
      Thread.new do
        system "#{START_SCRIPT} #{POSTCSS_SCRIPT} --development"
      end

      @postcss = nil
      while @postcss.nil?
        begin
          @postcss = TCPSocket.open("localhost", 8124)
        rescue StandardError
          nil # Suppressing exceptions
        end
      end
    end
  end
end


module Core
  class PostCss
    def initialize(config = {})
      @socket = ::PostCss::Socket.new
    end

    def huzzah(content)
      @socket.write content
      @socket.read
    end
  end
end

core = Core::PostCss.new

Jekyll::Hooks.register :pages, :post_render do |page|
  if page.relative_path.end_with?('.scss')
    page.output = core.huzzah(page.output)
  end
end