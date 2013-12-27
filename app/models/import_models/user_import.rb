# UserImport AR Model
class UserImport < ActiveRecord::Base
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation


  attr_accessor :source_user_id
  attr_accessor :user_id
  attr_accessor :source_archive_id
  attr_accessor :pseud_id
end
