class Mailbox
  attr_accessor :pseud
  attr_accessor :user

  def initialize(pseud)
    @pseud = pseud
  end

  def inbox
    Message.inbox(pseud)
  end

  def unread
    inbox.select {|m| m.unread?}
  end 

  def unread_count
    inbox.map(&:unread?).count
  end

  def outbox
    Message.outbox(pseud)
  end

  def drafts
    Message.drafts(pseud)
  end

  def trash
    Message.trash(pseud)
  end

  def empty_trash!
    trash.each { |message| message.delete! }
  end
end