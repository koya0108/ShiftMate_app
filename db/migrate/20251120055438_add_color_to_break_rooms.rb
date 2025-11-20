class AddColorToBreakRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :break_rooms, :color, :string
  end
end
