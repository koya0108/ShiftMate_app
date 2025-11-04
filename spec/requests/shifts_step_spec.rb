require "rails_helper"

RSpec.describe "Shifts Step Flow", type: :request do
  let(:user) { create(:user) }
  let!(:project) { create(:project, user: user) }
  let!(:staff1) { create(:staff, project: project) }
  let!(:staff2) { create(:staff, project: project) }
  let!(:break_room) { create(:break_room, project: project) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /projects/:project_id/shifts/step1" do
    it "夜勤モードでページが表示される" do
      get step1_project_shifts_path(project, shift_category: "night", date: "2025-11-01")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("夜勤")
    end

    it "日勤モードでページが表示される" do
      get step1_project_shifts_path(project, shift_category: "day", date: "2025-11-01")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /projects/:project_id/shifts/step1_create" do
    context "有効なパラメータの場合" do
      it "夜勤でセッションが保存され、step2にリダイレクトされる" do
        post step1_create_project_shifts_path(project), params: {
          shift_category: "night",
          date: "2025-11-01",
          staff_ids: [ staff1.id, staff2.id ],
          break_room_ids: [ break_room.id ]
        }

        expect(session[:shift_data]).to include(
          "date" => "2025-11-01",
          "staff_ids" => [ staff1.id.to_s, staff2.id.to_s ],
          "break_room_ids" => [ break_room.id.to_s ],
          "shift_category" => "night"
        )

        expect(response).to redirect_to(step2_project_shifts_path(project, shift_category: "night"))
      end

      it "日勤ではbreak_roomなしでも通過する" do
        post step1_create_project_shifts_path(project), params: {
          shift_category: "day",
          date: "2025-11-01",
          staff_ids: [ staff1.id ]
        }

        expect(session[:shift_data]["shift_category"]).to eq("day")
        expect(response).to redirect_to(step2_project_shifts_path(project, shift_category: "day"))
      end
    end

    context "無効なパラメータの場合" do
      it "スタッフ未選択ならエラーでstep1へ戻る" do
        post step1_create_project_shifts_path(project), params: {
          shift_category: "night",
          date: "2025-11-01",
          break_room_ids: [ break_room.id ]
        }

        expect(flash[:alert]).to eq("スタッフを1名以上選択してください")
        expect(response).to redirect_to(step1_project_shifts_path(project, date: "2025-11-01", shift_category: "night"))
      end

      it "夜勤で休憩室未選択ならエラー" do
        post step1_create_project_shifts_path(project), params: {
          shift_category: "night",
          date: "2025-11-01",
          staff_ids: [ staff1.id ]
        }

        expect(flash[:alert]).to eq("休憩室を1つ以上選択してください")
        expect(response).to redirect_to(step1_project_shifts_path(project, date: "2025-11-01", shift_category: "night"))
      end
    end
  end

  describe "GET /projects/:project_id/shifts/step2" do
    context "セッションありの場合" do
      before do
        post step1_create_project_shifts_path(project), params: {
          shift_category: "night",
          date: "2025-11-01",
          staff_ids: [ staff1.id ],
          break_room_ids: [ break_room.id ]
        }
      end

      it "step2ページが表示される" do
        get step2_project_shifts_path(project, shift_category: "night")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(staff1.name)
      end
    end

    context "セッションなしの場合" do
      it "step1へリダイレクトされる" do
        get step2_project_shifts_path(project)
        expect(response).to redirect_to(step1_project_shifts_path(project))
        expect(flash[:alert]).to eq("データがありません")
      end
    end
  end
end
