class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:privacy, :terms, :contact]

  def privacy
  end

  def terms
  end

  def contact
  end
end
