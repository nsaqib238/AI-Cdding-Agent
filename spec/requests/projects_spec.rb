require 'rails_helper'

RSpec.describe "Projects", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /projects" do
    it "returns http success" do
      get projects_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /projects/:id" do
    let(:project_record) { create(:coding_project) }

    it "returns http success" do
      get project_path(project_record)
      expect(response).to be_success_with_view_check('show')
    end
  end
end
