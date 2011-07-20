class SearchController < ApplicationController

  def search
    @q = request.parameters[:q]
    logger.info("searching for #{@q}" )
  end

  def index
  end

end
