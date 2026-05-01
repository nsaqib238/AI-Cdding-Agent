require 'rails_helper'

RSpec.describe "Conversations", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /conversations" do
    it "returns http success" do
      get conversations_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /conversations/:id" do
    let(:conversation_record) { create(:conversation) }

    it "returns http success" do
      get conversation_path(conversation_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "POST /conversations" do
    it "creates a new conversation" do
      post conversations_path, params: { conversation: attributes_for(:conversation) }
      expect(response).to be_success_with_view_check
    end
  end
end
