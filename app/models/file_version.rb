class FileVersion < ApplicationRecord
  belongs_to :coding_file
  
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :content, presence: true
end
