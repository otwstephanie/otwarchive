# ArchiveImport AR Model
class ArchiveImport < ActiveRecord::Base
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation

  has_many :users
  has_many :collections
  has_many :email_templates

  attr_accessor :old_url_link
  attr_accessor :new_url_link
  attr_accessor :archivist_link
  attr_accessor :archive_type_id
  attr_accessor :notes
  attr_accessor :associated_collection_id
  attr_accessor :new_user_notice_id
  attr_accessor :existing_user_notice_id
  attr_accessor :new_user_email_id
  attr_accessor :existing_user_email_id
  attr_accessor :archivist_user_id
  attr_accessor :new_user_email_id
  attr_accessor :new_url
  attr_accessor :old_base_url
  attr_accessor :name



  # @return [Object]
  def initialize

  end

  def build_links()
    @old_url_link = "<a href=\"http://#{self.old_base_url}>#{self.name}</a>"
    @old_url_link = "<a href=\"http://#{self.new_url}>#{self.name} - at Ao3</a>"
    u = User.find(self.archivist_id)
    @archivist_link = "<a href=\"mailto://#{u.email}>#{u.login}</a>"
  end
end