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

  def index
    @works = Works.order(:title)
    respond_to do |format|
      format.html
      format.csv { send_data @products.to_csv }
      format.xls # { send_data @products.to_csv(col_sep: "\t") }
    end
  end
end