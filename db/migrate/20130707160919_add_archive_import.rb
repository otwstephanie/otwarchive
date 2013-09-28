class AddArchiveImport < ActiveRecord::Migration
  def self.up
    create_table :archive_imports do |t|
      t.integer  :archive_type_id
      t.integer  :associated_collection_id
      t.integer  :new_user_email_id
      t.integer  :existing_user_email_id
      t.integer  :archivist_user_id

      t.string  :old_base_url
      t.string  :notes
      t.string  :new_url
      t.string  :name


    end
   end


  def self.down
    drop_table :archive_import
  end
end

