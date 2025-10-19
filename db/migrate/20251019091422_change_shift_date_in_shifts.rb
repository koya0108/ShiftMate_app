class ChangeShiftDateInShifts < ActiveRecord::Migration[8.0]
  def up
    change_column :shifts, :shift_date, :date, using: 'shift_date::date'
  end

  def down
    change_column :shifts, :shift_date, :datetime
  end
end
