# UserImport AR Model
class UserImport < ActiveRecord::Base
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation
  has_one :import_models_archive_import, :class_name => 'ImportModels::ArchiveImport'
  has_one :pseud
  validates_presence_of(:import_models_archive_import,:pseud)


  attr_accessor :source_user_id
  attr_accessor :user_id
  attr_accessor :source_archive_id
  attr_accessor :pseud_id
end
