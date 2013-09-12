#Internal ImportChapter Object
class ImportChapter
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  extend ActiveModel::Translation

  attr_accessor :new_chapter_id
  attr_accessor :new_work_id
  attr_accessor :old_story_id
  attr_accessor :source_archive_id
  attr_accessor :title
  attr_accessor :pseud_id
  attr_accessor :summary
  attr_accessor :notes
  attr_accessor :old_user_id
  attr_accessor :body
  attr_accessor :position
  attr_accessor :date_posted

end