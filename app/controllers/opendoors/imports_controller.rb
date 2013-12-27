class Opendoors::ImportsController < ApplicationController

  before_filter :opendoors_only
  @admin_import = AdminImport.new

  def index
    @admin_import = AdminImport.new

    @nmi = MassImportTool.new
  end


  def create
    @nmi = MassImportTool.new
    @nmi.import_data
=begin
    unless params[:admin_import] == nil
    @import_settings = params[:admin_import]
    end
    
    @nmi = MassImportTool.new()
    @nmi.populate(@import_settings)
    #setflash; flash[:notice] = ts("Running Import Task  #{@import_settings[:import_short_name]}")
    @nmi.perform

=end
  end

end
