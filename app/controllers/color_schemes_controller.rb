class ColorSchemesController < ApplicationController
  def index
  end

  def show
  end

  def new
  end

  def create
    color_scheme = ColorScheme.create(name: params[:name])

    params[:color_scheme_data].to_a.sort {|x, y| x[0].to_i <=> y[0].to_i}.each do |datum|
      color_scheme.color_scheme_data.create(color: datum["color"], time: datum["time"].to_f)
    end
  end
end
