require "rails_helper"

RSpec.describe User, type: :model do
  it "有効なユーザが作成できる" do
    user = build(:user, email: "test@example.com", password: "password123", employee_code: "E001")
    expect(user).to be_valid
  end

  it "メールが空だと無効" do
    user = build(:user, email: nil)
    expect(user).not_to be_valid
  end

  it "employee_codeが必須" do
    user = build(:user, employee_code: nil)
    expect(user).not_to be_valid
  end

  it "パスワードが必須" do
    user = build(:user, password: nil)
    expect(user).not_to be_valid
  end

  it "同じメールアドレスは登録できない" do
    create(:user, email: "test@example.com")
    duplicate_user = build(:user, email: "test@example.com")
    expect(duplicate_user).not_to be_valid
  end
end
