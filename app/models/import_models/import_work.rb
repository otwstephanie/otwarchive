#Internal ImportWork Object
class ImportWork
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation

  attr_accessor :old_work_id
  attr_accessor :new_work_id
  attr_accessor :author_string
  attr_accessor :title
  attr_accessor :summary
  attr_accessor :classes
  attr_accessor :old_user_id
  attr_accessor :tag_list
  attr_accessor :new_pseud_id
  attr_accessor :source_archive_id
  attr_accessor :word_count
  attr_accessor :categories
  attr_accessor :rating_integer
  attr_accessor :penname
  attr_accessor :published
  attr_accessor :new_user_id
  attr_accessor :cats
  attr_accessor :chapter_count
  attr_accessor :warnings
  attr_accessor :updated
  attr_accessor :completed
  attr_accessor :chapters
  attr_accessor :characters
  attr_accessor :hits
  attr_accessor :rating
  attr_accessor :generes

end