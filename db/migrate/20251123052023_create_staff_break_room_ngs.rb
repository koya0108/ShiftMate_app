class CreateStaffBreakRoomNgs < ActiveRecord::Migration[8.0]
  def change
    create_table :staff_break_room_ngs do |t|
      t.references :staff, null: false, foreign_key: true
      t.references :break_room, null: false, foreign_key: true

      t.timestamps
    end

    add_index :staff_break_room_ngs, [ :staff_id, :break_room_id ], unique: true
  end
end
