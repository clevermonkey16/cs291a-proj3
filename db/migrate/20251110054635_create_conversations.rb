class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :title
      t.string :status
      t.references :initiator, null: false, foreign_key: true
      t.references :assigned_expert, null: false, foreign_key: true
      t.datetime :last_message_at

      t.timestamps
    end
  end
end
