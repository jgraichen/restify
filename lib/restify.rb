require 'restify/version'

#
module Restify
  require 'restify/client'

  class << self
    def new(url)
      Client.new.get(url)
    end
  end
end
