class AddArchiveImportDetails
  def up
    create_table :archive_import_settings do |t|
      t.integer  :archive_import_id
      t.integer  :archivist_user_id
      t.integer  :archive_type_id
      t.integer  :create_archive_import_record,:default => 1
      t.integer  :archive_has_chapter_files
      t.integer  :check_archivist_activated,:default => 1
      t.integer  :rerun_import,:default => 0
      t.integer  :apply_temp_table_prefix,:default => 1
      t.integer  :use_proper_categories,:default => 0
      t.integer  :use_new_mysql,:default => 0
      t.integer  :target_rating_1,:default => 9
      t.integer  :target_rating_2,:default => 10
      t.integer  :target_rating_3,:default => 11
      t.integer  :target_rating_4,:default => 12
      t.integer  :target_rating_5,:default => 13
      t.integer  :source_warning_class_id
      t.integer  :new_user_email_id
      t.integer  :existing_user_email_id
      t.integer  :import_status, :default => 1
      t.string  :sql_filename
      t.string  :source_database_host
      t.string  :source_database_username
      t.string  :source_table_prefix
      t.string  :source_database_password
      t.string  :source_database_name
      t.string  :source_temp_table_prefix

      t.string  :archive_chapters_filename
      t.string  :import_fandom
      t.string  :archivist_login
      t.string  :archivist_password
      t.string  :archivist_email

    end
   end


  def down
    drop_table :archive_import_settings
  end
end

