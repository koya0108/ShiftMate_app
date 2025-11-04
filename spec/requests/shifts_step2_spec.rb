require "rails_helper"

RSpec.describe "Shifts Step2", type: :request do
  let(:user) { create(:user) }
  let!(:project) { create(:project, user: user) }
  let!(:staff1) { create(:staff, project: project) }
  let!(:break_room) { create(:break_room, project: project) }

  before do
    sign_in user, scope: :user
  end

  describe "POST /projects/:project_id/shifts/step2_create" do
    it "シフトが作成され、正しくリダイレクトされる" do
      # step1通過後のセッションを再現
      post step1_create_project_shifts_path(project), params: {
        shift_category: "night",
        date: Date.today,
        staff_ids: [ staff1.id ],
        break_room_ids: [ break_room.id ]
      }

      post step2_create_project_shifts_path(project), params: { group_ids: {} }

      expect(response).to redirect_to(project_shift_path(project, Shift.last))
      follow_redirect!
      expect(response.body).to include("シフトを作成しました")
    end
  end
end
