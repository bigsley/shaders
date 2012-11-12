class CreateColorSchemeData < ActiveRecord::Migration
  def change
    create_table :color_scheme_data do |t|
      t.integer :color_scheme_id
      t.integer :position
      t.string :color
      t.float :time

      t.timestamps
    end
  end
end
