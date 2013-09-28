class AddWorkImport < ActiveRecord::Migration
  def self.up
    create_table :work_imports do |t|
      t.integer  :archive_import_id
      t.integer  :source_work_id
      t.integer  :work_id
      t.integer  :source_user_id
      t.string   :source_url
      t.integer  :pseud_id
    end
   end


  def self.down
    drop_table :work_import
  end
end

