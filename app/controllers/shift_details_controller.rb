class ShiftDetailsController < ApplicationController
  before_action :set_shift_detail

  def update
    attrs = shift_detail_params.to_h

    if attrs["rest_start_time"].present?
      start_time = build_time(attrs["rest_start_time"].to_i)
      attrs["rest_start_time"] = start_time
      attrs["rest_end_time"] = start_time + 2.hours
    end

    if @shift_detail.update(attrs)
      result =  to_detail_json(@shift_detail)
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

  # "26" → 翌日の 2:00 に変換
  def build_time(hour_value)
    base_date = @shift_detail.shift.shift_date

    if hour_value >= 24
      date = base_date + 1.day
      hour = hour_value -24
    else
      date = base_date
      hour = hour_value
    end

    Time.zone.local(date.year, date.month, date.day, hour)
  end

  # JSONレスポンス
  def to_detail_json(detail)
    base_date = detail.shift.shift_date.in_time_zone("Tokyo")
    s = detail.rest_start_time.in_time_zone("Tokyo")
    e = detail.rest_end_time.in_time_zone("Tokyo")

    rest_start_hour =
      if s.to_date > base_date.to_date
        s.hour + 24
      else
        s.hour
      end

    rest_end_hour =
      if e.to_date > base_date.to_date
        e.hour + 24
      else
        e.hour
      end

    {
      id: detail.id,
      rest_start_time: rest_start_hour,
      rest_end_time: rest_end_hour,
      break_room_id: detail.break_room_id,
      comment: detail.comment
    }
  end
end
