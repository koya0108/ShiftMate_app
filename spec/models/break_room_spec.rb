require "rails_helper"

RSpec.describe BreakRoom, type: :model do
  let(:project) { create(:project) }

  it "有効な休憩室が作成できる" do
    break_room = build(:break_room, name: "テスト", project: project)
    expect(break_room).to be_valid
  end

  it "名前が空だと無効" do
    break_room = build(:break_room, name: nil, project: project)
    expect(break_room).not_to be_valid
  end
end
