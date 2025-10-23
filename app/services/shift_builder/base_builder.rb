module ShiftBuilder
  class BaseBuilder
    attr_reader :project, :date, :staffs, :break_rooms, :staff_groups, :user

    def initialize(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      @project = project
      @date = date.to_date
      @staffs = staffs
      @break_rooms = break_rooms
      @staff_groups = staff_groups || {}
      @user = user
    end

    private

    # 共通シフト作成
    def build_shift(category:)
      category_value = Shift.shift_categories[category.to_s]

      shift = project.shifts.find_or_initialize_by(
        shift_date: date,
        shift_category: category_value
      )

      shift.user = user
      shift.status = :draft

      shift.save!
      shift
    end

    # start_hour, end_hour, step_hourを与えると自動生成
    def generate_slots_for_range(start_hour:, end_hour:, step_hour: 1)
      start_time = Time.zone.local(date.year, date.month, date.day, start_hour, 0, 0)
      end_time = Time.zone.local(date.year, date.month, date.day, end_hour, 0, 0)

      slots = []
      while start_time < end_time
        slots << { start: start_time, end: start_time + step_hour.hours }
        start_time += step_hour.hours
      end
      slots
    end

    # グループ毎にスタッフをまとめる
    def group_map
      staffs.group_by { |s| staff_groups[s.id.to_s] || "ungrouped" }
    end

    # shift_detail共通生成
    def create_detail(shift:, staff:, start_time:, end_time:, group_id: nil, break_room: nil)
      shift.shift_details.create!(
        staff: staff,
        group_id: group_id,
        break_room: break_room,
        rest_start_time: start_time,
        rest_end_time: end_time,
        comment: staff.comment
      )
    end
  end
end
