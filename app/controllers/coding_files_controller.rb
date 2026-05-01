class CodingFilesController < ApplicationController

  def index
    @files = CodingFile.includes(:project).order(relative_path: :asc).page(params[:page])
  end

  def show
    @file = CodingFile.find(params[:id])
    @project = @file.project
  end

  private
  # Write your private methods here
end
