class CreateAgentTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_tasks do |t|
      t.references :conversation
      t.string :status, default: "pending"
      t.string :title
      t.text :description
      t.text :result


      t.timestamps
    end
  end
end
