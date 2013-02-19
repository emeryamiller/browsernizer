module Browsernizer
  class Router
    attr_reader :config

    def initialize(app, &block)
      @app = app
      @config = Config.new
      yield(@config)
    end

    def call(env)
      @unsupported = nil
      @env = env
      @env["browsernizer"] = {
        "supported" => true,
        "browser" => browser.name.to_s,
        "version" => browser.version.to_s,
        "os" => raw_browser.platform.to_s,
        "request_path" => @env['REQUEST_PATH']
      }
      handle_request
    end

  private
    def handle_request
      @env["browsernizer"]["supported"] = false if unsupported?

      catch(:response) do
        if !path_excluded?
          if unsupported?
            if !on_redirection_path? && @config.get_location
              throw :response, redirect_to_specified
            end
          elsif on_redirection_path?
            throw :response, redirect_to_root
          end
        end
        propagate_request
      end
    end

    def propagate_request
      @app.call(@env)
    end

    def redirect_to_specified
      [307, {"Content-Type" => "text/plain", "Location" => @config.get_location}, []]
    end

    def redirect_to_root
      [303, {"Content-Type" => "text/plain", "Location" => "/"}, []]
    end

    def path_excluded?
      @config.excluded? @env["PATH_INFO"]
    end

    def on_redirection_path?
      @config.get_location && @config.get_location == @env["PATH_INFO"]
    end

    def raw_browser
      ::Browser.new :ua => @env["HTTP_USER_AGENT"]
    end

    def browser
      Browser.new raw_browser.name.to_s, raw_browser.full_version.to_s
    end

    # supported by default
    def unsupported?
      if @unsupported == nil
        @unsupported = @config.get_supported.any? do |requirement|
          supported = if requirement.respond_to?(:call)
            requirement.call(raw_browser)
          else
            browser.meets?(requirement)
          end
          supported === false
        end
      end
      @unsupported
    end
  end

end
