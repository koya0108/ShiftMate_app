require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /user/edit" do
    it "ユーザー編集ページが表示される" do
      get edit_user_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email)
    end
  end

  describe "PATCH /user" do
    context "有効なパラメータの場合" do
      it "メールアドレスを変更すると確認メール送信メッセージが表示される" do
        patch user_path, params: { user: { email: "new_email@example.com" } }

        expect(response).to redirect_to(edit_user_path)
        follow_redirect!
        expect(response.body).to include("確認メールを送信しました")
      end

      it "ログインID(社員コード)を変更すると確認メール送信メッセージが表示される" do
        patch user_path, params: { user: { employee_code: "NEW001" } }

        expect(response).to redirect_to(edit_user_path)
        follow_redirect!
        expect(response.body).to include("確認メールを送信しました")
      end
    end

    context "無効なパラメータの場合" do
      it "メールアドレスが空欄だとエラーが表示される" do
        patch user_path, params: { user: { email: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("メールアドレス")
      end

      it "変更内容がない場合は警告が表示される" do
        patch user_path, params: { user: { email: user.email, employee_code: user.employee_code } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("変更内容がありません")
      end
    end
  end
end
