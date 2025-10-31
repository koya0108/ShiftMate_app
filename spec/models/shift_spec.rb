require "rails_helper"

RSpec.describe Shift, type: :model do
  describe "バリデーション" do
    let(:shift) { build(:shift) }

    it "有効なシフトを作成できる" do
      expect(shift).to be_valid
    end

    it "日付がないと無効" do
      shift.shift_date = nil
      expect(shift).not_to be_valid
    end

    it "カテゴリがないと無効" do
      shift.shift_category = nil
      expect(shift).not_to be_valid
    end

    it "同じプロジェクト・日付・カテゴリの組み合わせは重複不可" do
      existing = create(:shift)
      duplicate = build(:shift, project: existing.project, shift_date: existing.shift_date, shift_category: existing.shift_category)
      expect(duplicate).not_to be_valid
    end
  end

  describe "関連付け" do
    it "ユーザーと関連している" do
      assoc = Shift.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "プロジェクトと関連している" do
      assoc = Shift.reflect_on_association(:project)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "shift_detailsを多数持つ" do
      assoc = Shift.reflect_on_association(:shift_details)
      expect(assoc.macro).to eq(:has_many)
    end
  end
end
