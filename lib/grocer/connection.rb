require 'grocer'
require 'grocer/ssl_connection'

module Grocer


  class GotErrorResponseException < Exception
    attr_reader :identifier
    def initialize(msg,id)
      super(msg)
      @identifier = id
    end
  end

  class Connection
    attr_reader :certificate, :passphrase, :gateway, :port, :retries

    def initialize(options = {})
      @certificate = options.fetch(:certificate) { nil }
      @passphrase = options.fetch(:passphrase) { nil }
      @gateway = options.fetch(:gateway) { fail NoGatewayError }
      @port = options.fetch(:port) { fail NoPortError }
      @retries = options.fetch(:retries) { 3 }
    end

    def read(size = nil, buf = nil)
      with_connection do
        ssl.read(size, buf)
      end
    end

    def write(content)
      with_connection do
        ssl.write(content)
        response = ssl.read_nonblock(Grocer::ErrorResponse::LENGTH)
        handle_error_response(response)
      end

    end

    def connect
      ssl.connect unless ssl.connected?
    end

    def close(timeout)
      with_connection do
        response = ssl.read_nonblock(Grocer::ErrorResponse::LENGTH,timeout)
        handle_error_response(response)
      end
      ssl.disconnect
    end

    private

    def handle_error_response(response)
      if response
          error = ErrorResponse.new(response)
          raise (GotErrorResponseException.new(error.status, error.identifier))
        end
    end

    def ssl
      @ssl_connection ||= build_connection
    end

    def build_connection
      Grocer::SSLConnection.new(certificate: certificate,
                                passphrase: passphrase,
                                gateway: gateway,
                                port: port)
    end

    def destroy_connection
      return unless @ssl_connection

      @ssl_connection.disconnect rescue nil
      @ssl_connection = nil
    end

    def with_connection
      attempts = 1
      begin
        connect
        yield
      rescue => e
        if e.class == OpenSSL::SSL::SSLError && e.message =~ /certificate expired/i
          e.extend(CertificateExpiredError)
          raise
        end

        raise unless attempts < retries

        #destroy_connection
        attempts += 1
        retry
      end
    end
  end
end
