class MessageTable < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.string      :subject
      t.text        :body
      t.integer     :user_id
      t.integer     :pseud_id
      t.string      :ancestry
      t.string      :recipient_ids
      t.datetime    :sent_at
      t.datetime    :received_at
      t.datetime    :read_at
      t.datetime    :trashed_at
      t.datetime    :deleted_at
      t.boolean     :editable, default: true
      t.timestamps
    end
    add_index :messages, :pseud_id
    add_index :messages, :user_id
    add_index :messages, :ancestry
  end

  def self.down
    drop_table :messages
  end
end