require "rails_helper"

RSpec.describe ShiftBuilder::DayShiftBuilder, type: :service do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let!(:staffs) { create_list(:staff, 3, project: project) }
  let!(:break_rooms) { create_list(:break_room, 1, project: project) }
  let(:staff_groups) { {} }
  let(:date) { Date.new(2025, 11, 2) }

  subject(:builder) do
    described_class.new(
      project: project,
      date: date,
      staffs: staffs,
      break_rooms: break_rooms,
      staff_groups: staff_groups,
      user: user,
      preferences: {
        staffs[0].id.to_s => "early",
        staffs[1].id.to_s => "middle",
        staffs[2].id.to_s => "none"
      }
    )
  end

  describe "#build" do
    it "スタッフの希望に応じた休憩時間が割り当てられる" do
      shift = builder.build
      details = shift.shift_details.order(:rest_start_time)

      expect(details[0].rest_start_time.hour).to eq(11)
      expect(details[1].rest_start_time.hour).to eq(12)
      expect(details[2].rest_start_time.hour).to be_between(11, 13)
    end
  end
end
