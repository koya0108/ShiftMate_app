module ShiftBuilder
  class NightShiftBuilder < BaseBuilder
    SLOT_LENGTH = 2.hours

    def initialize(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      super(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      @assigned_staff_ids = []
    end

    # シフト新規作成
    def build
      shift = build_shift(category: "night")

      slots = generate_slots
      midnight_slots = slots.select { |s| midnight?(s) }
      other_slots = slots.reject { |s| midnight?(s) }

      # 深夜帯を優先、残りは深夜に近い順
      other_slots.sort_by! { |slot| distance_to_midnight(slot[:start]) }

      assign_staffs(shift, midnight_slots)
      assign_staffs(shift, other_slots)
      shift
    end

    def rebuild(existing_shift)
      existing_shift.shift_details.destroy_all

      existing_shift.update!(
        shift_date: date,
        user:  user,
        shift_category: "night",
        status: :draft
      )

      assign_all(existing_shift)
    end

    private

    # 全スロット再割り当て
    def assign_all(shift)
      slots = generate_slots
      midnight_slots = slots.select { |s| midnight?(s) }
      other_slots = slots.reject { |s| midnight?(s) }

      other_slots.sort_by! { |slot| distance_to_midnight(slot[:start]) }

      @assigned_staff_ids = []

      assign_staffs(shift, midnight_slots)
      assign_staffs(shift, other_slots)
      shift
    end

    # スロット生成(18-9時を2h区切)
    def generate_slots
      start_time = Time.zone.local(date.year, date.month, date.day, 18, 0, 0)
      end_time = Time.zone.local((date + 1).year, (date + 1).month, (date + 1).day, 9, 0, 0)

      slots = []
      while start_time < end_time
        slots << { start: start_time, end: start_time + SLOT_LENGTH }
        start_time += SLOT_LENGTH
      end
      slots
    end

    # 深夜帯を判定
    def midnight?(slot)
      (0..5).include?(slot[:start].hour)
    end

    # 深夜への近さを数値化
    def distance_to_midnight(time)
      midnight = time.change(hour: 0)
      [ (time - midnight).abs, (time - (midnight + 1.day)).abs ].min
    end

    def assign_staffs(shift, slots)
      room_index = 0

      slots.each do |slot|
        used_groups = []

        break_rooms.size.times do
          room = break_rooms[room_index % break_rooms.size]
          room_index += 1

          # 未割当かつグループ重複なしのスタッフを探す
          staff = staffs.find do |s|
            group_id = staff_groups[s.id.to_s].presence || "ungrouped"
            !@assigned_staff_ids.include?(s.id) && !used_groups.include?(group_id)
          end
          next unless staff # 全員割り当て済なら終了

          raw_gid = staff_groups[staff.id.to_s]
          group_id = raw_gid.present? ? raw_gid.to_i : nil

          create_detail(
            shift: shift,
            staff: staff,
            group_id: group_id,
            break_room: room,
            start_time: slot[:start],
            end_time: slot[:end]
          )

          @assigned_staff_ids << staff.id
          used_groups << staff_groups[staff.id.to_s]
        end
      end
    end
  end
end
