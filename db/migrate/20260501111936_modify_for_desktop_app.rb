class ModifyForDesktopApp < ActiveRecord::Migration[7.2]
  def change
    # Update coding_projects to use absolute_path instead of path
    rename_column :coding_projects, :path, :absolute_path
    change_column_null :coding_projects, :name, false
    change_column_null :coding_projects, :absolute_path, false
    add_index :coding_projects, :absolute_path, unique: true
    
    # Update coding_files to use relative_path and remove content storage
    rename_column :coding_files, :path, :relative_path
    change_column_null :coding_files, :relative_path, false
    remove_column :coding_files, :content, :text
    remove_column :coding_files, :language, :string if column_exists?(:coding_files, :language)
    add_column :coding_files, :last_modified_at, :datetime
    add_index :coding_files, [:project_id, :relative_path], unique: true
  end
end
