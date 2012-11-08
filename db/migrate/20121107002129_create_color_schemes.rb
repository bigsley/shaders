class CreateColorSchemes < ActiveRecord::Migration
  def change
    create_table :color_schemes do |t|

      t.timestamps
    end
  end
end
