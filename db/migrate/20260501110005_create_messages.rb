class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :conversation
      t.string :role
      t.text :content


      t.timestamps
    end
  end
end
