class CommandExecutionsController < ApplicationController

  def index
    if params[:conversation_id].present?
      @conversation = Conversation.find(params[:conversation_id])
      @executions = @conversation.command_executions.order(created_at: :desc).page(params[:page])
    else
      @executions = CommandExecution.includes(:conversation).order(created_at: :desc).page(params[:page])
    end
  end

  def show
    @execution = CommandExecution.find(params[:id])
    @conversation = @execution.conversation
  end

  private
  # Write your private methods here
end
