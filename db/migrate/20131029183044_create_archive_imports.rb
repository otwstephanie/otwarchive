class CreateArchiveImports < ActiveRecord::Migration
  def change
    create_table :archive_imports do |t|
      t.string :name
      t.string :archive_type_id
      t.string :old_base_url
      t.string :notes
      t.integer :collection_id
      t.integer :existing_user_email_id
      t.integer :new_user_email_id
      t.string :new_url
      t.integer :archivist_user_id

      t.timestamps
    end
  end
end
