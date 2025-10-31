require "rails_helper"

RSpec.describe "Staffs", type: :request do
  let(:user) { create(:user) }
  let!(:project) { create(:project, user: user) }
  let!(:staff) { create(:staff, project: project) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /projects/:project_id/staffs" do
    it "スタッフ一覧ページが表示される" do
      get project_staffs_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(staff.name)
    end
  end

  describe "GET /projects/:project_id/staffs/new" do
    it "新規作成ページが表示される" do
      get new_project_staff_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /projects/:project_id/staffs" do
    it "新しいスタッフを作成できる" do
      expect {
        post project_staffs_path(project), params: { staff: { name: "田中太郎", position: "看護師", comment: "夜勤可" } }
    }.to change(Staff, :count).by(1)

    expect(response).to redirect_to(project_staffs_path(project))
    follow_redirect!
    expect(response.body).to include("スタッフを登録しました")
  end

    it "無効なパラメータでは作成できない" do
        expect {
        post project_staffs_path(project), params: { staff: { name: "" } }
        }.not_to change(Staff, :count)

        expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /projects/:project_id/staffs/:id/edit" do
    it "編集ページが表示される" do
      get edit_project_staff_path(project, staff)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(staff.name)
    end
  end

  describe "PATCH /projects/:project_id/staffs/:id" do
    it "スタッフ情報を更新できる" do
      patch project_staff_path(project, staff), params: { staff: { name: "佐藤花子" } }
      expect(response).to redirect_to(project_staffs_path(project))
      follow_redirect!
      expect(staff.reload.name).to eq("佐藤花子")
    end
  end

  describe "DELETE /projects/:project_id/staffs/:id" do
    it "スタッフを削除できる" do
      expect {
        delete project_staff_path(project, staff)
      }.to change(Staff, :count).by(-1)
      expect(response).to redirect_to(project_staffs_path(project))
      follow_redirect!
      expect(response.body).to include("スタッフを削除しました")
    end
  end
end
