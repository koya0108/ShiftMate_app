class AddPreferenceToShiftDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :shift_details, :preference, :string
  end
end
