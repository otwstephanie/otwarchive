#Internal ImportWork Object
class ImportWork
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation

  attr_accessor :old_work_id,:new_work_id,:author_string
  attr_accessor :title,:summary,:old_user_id,:classes

  attr_accessor :tag_list,:new_pseud_id,:source_archive_id
  attr_accessor :word_count,:categories,:rating_integer
  attr_accessor :penname,:published,:new_user_id,:cats
  attr_accessor :chapter_count,:warnings,:updated
  attr_accessor :completed,:chapters,:characters
  attr_accessor :hits,:rating,:generes

end