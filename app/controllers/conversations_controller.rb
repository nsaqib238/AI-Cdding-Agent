class ConversationsController < ApplicationController

  def index
    @conversations = Conversation.includes(:project).order(updated_at: :desc).page(params[:page])
  end

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(created_at: :asc)
    @stream_name = "conversation_#{@conversation.id}"
  end

  def create
    @conversation = Conversation.new(conversation_params)
    
    if @conversation.save
      redirect_to conversation_path(@conversation)
    else
      @conversations = Conversation.includes(:project).order(updated_at: :desc).page(params[:page])
      render :index
    end
  end

  private
  
  def conversation_params
    params.require(:conversation).permit(:title, :project_id)
  end
end
