class BreakRoomsController < ApplicationController
  before_action :set_project
  before_action :set_break_room, only: [ :edit, :update, :destroy ]

  def index
    @break_rooms = @project.break_rooms
  end

  def new
    @break_room = @project.break_rooms.new
  end

  def create
    @break_room = @project.break_rooms.new(break_room_params)
    if @break_room.save
      redirect_to project_break_rooms_path(@project)
    else
      @break_rooms = @project.break_rooms
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def destroy
    @break_room.destroy
    redirect_to project_break_rooms_path(@project)
  end

  def update
    if @break_room.update(break_room_params)
      redirect_to project_break_rooms_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_break_room
    @break_room = @project.break_rooms.find(params[:id])
  end

  def break_room_params
    params.require(:break_room).permit(:name, :color)
  end
end
