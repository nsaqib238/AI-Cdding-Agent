require 'rails_helper'

RSpec.describe "Agent tasks", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /agent_tasks" do
    it "returns http success" do
      get agent_tasks_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /agent_tasks/:id" do
    let(:agent_task_record) { create(:agent_task) }

    it "returns http success" do
      get agent_task_path(agent_task_record)
      expect(response).to be_success_with_view_check('show')
    end
  end
end
