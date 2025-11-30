module ShiftServices
  class GroupHourCounter
    def initialize(shift)
      @shift = shift
      @details = shift.shift_details.includes(:staff, :break_room, :group)
      @times = (11 * 60...17 * 60).step(30).map { |m| m / 60.0 }  # 11:00〜16:30
    end

    def call
      # グループごとの総人数
      group_members_count = @details.group_by(&:group_id).transform_values(&:count)

      # 休憩中人数カウント
      break_counts = Hash.new { |h, k| h[k] = {} }

      group_members_count.keys.each do |gid|
        @times.each do |h|
          break_counts[gid][format_time(h)] = 0
        end
      end

      @details.each do |detail|
        gid = detail.group_id
        next if gid.nil?

        start = detail.rest_start_time
        stop  = detail.rest_end_time

        @times.each do |h|
          time = to_time(h, detail.shift.shift_date)
          if (start...stop).cover?(time)
            break_counts[gid][format_time(h)] += 1
          end
        end
      end

      # 勤務者数 = 総人数 − 休憩人数
      work_counts = {}

      group_members_count.each do |gid, total|
        work_counts[gid] = {}
        @times.each do |h|
          key = format_time(h)
          rest_count = break_counts[gid][key] || 0
          work_counts[gid][key] = total - rest_count
        end
      end

      work_counts
    end

    private

    def to_time(h, date)
      hour = h.floor
      min  = ((h - hour) * 60).to_i
      Time.zone.local(date.year, date.month, date.day, hour, min)
    end

    def format_time(h)
      hour = h.floor
      min  = ((h - hour) * 60).to_i
      format("%02d:%02d", hour, min)
    end
  end
end
