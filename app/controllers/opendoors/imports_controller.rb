class Opendoors::ImportsController < ApplicationController

  before_filter :opendoors_only
  @admin_import = AdminImport.new

  def index
    @admin_import = AdminImport.new

    @nmi = MassImportTool.new
  end


  def create
    @ai = ArchiveImport.new

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

  def populate(settings)
    ## database values
    @source_database_host = settings[:source_database_host]
    @source_database_name = settings[:source_database_name]
    @source_database_password = settings[:source_database_password]
    @source_database_username = settings[:source_database_username]
    @source_table_prefix = settings[:source_table_prefix]
    ## define temp value for temp appended prefix for table names
    @source_temp_table_prefix = "ODimport"
    if !settings[:source_temp_table_prefix] == nil
      @source_temp_table_prefix = settings[:source_temp_table_prefix]
    end
    ## archivist values
    @archivist_email = settings[:archivist_email]
    @archivist_login = settings[:archivist_username]
    @archivist_password = settings[:archivist_password]
    ## import values
    @import_fandom = settings[:import_fandom]
    @import_name = settings[:import_name]
    @import_id = settings[:import_id]
    @import_reviews = settings[:import_reviews]
    @categories_as_sub_collections = settings[:categories_as_sub_collections]
    ## collection values
    @create_collection = settings[:create_collection]
    @new_collection_description = settings[:new_collection_description]
    @new_collection_id = settings[:new_collection_id]
    @new_collection_name = settings[:new_collection_short_name]
    @new_collection_owner = settings[:new_collection_owner]
    @new_collection_title = settings[:new_collection_title]
    @new_collection_restricted = settings[:new_collection_restricted]
    ## notification values
    @new_notification_message = settings[:new_message]
    @existing_notification_message = settings[:existing_message]

    case settings[:archive_type]
      when "efiction3"
        @source_archive_type = 3
      when "storyline18"
        @source_archive_type = 4
      when "efiction1"
        @source_archive_type = 1
      when "efiction2"
        @source_archive_type = 2
      when "otwarchive"
        @source_archive_type = 5

    end

    ## Overrides for abnormal / non-typical imports (advanced use only)
    if settings[:override_tables] == 1
      @source_users_table = settings[:source_users_table]
      @source_chapters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_chapters_table]}"
      @source_reviews_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_reviews_table]}"
      @source_stories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_stories_table]}"
      @source_users_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_users_table]}"
      @source_categories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_category_table]}"
      @source_subcategories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_subcategory_table]}"
      @source_ratings_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_ratings_table]}"
      @source_classes_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_classes_table]}"
      @source_class_types_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_class_types_table]}"
      @source_warnings_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_warnings_table]}"
      @source_characters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_characters_table]}"
      @source_challenges_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_challenges_table]}"
      @source_collections_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_collections_table]}"
      @source_hitcount_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_hitcount_table]}"
      @source_user_preferences_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_preferences_table]}"
      @source_user_profile_fields_table ="#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_profiles_fields_table]}"
      @source_user_profile_values_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_profiles_values_table]}"
      @source_user_profiles_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_profiles_table]}"
      @source_pseuds_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_pseuds_table]}"
      @source_collection_items_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_collection_items_table]}"
      @source_collection_participants_table = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_collection_participants]}"
      ## other possible source tables to be added here

    end
    if settings[:override_target_ratings] == 1
      @target_rating_1 = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_1]}" #NR
      @target_rating_2 = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_2]}" #general audiences
      @target_rating_3 = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_3]}" #teen
      @target_rating_4 = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_4]}" #Mature
      @target_rating_5 = "#{@source_temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_5]}" #Explicit
    end



  end

end
