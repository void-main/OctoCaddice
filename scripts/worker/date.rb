# Mixin methods for Time class
#
class Time
  SECONDS_DAY = 60 * 60 * 24

  # Is the event still within deadline?
  def within_deadline?
    deadline = init_deadline Time.now.getlocal("+08:00")
    self < deadline && self >= (deadline - SECONDS_DAY)
  end

  private # methods
  def init_deadline time
    if time.hour >= 15
      time += SECONDS_DAY
    end

    Time.new(time.year, time.month, time.day, 15, 0, 0, time.utc_offset)
  end
end
