class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.references :project
      t.string :title, default: "New Chat"


      t.timestamps
    end
  end
end
