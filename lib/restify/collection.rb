module Restify
  #
  class Collection < Array
    include Contextual
    include Relations

    def initialize(context, data = [])
      @context = context

      super data

      map! {|item| @context.inherit_value(item) }
    end
  end
end
