class CodingProject < ApplicationRecord
  has_many :coding_files, dependent: :destroy, foreign_key: :project_id
  has_many :conversations, dependent: :destroy, foreign_key: :project_id

  validates :name, presence: true
  validates :absolute_path, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active archived] }

  validate :path_must_exist

  # Read file content from filesystem
  def read_file(relative_path)
    full_path = File.join(absolute_path, relative_path)
    return nil unless File.exist?(full_path)
    File.read(full_path)
  end

  # Write file content to filesystem
  def write_file(relative_path, content)
    full_path = File.join(absolute_path, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    
    # Update or create tracking record
    file = coding_files.find_or_initialize_by(relative_path: relative_path)
    file.version += 1 if file.persisted?
    file.last_modified_at = Time.current
    file.save!
    file
  end

  # List all files in project directory
  def list_files(pattern: '**/*', include_hidden: false)
    Dir.glob(File.join(absolute_path, pattern)).select do |path|
      File.file?(path) && (include_hidden || !File.basename(path).start_with?('.'))
    end.map { |path| path.sub("#{absolute_path}/", '') }
  end

  private

  def path_must_exist
    return if absolute_path.blank?
    errors.add(:absolute_path, 'must exist on filesystem') unless Dir.exist?(absolute_path)
  end
end
