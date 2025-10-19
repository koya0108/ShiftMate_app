module ShiftBuilder
  class DayShiftBuilder < BaseBuilder
    SLOT_LENGTH = 1.hours

    def initialize(project:, date:, staffs:, break_rooms:, staff_groups:, user:, preferences:)
        super(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
        @preferences = preferences || {}
    end

    # シフト新規作成
    def build
        shift = build_shift(category: "day")
        assign_by_preferences(shift)
        shift
    end

    # シフト再構築
    def rebuild(existing_shift)
        existing_shift.shift_details.destroy_all
        existing_shift.update!(
        shift_date: @date,
        user: @user,
        shift_category: "day",
        status: :draft
        )

        assign_by_preferences(existing_shift)
    end

    private

    # 自動割り当てロジック
    def assign_by_preferences(shift)
        slots = generate_slots

        # 各グループごとにスロット使用回数を管理
        group_usage = Hash.new { |h, k| h[k] = Hash.new(0) }

        @staffs.each do |staff|
        pref = @preferences[staff.id.to_s] || "none"
        group_id = @staff_groups[staff.id.to_s].presence || "ungrouped"

        # 希望に応じて枠を決定
        slot =
            case pref
            when "early" then slots[0] # 11-12時
            when "middle" then slots[1] # 12-13時
            when "late" then slots[2] # 13-14時
            else
              # 希望なし→グループ内で最も少ない枠に振り分け
              slots.min_by { |s| group_usage[group_id][s] }
            end

        shift.shift_details.create!(
            staff: staff,
            group_id: (group_id == "ungrouped" ? nil : group_id.to_i),
            rest_start_time: slot[:start],
            rest_end_time: slot[:end],
            comment: staff.comment,
            preference: pref
        )

        group_usage[group_id][slot] += 1
        end
    end

    def generate_slots
        start_time = Time.zone.local(@date.year, @date.month, @date.day, 11, 0, 0)
        end_time = Time.zone.local(@date.year, @date.month, @date.day, 14, 0, 0)

        slots = []
        while start_time < end_time
        slots << { start: start_time, end: start_time + SLOT_LENGTH }
        start_time += SLOT_LENGTH
        end
        slots
    end
  end
end
