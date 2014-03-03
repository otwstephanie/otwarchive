class MessagesController < ApplicationController
  #before_action :message, only: [:show, :update, :destroy]
  #before_action :can_view_message, only: [:show, :edit, :destroy]

  def index
    mailbox = Mailbox.new(User.current_user.default_pseud)
    @inbox_messages = mailbox.inbox
  end

  def sent
    mailbox = Mailbox.new(User.current_user.default_pseud)
    @sent_messages = mailbox.outbox
  end

  def new
    @message = User.current_user.default_pseud.messages.new
  end

  def create
    message_params[:recipient_ids]=message_params[:recipient_ids].select{|r| !r.blank?}
    @message = Message.new(message_params.merge(:pseud=> User.current_user.default_pseud))
    if @message.save
      send_message
    else
      render :new
    end
  end

  def edit
    redirect_to message unless message.unsent?
  end

  def update
    message.update(message_params)
    send_message
  end

  def show
    @message = Message.find(params[:id])
    @message.read! if @message.received? || @message.unread?
  end

  def reply
    @message = Message.find(params[:id])
    if params[:message][:body]
      @message.reply! message_params.merge(:pseud=> User.current_user.default_pseud)
      set_flash_message :notice, :replied
      redirect_to index_messages_path
    else
      set_flash_message :alert, :invalid
      redirect_to :back
    end
  end

  def trash
    @message = Message.find(params[:id])
    @message.trash!
    set_flash_message :notice, :trashed
    redirect_to index_messages_path
  end

  def destroy
    message.delete!
    set_flash_message :notice, :deleted
    redirect_to mailbox_path(:inbox)
  end

  def empty_trash
    Mailbox.new(User.current_user.default_pseud).empty_trash!
    set_flash_message :notice, :trash_emptied
    redirect_to mailbox_path(:inbox)
  end

  private
  def message
    @message ||= Message.find(params[:id])
  end
  helper_method :message

  def message_params
    params[:message]
  end

  def send_message
    message.send!
    notice = message.sent? ? set_flash_message(:notice, :sent) : set_flash_message(:notice, :saved)
    redirect_to :back, notice: notice
  end

  def mailbox_name
    params[:mailbox] || message.mailbox.to_s
  end
  helper_method :mailbox_name

  def can_view_message
    unless mine?
      set_flash_message :notice, :unauthorised
      redirect_to mailbox_path(:inbox)
    end
  end

  def mine?
    message.pseud == User.current_user.default_pseud
  end
end