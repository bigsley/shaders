class CreateColorSchemes < ActiveRecord::Migration
  def change
    create_table :color_schemes do |t|
      t.text :code
      t.string :name

      t.timestamps
    end
  end
end
