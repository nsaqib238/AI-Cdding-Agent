class AgentTasksController < ApplicationController

  def index
    if params[:conversation_id].present?
      @conversation = Conversation.find(params[:conversation_id])
      @tasks = @conversation.agent_tasks.order(created_at: :desc).page(params[:page])
    else
      @tasks = AgentTask.includes(:conversation).order(created_at: :desc).page(params[:page])
    end
  end

  def show
    @task = AgentTask.find(params[:id])
    @conversation = @task.conversation
  end

  private
  # Write your private methods here
end
