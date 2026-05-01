require 'rails_helper'

RSpec.describe "Command executions", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /command_executions" do
    it "returns http success" do
      get command_executions_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /command_executions/:id" do
    let(:command_execution_record) { create(:command_execution) }

    it "returns http success" do
      get command_execution_path(command_execution_record)
      expect(response).to be_success_with_view_check('show')
    end
  end
end
