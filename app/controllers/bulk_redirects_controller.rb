class BulkRedirectsController < ApplicationController
  def new
      @bulk_redirect = BulkRedirect.new
  end

  def create
    @bulk_redirect = BulkRedirect.new(params[:bulk_redirect])
    if @bulk_redirect.save
      redirect_to root_url, notice: "Works updated successfully."
    else
      render :new
    end
  end
end