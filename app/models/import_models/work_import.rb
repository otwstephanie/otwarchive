# WorkImport AR Model
class WorkImport < ActiveRecord::Base
  has_many(:works)

  attr_accessor :source_user_id
  attr_accessor :work_id
  attr_accessor :source_work_id
  attr_accessor :pseud_id
  attr_accessor :source_archive_id
  attr_accessor :source_url
end
