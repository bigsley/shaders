class ColorScheme < ActiveRecord::Base
  attr_accessible :name
  has_many :color_scheme_data, order: 'position'
end
