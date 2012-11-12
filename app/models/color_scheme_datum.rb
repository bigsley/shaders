class ColorSchemeDatum < ActiveRecord::Base
  attr_accessible :color, :time, :position

  belongs_to :color_scheme
  acts_as_list :scope => :color_scheme
end
