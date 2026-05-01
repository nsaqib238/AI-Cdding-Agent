class CreateCodingProjects < ActiveRecord::Migration[7.2]
  def change
    create_table :coding_projects do |t|
      t.string :name
      t.text :description
      t.string :path
      t.string :status, default: "active"


      t.timestamps
    end
  end
end
