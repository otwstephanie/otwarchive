class Api::V1::WorksController < Api::V1::BaseController
  respond_to :html, :json
  
  def show
    respond_with Work.find(params[:id])
  end
end