class ProjectsController < ApplicationController

  def index
    @recent_projects = CodingProject.where(status: 'active').order(updated_at: :desc).limit(10)
  end

  def show
    @project = CodingProject.find(params[:id])
    
    # List files from filesystem
    @files = @project.list_files.take(100)
  end

  def create
    @project = CodingProject.new(project_params)
    
    if @project.save
      # Create initial conversation for this project
      conversation = @project.conversations.create!(
        title: "Chat with #{@project.name}"
      )
      redirect_to conversation_path(conversation), notice: 'Project opened successfully!'
    else
      @recent_projects = CodingProject.where(status: 'active').order(updated_at: :desc).limit(10)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:coding_project).permit(:name, :absolute_path, :description, :status)
  end
end
