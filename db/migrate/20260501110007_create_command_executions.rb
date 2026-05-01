class CreateCommandExecutions < ActiveRecord::Migration[7.2]
  def change
    create_table :command_executions do |t|
      t.references :conversation
      t.text :command
      t.text :output
      t.integer :exit_code
      t.string :status, default: "pending"


      t.timestamps
    end
  end
end
