class Api::V1::WorksController < Api::V1::BaseController
  respond_to :html, :json, :xml
  
  def show
    @work = Work.find_by_id(params[:id])
  end
end