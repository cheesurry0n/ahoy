module Ahoy
  class BaseStore
    attr_writer :user

    def initialize(options)
      @options = options
    end

    def track_visit(data)
    end

    def track_event(data)
    end

    def geocode(data)
    end

    def authenticate(data)
    end

    def visit
    end

    def user
      @user ||= begin
        if Ahoy.user_method.respond_to?(:call)
          Ahoy.user_method.call(controller)
        else
          controller.send(Ahoy.user_method)
        end
      end
    end

    def exclude?
      (!Ahoy.track_bots && bot?) || exclude_by_method?
    end

    def generate_id
      Ahoy.token_generator.call
    end

    protected

    def bot?
      @bot ||= request ? Browser.new(request.user_agent).bot? : false
    end

    def exclude_by_method?
      if Ahoy.exclude_method
        if Ahoy.exclude_method.arity == 1
          Ahoy.exclude_method.call(controller)
        else
          Ahoy.exclude_method.call(controller, request)
        end
      else
        false
      end
    end

    def request
      @request ||= @options[:request] || controller.try(:request)
    end

    def controller
      @controller ||= @options[:controller]
    end

    def ahoy
      @ahoy ||= @options[:ahoy]
    end
  end
end
