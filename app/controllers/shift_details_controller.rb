class ShiftDetailsController < ApplicationController
  before_action :set_shift_detail

  def update
    attrs = shift_detail_params.to_h

    if attrs["rest_start_time"].present?
      start_time = build_time_from_string(attrs["rest_start_time"])
      attrs["rest_start_time"] = start_time

      # 日勤・夜勤で休憩時間を切り替え
      shift_type = @shift_detail.shift.shift_category
      duration = shift_type == "day" ? 1.hour : 2.hours

      attrs["rest_end_time"] = start_time + duration
    end

    if @shift_detail.update(attrs)
      render json: { success: true, detail: to_detail_json(@shift_detail) }
    else
      # DBの正しい状態に戻す
      @shift_detail.reload
      render json: {
        success: false,
        errors: @shift_detail.errors.full_messages,
        detail: to_detail_json(@shift_detail)
      }, status: :unprocessable_entity
    end
  end

  private

  def set_shift_detail
    @shift_detail = ShiftDetail.find(params[:id])
  end

  def shift_detail_params
    permitted = params.require(:shift_detail).permit(:rest_start_time, :break_room_id, :group_id, :comment)
    # 未所属は nil に統一する
    permitted[:group_id] = nil if permitted[:group_id].blank? || permitted[:group_id].to_i == 0
    permitted
  end

  # 正確なtimeに変換(日勤・夜勤両対応)
  def build_time_from_string(time_str)
    base_date = @shift_detail.shift.shift_date
    shift_type = @shift_detail.shift.shift_category

    parts = time_str.to_s.split(":").map(&:to_i)
    hour = parts[0]
    min = parts[1] || 0

    if shift_type == "night"
      if hour < 9
        base_date += 1.day
      end
    else
      if hour >= 24
        base_date += 1.day
        hour -= 24
      end
    end

    Time.zone.local(base_date.year, base_date.month, base_date.day, hour, min)
  end

  # JSONレスポンス
  def to_detail_json(detail)
    base_date = detail.shift.shift_date
    s = detail.rest_start_time.in_time_zone("Tokyo")
    e = detail.rest_end_time.in_time_zone("Tokyo")

    rest_start_hour =
      if s.to_date > base_date.to_date
        s.hour + 24 + (s.min / 60.0)
      else
        s.hour + (s.min / 60.0)
      end

    rest_end_hour =
      if e.to_date > base_date.to_date
        e.hour + 24 + (e.min / 60.0)
      else
        e.hour + (e.min / 60.0)
      end

    {
      id: detail.id,
      rest_start_time: rest_start_hour,
      rest_end_time: rest_end_hour,
      break_room_id: detail.break_room_id,
      break_room_color: detail.break_room&.color,
      comment: detail.comment
    }
  end
end
