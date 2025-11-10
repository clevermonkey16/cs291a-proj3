class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: true
      t.text :content
      t.boolean :is_read

      t.timestamps
    end
  end
end
