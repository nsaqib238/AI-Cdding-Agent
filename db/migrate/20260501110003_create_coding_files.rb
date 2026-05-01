class CreateCodingFiles < ActiveRecord::Migration[7.2]
  def change
    create_table :coding_files do |t|
      t.references :project
      t.string :path
      t.text :content
      t.string :language
      t.integer :size, default: 0
      t.integer :version, default: 1


      t.timestamps
    end
  end
end
