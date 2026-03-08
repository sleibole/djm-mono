class HomeController < ApplicationController
  layout :choose_layout

  def show
  end

  private

  def choose_layout
    logged_in? ? "application" : "landing"
  end
end
