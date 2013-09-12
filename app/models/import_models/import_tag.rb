#Internal ImportTag Object
class ImportTag
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation

  attr_accessor :old_id
  attr_accessor :new_id
  attr_accessor :tag
  attr_accessor :tag_type
  attr_accessor :old_parent_id
  attr_accessor :new_parent_id

end