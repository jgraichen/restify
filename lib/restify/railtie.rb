# frozen_string_literal: true

module Restify
  class Railtie < Rails::Railtie
    initializer 'restify.logger' do
      config.after_initialize do
        Restify.logger = Rails.logger
      end
    end
  end
end
