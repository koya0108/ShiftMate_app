module ShiftBuilder
  class NightShiftBuilder < BaseBuilder
    SLOT_LENGTH = 2.hours

    attr_reader :unassigned_staffs

    def initialize(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      super(project:, date:, staffs:, break_rooms:, staff_groups:, user:)
      @assigned_counts    = Hash.new(0) # スタッフごとの割り当て回数（今回の仕様では0 or 1のはず）
      @unassigned_staffs  = []
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

      assign_midnight_slots(existing_shift)
      existing_shift
    end

    private

    # 0〜6時のスロットに対して休憩を割り当てるメイン処理
    def assign_midnight_slots(shift)
      slots = generate_midnight_slots   # 0:00-2:00, 2:00-4:00, 4:00-6:00 の3スロット
      rooms = break_rooms.to_a

      # --- ① グループごとにスタッフをまとめる ---
      # key: group_key（group_id or "ungrouped"）、value: [Staff, ...]
      group_staffs = staffs.group_by { |s| staff_groups[s.id.to_s].presence || "ungrouped" }

      slot_count = slots.size

      # --- ② グループごとに「各スロットに何人入れたいか」の理想人数を決める ---
      # group_slot_quota[group_key] = [slot0の予定人数, slot1..., slot2...]
      group_slot_quota = {}

      group_staffs.each do |group_key, members|
        total = members.size
        base  = total / slot_count          # 各スロットの最低人数
        extra = total % slot_count          # 余りを前から順に +1 していく

        quotas = Array.new(slot_count, base)
        extra.times do |i|
          quotas[i] += 1
        end
        group_slot_quota[group_key] = quotas
      end

      # --- ③ 割り当て用の状態 ---
      # [slot_index][room_index] => Staff or nil
      assignments    = Array.new(slot_count) { Array.new(rooms.size) }
      assigned_ids   = Set.new

      # --- ④ 第1パス：グループのクォータを尊重しながら割り当て ---
      slots.each_with_index do |slot, slot_index|
        rooms.each_with_index do |room, room_index|
          # クォータが残っているグループから探す
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
          remaining_staffs -= [staff]
        end
      end

      # --- ⑥ 割り当て結果を ShiftDetail に保存 ---
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

      # --- ⑦ どうしても入れられなかったスタッフ（主にNG条件のせい）を記録 ---
      @unassigned_staffs = remaining_staffs.map(&:name)
    end

    # 第1パス用：
    # - グループの各スロットの残クォータを見ながら
    # - そのスロット＆部屋に入れられるスタッフを1人返す
    def find_staff_for_slot_and_room(group_staffs, group_slot_quota, slot_index, room, assigned_ids)
      # グループのキー順で見ていく（順番が重要ならここでソート条件を変える）
      group_staffs.keys.each do |group_key|
        quotas = group_slot_quota[group_key]
        next if quotas[slot_index].to_i <= 0

        members = group_staffs[group_key]

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
      slots = []
      next_day = date + 1.day

      [0, 2, 4].each do |h|
        start_time = Time.zone.local(next_day.year, next_day.month, next_day.day, h)  # 翌日
        end_time   = start_time + SLOT_LENGTH

        slots << { start: start_time, end: end_time }
      end

      slots
    end
  end
end