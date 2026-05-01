class FileVersionsController < ApplicationController

  def index
    @file = CodingFile.find(params[:coding_file_id])
    @versions = @file.file_versions.order(version: :desc).page(params[:page])
  end

  def show
    @version = FileVersion.find(params[:id])
    @file = @version.coding_file
  end

  def create
    @file = CodingFile.find(params[:coding_file_id])
    
    # Save current version before updating
    @file.file_versions.create!(
      version: @file.version,
      content: @file.content,
      size: @file.size
    )
    
    # Rollback to specified version
    target_version = @file.file_versions.find_by(version: params[:target_version])
    
    if target_version
      @file.update!(
        content: target_version.content,
        size: target_version.size,
        version: @file.version + 1
      )
      
      redirect_to coding_file_path(@file), notice: "Rolled back to version #{params[:target_version]}"
    else
      redirect_to coding_file_path(@file), alert: "Version not found"
    end
  end

  private
  # Write your private methods here
end
