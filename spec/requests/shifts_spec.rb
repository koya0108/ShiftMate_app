require "rails_helper"

RSpec.describe "Shifts", type: :request do
  let(:user) { create(:user) }
  let!(:project) { create(:project, user: user) }
  let!(:shift) { create(:shift, project: project) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /projects/:project_id/shifts/top" do
    it "シフト一覧(TOP)ページが表示される" do
      get project_shift_top_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(project.name)
    end
  end

  describe "DELETE /projects/:project_id/shifts/:id" do
    it "シフトを削除できる" do
      expect {
        delete project_shift_path(project, shift)
      }.to change(Shift, :count).by(-1)

      expect(response).to redirect_to(project_shift_top_path(project))
      follow_redirect!
      expect(response.body).to include("シフトを削除しました")
    end
  end

  describe "PATCH /projects/:project_id/shifts/:id/finalize" do
    it "シフトを確定できる" do
      patch finalize_project_shift_path(project, shift)
      expect(response).to redirect_to(confirm_project_shift_path(project, shift))
      follow_redirect!
      expect(shift.reload.status).to eq("finalized")
    end
  end

  describe "PATCH /projects/:project_id/shifts/:id/reopen" do
    it "確定済みシフトを再度下書き状態に戻せる" do
      shift.update!(status: :finalized)
      patch reopen_project_shift_path(project, shift)
      expect(response).to redirect_to(project_shift_path(project, shift))
      expect(shift.reload.status).to eq("draft")
    end
  end
end
