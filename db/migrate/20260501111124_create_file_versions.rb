class CreateFileVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :file_versions do |t|
      t.integer :coding_file_id
      t.integer :version
      t.text :content
      t.integer :size


      t.timestamps
    end
  end
end
