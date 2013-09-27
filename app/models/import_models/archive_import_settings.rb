# ArchiveImport AR Model
class ArchiveImportSettings < ActiveRecord::Base

  attr_accessible :archive_import_id
  attr_accessible :archivist_user_id
  attr_accessible :archive_type_id
  attr_accessible :create_archive_import_record
  attr_accessible :archive_has_chapter_files
  attr_accessible :check_archivist_activated
  attr_accessible :rerun_import
  attr_accessible :apply_temp_table_prefix
  attr_accessible :use_proper_categories
  attr_accessible :use_new_mysql
  attr_accessible :target_rating_1
  attr_accessible :target_rating_2
  attr_accessible :target_rating_3
  attr_accessible :target_rating_4
  attr_accessible :target_rating_5
  attr_accessible :source_warning_class_id
  attr_accessible :new_user_email_id
  attr_accessible :existing_user_email_id
  attr_accessible :import_status
  attr_accessible :sql_filename
  attr_accessible :source_database_host
  attr_accessible :source_database_username
  attr_accessible :source_table_prefix
  attr_accessible :source_database_password
  attr_accessible :source_database_name
  attr_accessible :source_temp_table_prefix
  attr_accessible :archive_chapters_filename
  attr_accessible :import_fandom
  attr_accessible :archivist_login
  attr_accessible :archivist_password
  attr_accessible :archivist_email
  attr_accessible :new_collection_title
  attr_accessible :new_collection_description
end