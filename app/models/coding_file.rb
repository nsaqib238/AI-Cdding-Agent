class CodingFile < ApplicationRecord
  belongs_to :project, class_name: 'CodingProject'
  has_many :file_versions, dependent: :destroy

  validates :relative_path, presence: true
  validates :relative_path, uniqueness: { scope: :project_id }

  # Read content from filesystem
  def content
    project.read_file(relative_path)
  end

  # Write content to filesystem
  def content=(new_content)
    project.write_file(relative_path, new_content)
    reload
  end

  # Get absolute path on filesystem
  def absolute_path
    File.join(project.absolute_path, relative_path)
  end

  # Check if file exists on disk
  def exists?
    File.exist?(absolute_path)
  end

  # Get file size from disk
  def size
    return 0 unless exists?
    File.size(absolute_path)
  end
end
