require "rails_helper"

RSpec.describe ShiftBuilder::NightShiftBuilder, type: :service do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let!(:staffs) { create_list(:staff, 4, project: project) }
  let!(:break_rooms) { create_list(:break_room, 2, project: project) }
  let(:staff_groups) { {} }
  let(:date) { Date.new(2025, 11, 1) }

  subject(:builder) do
    described_class.new(
      project: project,
      date: date,
      staffs: staffs,
      break_rooms: break_rooms,
      staff_groups: staff_groups,
      user: user
    )
  end

  describe "#build" do
    it "Shift と ShiftDetail が作成される" do
      shift = builder.build

      expect(shift).to be_a(Shift)
      expect(shift.shift_details.count).to be > 0
      expect(shift.shift_details.first.break_room).to be_present
    end
  end

  describe "#rebuild" do
    it "既存シフトの詳細を削除し再作成する" do
      existing_shift = create(:shift, project: project, shift_date: date, shift_category: "night")
      create(:shift_detail, shift: existing_shift, staff: staffs.first, break_room: break_rooms.first)

      expect {
        builder.rebuild(existing_shift)
      }.to change { existing_shift.shift_details.count }.from(1)
    end
  end
end
