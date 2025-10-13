class StaffsController < ApplicationController
  before_action :set_project
  before_action :set_staff, only: [ :edit, :update, :destroy ]

  def index
    # ransack用検索オブジェクトを作成
    @q = @project.staffs.ransack(params[:q])
    # 検索結果をページネーション付きで取得
    @staffs = @q.result(distinct: true).page(params[:page]).per(20)
  end

  def new
    @staff = @project.staffs.new
  end

  def create
    @staff = @project.staffs.new(staff_params)
    if @staff.save
      redirect_to project_staffs_path(@project), notice: "スタッフを登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @staff.update(staff_params)
      redirect_to project_staffs_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @staff.destroy
    redirect_to project_staffs_path(@project), notice: "スタッフを削除しました"
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_staff
    @staff = @project.staffs.find(params[:id])
  end

  def staff_params
    params.require(:staff).permit(:name, :position, :comment)
  end
end
