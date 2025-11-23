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
            when "middle-late" then slots[2] # 13-14時
            when "late" then slots[3] # 14~15時
            when "long-shift" then slots[4] # 16時~17時
            else
              nil # 希望なし
            end

        if slot.nil?
          # 希望なしの時のスロット（11時～15時）
          normal_slots = slots[0..3]

          # 各スロットの使用回数から最小値を取る
          min_usage = normal_slots.map { |s| group_usage[group_id][s] }.min

          candidates = normal_slots.select { |s| group_usage[group_id][s] == min_usage }

          # ランダムに一つ選ぶ
          slot = candidates.sample
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
      base = Time.zone.local(@date.year, @date.month, @date.day)

      [
        { start: base + 11.hours, end: base + 12.hours },
        { start: base + 12.hours, end: base + 13.hours },
        { start: base + 13.hours, end: base + 14.hours },
        { start: base + 14.hours, end: base + 15.hours },
        { start: base + 16.hours, end: base + 17.hours }
      ]
    end
  end
end
