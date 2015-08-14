
class Obligation::RejectedError
  def backtrace
    if cause
      if (sup = super).nil?
        sup
      else
        super + ["==== caused by #{cause.class}: #{cause}"] + cause.backtrace
      end
    else
      super
    end
  end
end
