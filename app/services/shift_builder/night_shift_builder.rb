module ShiftBuilder
  class NightShiftBuilder < BaseBuilder
    SLOT_LENGTH = 2.hours

    attr_reader :unassigned_staffs, :no_room_staffs

    def initialize(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      super(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      @assigned_counts    = Hash.new(0)
      @unassigned_staffs  = []
      @no_room_staffs     = []   # NG部屋のみで room を割り当てられなかったスタッフ
    end

    # シフト新規作成
    def build
      shift = build_shift(category: "night")
      assign_midnight_slots(shift)
      shift
    end

    # 既存シフトの再作成
    def rebuild(existing_shift)
      existing_shift.shift_details.destroy_all

      existing_shift.update!(
        shift_date:      date,
        user:            user,
        shift_category:  "night",
        status:          :draft
      )

      @assigned_counts   = Hash.new(0)
      @unassigned_staffs = []
      @no_room_staffs    = []

      assign_midnight_slots(existing_shift)
      existing_shift
    end

    private

    # 0〜6時のスロットに対して休憩を割り当てるメイン処理
    def assign_midnight_slots(shift)
      slots       = generate_midnight_slots   # 0:00-2:00, 2:00-4:00, 4:00-6:00 の3スロット
      rooms       = break_rooms.to_a
      slot_count  = slots.size

      # --- ① グループごとにスタッフをまとめる ---
      group_staffs = staffs.group_by { |s| staff_groups[s.id.to_s].presence || "ungrouped" }

      # --- ② グループごとに「各スロットに何人入れたいか」の理想人数を決める ---
      group_slot_quota = {}

      group_staffs.each do |group_key, members|
        total = members.size

        group_slot_quota[group_key] =
          if total <= slot_count
            # 3名以内 → ランダムに被りなし（偏りを防ぐ）
            ones  = Array.new(total, 1)
            zeros = Array.new(slot_count - total, 0)
            (ones + zeros).shuffle
          else
            # 4名以上 → 均等割り（例：5名 → 2,2,1）
            base  = total / slot_count
            extra = total % slot_count
            quotas = Array.new(slot_count, base)
            extra.times { |i| quotas[i] += 1 }
            quotas
          end
      end

      # --- ③ 割り当て用の状態 ---
      assignments    = Array.new(slot_count) { Array.new(rooms.size) }
      assigned_ids   = Set.new

      # 各グループのスロット人数カウント（NG休憩者の割当にも使用）
      group_slot_count = Hash.new { |h, k| h[k] = Array.new(slot_count, 0) }

      # --- ④ 第1パス：グループのクォータを尊重しながら割り当て ---
      slots.each_with_index do |slot, slot_index|
        rooms.each_with_index do |room, room_index|
          staff = find_staff_for_slot_and_room(
            group_staffs,
            group_slot_quota,
            slot_index,
            room,
            assigned_ids
          )

          # 見つからなければこの room/slot は一旦空のまま（第2パスで再挑戦）
          next unless staff

          assignments[slot_index][room_index] = staff
          assigned_ids << staff.id
          @assigned_counts[staff.id] += 1

          # カウント更新
          gkey = staff_groups[staff.id.to_s].presence || "ungrouped"
          group_slot_count[gkey][slot_index] += 1
        end
      end

      # --- ⑤ 第2パス：まだ割り当てられていないスタッフを、空いている枠に入れる ---
      remaining_staffs = staffs.reject { |s| assigned_ids.include?(s.id) }

      slots.each_with_index do |slot, slot_index|
        rooms.each_with_index do |room, room_index|
          next if assignments[slot_index][room_index].present?
          break if remaining_staffs.empty?

          # NGでないスタッフを探す
          staff = remaining_staffs.find { |s| !s.ng_break_room_ids.include?(room.id) }
          next unless staff

          assignments[slot_index][room_index] = staff
          assigned_ids << staff.id
          @assigned_counts[staff.id] += 1

          # カウント
          gkey = staff_groups[staff.id.to_s].presence || "ungrouped"
          group_slot_count[gkey][slot_index] += 1

          remaining_staffs -= [ staff ]
        end
      end

      # --- ⑥ NG 制約などで room を割り当てられなかったスタッフ ---
      # → 休憩時間だけ break_room=nil で作成（偏らないように、最少人数のスロットへ配置）
      remaining_staffs.each do |staff|
        raw_gid   = staff_groups[staff.id.to_s]
        group_key = raw_gid.present? ? raw_gid.to_s : "ungrouped"
        group_id  = raw_gid.present? ? raw_gid.to_i : nil

        # ★ 最少人数スロットへ配置
        slot_index = group_slot_count[group_key].each_with_index.min[1]
        selected_slot = slots[slot_index]

        # カウント更新
        group_slot_count[group_key][slot_index] += 1

        create_detail(
          shift:       shift,
          staff:       staff,
          group_id:    group_id,
          break_room:  nil,
          start_time:  selected_slot[:start],
          end_time:    selected_slot[:end]
        )

        @no_room_staffs << staff.name
      end

      # --- ⑦ 割り当て結果を ShiftDetail に保存 ---
      slots.each_with_index do |slot, slot_index|
        rooms.each_with_index do |room, room_index|
          staff = assignments[slot_index][room_index]
          next unless staff

          raw_gid  = staff_groups[staff.id.to_s]
          group_id = raw_gid.present? ? raw_gid.to_i : nil

          create_detail(
            shift:       shift,
            staff:       staff,
            group_id:    group_id,
            break_room:  room,
            start_time:  slot[:start],
            end_time:    slot[:end]
          )
        end
      end

      @unassigned_staffs = @no_room_staffs
    end

    # 第1パス用：
    # - グループの各スロットの残クォータを見ながら
    # - そのスロット＆部屋に入れられるスタッフを1人返す
    def find_staff_for_slot_and_room(group_staffs, group_slot_quota, slot_index, room, assigned_ids)
      group_staffs.each do |group_key, members|
        quotas = group_slot_quota[group_key]
        next if quotas[slot_index].to_i <= 0

        staff = members.find do |s|
          !assigned_ids.include?(s.id) &&
            !s.ng_break_room_ids.include?(room.id)
        end

        next unless staff

        # このスロットに1人埋めたので、このグループのクォータを減らす
        quotas[slot_index] -= 1
        return staff
      end

      nil
    end

    # 深夜スロット生成（0:00〜6:00を2時間刻み）
    def generate_midnight_slots
      next_day = date + 1.day
      [
        { start: Time.zone.local(next_day.year, next_day.month, next_day.day, 0), end: Time.zone.local(next_day.year, next_day.month, next_day.day, 2) },
        { start: Time.zone.local(next_day.year, next_day.month, next_day.day, 2), end: Time.zone.local(next_day.year, next_day.month, next_day.day, 4) },
        { start: Time.zone.local(next_day.year, next_day.month, next_day.day, 4), end: Time.zone.local(next_day.year, next_day.month, next_day.day, 6) }
      ]
    end
  end
end
