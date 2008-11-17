module RequestId
  def self.included(base)
    instance_methods = rails2x? ? Rails2x : Rails1x
    base.class_eval do
      cattr_accessor :max_request_id
      cattr_accessor :request_id_with_port
      self.request_id_with_port = true
      include instance_methods
    end
  end

  def self.rails2x?
    ActionController::Base.private_instance_methods.include?("log_processing_for_request_id")
  end

  def request_id
    @request_id ||= new_request_id
  end

  private
    def new_request_id
      id = self.class.max_request_id = self.class.max_request_id.to_i + 1
      if self.class.request_id_with_port
        port = backend_port || request.port
        "#{port}:#{id}"
      else
        id.to_s
      end
    end

    def backend_port
      case request.cgi.class.name
      when "Mongrel::CGIWrapper"
        request.cgi.handler.listener.port rescue "unknown_mongrel"
      when "Rack::Adapter::Rails::CGIWrapper"
        # not implemented yet
        nil
      else
        nil
      end
    end

  module Rails1x
    def self.included(base)
      base.class_eval do
        alias_method_chain :log_processing, :request_id
      end
    end

    private
      def log_processing_with_request_id
        if logger
          logger.info "\n\nProcessing #{controller_class_name}\##{action_name} (for #{request_origin}) [#{request.method.to_s.upcase}]"
          logger.info "  Request ID: #{request_id}"
          logger.info "  Session ID: #{@_session.session_id}" if @_session and @_session.respond_to?(:session_id)
          logger.info "  Parameters: #{respond_to?(:filter_parameters) ? filter_parameters(params).inspect : params.inspect}"
        end
      end
  end

  module Rails2x
    def self.included(base)
      base.class_eval do
        alias_method_chain :log_processing_for_request_id, :request_id
      end
    end

    private
      def log_processing_for_request_id_with_request_id
        log_processing_for_request_id_without_request_id
        logger.info "  Request ID: #{request_id}"
      end
  end
end
