require 'rails_helper'

RSpec.describe "File versions", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /coding_files/:coding_file_id/file_versions" do
    let(:coding_file) { create(:coding_file) }

    it "returns http success" do
      get coding_file_file_versions_path(coding_file_id: coding_file.id)
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /file_versions/:id" do
    let(:file_version_record) { create(:file_version) }

    it "returns http success" do
      get file_version_path(file_version_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "POST /coding_files/:coding_file_id/file_versions" do
    let(:coding_file) { create(:coding_file, version: 1) }
    let!(:file_version) { create(:file_version, coding_file: coding_file, version: 1) }

    it "creates a new file_version" do
      expect {
        post coding_file_file_versions_path(coding_file_id: coding_file.id, target_version: 1)
      }.to change { FileVersion.count }.by(1)
      expect(response).to redirect_to(coding_file_path(coding_file))
    end
  end
end
