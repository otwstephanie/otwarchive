# UserImport AR Model
class UserImport < ActiveRecord::Base
  attr_accessible :source_user_id, :user_id, :source_archive_id, :pseud_id
  has_one :archive_import
  has_one :pseud
  validates_presence_of(:source_user_id,:user_id,:source_archive_id,:pseud_id)


end
