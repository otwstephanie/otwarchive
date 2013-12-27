#Internal ImportUser Object
class ImportUser
extend ActiveModel::Naming
include ActiveModel::Conversion
include ActiveModel::Validations
extend ActiveModel::Translation

attr_accessor :old_username
attr_accessor :realname
attr_accessor :penname
attr_accessor :password_salt
attr_accessor :password
attr_accessor :old_user_id
attr_accessor :joindate
attr_accessor :bio
attr_accessor :aol
attr_accessor :source_archive_id
attr_accessor :website
attr_accessor :yahoo
attr_accessor :msn
attr_accessor :icq
attr_accessor :new_user_id
attr_accessor :email
attr_accessor :is_adult
attr_accessor :pseud_id

end