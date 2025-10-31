require "rails_helper"

RSpec.describe Group, type: :model do
  let(:project) { create(:project) }

  it "有効なグループが作成できる" do
    group = build(:group, name: "テスト", project: project)
    expect(group).to be_valid
  end

  it "名前が空だと無効" do
    group = build(:group, name: nil, project: project)
    expect(group).not_to be_valid
  end
end
