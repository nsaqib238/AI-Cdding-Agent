class ConversationsController < ApplicationController

  def index
    @conversations = Conversation.includes(:project).order(updated_at: :desc).page(params[:page])
  end

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(created_at: :asc)
    @stream_name = "conversation_#{@conversation.id}"
    
    # Load file tree for project
    if @conversation.project
      service = AiAgentService.new(
        conversation: @conversation,
        prompt: '',
        stream_name: @stream_name
      )
      @file_tree = service.send(:get_file_tree_tool, { 'path' => '.', 'max_depth' => 5, 'include_hidden' => false })
    else
      @file_tree = { total_items: 0, tree: nil }
    end
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
