class ShiftsController < ApplicationController
  before_action :set_project
  before_action :reset_old_session, only: :step1

  def top
    @shifts = @project.shifts.order(:shift_date, :shift_category).select(:id, :shift_date, :shift_category)
  end

  def fetch
    project = Project.find(params[:project_id])
    start_date = params[:start].to_date
    end_date   = params[:end].to_date

    shifts = project.shifts.where(shift_date: start_date..end_date).order(:shift_date, :shift_category)
    render json: shifts.select(:id, :shift_date, :shift_category)
  end

  def step1
    @shift_category = params[:shift_category] || "night"
    @staffs = @project.staffs
    @break_rooms = @project.break_rooms

    data = session[:shift_data]

    if data.present?
      # セッションがあればセッションを優先
      @selected_staff_ids = data["staff_ids"] || []
      @selected_break_room_ids = data["break_room_ids"] || []
      @date = data["date"]
    else
      # 新規アクセスまたはエラー直後のparamsを復元
      @selected_staff_ids = []
      @selected_break_room_ids = []
      @date = params[:date]
    end

    render_step1_view
  end

  def step1_create
    @shift_category = params[:shift_category] || "night"

    session[:shift_data] = {
      "date" => params[:date],
      "staff_ids" => params[:staff_ids] || [],
      "break_room_ids" => params[:break_room_ids] || [],
      "shift_category" => @shift_category
    }

    # 入力チェック
    if params[:staff_ids].blank?
      flash[:alert] = "スタッフを1名以上選択してください"
      return redirect_to step1_project_shifts_path(@project, date: params[:date], shift_category: @shift_category)
    end

    # 夜勤の場合のみ休憩室の必須チェック
    if @shift_category == "night" && params[:break_room_ids].blank?
      flash[:alert] = "休憩室を1つ以上選択してください"
      return redirect_to step1_project_shifts_path(@project, date: params[:date], shift_category: @shift_category)
    end

    if @shift_category == "night"
      staff_count = params[:staff_ids].size
      break_room_count = params[:break_room_ids].size

      max_capacity = break_room_count * 3

      if staff_count > max_capacity
        flash[:alert] = "選択された休憩室ではスタッフ全員を0～6時に配置できません"
        return redirect_to step1_project_shifts_path(@project, date: params[:date], shift_category: @shift_category)
      end
    end

    session[:shift_data] = {
      "date" => params[:date],
      "staff_ids" => params[:staff_ids],
      "break_room_ids" => params[:break_room_ids],
      "shift_category" => @shift_category
    }

    redirect_to step2_project_shifts_path(@project, shift_category: @shift_category)
  end

  def edit_step1
    @shift = @project.shifts.find(params[:id])
    @shift_category = @shift.shift_category || "night"

    session[:shift_data] = {
      "date" => @shift.shift_date.strftime("%Y-%m-%d"),
      "staff_ids" => @shift.shift_details.pluck(:staff_id),
      "break_room_ids" => @shift.shift_details.pluck(:break_room_id),
      "shift_category" => @shift_category
    }

    # 日勤・夜勤どちらかのstep1に戻すかを指定
    redirect_to step1_project_shifts_path(@project, shift_id: @shift.id, shift_category: @shift_category)
  end

  def step2
    data = session[:shift_data]
    if data.blank? || data["staff_ids"].blank? || (data["shift_category"] == "night" && data["break_room_ids"].blank?)
      redirect_to step1_project_shifts_path(@project), alert: "データがありません"
      return
    end

    @shift_category = data["shift_category"] || "night"
    @staffs = @project.staffs.where(id: data["staff_ids"])
    @break_rooms = @project.break_rooms.where(id: data["break_room_ids"]) if data["break_room_ids"].present?
    @date = data["date"]
    @groups = @project.groups
    @shift = @project.shifts.find_by(id: params[:shift_id])

    # 日勤ならdayviewを描画
    if @shift_category == "day"
      render "shifts/step2_day"
    else
      render "shifts/step2_night"
    end
  end

  def update_step2
    data = session[:shift_data]
    return redirect_to step1_project_shifts_path(@project), alert: "データがありません" if data.blank?

    @shift = @project.shifts.find(params[:id])

    selected_staff_ids = data["staff_ids"].map(&:to_s)

    staffs = Staff.where(id: selected_staff_ids)
    break_rooms = data["break_room_ids"].present? ? BreakRoom.where(id: data["break_room_ids"]) : []
    date = data["date"]

    staff_groups = params[:group_ids] || {}
    preferences = params[:preferences] || {}
    shift_category = data["shift_category"] || "night"

    builder =
      if shift_category == "day"
        ShiftBuilder::DayShiftBuilder.new(
          project: @project,
          date: date,
          staffs: staffs,
          break_rooms: break_rooms,
          staff_groups: staff_groups,
          user: current_user,
          preferences: preferences
        )
      else
        ShiftBuilder::NightShiftBuilder.new(
          project: @project,
          date: date,
          staffs: staffs,
          break_rooms: break_rooms,
          staff_groups: staff_groups,
          user: current_user
        )
      end

    @shift.transaction do
      @shift.shift_details.destroy_all
      builder.rebuild(@shift)
    end

    session.delete(:shift_data)

    if builder.no_room_staffs.present?
      flash[:alert] = "休憩室の制約により休憩室に入れなかったスタッフがいます: #{builder.no_room_staffs.join(', ')}"
    end

    redirect_to project_shift_path(@project, @shift), notice: "シフトを更新しました"
  end

  def step2_create
    data = session[:shift_data]
    return redirect_to step1_project_shifts_path(@project), alert: "データがありません" if data.blank?

    @shift_category = data["shift_category"] || "night"
    selected_staff_ids = data["staff_ids"].map(&:to_s)

    # 共通データ取得
    staffs = Staff.where(id: selected_staff_ids)
    break_rooms = data["break_room_ids"].present? ? BreakRoom.where(id: data["break_room_ids"]) : []
    date = data["date"]
    staff_groups = params[:group_ids] || {}

    # 日勤用休憩希望を追加
    preferences = params[:preferences] || {}

    # builderを分岐
    builder =
      if @shift_category == "day"
        ShiftBuilder::DayShiftBuilder.new(
          project: @project,
          date: date,
          staffs: staffs,
          break_rooms: break_rooms,
          staff_groups: staff_groups,
          user: current_user,
          preferences: preferences
        )
      else
        ShiftBuilder::NightShiftBuilder.new(
          project: @project,
          date: date,
          staffs: staffs,
          break_rooms: break_rooms,
          staff_groups: staff_groups,
          user: current_user
        )
      end

    existing_shift = @project.shifts.find_by(shift_date: date, shift_category: @shift_category)

    if existing_shift # 既存シフト→上書き更新
      builder.rebuild(existing_shift)
      target_shift = existing_shift
      notice_message = "シフトを更新しました"
    else
      target_shift = builder.build
      notice_message = "シフトを作成しました"
    end

    session.delete(:shift_data)

    if builder.no_room_staffs.present?
      flash[:alert] = "休憩室制約により休憩室に入れなかったスタッフがいます: #{builder.no_room_staffs.join(', ')}"
    end

    redirect_to project_shift_path(@project, target_shift), notice: notice_message
  end

  def show
    @shift = @project.shifts.find(params[:id])
    @shift_details = @shift.shift_details.includes(:staff, :break_room)
    @break_rooms = @project.break_rooms

    if @shift.shift_category == "night"
      render "shifts/show_night"
    else
      render "shifts/show_day"
    end
  end

  def confirm
    @shift = @project.shifts.find(params[:id])
    @shift_details = @shift.shift_details.includes(:staff, :break_room)

    overlaps = overlap_messages(@shift_details)

    # 休憩室重複チェック
    if overlaps.any?
      @shift.update(status: :draft)

      flash[:alert] = "休憩室が重複しています：\n" + overlaps.join("\n")
      return redirect_to project_shift_path(@project, @shift)
    end

    respond_to do |format|
      format.html do
        if @shift.shift_category == "day"
          render "shifts/confirm_day"
        else
          render "shifts/confirm_night"
        end
      end

      format.pdf do
        pdf_template =
          if @shift.shift_category == "day"
            "shifts/pdf_day"
          else
            "shifts/pdf_night"
          end

        render pdf: "shift_#{@shift.id}",
               template: pdf_template,
               formats: [ :html ],
               layout: "pdf",
               page_size: "A4",
               orientation: "Landscape",
               disposition: "inline"
      end
    end
  end

  def finalize
    @shift = @project.shifts.find(params[:id])
    @shift.update!(status: :finalized)
    redirect_to confirm_project_shift_path(@project, @shift), notice: "シフトを確定しました"
  end

  def reopen
    @shift = @project.shifts.find(params[:id])
    @shift.update!(status: :draft)
    redirect_to project_shift_path(@project, @shift)
  end

  def destroy
    @shift = @project.shifts.find(params[:id])
    @shift.destroy
    redirect_to project_shift_top_path(@project), notice: "シフトを削除しました"
  end

  private

  def render_step1_view
    if @shift_category == "day"
      render "shifts/step1_day"
    else
      render "shifts/step1_night"
    end
  end

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def reset_old_session
    return unless session[:shift_data].present?

    prev_date = session[:shift_data]["date"]
    # URLのDateパラメータが前回と異なる場合、セッションをリセット
    if params[:date].present? && prev_date != params[:date]
      session.delete(:shift_data)
    end
  end

  # 同じ休憩室で時間重複していないかチェック
  def has_overlap_breaks?(details)
    # スロット範囲（22時〜8時 → 内部的には 22..31 の 10 スロット）
    slot_range = (22..31)

    # スロットごとに { break_room_id => count } を管理
    slot_room_counts = {}

    slot_range.each do |slot|
      slot_room_counts[slot] = Hash.new(0)
    end

    details.each do |d|
      next if d.break_room_id.nil?

      # 休憩開始と終了の “表示上の時刻” を正規化（夜勤だけ24時間加算）
      s = normalize_hour_for_check(d.rest_start_time)
      e = normalize_hour_for_check(d.rest_end_time)

      # 22〜8時の各1時間スロットに滞在するか判定
      slot_range.each do |slot|
        if s <= slot && slot < e
          slot_room_counts[slot][d.break_room_id] += 1
          return true if slot_room_counts[slot][d.break_room_id] > 1
        end
      end
    end

    false
  end

  def normalize_hour_for_check(time)
    h = time.hour
    h += 24 if h < 9 # 夜勤ロジック：翌日0〜8時は 24〜32
    h
  end

  # どのスロットが重複しているかを返す
  def find_overlap_slots(details)
    slot_range = (22..31)

    slot_room_counts = {}
    slot_range.each { |slot| slot_room_counts[slot] = Hash.new(0) }

    overlaps = []

    details.each do |d|
      next if d.break_room_id.nil?

      s = normalize_hour_for_check(d.rest_start_time)
      e = normalize_hour_for_check(d.rest_end_time)

      slot_range.each do |slot|
        if s <= slot && slot < e
          slot_room_counts[slot][d.break_room_id] += 1

          if slot_room_counts[slot][d.break_room_id] == 2
            overlaps << {
              slot: slot,
              break_room_id: d.break_room_id
            }
          end
        end
      end
    end

    overlaps
  end

  def overlap_messages(details)
    overlaps = find_overlap_slots(details)

    return [] if overlaps.empty?

    overlaps.map do |o|
      room = BreakRoom.find(o[:break_room_id])
      start_h = o[:slot] % 24
      end_h = (o[:slot] + 1) % 24

      "#{room.name}:#{format('%02d:00', start_h)}～#{format('%02d:00', end_h)}"
    end
  end
end
