require "rails_helper"

RSpec.describe ShiftDetail, type: :model do
  describe "バリデーション" do
    let(:shift_detail) { build(:shift_detail) }

    it "有効なシフト詳細を作成できる" do
      expect(shift_detail).to be_valid
    end

    it "休憩開始時間がないと無効" do
      shift_detail.rest_start_time = nil
      expect(shift_detail).not_to be_valid
    end

    it "休憩終了時間がないと無効" do
      shift_detail.rest_end_time = nil
      expect(shift_detail).not_to be_valid
    end

    it "コメントが15文字を超えると無効" do
      shift_detail.comment = "あ" * 16
      expect(shift_detail).not_to be_valid
    end
  end

  describe "関連付け" do
    it "staffに属する" do
      assoc = ShiftDetail.reflect_on_association(:staff)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "shiftに属する" do
      assoc = ShiftDetail.reflect_on_association(:shift)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "インスタンスメソッド" do
    it "JST変換された休憩開始時間を返す" do
      detail = build(:shift_detail, rest_start_time: Time.utc(2025, 10, 25, 3, 0, 0))
      expect(detail.rest_start_time_jst.hour).to eq(12) #JST +9
    end
  end
end