require "rails_helper"

RSpec.describe Project, type: :model do
  let(:user) { create(:user) }

  it "有効なプロジェクトが作成できる" do
    project = build(:project, name: "テスト", user: user)
    expect(project).to be_valid
  end

  it "名前が空だと無効" do
    project = build(:project, name: nil, user: user)
    expect(project).not_to be_valid
  end

  it "ユーザが紐づいていないと無効" do
    project = build(:project, name: "テスト", user: nil)
    expect(project).not_to be_valid
  end

  it "プロジェクト削除時に関連データも削除される" do
    project = create(:project, user: user)
    create(:staff, project: project)
    create(:group, project: project)
    create(:break_room,  project: project)
    expect { project.destroy }.to change { [ Staff.count, Group.count, BreakRoom.count ] }.to([ 0, 0, 0 ])
  end
end
