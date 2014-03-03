require 'message_sender'
class Message < ActiveRecord::Base
  has_ancestry

  attr_accessor :draft
  serialize :recipient_ids, Array

  belongs_to :pseud

  validates :body, :pseud_id, presence: true
  validate :lock_down_attributes, on: :update

  scope :ordered,      -> { order('created_at asc') }
  scope :active,       -> { not_trashed.not_deleted }

  scope :draft,        -> { where('sent_at is NULL') }
  scope :not_draft,    -> { where('sent_at is not NULL')  }

  scope :sent,         -> { where('sent_at is not NULL') }
  scope :unsent,       -> { where('sent_at is NULL')  }

  scope :received,     -> { where('received_at is not NULL') }
  scope :not_received, -> { where('received_at is NULL') }

  scope :trashed,      -> { where('trashed_at is not NULL') }
  scope :not_trashed,  -> { where('trashed_at is NULL') }

  scope :deleted,      -> { where('deleted_at is not NULL') }
  scope :not_deleted,  -> { where('deleted_at is NULL') }

  scope :by_user, lambda { |user| where(user_id: user.id) }
  scope :by_pseud, lambda { |pseud| where(pseud_id: pseud.id) }
  scope :inbox,   lambda { |pseud| by_pseud(pseud).active.received }
  scope :outbox,  lambda { |pseud| by_pseud(pseud).active.sent }
  scope :drafts,  lambda { |pseud| by_pseud(pseud).active.draft.not_received }
  scope :trash,   lambda { |pseud| by_pseud(pseud).trashed.not_deleted }

  scope :read,    lambda { |pseud| by_pseud(pseud).where('read_at is not NULL').received }
  scope :unread,  lambda { |pseud| by_pseud(pseud).where('read_at is NULL').received }

  def active?
    !trashed? && !deleted?
  end

  def sender= sending_pseud
    pseud = sending_pseud
  end

  def sender
    sent? ? pseud : parent.pseud
  end

  def recipients
    sent? ? children.collect(&:pseud) : parent.recipients
  end

  def recipients= pseuds
    pseuds.each { |p| recipient_ids << p.id }
  end

  def recipient_list
    recipient_ids.reject(&:blank?).map {|id| Pseud.find id}
  end

  def mailbox
    case
    when sent? then :outbox
    when received? then :inbox
    when !new_record? && unsent? then :drafts
    when trashed? then :trash
    else
      :compose
    end
  end

  def send!
    lock.synchronize do
      MessageSender.new(self).run unless draft?
    end
  end

  def reply! options={}
    if parent
      reply = children.create!(subject: options.fetch(:subject, subject),
       body: options.fetch(:body, nil),
       pseud: pseud,
       recipients: [parent.pseud])
      reply.send!
    end
  end

  def receive!
    update_attributes(:received_at=> Time.now)
  end

  def read!
    update_attributes(:read_at=> Time.now) if !self.read_at.present?
  end

  def trash!
    update_attributes(:trashed_at=> Time.now)
  end

  def delete!
    update_attributes(:deleted_at=> Time.now)
  end

  %w[sent received trashed deleted read].each do |act|
    define_method "#{act}?" do
      self.send(:"#{act}_at").present?
    end
  end

  def unread?
    !read?
  end

  def uneditable?
    !editable?
  end

  def unsent?
    !sent?
  end

  def draft?
    self.draft == '1'
  end

  def sent_date
    sent_at || received_at
  end

  private
  def lock_down_attributes
    return if editable?
    errors.add(:base, 'Cannot edit') unless deleted_at_changed? || trashed_at_changed? || read_at_changed?
  end

  def lock
    @lock ||= Mutex.new
  end
end