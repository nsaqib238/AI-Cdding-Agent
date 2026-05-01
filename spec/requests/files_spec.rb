require 'rails_helper'

RSpec.describe "CodingFiles", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /coding_files" do
    it "returns http success" do
      get coding_files_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /coding_files/:id" do
    let(:coding_file_record) { create(:coding_file) }

    it "returns http success" do
      get coding_file_path(coding_file_record)
      expect(response).to be_success_with_view_check('show')
    end
  end
end
