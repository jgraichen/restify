module Restify
  module Result
    # Return response status if available.
    #
    # @return [Symbol] Response status.
    # @see Response#status
    #
    def status
      @response ? @response.status : nil
    end

    # Return response status code if available.
    #
    # @return [Fixnum] Response status code.
    # @see Response#code
    #
    def code
      @response ? @response.code : nil
    end

    # Follow the Location header from the response of
    # this resource if available.
    #
    # @return [Obligation<Resource>] Followed resource.
    #
    def follow
      if @response && @response.headers['LOCATION']
        @client.request :get, @response.headers['LOCATION']
      else
        raise RuntimeError.new 'Nothing to follow.'
      end
    end
  end
end
