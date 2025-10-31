require "rails_helper"

RSpec.describe Staff, type: :model do
  let(:project) { create(:project) }

  it "有効なスタッフが作成できる" do
    staff = build(:staff, name: "テスト", project: project)
    expect(staff).to be_valid
  end

  it "名前が空だと無効" do
    staff = build(:staff, name: nil, project: project)
    expect(staff).not_to be_valid
  end
end
