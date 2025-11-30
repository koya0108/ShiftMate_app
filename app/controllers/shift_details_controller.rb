class ShiftDetailsController < ApplicationController
  before_action :set_shift_detail

  def update
    attrs = shift_detail_params.to_h

    # ▼ rest_start_time の変更がある場合は rest_end_time を再計算
    if attrs["rest_start_time"].present?
      start_time = build_time_from_string(attrs["rest_start_time"])
      attrs["rest_start_time"] = start_time

      shift_type = @shift_detail.shift.shift_category
      duration = shift_type == "day" ? 1.hour : 2.hours
      attrs["rest_end_time"] = start_time + duration
    end

    @shift_detail.update(attrs)
    @shift = @shift_detail.shift

    # 勤務人数の計算
    @group_counts = ShiftServices::GroupHourCounter.new(@shift).call
    @times = (11 * 60...17 * 60).step(30).map { |m| m / 60.0 }

    # どの group の行を更新すべきか
    group = @shift_detail.group
    group_id = group&.id || "none"

    # group_row の HTML を生成（ここが重要）
    group_row_html = render_to_string(
      partial: "shifts/group_row",
      formats: [ :html ],
      locals: {
        group: group,
        times: @times,
        group_counts: @group_counts
      }
    )

    respond_to do |format|
      format.json do
        if @shift_detail.errors.empty?
          render json: {
            success: true,
            detail: to_detail_json(@shift_detail),
            group_id: group_id,
            group_row_html: group_row_html
          }
        else
          render json: {
            success: false,
            errors: @shift_detail.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
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
    {
      id: detail.id,
      rest_start_time: detail.rest_start_time.strftime("%H:%M"),
      rest_end_time:   detail.rest_end_time.strftime("%H:%M"),
      break_room_id: detail.break_room_id,
      break_room_color: detail.break_room&.color,
      comment: detail.comment
    }
  end
end
