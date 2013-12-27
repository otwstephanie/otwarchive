class ImportCategory
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation

  attr_accessor :old_id
  attr_accessor :new_id
  attr_accessor :description
  attr_accessor :title
  attr_accessor :category_name
  attr_accessor :locked
  attr_accessor :new_parent_id
  attr_accessor :old_parent_id
end