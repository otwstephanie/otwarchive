# WorkImport AR Model
class WorkImport < ActiveRecord::Base
  attr_accessible :source_user_id,  :source_work_id, :source_url
  attr_accessible :work_id, :pseud_id, :source_archive_id

  has_one(:work)
  has_one(:pseud)
  has_one(:archive_import)

  validates_presence_of :work_id,:pseud_id,:source_work_id,:source_archive_id

  attr_accessible :source_user_id,  :source_work_id, :source_url
  attr_accessible :work_id, :pseud_id, :source_archive_id

end
