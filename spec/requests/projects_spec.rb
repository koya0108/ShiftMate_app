require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:user) { create(:user) }
  let!(:project) { create(:project, user: user) }

  before do
    sign_in user, scope: :user # Deviseのログインヘルパー
  end

  describe "GET /projects" do
    it "一覧ページが表示される" do
      get projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(project.name)
    end
  end

  describe "GET /projects/new" do
    it "新規作成ページが表示される" do
      get new_project_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /projects" do
    it "新しいプロジェクトが作成できる" do
      expect {
        post projects_path, params: { project: { name: "新プロジェクト" } }
    }.to change(Project, :count).by(1)

    expect(response).to redirect_to(projects_path)
    follow_redirect!
    expect(response.body).to include("プロジェクトを作成しました")
  end

    it "無効なパラメータでは作成できない" do
        expect {
        post projects_path, params: { project: { name: "" } }
        }.not_to change(Project, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("プロジェクト")
    end
  end

  describe "PATCH /projects/:id" do
    it "プロジェクトを更新できる" do
      patch project_path(project), params: { project: { name: "更新後プロジェクト" } }
      expect(response).to redirect_to(projects_path)
      follow_redirect!
      expect(response.body).to include("プロジェクトを更新しました")
      expect(project.reload.name).to eq("更新後プロジェクト")
    end
  end

  describe "DELETE /projects/:id" do
    it "プロジェクトを削除できる" do
      expect {
        delete project_path(project)
      }.to change(Project, :count).by(-1)
      expect(response).to redirect_to(projects_path)
      follow_redirect!
      expect(response.body).to include("プロジェクトを削除しました")
    end
  end
end
