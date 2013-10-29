class ArchiveImportsController < ApplicationController
  # GET /archive_imports
  # GET /archive_imports.json
  def index
    @archive_imports = ArchiveImport.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @archive_imports }
    end
  end

  # GET /archive_imports/1
  # GET /archive_imports/1.json
  def show
    @archive_import = ArchiveImport.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @archive_import }
    end
  end

  # GET /archive_imports/new
  # GET /archive_imports/new.json
  def new
    @archive_import = ArchiveImport.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @archive_import }
    end
  end

  # GET /archive_imports/1/edit
  def edit
    @archive_import = ArchiveImport.find(params[:id])
  end

  # POST /archive_imports
  # POST /archive_imports.json
  def create
    @archive_import = ArchiveImport.new(params[:archive_import])

    respond_to do |format|
      if @archive_import.save
        format.html { redirect_to @archive_import, notice: 'Archive import was successfully created.' }
        format.json { render json: @archive_import, status: :created, location: @archive_import }
      else
        format.html { render action: "new" }
        format.json { render json: @archive_import.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /archive_imports/1
  # PUT /archive_imports/1.json
  def update
    @archive_import = ArchiveImport.find(params[:id])

    respond_to do |format|
      if @archive_import.update_attributes(params[:archive_import])
        format.html { redirect_to @archive_import, notice: 'Archive import was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @archive_import.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /archive_imports/1
  # DELETE /archive_imports/1.json
  def destroy
    @archive_import = ArchiveImport.find(params[:id])
    @archive_import.destroy

    respond_to do |format|
      format.html { redirect_to archive_imports_url }
      format.json { head :no_content }
    end
  end
end
