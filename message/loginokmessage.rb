require_relative '../stream/byte'

class LoginOkMessage
  def initialize(wws = nil)
    @stream = ByteStream.new
    @wws = wws
  end

  def decode(data)
    # idk
  end

  def process(messaging)
    case @wws
    when 1
      messaging.send_friend
    when 2
      messaging.send_spectate
    end
  end
end
