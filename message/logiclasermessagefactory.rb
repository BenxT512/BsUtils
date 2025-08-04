require_relative 'serverhellomessage'
require_relative 'loginokmessage'
require_relative 'ownhomedatamessage'

module LogicLaserMessageFactory
  MESSAGES = {
    20100 => ServerHelloMessage,
    20104 => LoginOkMessage,
    24101 => OwnHomeDataMessage
  }.freeze

  def self.create_message_by_type(type, wws = nil)
    klass = MESSAGES[type]
    return nil unless klass

    if type == 20104
      klass.new(wws)
    else
      klass.new
    end
  end
end
