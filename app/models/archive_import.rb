class ArchiveImport < ActiveRecord::Base
  attr_accessible :archive_type_id, :archivist_user_id, :collection_id, :existing_user_email_id, :name, :new_url, :new_user_email_id, :notes, :old_base_url
end
